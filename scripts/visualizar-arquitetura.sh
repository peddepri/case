#!/bin/bash

# Script para visualizar o diagrama de arquitetura
# Uso: ./visualizar-arquitetura.sh

DIAGRAM_PATH="docs/producao/arquitetura-aws-eks-datadog.html"

echo "🏗️  Abrindo diagrama de arquitetura AWS EKS + Datadog Stack"
echo "📁 Arquivo: $DIAGRAM_PATH"
echo ""

# Verificar se o arquivo existe
if [ ! -f "$DIAGRAM_PATH" ]; then
    echo "❌ Erro: Arquivo não encontrado em $DIAGRAM_PATH"
    exit 1
fi

# Tentar abrir com diferentes comandos dependendo do OS
case "$OSTYPE" in
    darwin*)
        # macOS
        open "$DIAGRAM_PATH"
        echo "✅ Diagrama aberto no navegador padrão (macOS)"
        ;;
    linux*)
        # Linux
        if command -v xdg-open &> /dev/null; then
            xdg-open "$DIAGRAM_PATH"
            echo "✅ Diagrama aberto no navegador padrão (Linux)"
        elif command -v firefox &> /dev/null; then
            firefox "$DIAGRAM_PATH" &
            echo "✅ Diagrama aberto no Firefox (Linux)"
        else
            echo "📋 Abra manualmente: file://$(pwd)/$DIAGRAM_PATH"
        fi
        ;;
    cygwin*|msys*|win32*)
        # Windows
        if command -v start &> /dev/null; then
            start "$DIAGRAM_PATH"
            echo "✅ Diagrama aberto no navegador padrão (Windows)"
        else
            echo "📋 Abra manualmente: file://$(pwd)/$DIAGRAM_PATH"
        fi
        ;;
    *)
        echo "📋 Sistema operacional não reconhecido"
        echo "📋 Abra manualmente: file://$(pwd)/$DIAGRAM_PATH"
        ;;
esac

echo ""
echo "🎯 Características do diagrama:"
echo "   • Stencils oficiais da AWS"
echo "   • Setas animadas mostrando fluxo de dados"
echo "   • Componentes interativos com tooltips"
echo "   • Métricas de performance em tempo real"
echo "   • Legenda completa e informações técnicas"
echo ""
echo "📚 Para diagramas técnicos adicionais:"
echo "   • docs/producao/arquitetura-diagramas-mermaid.md"
echo ""