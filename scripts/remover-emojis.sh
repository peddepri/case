#!/bin/bash

# Script para remover emojis de todos os arquivos do projeto
# Preserva funcionalidade técnica

echo "Iniciando limpeza de emojis nos arquivos..."

# Lista de arquivos para processar
FILES=(
    "scripts/start-localstack-pro-full.sh"
    "docs/producao/arquitetura-aws-eks-datadog.html"
    "docs/producao/arquitetura-diagramas-mermaid.md"
    "VERIFICACAO-OBSERVABILIDADE.md"
    "SCRIPTS-LOCALSTACK-PRO.md"
    "scripts/comparar-observabilidade.sh"
    "scripts/abrir-diagramas.sh"
    "docs/producao/GRAFANA-STACK-IMPLEMENTACAO.md"
)

# Função para substituir emojis por texto equivalente
remove_emojis() {
    local file="$1"
    if [[ -f "$file" ]]; then
        echo "Processando: $file"
        
        # Backup do arquivo original
        cp "$file" "$file.backup"
        
        # Lista de substituições emoji -> texto
        sed -i -E 's/🚀/[DEPLOY]/g' "$file"
        sed -i -E 's/💡/[TIP]/g' "$file"
        sed -i -E 's/⚡/[FAST]/g' "$file"
        sed -i -E 's/✨/[NEW]/g' "$file"
        sed -i -E 's/📊/[METRICS]/g' "$file"
        sed -i -E 's/📈/[CHART]/g' "$file"
        sed -i -E 's/🔧/[CONFIG]/g' "$file"
        sed -i -E 's/🌟/[STAR]/g' "$file"
        sed -i -E 's/🎯/[TARGET]/g' "$file"
        sed -i -E 's/📝/[NOTE]/g' "$file"
        sed -i -E 's/✅/[OK]/g' "$file"
        sed -i -E 's/❌/[ERROR]/g' "$file"
        sed -i -E 's/🔍/[SEARCH]/g' "$file"
        sed -i -E 's/💰/[COST]/g' "$file"
        sed -i -E 's/🎉/[SUCCESS]/g' "$file"
        sed -i -E 's/📦/[PACKAGE]/g' "$file"
        sed -i -E 's/🔄/[SYNC]/g' "$file"
        sed -i -E 's/⚠️/[WARNING]/g' "$file"
        sed -i -E 's/📋/[LIST]/g' "$file"
        sed -i -E 's/🛡️/[SECURITY]/g' "$file"
        sed -i -E 's/💻/[COMPUTER]/g' "$file"
        sed -i -E 's/🌐/[WEB]/g' "$file"
        sed -i -E 's/🚨/[ALERT]/g' "$file"
        sed -i -E 's/📡/[NETWORK]/g' "$file"
        sed -i -E 's/🎮/[GAME]/g' "$file"
        sed -i -E 's/🔗/[LINK]/g' "$file"
        sed -i -E 's/🏗️/[BUILD]/g' "$file"
        sed -i -E 's/🐳/[DOCKER]/g' "$file"
        sed -i -E 's/🔐/[LOCK]/g' "$file"
        sed -i -E 's/📚/[DOCS]/g' "$file"
        sed -i -E 's/💾/[SAVE]/g' "$file"
        sed -i -E 's/⭐/[STAR]/g' "$file"
        sed -i -E 's/🎨/[DESIGN]/g' "$file"
        sed -i -E 's/🔥/[FIRE]/g' "$file"
        sed -i -E 's/👍/[GOOD]/g' "$file"
        sed -i -E 's/📄/[FILE]/g' "$file"
        sed -i -E 's/📱/[MOBILE]/g' "$file"
        sed -i -E 's/💼/[BUSINESS]/g' "$file"
        sed -i -E 's/🖥️/[DESKTOP]/g' "$file"
        sed -i -E 's/⚙️/[GEAR]/g' "$file"
        sed -i -E 's/📞/[PHONE]/g' "$file"
        sed -i -E 's/🔔/[BELL]/g' "$file"
        
        echo "Processado com sucesso: $file"
    else
        echo "Arquivo não encontrado: $file"
    fi
}

# Processa todos os arquivos
for file in "${FILES[@]}"; do
    if [[ -f "$file" ]]; then
        remove_emojis "$file"
    else
        echo "Arquivo não encontrado (ignorando): $file"
    fi
done

echo ""
echo "Limpeza de emojis concluída!"
echo "Arquivos de backup criados com extensão .backup"
echo ""
echo "Para reverter as mudanças, execute:"
echo "for f in \$(find . -name '*.backup'); do mv \"\$f\" \"\${f%.backup}\"; done"