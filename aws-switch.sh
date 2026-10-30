# shellcheck shell=bash
# aws-switch — login SSO nativo + scelta account/ruolo con fzf + export credenziali
#
# NON va eseguito, va "sourced": la funzione esporta le variabili nella shell corrente.
# Installazione: vedi in fondo al file.
#
# Dipendenze: aws-cli v2, fzf, jq
# Prerequisito: un blocco [sso-session Tierra] in ~/.aws/config, es:
#
#   [sso-session Tierra]
#   sso_start_url = https://tierradirectory.awsapps.com/start
#   sso_region = eu-west-1
#   sso_registration_scopes = sso:account:access

# ------------------------------------------------------------------
# Configurazione (sovrascrivibile via env)
# ------------------------------------------------------------------
: "${AWS_SWITCH_SSO_SESSION:=Tierra}"
# Region esportata per i comandi successivi (es. terraform)
: "${AWS_SWITCH_DEFAULT_REGION:=eu-west-1}"

aws-switch() {
    # --- controllo dipendenze ---------------------------------------------
    local missing=()
    for cmd in aws fzf jq; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    if ((${#missing[@]})); then
        echo "aws-switch: comandi mancanti: ${missing[*]}" >&2
        echo "  installa con: sudo apt install ${missing[*]}" >&2
        return 1
    fi

    local sso_session="$AWS_SWITCH_SSO_SESSION"

    # --- leggo start_url e region dal blocco [sso-session ...] ------------
    local start_url sso_region
    start_url="$(aws configure get "sso_start_url" --sso-session "$sso_session" 2>/dev/null)"
    sso_region="$(aws configure get "sso_region" --sso-session "$sso_session" 2>/dev/null)"

    if [[ -z "$start_url" || -z "$sso_region" ]]; then
        echo "aws-switch: sso-session '$sso_session' non trovato in ~/.aws/config" >&2
        echo "  imposta AWS_SWITCH_SSO_SESSION col nome corretto, o verifica il config." >&2
        return 1
    fi

    # --- token SSO valido? altrimenti login nativo (apre il browser) ------
    local access_token
    access_token="$(_aws_switch_get_token "$start_url")"
    if [[ -z "$access_token" ]]; then
        echo "aws-switch: sessione SSO assente o scaduta, eseguo il login..." >&2
        # --use-device-code: in WSL è più affidabile del redirect su 127.0.0.1
        if ! aws sso login --sso-session "$sso_session" --use-device-code; then
            echo "aws-switch: login SSO fallito" >&2
            return 1
        fi
        access_token="$(_aws_switch_get_token "$start_url")"
        if [[ -z "$access_token" ]]; then
            echo "aws-switch: impossibile leggere il token SSO dopo il login" >&2
            return 1
        fi
    fi

    # --- scelta account ----------------------------------------------------
    echo "aws-switch: recupero elenco account..." >&2
    local accounts
    accounts="$(aws sso list-accounts \
        --access-token "$access_token" \
        --region "$sso_region" \
        --output json 2>/dev/null \
        | jq -r '.accountList | sort_by(.accountName) | .[] | "\(.accountId)\t\(.accountName)\t\(.emailAddress)"')"

    if [[ -z "$accounts" ]]; then
        echo "aws-switch: nessun account disponibile (token non valido?)" >&2
        return 1
    fi

    local account_line
    account_line="$(printf '%s\n' "$accounts" \
        | fzf --with-nth=2,3 --delimiter='\t' \
              --prompt='Account > ' \
              --header='Seleziona un account AWS')" \
        || { echo "aws-switch: selezione annullata" >&2; return 1; }

    local account_id account_name
    account_id="$(cut -f1 <<<"$account_line")"
    account_name="$(cut -f2 <<<"$account_line")"
    [[ -z "$account_id" ]] && { echo "aws-switch: nessun account selezionato" >&2; return 1; }

    # --- scelta ruolo ------------------------------------------------------
    local roles
    roles="$(aws sso list-account-roles \
        --access-token "$access_token" \
        --account-id "$account_id" \
        --region "$sso_region" \
        --output json 2>/dev/null \
        | jq -r '.roleList | sort_by(.roleName) | .[].roleName')"

    if [[ -z "$roles" ]]; then
        echo "aws-switch: nessun ruolo disponibile per l'account $account_name" >&2
        return 1
    fi

    local role_name
    if [[ "$(wc -l <<<"$roles")" -eq 1 ]]; then
        role_name="$roles"   # un solo ruolo -> selezione automatica
    else
        role_name="$(printf '%s\n' "$roles" \
            | fzf --prompt='Ruolo > ' \
                  --header="Ruoli per $account_name ($account_id)")" \
            || { echo "aws-switch: selezione annullata" >&2; return 1; }
    fi
    [[ -z "$role_name" ]] && { echo "aws-switch: nessun ruolo selezionato" >&2; return 1; }

    # --- recupero credenziali temporanee ----------------------------------
    local creds
    creds="$(aws sso get-role-credentials \
        --access-token "$access_token" \
        --account-id "$account_id" \
        --role-name "$role_name" \
        --region "$sso_region" \
        --output json 2>/dev/null)"

    if [[ -z "$creds" ]]; then
        echo "aws-switch: impossibile ottenere le credenziali per $role_name@$account_name" >&2
        return 1
    fi

    local akid secret token expiration
    akid="$(jq -r '.roleCredentials.accessKeyId' <<<"$creds")"
    secret="$(jq -r '.roleCredentials.secretAccessKey' <<<"$creds")"
    token="$(jq -r '.roleCredentials.sessionToken' <<<"$creds")"
    expiration="$(jq -r '.roleCredentials.expiration' <<<"$creds")"

    if [[ -z "$akid" || "$akid" == "null" ]]; then
        echo "aws-switch: credenziali non valide" >&2
        return 1
    fi

    # --- export nella shell corrente ---------------------------------------
    export AWS_ACCESS_KEY_ID="$akid"
    export AWS_SECRET_ACCESS_KEY="$secret"
    export AWS_SESSION_TOKEN="$token"
    export AWS_DEFAULT_REGION="$AWS_SWITCH_DEFAULT_REGION"
    export AWS_REGION="$AWS_SWITCH_DEFAULT_REGION"
    # informative, comode per il prompt
    export AWS_SWITCH_ACCOUNT_NAME="$account_name"
    export AWS_SWITCH_ACCOUNT_ID="$account_id"
    export AWS_SWITCH_ROLE_NAME="$role_name"

    local exp_human=""
    if [[ "$expiration" =~ ^[0-9]+$ ]]; then
        exp_human="$(date -d "@$((expiration / 1000))" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)"
    fi

    echo "aws-switch: credenziali esportate ✓" >&2
    echo "  account : $account_name ($account_id)" >&2
    echo "  ruolo   : $role_name" >&2
    echo "  region  : $AWS_SWITCH_DEFAULT_REGION" >&2
    [[ -n "$exp_human" ]] && echo "  scadenza: $exp_human" >&2
}

# ------------------------------------------------------------------
# Helper: ritorna un access token SSO valido dalla cache, altrimenti vuoto
# ------------------------------------------------------------------
_aws_switch_get_token() {
    local start_url="$1"
    local cache_dir="$HOME/.aws/sso/cache"
    [[ -d "$cache_dir" ]] || { echo ""; return 0; }

    local now_epoch
    now_epoch="$(date -u +%s)"

    local f
    for f in "$cache_dir"/*.json; do
        [[ -e "$f" ]] || continue
        jq -e \
            --arg url "$start_url" \
            --argjson now "$now_epoch" \
            '(.startUrl == $url)
             and (.accessToken != null)
             and ((.expiresAt | sub("\\.[0-9]+"; "") | sub("UTC$"; "Z") | fromdateiso8601) > $now)' \
            "$f" >/dev/null 2>&1 || continue
        jq -r '.accessToken' "$f"
        return 0
    done
    echo ""
}

# ------------------------------------------------------------------
# (opzionale) ripulisce le variabili AWS dalla shell corrente
# ------------------------------------------------------------------
aws-switch-clear() {
    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
    unset AWS_SWITCH_ACCOUNT_NAME AWS_SWITCH_ACCOUNT_ID AWS_SWITCH_ROLE_NAME
    echo "aws-switch: variabili AWS rimosse dalla shell" >&2
}

# ------------------------------------------------------------------
# Indicatore per il prompt (PS1)
# Stampa es. "(aws: shared-services-dev/AdministratorAccess) " se attivo.
# ------------------------------------------------------------------
aws_switch_prompt() {
    [[ -n "$AWS_SWITCH_ACCOUNT_NAME" ]] || return 0
    printf '(aws: %s/%s) ' "$AWS_SWITCH_ACCOUNT_NAME" "${AWS_SWITCH_ROLE_NAME:-?}"
}

# Aggancia l'indicatore a PS1 una sola volta (idempotente).
# Colore giallo per renderlo visibile prima di un apply.
_aws_switch_install_prompt() {
    case "$PS1" in
        *aws_switch_prompt*) return 0 ;;  # già installato
    esac
    # \[\e[33m\] = giallo, \[\e[0m\] = reset (racchiusi in \[ \] per non sballare la larghezza)
    PS1='\[\e[33m\]$(aws_switch_prompt)\[\e[0m\]'"$PS1"
}
_aws_switch_install_prompt

# ==================================================================
# INSTALLAZIONE (una tantum), da WSL:
#
#   mkdir -p ~/.local/bin
#   cp /mnt/c/Users/mmatteis/Documents/Sources/IT/aws/scripts/aws-switch.sh ~/.local/bin/
#   echo 'source ~/.local/bin/aws-switch.sh' >> ~/.bashrc
#   source ~/.bashrc
#
# Uso:
#   aws-switch          # scegli account -> ruolo -> credenziali esportate
#   terraform plan      # usa subito le credenziali nella stessa shell
#   aws-switch-clear    # (opzionale) pulisce le variabili e l'indicatore
#
# Dopo 'aws-switch' il prompt mostra, es:  (aws: shared-services-dev/AdministratorAccess)
# ==================================================================
