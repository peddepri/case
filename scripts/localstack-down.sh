#!/bin/bash
# Script para parar ambiente LocalStack

set -e

# Ir para o diretório raiz do projeto
cd "$(dirname "$0")/.."

echo "🛑 Parando ambiente LocalStack..."

docker compose -f docker-compose.localstack.yml down

echo ""
read -p "🗑️  Deseja remover dados persistentes? (s/N): " REMOVE_DATA

if [[ "$REMOVE_DATA" =~ ^[Ss]$ ]]; then
    echo "🗑️  Removendo dados do LocalStack..."
    rm -rf localstack-data
    rm -rf localstack-kubeconfig
    echo "✅ Dados removidos"
else
    echo "📦 Dados preservados em ./localstack-data"
fi

echo "✅ LocalStack parado"
