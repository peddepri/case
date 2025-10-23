#!/bin/bash
# Script para subir ambiente LocalStack completo

set -e

echo "🚀 Iniciando ambiente LocalStack AWS..."
echo ""

# Verificar se .env.localstack existe
if [ ! -f .env.localstack ]; then
    echo "⚠️  Arquivo .env.localstack não encontrado!"
    echo "   Criando a partir do template..."
    cat > .env.localstack << 'EOF'
# LocalStack Configuration
LOCALSTACK_AUTH_TOKEN=ls-rOhOqaQe-9209-3474-kAto-faXUpetu092e

# AWS Credentials (fake for LocalStack)
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
AWS_DEFAULT_REGION=us-east-1

# Datadog (opcional)
DD_API_KEY=
DD_SITE=us5.datadoghq.com

# LocalStack Settings
DEBUG=0
LOCALSTACK_VOLUME_DIR=./localstack-data
EOF
fi

# Carregar variáveis
export $(grep -v '^#' .env.localstack | xargs)

# Criar diretório para dados persistentes
mkdir -p localstack-data
mkdir -p localstack-kubeconfig

echo "📦 Subindo containers LocalStack..."
docker compose -f docker-compose.localstack.yml up -d

echo ""
echo "⏳ Aguardando LocalStack ficar pronto..."
until curl -s http://localhost:4566/_localstack/health | grep -q '"dynamodb": "available"'; do
    echo -n "."
    sleep 2
done
echo ""
echo "✅ LocalStack pronto!"

echo ""
echo "📊 Status dos serviços:"
docker compose -f docker-compose.localstack.yml ps

echo ""
echo "🔍 Health check:"
curl -s http://localhost:4566/_localstack/health | python -m json.tool 2>/dev/null || \
curl -s http://localhost:4566/_localstack/health

echo ""
echo "📋 Recursos disponíveis:"
echo "   🌐 LocalStack Gateway: http://localhost:4566"
echo "   🖥️  Backend: http://localhost:3001"
echo "   🎨 Frontend: http://localhost:5174"
echo "   📊 Datadog Agent: localhost:8127 (APM), localhost:8126 (StatsD)"
echo ""
echo "🔧 Comandos úteis:"
echo "   # Listar DynamoDB tables"
echo "   aws --endpoint-url=http://localhost:4566 dynamodb list-tables"
echo ""
echo "   # Listar ECR repositories"
echo "   aws --endpoint-url=http://localhost:4566 ecr describe-repositories"
echo ""
echo "   # Ver EKS clusters"
echo "   aws --endpoint-url=http://localhost:4566 eks list-clusters"
echo ""
echo "   # Logs do LocalStack"
echo "   docker compose -f docker-compose.localstack.yml logs -f localstack"
echo ""
echo "   # Parar tudo"
echo "   ./scripts/localstack-down.sh"
