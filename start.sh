#!/bin/bash

# Percorso principale
base_dir="/mnt/c/Users/mmatteis/Documents/Sources"
# Versione di default per Ansible virtualenv
base_ansible="11.2.0"
# Percorso per il file nascosto che memorizza l'ultima directory usata
last_used_file="$HOME/.last_used_directory"

# Trova tutte le directory di secondo livello (sottolivelli)
mapfile -t dirs < <(find "$base_dir" -mindepth 2 -maxdepth 2 -type d | sort)

# Se non ci sono directory, esci
if [ ${#dirs[@]} -eq 0 ]; then
  echo "Nessuna directory trovata in $base_dir"
  exit 1
fi

clear

# Carica l'ultima directory usata, se esiste
if [ -f "$last_used_file" ]; then
  last_used_dir=$(<"$last_used_file")
else
  last_used_dir=""
fi

# Numero di colonne desiderate
num_cols=3

# Assicura che l'associativo sia inizializzato vuoto
declare -A grouped_dirs=()

# Raggruppa le directory per primo livello
for dir in "${dirs[@]}"; do
  first_level_dir=$(basename "$(dirname "$dir")")
  grouped_dirs["$first_level_dir"]+="$dir"$'\n'
done

# Calcola la larghezza massima globale per avere colonne uniformi
global_max_len=0
for dir in "${dirs[@]}"; do
  sub_dir=$(basename "$dir")
  len=${#sub_dir}
  (( len > global_max_len )) && global_max_len=$len
done
global_col_width=$((global_max_len + 8))

echo -e "\nSeleziona una directory:\n"

counter=0

# Ordina le chiavi dei gruppi per stampa ordinata
for first_level_dir in $(printf "%s\n" "${!grouped_dirs[@]}" | sort); do
  echo -e "\e[1;38;5;214m$first_level_dir\e[0m"

  # Leggi le directory del gruppo in array
  IFS=$'\n' read -r -d '' -a group <<< "${grouped_dirs[$first_level_dir]}"$'\0'

  # Stampa a colonne (con colori e padding uniformi)
  for ((i=0; i<${#group[@]}; i++)); do
    dir="${group[$i]}"
    sub_dir=$(basename "$dir")

    # Colori per ultima directory
    if [ "$dir" == "$last_used_dir" ]; then
      label_color="\e[32m"
      label_reset="\e[0m"
      label_text="$counter) $sub_dir"
    else
      label_color=""
      label_reset=""
      label_text="$counter) $sub_dir"
    fi

    # Calcola padding su versione "pulita"
    plain_len=${#label_text}
    padding=$((global_col_width - plain_len))
    ((padding < 1)) && padding=1

    # Stampa colonna colorata e allineata
    echo -ne "${label_color}${label_text}${label_reset}"
    printf "%${padding}s" ""

    # A capo dopo num_cols colonne
    if (( (i + 1) % num_cols == 0 )); then
      echo ""
    fi

    ((counter++))
  done

  echo -e "\n"
done
# Disattiva eventuale virtualenv
deactivate 2>/dev/null

read -p "Digita il numero della directory (premi Invio per l'ultima usata): " choice
chosen_dir=""

if [ -z "$choice" ]; then
  if [ -n "$last_used_dir" ] && [ -d "$last_used_dir" ]; then
    chosen_dir="$last_used_dir"
  else
    echo "Nessuna directory selezionata in precedenza o directory non trovata."
    exit 1
  fi
else
  if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 0 ] && [ "$choice" -lt "$counter" ]; then
    chosen_dir="${dirs[$choice]}"
    echo "$chosen_dir" > "$last_used_file"
  else
    echo "Scelta non valida."
    exit 1
  fi
fi

if [ -n "$chosen_dir" ]; then
  cd "$chosen_dir" || exit 1
fi

# Controlla la presenza del file ansible.cfg e attiva il virtualenv solo se esiste
if [ -f "$chosen_dir/ansible.cfg" ]; then
  if [ -z "$1" ]; then
    workon "ansible$base_ansible"
  else
    workon "ansible$1"
  fi
else
  echo "Virtualenv Ansible non attivato."
fi

echo ""