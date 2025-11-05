#!/bin/bash
# Script mestre para provisionar infraestrutura completa no LocalStack

set -e

cd "$(dirname "$0")/.."

echo "🚀 Provisionamento Completo da Infraestrutura no LocalStack"
echo "==========================================================="
echo ""

# Verificar pré-requisitos
echo "📋 Verificando pré-requisitos..."

if ! docker info > /dev/null 2>&1; then
    echo " Docker não está rodando"
    exit 1
fi

# Passo 1: Subir LocalStack
echo ""
echo "1⃣  Iniciando LocalStack..."
if ! curl -s http://localhost:4566/_localstack/health > /dev/null 2>&1; then
    echo "   LocalStack não está rodando. Subindo..."
    bash scripts/localstack-up.sh
else
    echo "    LocalStack já está rodando"
fi

# Aguardar LocalStack ficar pronto
echo "    Aguardando LocalStack..."
until curl -s http://localhost:4566/_localstack/health | grep -q '"dynamodb": "running"'; do
    echo -n "."
    sleep 2
done
echo " "

# Passo 2: Provisionar recursos AWS via Terraform
echo ""
echo "2⃣  Provisionando recursos AWS no LocalStack..."

# Criar diretório temporário para Terraform
TF_DIR="infra/terraform-localstack"
mkdir -p "$TF_DIR"

# Copiar arquivos Terraform
cp infra/terraform/main.localstack.tf "$TF_DIR/main.tf"
cp infra/terraform/variables.localstack.tf "$TF_DIR/variables.tf"
cp infra/terraform/outputs.localstack.tf "$TF_DIR/outputs.tf"

# Criar terraform.tfvars
cat > "$TF_DIR/terraform.tfvars" << EOF
region              = "us-east-1"
project_name        = "case"
eks_cluster_name    = "case-eks"
dd_api_key          = "${DD_API_KEY:-}"
dd_site             = "us5.datadoghq.com"
dynamodb_table_name = "orders"
EOF

echo "   📦 Executando Terraform via Docker..."

# Terraform init
WORKSPACE_PATH="$(cd "$(pwd)/$TF_DIR" && pwd)"
docker run --rm \
  --network case_localstack-network \
  -v "$WORKSPACE_PATH:/workspace" \
  -w //workspace \
  -e AWS_ACCESS_KEY_ID=test \
  -e AWS_SECRET_ACCESS_KEY=test \
  -e AWS_DEFAULT_REGION=us-east-1 \
  -e TF_LOG=ERROR \
  hashicorp/terraform:1.9 init -input=false

# Terraform apply
docker run --rm \
  --network case_localstack-network \
  -v "$WORKSPACE_PATH:/workspace" \
  -w //workspace \
  -e AWS_ACCESS_KEY_ID=test \
  -e AWS_SECRET_ACCESS_KEY=test \
  -e AWS_DEFAULT_REGION=us-east-1 \
  -e TF_LOG=ERROR \
  hashicorp/terraform:1.9 apply -auto-approve -input=false

# Capturar outputs
echo ""
echo "   📊 Outputs do Terraform:"
docker run --rm \
  --network case_localstack-network \
  -v "$WORKSPACE_PATH:/workspace" \
  -w //workspace \
  hashicorp/terraform:1.9 output

# Salvar outputs em arquivo
docker run --rm \
  --network case_localstack-network \
  -v "$WORKSPACE_PATH:/workspace" \
  -w //workspace \
  hashicorp/terraform:1.9 output -json > "$TF_DIR/outputs.json"

echo "    Recursos AWS provisionados"

# Passo 3: Verificar recursos criados
echo ""
echo "3⃣  Verificando recursos no LocalStack..."

echo "   📦 DynamoDB Tables:"
bash scripts/awslocal.sh dynamodb list-tables | grep -A1 TableNames || echo "   Nenhuma table encontrada"

echo ""
echo "   📦 ECR Repositories:"
bash scripts/awslocal.sh ecr describe-repositories --query 'repositories[].repositoryName' --output text || echo "   Nenhum repository encontrado"

echo ""
echo "   🔐 IAM Roles:"
bash scripts/awslocal.sh iam list-roles --query 'Roles[?contains(RoleName, `backend`)].RoleName' --output text || echo "   Nenhum role encontrado"

echo ""
echo "   🔑 Secrets Manager:"
bash scripts/awslocal.sh secretsmanager list-secrets --query 'SecretList[].Name' --output text || echo "   Nenhum secret encontrado"

# Passo 4: Build e push de imagens (simulado)
echo ""
echo "4⃣  Build de imagens Docker..."

echo "   🏗  Backend image..."
docker build -t case-backend:latest -t 000000000000.dkr.ecr.us-east-1.localhost.localstack.cloud:4566/backend:latest app/backend -q

echo "   🏗  Frontend image..."
docker build -t case-frontend:latest -t 000000000000.dkr.ecr.us-east-1.localhost.localstack.cloud:4566/frontend:latest app/frontend -q

echo "    Imagens construídas"

# Passo 5: Restart containers para usar novos recursos
echo ""
echo "5⃣  Reiniciando containers para usar recursos provisionados..."

docker compose -f docker-compose.localstack.yml restart backend-localstack
docker compose -f docker-compose.localstack.yml restart frontend-localstack

echo "    Containers reiniciados"

# Passo 6: Validação
echo ""
echo "6⃣  Validando ambiente..."

sleep 3

echo "   🧪 Testando backend..."
if curl -sf http://localhost:3001/healthz > /dev/null; then
    echo "    Backend respondendo"
else
    echo "     Backend não está respondendo"
fi

echo "   🧪 Testando API..."
TEST_ORDER=$(curl -sf -X POST http://localhost:3001/api/orders \
  -H "Content-Type: application/json" \
  -d '{"item":"test-infra","price":100}' 2>/dev/null || echo "")

if [ -n "$TEST_ORDER" ]; then
    echo "    API funcionando (order criada)"
else
    echo "     API não respondeu"
fi

# Resumo final
echo ""
echo "=========================================================="
echo " Provisionamento Completo!"
echo "=========================================================="
echo ""
echo "📊 Recursos Provisionados:"
echo "   • DynamoDB table: orders"
echo "   • ECR repositories: backend, frontend"
echo "   • IAM role: case-backend-sa-role"
echo "   • Secrets Manager: datadog/api-key"
echo "   • S3 bucket: case-artifacts"
echo "   • CloudWatch Log Group: /aws/containerinsights/case-eks/application"
echo ""
echo "🌐 Endpoints:"
echo "   • LocalStack: http://localhost:4566"
echo "   • Backend: http://localhost:3001"
echo "   • Frontend: http://localhost:5174"
echo ""
echo "📝 Comandos úteis:"
echo "   # Ver recursos AWS"
echo "   bash scripts/awslocal.sh dynamodb scan --table-name orders"
echo "   bash scripts/awslocal.sh ecr describe-repositories"
echo ""
echo "   # Ver outputs Terraform"
echo "   cat $TF_DIR/outputs.json | jq"
echo ""
echo "   # Logs"
echo "   docker compose -f docker-compose.localstack.yml logs -f backend-localstack"
echo ""
echo "   # Destruir tudo"
echo "   docker compose -f docker-compose.localstack.yml down"
echo "   rm -rf $TF_DIR"
