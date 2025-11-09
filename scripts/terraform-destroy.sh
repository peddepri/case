#!/bin/bash

# Terraform Destroy Script - Cleanup all AWS resources
# Este script remove todos os recursos AWS provisionados pelo Terraform

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

AWS_REGION="us-east-2"
CONFIRMATION_WORD="DESTROY"

echo -e "${RED}⚠️  TERRAFORM DESTROY - AWS RESOURCE CLEANUP${NC}"
echo "=============================================="
echo ""
echo "Este script irá DESTRUIR PERMANENTEMENTE todos os recursos AWS provisionados."
echo "Esta ação NÃO PODE SER DESFEITA!"
echo ""
echo -e "${YELLOW}Recursos que serão removidos:${NC}"
echo "- Cluster EKS e Node Groups"
echo "- VPC, Subnets, Internet Gateway, NAT Gateway"
echo "- Load Balancers (ALB/NLB)"
echo "- Security Groups"
echo "- IAM Roles (GitHub Actions)"
echo "- ECR Repositories (opcional)"
echo ""

# Confirmar destruição
echo -e "${RED}Para continuar, digite exatamente: ${CONFIRMATION_WORD}${NC}"
read -p "Confirmação: " user_input

if [ "$user_input" != "$CONFIRMATION_WORD" ]; then
    echo "❌ Confirmação falhou. Saindo..."
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Confirmação aceita. Iniciando destruição...${NC}"
echo ""

# Função para executar terraform destroy com logs
destroy_terraform() {
    local dir=$1
    local description=$2
    
    echo -e "${YELLOW}🚨 Destruindo: $description${NC}"
    echo "Diretório: $dir"
    
    if [ ! -d "$dir" ]; then
        echo "⚠️ Diretório não encontrado: $dir"
        return 0
    fi
    
    cd "$dir"
    
    # Verificar se há state file
    if [ ! -f "terraform.tfstate" ] && [ ! -f ".terraform/terraform.tfstate" ]; then
        echo "ℹ️ Nenhum state file encontrado em $dir"
        cd - > /dev/null
        return 0
    fi
    
    # Inicializar se necessário
    if [ ! -d ".terraform" ]; then
        echo "🔧 Inicializando Terraform..."
        terraform init -input=false
    fi
    
    # Listar recursos antes da destruição
    echo "📋 Recursos atuais:"
    terraform state list 2>/dev/null || echo "Nenhum recurso no state"
    
    # Mostrar plano de destruição
    echo "🔍 Plano de destruição:"
    terraform plan -destroy -input=false -no-color 2>/dev/null || echo "Erro ao gerar plano"
    
    # Executar destroy
    echo "💥 Executando terraform destroy..."
    terraform destroy -auto-approve -input=false
    
    echo -e "${GREEN}✅ $description destruído com sucesso${NC}"
    cd - > /dev/null
    echo ""
}

# 1. Destruir infraestrutura principal (EKS, VPC, etc.)
if [ -d "domains/infra/terraform" ]; then
    destroy_terraform "domains/infra/terraform" "Infraestrutura Principal (EKS, VPC, ALB)"
fi

# 2. Destruir recursos OIDC
if [ -d "terraform/github-oidc" ]; then
    destroy_terraform "terraform/github-oidc" "GitHub OIDC (IAM Role)"
fi

# 3. Verificar recursos restantes na AWS
echo -e "${YELLOW}🔍 Verificando recursos restantes na AWS...${NC}"

# Verificar EKS clusters
echo "EKS Clusters:"
aws eks list-clusters --region $AWS_REGION --query 'clusters[?contains(@, `case`)]' --output table 2>/dev/null || echo "Nenhum cluster EKS encontrado"

# Verificar VPCs
echo "VPCs do projeto:"
aws ec2 describe-vpcs --region $AWS_REGION --filters "Name=tag:Project,Values=case" --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0]]' --output table 2>/dev/null || echo "Nenhuma VPC encontrada"

# Verificar Load Balancers
echo "Load Balancers:"
aws elbv2 describe-load-balancers --region $AWS_REGION --query 'LoadBalancers[?contains(LoadBalancerName, `case`)].[LoadBalancerName,State.Code]' --output table 2>/dev/null || echo "Nenhum Load Balancer encontrado"

# Verificar ECR repositories
echo "ECR Repositories:"
aws ecr describe-repositories --region $AWS_REGION --query 'repositories[?contains(repositoryName, `case`)].repositoryName' --output table 2>/dev/null || echo "Nenhum repositório ECR encontrado"

# Verificar Security Groups
echo "Security Groups do projeto:"
aws ec2 describe-security-groups --region $AWS_REGION --filters "Name=tag:Project,Values=case" --query 'SecurityGroups[*].[GroupId,GroupName]' --output table 2>/dev/null || echo "Nenhum Security Group encontrado"

# 4. Opção para limpar ECR repositories
echo ""
echo -e "${YELLOW}🗂️ Limpeza de ECR Repositories${NC}"
read -p "Deseja deletar os repositórios ECR (case-backend, case-frontend, case-mobile)? [y/N]: " delete_ecr

if [[ $delete_ecr =~ ^[Yy]$ ]]; then
    echo "🗑️ Removendo repositórios ECR..."
    
    for repo in case-backend case-frontend case-mobile; do
        echo "Deletando repositório: $repo"
        aws ecr delete-repository --region $AWS_REGION --repository-name $repo --force 2>/dev/null && \
            echo "✅ $repo deletado" || echo "⚠️ $repo não encontrado ou erro na deleção"
    done
fi

# 5. Limpeza de arquivos locais
echo ""
echo -e "${YELLOW}🧹 Limpeza de arquivos locais${NC}"
read -p "Deseja remover arquivos de state local do Terraform? [y/N]: " cleanup_local

if [[ $cleanup_local =~ ^[Yy]$ ]]; then
    echo "🧹 Removendo arquivos locais..."
    
    # Remover state files
    find . -name "terraform.tfstate*" -type f -delete 2>/dev/null || true
    find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
    find . -name ".terraform.lock.hcl" -type f -delete 2>/dev/null || true
    
    echo "✅ Arquivos locais removidos"
fi

# 6. Verificação final de custos
echo ""
echo -e "${GREEN}🎉 DESTRUIÇÃO CONCLUÍDA${NC}"
echo "========================"
echo ""
echo -e "${YELLOW}📊 PRÓXIMOS PASSOS:${NC}"
echo "1. Verifique o AWS Console para recursos órfãos"
echo "2. Monitore o AWS Billing pelos próximos dias"
echo "3. Verifique se há recursos em outras regiões"
echo "4. Considere deletar S3 buckets de logs (se existirem)"
echo ""
echo -e "${RED}⚠️ IMPORTANTE:${NC}"
echo "- Alguns recursos podem ter período de retenção (ex: Load Balancer)"
echo "- NAT Gateway é cobrado por hora - verifique se foi removido"
echo "- EIP (Elastic IP) órfãos também são cobrados"
echo ""
echo -e "${GREEN}✅ Script concluído com sucesso!${NC}"