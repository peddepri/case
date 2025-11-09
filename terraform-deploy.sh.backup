#!/bin/bash

# Script para deploy da infraestrutura AWS com Terraform

set -e

echo "Iniciando deploy da infraestrutura AWS..."

# Verificar se as credenciais AWS estão configuradas
if ! aws sts get-caller-identity &>/dev/null; then
  echo "ERRO: Credenciais AWS não configuradas"
  echo "Configure com: aws configure"
  echo "Ou defina as variáveis: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY"
  exit 1
fi

# Verificar Account ID
CURRENT_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
EXPECTED_ACCOUNT="918859180133"

if [ "$CURRENT_ACCOUNT" != "$EXPECTED_ACCOUNT" ]; then
  echo "ERRO: Account ID não confere"
  echo "Atual: $CURRENT_ACCOUNT"
  echo "Esperado: $EXPECTED_ACCOUNT"
  exit 1
fi

echo "Account ID verificado: $CURRENT_ACCOUNT"

# Navegar para diretório do Terraform
cd infra/terraform

# Configurar variáveis do Terraform
cat > terraform.tfvars << EOF
region = "us-east-1"
project_name = "case"
eks_cluster_name = "case-cluster"
dynamodb_table_name = "orders"
dd_site = "datadoghq.com"
dd_api_key = "SUBSTITUA_PELA_SUA_DATADOG_API_KEY"

tags = {
 Environment = "production"
 Project   = "case"
 ManagedBy  = "terraform"
}
EOF

echo "Arquivo terraform.tfvars criado. Verifique as variáveis antes de continuar."
echo "IMPORTANTE: Substitua dd_api_key pela sua chave real do Datadog"

# Inicializar Terraform
echo "Inicializando Terraform..."
terraform init

# Planejar deploy
echo "Criando plano de execução..."
terraform plan -out=tfplan

echo ""
echo "Próximos passos:"
echo "1. Revise o plano acima"
echo "2. Edite terraform.tfvars com suas configurações"
echo "3. Execute: terraform apply tfplan"
echo ""
echo "AVISO: O deploy criará recursos que podem gerar custos na AWS!"