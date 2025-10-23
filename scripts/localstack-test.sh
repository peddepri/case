#!/bin/bash
# Script para testar recursos AWS no LocalStack

set -e

# Ir para o diretório raiz do projeto
cd "$(dirname "$0")/.."

export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_REGION=us-east-1
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test

echo "🧪 Testando recursos AWS no LocalStack"
echo ""

echo "📊 1. DynamoDB Tables:"
aws dynamodb list-tables --endpoint-url $AWS_ENDPOINT_URL | grep -A5 TableNames

echo ""
echo "📦 2. ECR Repositories:"
aws ecr describe-repositories --endpoint-url $AWS_ENDPOINT_URL | grep repositoryName

echo ""
echo "🔐 3. IAM Roles:"
aws iam list-roles --endpoint-url $AWS_ENDPOINT_URL | grep backend-sa-role || echo "Nenhum role encontrado"

echo ""
echo "🔑 4. Secrets Manager:"
aws secretsmanager list-secrets --endpoint-url $AWS_ENDPOINT_URL | grep Name || echo "Nenhum secret encontrado"

echo ""
echo "☁️  5. S3 Buckets:"
aws s3 ls --endpoint-url $AWS_ENDPOINT_URL || echo "Nenhum bucket encontrado"

echo ""
echo "☸️  6. EKS Clusters:"
aws eks list-clusters --endpoint-url $AWS_ENDPOINT_URL 2>/dev/null || echo "EKS não disponível (requer LocalStack Pro)"

echo ""
echo "📝 7. CloudWatch Logs:"
aws logs describe-log-groups --endpoint-url $AWS_ENDPOINT_URL | grep logGroupName || echo "Nenhum log group encontrado"

echo ""
echo "🧪 8. Testando insert no DynamoDB:"
ITEM_ID=$(date +%s)
aws dynamodb put-item \
    --endpoint-url $AWS_ENDPOINT_URL \
    --table-name orders \
    --item "{\"id\": {\"S\": \"$ITEM_ID\"}, \"item\": {\"S\": \"test-item\"}, \"price\": {\"N\": \"999\"}}"

echo "✅ Item inserido com ID: $ITEM_ID"

echo ""
echo "🔍 9. Verificando item inserido:"
aws dynamodb scan \
    --endpoint-url $AWS_ENDPOINT_URL \
    --table-name orders \
    --max-items 5

echo ""
echo "🌐 10. Testando Backend (LocalStack):"
curl -s http://localhost:3001/healthz && echo "" || echo "❌ Backend não está respondendo"

echo ""
echo "📊 11. Testando métricas:"
curl -s http://localhost:3001/metrics | head -n 10

echo ""
echo "✅ Testes concluídos!"
