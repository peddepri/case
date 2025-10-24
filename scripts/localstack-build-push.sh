#!/bin/bash
# Script para build e push de imagens Docker no ECR LocalStack

set -e

# Ir para o diretório raiz do projeto
cd "$(dirname "$0")/.."

export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_REGION=us-east-1
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_ACCOUNT_ID=000000000000

echo "🐳 Build e Push de imagens Docker para ECR LocalStack"
echo ""

# Login no ECR local
echo "🔐 Fazendo login no ECR..."
aws ecr get-login-password --endpoint-url $AWS_ENDPOINT_URL | \
  docker login --username AWS --password-stdin \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.localhost.localstack.cloud:4566 \
  2>/dev/null || echo "  ECR login pode não funcionar totalmente no Community"

# Build backend
echo ""
echo "🏗️  Building backend..."
docker build -t backend:latest ./app/backend

echo "🏷️  Tagging backend..."
docker tag backend:latest \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.localhost.localstack.cloud:4566/backend:latest

echo "⬆️  Pushing backend to LocalStack ECR..."
docker push \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.localhost.localstack.cloud:4566/backend:latest \
  2>/dev/null || echo "  Push pode não funcionar totalmente (ECR mock básico)"

# Build frontend
echo ""
echo "🏗️  Building frontend..."
docker build -t frontend:latest ./app/frontend

echo "🏷️  Tagging frontend..."
docker tag frontend:latest \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.localhost.localstack.cloud:4566/frontend:latest

echo "⬆️  Pushing frontend to LocalStack ECR..."
docker push \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.localhost.localstack.cloud:4566/frontend:latest \
  2>/dev/null || echo "  Push pode não funcionar totalmente (ECR mock básico)"

echo ""
echo "📦 Verificando imagens no ECR:"
aws ecr list-images \
  --endpoint-url $AWS_ENDPOINT_URL \
  --repository-name backend \
  2>/dev/null || echo "Nenhuma imagem encontrada"

aws ecr list-images \
  --endpoint-url $AWS_ENDPOINT_URL \
  --repository-name frontend \
  2>/dev/null || echo "Nenhuma imagem encontrada"

echo ""
echo " Build concluído!"
echo ""
echo "💡 Nota: ECR no LocalStack Community tem limitações."
echo "   Para ECR completo, considere LocalStack Pro ou use Docker Hub."
