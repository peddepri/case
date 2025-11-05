#!/bin/bash
# Script simplificado para provisionar recursos no LocalStack via AWS CLI

set -e

cd "$(dirname "$0")/.."

echo "🚀 Provisionamento de Recursos no LocalStack via AWS CLI"
echo "========================================================"
echo ""

# Verificar se LocalStack está rodando
if ! curl -s http://localhost:4566/_localstack/health > /dev/null 2>&1; then
    echo " LocalStack não está rodando!"
    echo "   Execute primeiro: bash scripts/localstack-up.sh"
    exit 1
fi

echo " LocalStack está rodando"
echo ""

# Função helper
awslocal() {
    docker compose -f docker-compose.localstack.yml exec -T localstack \
        awslocal "$@" 2>/dev/null || \
    bash scripts/awslocal.sh "$@"
}

# 1. DynamoDB Table
echo "1⃣  Criando DynamoDB table 'orders'..."
awslocal dynamodb create-table \
    --table-name orders \
    --attribute-definitions AttributeName=id,AttributeType=S \
    --key-schema AttributeName=id,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --tags Key=Project,Value=case Key=Environment,Value=localstack \
    2>/dev/null || echo "     Table já existe"

# 2. ECR Repositories
echo ""
echo "2⃣  Criando ECR repositories..."
awslocal ecr create-repository \
    --repository-name backend \
    --tags Key=Project,Value=case \
    2>/dev/null || echo "     Repository 'backend' já existe"

awslocal ecr create-repository \
    --repository-name frontend \
    --tags Key=Project,Value=case \
    2>/dev/null || echo "     Repository 'frontend' já existe"

# 3. IAM Role
echo ""
echo "3⃣  Criando IAM role 'case-backend-sa-role'..."
awslocal iam create-role \
    --role-name case-backend-sa-role \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {"Service": "eks.amazonaws.com"},
            "Action": "sts:AssumeRole"
        }]
    }' \
    2>/dev/null || echo "     Role já existe"

# 4. IAM Policy para DynamoDB
echo ""
echo "4⃣  Anexando política DynamoDB ao role..."
awslocal iam put-role-policy \
    --role-name case-backend-sa-role \
    --policy-name DynamoDBAccess \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Sid": "DynamoDBAccess",
            "Effect": "Allow",
            "Action": [
                "dynamodb:PutItem",
                "dynamodb:GetItem",
                "dynamodb:UpdateItem",
                "dynamodb:DeleteItem",
                "dynamodb:Scan",
                "dynamodb:Query"
            ],
            "Resource": "arn:aws:dynamodb:us-east-1:000000000000:table/orders"
        }]
    }' \
    2>/dev/null || echo "     Política já anexada"

# 5. Secrets Manager
echo ""
echo "5⃣  Criando secret 'datadog/api-key'..."
awslocal secretsmanager create-secret \
    --name datadog/api-key \
    --secret-string "{\"api-key\":\"${DD_API_KEY:-dummy-key-for-localstack}\"}" \
    2>/dev/null || echo "     Secret já existe"

# 6. S3 Bucket
echo ""
echo "6⃣  Criando S3 bucket 'case-artifacts'..."
awslocal s3 mb s3://case-artifacts 2>/dev/null || echo "     Bucket já existe"

# 7. CloudWatch Log Group
echo ""
echo "7⃣  Criando CloudWatch log group..."
awslocal logs create-log-group \
    --log-group-name /aws/containerinsights/case-eks/application \
    2>/dev/null || echo "     Log group já existe"

# Verificação
echo ""
echo "=========================================================="
echo " Provisionamento Completo!"
echo "=========================================================="
echo ""

echo "📊 Recursos Provisionados:"
echo ""

echo "   📦 DynamoDB Tables:"
awslocal dynamodb list-tables --query 'TableNames' --output text

echo ""
echo "   📦 ECR Repositories:"
awslocal ecr describe-repositories --query 'repositories[].repositoryName' --output text

echo ""
echo "   🔐 IAM Roles:"
awslocal iam list-roles --query 'Roles[?contains(RoleName, `case`)].RoleName' --output text

echo ""
echo "   🔑 Secrets:"
awslocal secretsmanager list-secrets --query 'SecretList[].Name' --output text

echo ""
echo "   ☁  S3 Buckets:"
awslocal s3 ls | awk '{print $3}'

echo ""
echo "   📝 Log Groups:"
awslocal logs describe-log-groups --query 'logGroups[].logGroupName' --output text

echo ""
echo "🌐 Testando aplicação:"
echo ""

# Testar backend
sleep 2
if curl -sf http://localhost:3001/healthz > /dev/null; then
    echo "    Backend: http://localhost:3001"
else
    echo "     Backend não está respondendo"
fi

# Testar frontend
if curl -sfI http://localhost:5174 > /dev/null; then
    echo "    Frontend: http://localhost:5174"
else
    echo "     Frontend não está respondendo"
fi

# Testar criação de order
echo ""
echo "   🧪 Testando criação de order..."
ORDER_RESULT=$(curl -sf -X POST http://localhost:3001/api/orders \
    -H "Content-Type: application/json" \
    -d '{"item":"infra-test","price":999}' 2>/dev/null || echo "")

if [ -n "$ORDER_RESULT" ]; then
    echo "    Order criada: $ORDER_RESULT"
    
    echo ""
    echo "   📊 Verificando no DynamoDB..."
    awslocal dynamodb scan --table-name orders --max-items 3 --query 'Items[].{id:id.S,item:item.S,price:price.N}'
else
    echo "     Erro ao criar order"
fi

echo ""
echo "=========================================================="
echo "📝 Próximos Passos:"
echo ""
echo "   # Build e push de imagens (simulado)"
echo "   docker build -t 000000000000.dkr.ecr.us-east-1.localhost.localstack.cloud:4566/backend:latest app/backend"
echo ""
echo "   # Ver recursos AWS"
echo "   bash scripts/awslocal.sh dynamodb scan --table-name orders"
echo "   bash scripts/awslocal.sh ecr describe-repositories"
echo ""
echo "   # Acessar aplicação"
echo "   # Frontend: http://localhost:5174"
echo "   # Backend API: http://localhost:3001/api/orders"
echo ""
