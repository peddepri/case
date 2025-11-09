#!/bin/bash

# Script para remover emojis de arquivos .sh e .md

echo "Removendo emojis de arquivos do projeto..."

# Lista dos emojis mais comuns encontrados no projeto
EMOJIS=(
  "🚀" "📊" "🔍" "📋" "🔧" "📝" "🎯" "" "💰" "🔥" "" "🏗️" 
  "📈" "🎬" "🚦" "🎉" "💾" "" "🌟" "📱" "💻" "🖥️" "🎮" "🛠️" 
  "🔬" "🧪" "💡" "" "🎛️" "🎚️" "🔊" "🎵" "🎶" "🎤" "🎧" "🎼" 
  "🎹" "🥁" "🎺" "🎸" "🎻" "👀" "📱" ""
)

# Função para remover emojis de um arquivo
remove_emojis() {
  local file="$1"
  echo "Processando: $file"
  
  # Criar backup
  cp "$file" "$file.backup"
  
  # Remover cada emoji
  for emoji in "${EMOJIS[@]}"; do
    sed -i "s/$emoji//g" "$file"
  done
  
  # Remover espaços duplos que podem ter ficado
  sed -i 's/ / /g' "$file"
  
  echo "Concluído: $file"
}

# Processar todos os arquivos .sh
echo "Processando arquivos .sh..."
find . -name "*.sh" -type f | while read file; do
  remove_emojis "$file"
done

# Processar todos os arquivos .md
echo "Processando arquivos .md..."
find . -name "*.md" -type f | while read file; do
  remove_emojis "$file"
done

echo "Remoção de emojis concluída!"
echo "Backups dos arquivos originais foram criados com extensão .backup"