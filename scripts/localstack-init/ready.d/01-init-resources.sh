#!/bin/bash
# LocalStack initialization script
# Runs automatically when LocalStack starts (ready.d hook)

set -e

echo "🚀 Inicializando recursos AWS no LocalStack..."

# Configurar endpoint
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_REGION=us-east-1
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test

# Função helper para AWS CLI
aws_local() {
    aws --endpoint-url "$AWS_ENDPOINT_URL" "$@"
}

echo "📦 Criando DynamoDB table 'orders'..."
aws_local dynamodb create-table \
    --table-name orders \
    --attribute-definitions \
        AttributeName=id,AttributeType=S \
    --key-schema \
        AttributeName=id,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --tags Key=Environment,Value=localstack Key=Project,Value=case \
    2>/dev/null || echo "Table 'orders' já existe"

echo "🔐 Criando IAM role para backend (IRSA simulado)..."
aws_local iam create-role \
    --role-name backend-sa-role \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {"Service": "eks.amazonaws.com"},
            "Action": "sts:AssumeRole"
        }]
    }' 2>/dev/null || echo "Role 'backend-sa-role' já existe"

echo "📝 Anexando política de acesso ao DynamoDB..."
aws_local iam put-role-policy \
    --role-name backend-sa-role \
    --policy-name DynamoDBAccess \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Action": [
                "dynamodb:Scan",
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:Query"
            ],
            "Resource": "arn:aws:dynamodb:us-east-1:000000000000:table/orders"
        }]
    }' 2>/dev/null || echo "Política já anexada"

echo "📦 Criando ECR repositories..."
aws_local ecr create-repository \
    --repository-name backend \
    --tags Key=Environment,Value=localstack Key=Project,Value=case \
    2>/dev/null || echo "Repository 'backend' já existe"

aws_local ecr create-repository \
    --repository-name frontend \
    --tags Key=Environment,Value=localstack Key=Project,Value=case \
    2>/dev/null || echo "Repository 'frontend' já existe"

echo "🔑 Criando Secrets Manager secret para Datadog..."
aws_local secretsmanager create-secret \
    --name datadog/api-key \
    --secret-string "{\"api-key\":\"${DD_API_KEY:-dummy-key-for-localstack}\"}" \
    2>/dev/null || echo "Secret 'datadog/api-key' já existe"

echo "☸️  Criando EKS cluster 'case-eks'..."
aws_local eks create-cluster \
    --name case-eks \
    --role-arn arn:aws:iam::000000000000:role/eks-service-role \
    --resources-vpc-config subnetIds=subnet-12345,subnet-67890 \
    --kubernetes-version 1.28 \
    --tags Environment=localstack,Project=case \
    2>/dev/null || echo "Cluster 'case-eks' já existe ou EKS não totalmente suportado"

echo "📊 Criando CloudWatch Log Group..."
aws_local logs create-log-group \
    --log-group-name /aws/eks/case-eks/cluster \
    2>/dev/null || echo "Log group já existe"

echo "🎯 Criando S3 bucket para Terraform state (simulado)..."
aws_local s3 mb s3://case-terraform-state 2>/dev/null || echo "Bucket já existe"

echo "✅ Inicialização do LocalStack concluída!"
echo ""
echo "📋 Recursos criados:"
echo "   - DynamoDB table: orders"
echo "   - IAM role: backend-sa-role"
echo "   - ECR repos: backend, frontend"
echo "   - Secrets: datadog/api-key"
echo "   - EKS cluster: case-eks (se suportado)"
echo "   - CloudWatch Log Group: /aws/eks/case-eks/cluster"
echo "   - S3 bucket: case-terraform-state"
echo ""
echo "🔗 Acesse LocalStack em: http://localhost:4566"
echo "📊 Dashboard (se Pro): https://app.localstack.cloud"
