#!/bin/bash
# Script para configurar Datadog no ambiente local

set -e

echo "🐕 Configuração do Datadog"
echo ""

# Verificar se .env existe
if [ ! -f .env ]; then
    echo "📋 Criando arquivo .env..."
    cp .env.example .env
    echo "✅ Arquivo .env criado"
fi

# Verificar se DD_API_KEY está configurado
DD_API_KEY=$(grep "^DD_API_KEY=" .env | cut -d'=' -f2)

if [ -z "$DD_API_KEY" ]; then
    echo ""
    echo "⚠️  DD_API_KEY não configurado no arquivo .env"
    echo ""
    echo "📝 Para configurar:"
    echo "   1. Acesse: https://app.us5.datadoghq.com/organization-settings/api-keys"
    echo "   2. Copie sua API key"
    echo "   3. Edite .env e cole a key em DD_API_KEY="
    echo ""
    read -p "Digite sua Datadog API key (ou Enter para pular): " NEW_KEY
    
    if [ -n "$NEW_KEY" ]; then
        # Atualizar .env com a nova key
        sed -i.bak "s/^DD_API_KEY=.*/DD_API_KEY=$NEW_KEY/" .env
        rm -f .env.bak
        echo "✅ API key configurada!"
    else
        echo "⏭️  Pulando configuração. Edite .env manualmente."
        exit 0
    fi
fi

echo ""
echo "🔄 Reiniciando stack Docker com Datadog..."
docker compose down
docker compose up -d

echo ""
echo "⏳ Aguardando Datadog Agent iniciar..."
sleep 5

echo ""
echo "📊 Status do Datadog Agent:"
docker compose logs datadog-agent --tail=20 | grep -i "datadog agent" || true

echo ""
echo "✅ Configuração concluída!"
echo ""
echo "📍 Próximos passos:"
echo "   1. Aguarde 1-2 minutos para dados aparecerem"
echo "   2. Acesse: https://app.us5.datadoghq.com/infrastructure"
echo "   3. Veja APM: https://app.us5.datadoghq.com/apm/services"
echo "   4. Faça requisições: curl http://localhost:3000/api/orders"
echo ""
