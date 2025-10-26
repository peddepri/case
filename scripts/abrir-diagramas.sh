#!/bin/bash

# Script para abrir diagramas de arquitetura
# Uso: ./abrir-diagramas.sh [drawio|html|mermaid|all]

DOCS_PATH="docs/producao"
DRAWIO_FILE="$DOCS_PATH/arquitetura-aws-eks-datadog.drawio"
HTML_FILE="$DOCS_PATH/arquitetura-aws-eks-datadog.html"
MERMAID_FILE="$DOCS_PATH/arquitetura-diagramas-mermaid.md"

function open_file() {
    local file="$1"
    local description="$2"
    
    if [ ! -f "$file" ]; then
        echo "[ERROR] Erro: Arquivo não encontrado - $file"
        return 1
    fi
    
    echo "🔍 Abrindo: $description"
    echo "📁 Arquivo: $file"
    
    case "$OSTYPE" in
        darwin*)
            # macOS
            open "$file"
            ;;
        linux*)
            # Linux
            if command -v xdg-open &> /dev/null; then
                xdg-open "$file"
            elif command -v code &> /dev/null; then
                code "$file"
            else
                echo "   📋 Abra manualmente: $file"
            fi
            ;;
        cygwin*|msys*|win32*)
            # Windows
            if command -v start &> /dev/null; then
                start "$file"
            elif command -v code &> /dev/null; then
                code "$file"
            else
                echo "   📋 Abra manualmente: $file"
            fi
            ;;
        *)
            echo "   📋 Sistema operacional não reconhecido"
            echo "   📋 Abra manualmente: $file"
            ;;
    esac
    echo ""
}

function show_help() {
    echo "🏗️  Script para Visualizar Diagramas de Arquitetura AWS EKS + Datadog"
    echo ""
    echo "📋 Uso: $0 [opção]"
    echo ""
    echo "🎯 Opções disponíveis:"
    echo "   drawio    - Abre o diagrama Draw.io (editável, stencils oficiais AWS)"
    echo "   html      - Abre o diagrama HTML interativo (animações, métricas)"
    echo "   mermaid   - Abre documentação Mermaid (múltiplas visões técnicas)"
    echo "   all       - Abre todos os diagramas"
    echo "   help      - Mostra esta ajuda"
    echo ""
    echo "📊 Características dos diagramas:"
    echo "   • Draw.io: Stencils AWS oficiais, editável no VS Code ou web"
    echo "   • HTML: Animações CSS, tooltips interativos, métricas simuladas"
    echo "   • Mermaid: Documentação técnica, fluxos de deploy e segurança"
    echo ""
    echo "💡 Extensões recomendadas para VS Code:"
    echo "   • Draw.io Integration (para .drawio)"
    echo "   • Markdown Preview Enhanced (para .md com Mermaid)"
    echo ""
}

# Verificar argumentos
case "${1:-all}" in
    "drawio"|"draw")
        open_file "$DRAWIO_FILE" "Diagrama Draw.io - Stencils Oficiais AWS"
        echo "[NEW] Dicas para Draw.io:"
        echo "   • VS Code: Instale 'Draw.io Integration'"
        echo "   • Web: Acesse app.diagrams.net"
        echo "   • Exportar: File > Export as > PNG/PDF/SVG"
        ;;
    
    "html"|"interactive")
        open_file "$HTML_FILE" "Diagrama HTML Interativo"
        echo "[NEW] Características do diagrama HTML:"
        echo "   • Setas animadas mostrando fluxo de dados"
        echo "   • Tooltips ao passar o mouse nos componentes"
        echo "   • Métricas de performance simuladas"
        echo "   • Legenda completa e informações técnicas"
        ;;
    
    "mermaid"|"md")
        open_file "$MERMAID_FILE" "Documentação Mermaid - Visões Técnicas"
        echo "[NEW] Conteúdo da documentação Mermaid:"
        echo "   • Arquitetura geral com componentes AWS"
        echo "   • Fluxo de deploy Blue/Green"
        echo "   • Observabilidade e monitoramento"
        echo "   • Segurança e compliance"
        echo "   • Tabelas de custos e métricas SLA"
        ;;
    
    "all")
        echo "🚀 Abrindo todos os diagramas de arquitetura..."
        echo ""
        open_file "$DRAWIO_FILE" "Diagrama Draw.io - Stencils Oficiais AWS"
        sleep 1
        open_file "$HTML_FILE" "Diagrama HTML Interativo"
        sleep 1
        open_file "$MERMAID_FILE" "Documentação Mermaid - Visões Técnicas"
        
        echo "📊 Todos os diagramas foram abertos!"
        echo ""
        echo "📋 Resumo dos arquivos:"
        echo "   1. $DRAWIO_FILE (Editável)"
        echo "   2. $HTML_FILE (Interativo)"  
        echo "   3. $MERMAID_FILE (Documentação)"
        ;;
    
    "help"|"-h"|"--help")
        show_help
        ;;
    
    *)
        echo "[ERROR] Opção inválida: $1"
        echo ""
        show_help
        exit 1
        ;;
esac

echo "🏗️  Arquitetura AWS EKS + Datadog Stack"
echo "📍 Ambiente: Produção (us-east-1)"
echo "🎯 Stack: EKS Fargate + DynamoDB + Datadog APM"