#!/bin/bash
# Script para provisionar infraestrutura no LocalStack via Terraform

set -e

cd "$(dirname "$0")/.."

echo "🏗  Provisionando infraestrutura no LocalStack com Terraform"
echo ""

# Verificar se LocalStack está rodando
if ! curl -s http://localhost:4566/_localstack/health > /dev/null 2>&1; then
    echo " LocalStack não está rodando!"
    echo "   Execute primeiro: ./scripts/localstack-up.sh"
    exit 1
fi

echo " LocalStack está rodando"
echo ""

# Criar diretório para Terraform no LocalStack
TERRAFORM_DIR="infra/terraform-localstack"
mkdir -p "$TERRAFORM_DIR"

# Copiar arquivos Terraform LocalStack
echo "📋 Preparando configuração Terraform..."
cp infra/terraform/main.localstack.tf "$TERRAFORM_DIR/main.tf"
cp infra/terraform/variables.localstack.tf "$TERRAFORM_DIR/variables.tf"
cp infra/terraform/outputs.localstack.tf "$TERRAFORM_DIR/outputs.tf"

# Criar terraform.tfvars
cat > "$TERRAFORM_DIR/terraform.tfvars" << EOF
region              = "us-east-1"
project_name        = "case"
eks_cluster_name    = "case-eks"
dd_api_key          = "${DD_API_KEY:-}"
dd_site             = "us5.datadoghq.com"
dynamodb_table_name = "orders"
EOF

echo " Configuração preparada"
echo ""

# Rodar Terraform via Docker (toolbox)
echo "🔧 Inicializando Terraform..."
docker compose -f docker-compose.localstack.yml run --rm \
  -v "$(pwd)/$TERRAFORM_DIR:/workspace" \
  -w /workspace \
  -e AWS_ACCESS_KEY_ID=test \
  -e AWS_SECRET_ACCESS_KEY=test \
  -e AWS_DEFAULT_REGION=us-east-1 \
  --entrypoint sh \
  localstack -c "
    apk add --no-cache terraform aws-cli
    terraform init -input=false
  "

echo ""
echo "📋 Validando plano Terraform..."
docker compose -f docker-compose.localstack.yml run --rm \
  -v "$(pwd)/$TERRAFORM_DIR:/workspace" \
  -w /workspace \
  -e AWS_ACCESS_KEY_ID=test \
  -e AWS_SECRET_ACCESS_KEY=test \
  -e AWS_DEFAULT_REGION=us-east-1 \
  --entrypoint sh \
  localstack -c "
    apk add --no-cache terraform
    terraform plan -input=false
  "

echo ""
read -p "🚀 Aplicar infraestrutura no LocalStack? (s/N): " APPLY

if [[ "$APPLY" =~ ^[Ss]$ ]]; then
    echo ""
    echo "  Aplicando Terraform..."
    docker compose -f docker-compose.localstack.yml run --rm \
      -v "$(pwd)/$TERRAFORM_DIR:/workspace" \
      -w /workspace \
      -e AWS_ACCESS_KEY_ID=test \
      -e AWS_SECRET_ACCESS_KEY=test \
      -e AWS_DEFAULT_REGION=us-east-1 \
      --entrypoint sh \
      localstack -c "
        apk add --no-cache terraform
        terraform apply -auto-approve -input=false
      "
    
    echo ""
    echo "📊 Outputs do Terraform:"
    docker compose -f docker-compose.localstack.yml run --rm \
      -v "$(pwd)/$TERRAFORM_DIR:/workspace" \
      -w /workspace \
      --entrypoint sh \
      localstack -c "
        apk add --no-cache terraform
        terraform output
      "
    
    echo ""
    echo " Infraestrutura provisionada no LocalStack!"
else
    echo "⏭  Pulando apply"
fi

echo ""
echo "📝 Próximos passos:"
echo "   1. Aplicar manifests K8s: ./scripts/localstack-k8s-apply.sh"
echo "   2. Verificar recursos: bash scripts/awslocal.sh dynamodb list-tables"
