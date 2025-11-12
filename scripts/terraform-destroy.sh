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

echo -e "${RED}TERRAFORM DESTROY - AWS RESOURCE CLEANUP${NC}"
echo "=============================================="
echo ""
echo "Este script irá DESTRUIR PERMANENTEMENTE todos os recursos AWS provisionados."
echo "Esta ação NÃO PODE SER DESFEITA!"
echo ""
echo -e "${YELLOW}Recursos que serão removidos:${NC}"
echo "- Cluster EKS e Node Groups"
echo "- VPC, Subnets, Internet Gateway, NAT Gateway"
echo "- Load Balancers (ALB/NLB)"
#!/bin/bash

# Script seguro para destruir a infraestrutura provisionada via Terraform.
# Uso: ./scripts/terraform-destroy.sh <caminho_ambiente>
# Ex.: ./scripts/terraform-destroy.sh domains/infra/terraform/environments/dev

set -euo pipefail

CONFIRMATION_WORD="DESTROY"
AWS_REGION_DEFAULT="us-east-1" # Alinhado ao deploy

ENV_PATH="${1:-}"

if [ -z "$ENV_PATH" ]; then
    echo "ERRO: informe o caminho do ambiente Terraform (ex: domains/infra/terraform/environments/dev)"
    exit 1
fi

if [ ! -d "$ENV_PATH" ]; then
    echo "ERRO: diretório não encontrado: $ENV_PATH"
    exit 1
fi

echo "===================================================="
echo "TERRAFORM DESTROY (alvo: $ENV_PATH)"
echo "===================================================="
echo "ATENÇÃO: TODOS os recursos gerenciados pelo state deste ambiente serão destruídos."
echo "Esta ação é irreversível. Certifique-se de que o ambiente é apenas de laboratório." 
echo ""
echo "Digite a palavra de confirmação para continuar: $CONFIRMATION_WORD"
read -p "Confirmação: " user_input
if [ "$user_input" != "$CONFIRMATION_WORD" ]; then
    echo "Confirmação incorreta. Abortando."
    exit 1
fi

echo "Confirmação aceita. Prosseguindo."
echo ""

destroy_one() {
    local dir="$1"
    echo "---"
    echo "Ambiente: $dir"
    pushd "$dir" >/dev/null

    echo "Inicializando Terraform (backend remoto/local)..."
    terraform init -input=false -no-color

    echo "Obtendo lista de recursos (state)..."
    terraform state list || echo "Nenhum recurso no state ou state remoto não acessível ainda."

    echo "Gerando plano de destruição (destroy.tfplan)..."
    terraform plan -destroy -input=false -out=destroy.tfplan -no-color || {
        echo "Falha ao gerar plano. Verifique erros acima."; popd >/dev/null; return 1; }

    echo "Resumo do plano (linhas relevantes):"
    terraform show -no-color destroy.tfplan | grep -E "(Plan:|Destroy:)" || true

    echo "Executando terraform destroy..."
    terraform destroy -auto-approve -input=false -no-color

    echo "Destroy concluído: $dir"
    popd >/dev/null
}

# Se for uma pasta "environments", destruir todos os subambientes; do contrário, apenas o alvo
if [ -d "$ENV_PATH" ] && [ -f "$ENV_PATH/main.tf" ]; then
    # Diretório de um ambiente individual
    read -p "Confirmar destroy para este ambiente único? [y/N]: " proceed
    if [[ $proceed =~ ^[Yy]$ ]]; then
        destroy_one "$ENV_PATH"
    else
        echo "Abortado."
        exit 0
    fi
elif [ -d "$ENV_PATH" ] && ls "$ENV_PATH" >/dev/null 2>&1; then
    # Diretório pai (ex: domains/infra/terraform/environments)
    echo "Detectado diretório pai. Serão destruídos todos os subdiretórios que contêm main.tf."
    read -p "Deseja continuar destruindo TODOS os ambientes deste diretório? [y/N]: " proceed_all
    if [[ $proceed_all =~ ^[Yy]$ ]]; then
        mapfile -t envs < <(find "$ENV_PATH" -maxdepth 1 -mindepth 1 -type d)
        for envdir in "${envs[@]}"; do
            if [ -f "$envdir/main.tf" ]; then
                destroy_one "$envdir"
            fi
        done
    else
        echo "Abortado."
        exit 0
    fi
fi

echo "Verificando possíveis recursos órfãos marcados com tag Project=case na região padrão..."
AWS_REGION="${AWS_REGION:-$AWS_REGION_DEFAULT}"

echo "Clusters EKS restantes:"; aws eks list-clusters --region "$AWS_REGION" --query 'clusters' --output table 2>/dev/null || true
echo "VPCs tag Project=case:"; aws ec2 describe-vpcs --region "$AWS_REGION" --filters Name=tag:Project,Values=case --query 'Vpcs[*].VpcId' --output table 2>/dev/null || true
echo "ALBs contendo 'case':"; aws elbv2 describe-load-balancers --region "$AWS_REGION" --query 'LoadBalancers[?contains(LoadBalancerName, `case`)].LoadBalancerName' --output table 2>/dev/null || true
echo "Security Groups tag Project=case:"; aws ec2 describe-security-groups --region "$AWS_REGION" --filters Name=tag:Project,Values=case --query 'SecurityGroups[*].GroupId' --output table 2>/dev/null || true

echo "Opcional: remover repositórios ECR (case-backend, case-frontend, case-mobile)."
read -p "Remover repositórios ECR? [y/N]: " remove_ecr
if [[ $remove_ecr =~ ^[Yy]$ ]]; then
    for repo in case-backend case-frontend case-mobile; do
        echo "Removendo $repo ..."
        aws ecr delete-repository --region "$AWS_REGION" --repository-name "$repo" --force 2>/dev/null && echo "OK" || echo "Não encontrado / erro"
    done
fi

# OIDC (IAM role para GitHub Actions) — sem custo, mas pode ser removido
if [ -d "terraform/github-oidc" ]; then
    echo "OIDC para GitHub Actions encontrado em terraform/github-oidc."
    read -p "Deseja destruir também os recursos de OIDC (IAM Role/Policies)? [y/N]: " destroy_oidc
    if [[ $destroy_oidc =~ ^[Yy]$ ]]; then
        pushd "terraform/github-oidc" >/dev/null
        terraform init -input=false -no-color || true
        terraform destroy -auto-approve -input=false -no-color || true
        popd >/dev/null
    fi
fi

echo "Limpar arquivos locais de state (cache .terraform)?"
read -p "Limpar? [y/N]: " clean_state
if [[ $clean_state =~ ^[Yy]$ ]]; then
    find "$ENV_PATH" -name "terraform.tfstate*" -type f -delete 2>/dev/null || true
    find "$ENV_PATH" -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
    find "$ENV_PATH" -name ".terraform.lock.hcl" -type f -delete 2>/dev/null || true
    echo "Limpeza local concluída."
fi

echo "===================================================="
echo "Destroy finalizado. Próximos passos:"
echo "- Conferir AWS Billing para garantir ausência de custos residuais"
echo "- Verificar se há NAT Gateway, EIP ou buckets S3 órfãos"
echo "- Remover possíveis logs ou artefatos se desejado"
echo "===================================================="
echo "Pronto."