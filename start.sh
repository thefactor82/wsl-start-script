#!/bin/bash

# Percorso principale
base_dir="/mnt/c/Users/mmatteis/Documents/Sources"
# Versione di default per Ansible virtualenv
base_ansible="9.2.0"
# Percorso per il file nascosto che memorizza l'ultima directory usata
last_used_file="$HOME/.last_used_directory"

# Trova tutte le directory di secondo livello (sottolivelli)
dirs=($(find "$base_dir" -mindepth 2 -maxdepth 2 -type d))

# Carica l'ultima directory usata, se esiste
if [ -f "$last_used_file" ]; then
  last_used_dir=$(<"$last_used_file")
else
  last_used_dir=""
fi

# Mostra l'elenco delle directory raggruppate con intestazioni per il primo livello
echo -e "\nSeleziona una directory:\n"
previous_first_level_dir=""
counter=0

for dir in "${dirs[@]}"; do
  # Estrai la directory di primo livello e il nome della sottocartella
  first_level_dir=$(basename "$(dirname "$dir")")
  sub_dir=$(basename "$dir")

  # Se la directory di primo livello è cambiata, stampa una riga vuota e l'intestazione
  if [ "$first_level_dir" != "$previous_first_level_dir" ]; then
    if [ -n "$previous_first_level_dir" ]; then
      echo ""  # Riga vuota tra i gruppi
    fi
    # Stampa il titolo della cartella principale in "arancione" e grassetto
    echo -e "\e[1;38;5;214m$first_level_dir\e[0m"
    previous_first_level_dir="$first_level_dir"
  fi

  # Evidenzia l'ultima directory usata in verde
  if [ "$dir" == "$last_used_dir" ]; then
    echo -e "\e[32m$counter) $sub_dir (ultima usata)\e[0m"
  else
    echo "$counter) $sub_dir"
  fi

  # Incrementa il contatore
  ((counter++))
done

echo ""  # Riga vuota alla fine dell'elenco

# Disattiva ansible env a prescindere (senza errori in output)
deactivate 2>/dev/null

# Richiedi l'input all'utente
read -p "Digita il numero della directory (premi Invio per l'ultima usata): " choice

# Variabile per memorizzare la directory scelta
chosen_dir=""

# Se l'input è vuoto, usa l'ultima directory selezionata, se esiste
if [ -z "$choice" ]; then
  if [ -n "$last_used_dir" ] && [ -d "$last_used_dir" ]; then
    chosen_dir="$last_used_dir"
  else
    echo "Nessuna directory selezionata in precedenza o directory non trovata."
    exit 1
  fi
else
  # Verifica che l'input sia un numero valido e seleziona la directory
  if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 0 ] && [ "$choice" -lt "$counter" ]; then
    chosen_dir="${dirs[$choice]}"
    echo "$chosen_dir" > "$last_used_file"
  else
    echo "Scelta non valida."
    exit 1
  fi
fi

# Effettua il cd nella directory selezionata se è stata scelta una directory
if [ -n "$chosen_dir" ]; then
  cd "$chosen_dir"
  echo "Ora sei in: $(pwd)"
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

#kinit mmatteis@TOPTIERRA.IT