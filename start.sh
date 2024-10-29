#!/bin/bash

# Percorso principale
base_dir="/mnt/c/Users/mmatteis/Documents/Sources"
# Percorso per il file nascosto che memorizza l'ultima directory usata
last_used_file="$HOME/.last_used_directory"

# Trova tutte le directory di primo e secondo livello
dirs=($(find "$base_dir" -mindepth 2 -maxdepth 2 -type d))

# Carica l'ultima directory usata, se esiste
if [ -f "$last_used_file" ]; then
  last_used_dir=$(<"$last_used_file")
else
  last_used_dir=""
fi

# Mostra l'elenco numerato delle directory di secondo livello con righe vuote per i gruppi
echo -e "\nSeleziona una directory:\n"
previous_first_level_dir=""

for i in "${!dirs[@]}"; do
  # Estrai la directory di primo livello dalla directory corrente
  first_level_dir=$(dirname "${dirs[$i]}") 

  # Se la directory di primo livello è cambiata, aggiungi una riga vuota
  if [ "$first_level_dir" != "$previous_first_level_dir" ] && [ -n "$previous_first_level_dir" ]; then
    echo ""  # Riga vuota tra i gruppi
  fi

  # Se la directory corrente è l'ultima usata, evidenziala in verde
  if [ "${dirs[$i]}" == "$last_used_dir" ]; then
    echo -e "\e[32m$i) ${dirs[$i]#$base_dir/} (ultima usata)\e[0m"
  else
    echo "$i) ${dirs[$i]#$base_dir/}"
  fi

  # Aggiorna la directory di primo livello precedente
  previous_first_level_dir="$first_level_dir"
done

echo ""  # Riga vuota alla fine della lista

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
  fi
else
  # Verifica che l'input sia un numero valido e seleziona la directory
  if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 0 ] && [ "$choice" -lt "${#dirs[@]}" ]; then
    # Memorizza la directory scelta nel file nascosto
    chosen_dir="${dirs[$choice]}"
    echo "$chosen_dir" > "$last_used_file"
  else
    echo "Scelta non valida."
  fi
fi

# Effettua il cd nella directory selezionata se è stata scelta una directory
if [ -n "$chosen_dir" ]; then
  cd "$chosen_dir"
  echo "Ora sei in: $(pwd)"
fi

# Attiva ansible virtualenv
if [ -z "$1" ]
then
    workon ansible9.2.0
else
    workon ansible$1
fi

#kinit mmatteis@TOPTIERRA.IT
