#!/bin/bash

# Script de validação da nova arquitetura refatorada

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

success() { echo -e "${GREEN}[OK] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; }
info() { echo -e "${BLUE}[INFO] $1${NC}"; }
warning() { echo -e "${YELLOW}[WARN] $1${NC}"; }

echo "=========================================="
echo "  VALIDAÇÃO DA ARQUITETURA REFATORADA"
echo "=========================================="

# Verificar estrutura de módulos Terraform
info "1. Verificando módulos Terraform"
if [ -d "infra/terraform/modules/eks" ] && [ -d "infra/terraform/modules/fargate" ] && [ -d "infra/terraform/modules/irsa" ] && [ -d "infra/terraform/modules/alb" ]; then
    success "Módulos Terraform criados"
else
    error "Módulos Terraform não encontrados"
fi

# Verificar estrutura Argo CD
info "2. Verificando estrutura Argo CD"
if [ -f "argo/root.yaml" ] && [ -d "argo/apps" ]; then
    success "Estrutura Argo CD configurada"
else
    error "Estrutura Argo CD não encontrada"
fi

# Verificar plataforma
info "3. Verificando configuração de plataforma"
if [ -d "plataforma/ingress" ] && [ -d "plataforma/observabilidade" ]; then
    success "Estrutura de plataforma criada"
else
    error "Estrutura de plataforma não encontrada"
fi

# Verificar remoção de arquivos desnecessários
info "4. Verificando limpeza de arquivos"
REMOVED_ITEMS=0

if [ ! -f "docker-compose.localstack.yml" ]; then
    success "docker-compose.localstack.yml removido"
    ((REMOVED_ITEMS++))
fi

if [ ! -f "docker-compose.tools.yml" ]; then
    success "docker-compose.tools.yml removido"
    REMOVED_ITEMS=$((REMOVED_ITEMS + 1))
fi

if [ ! -d "infra/terraform-localstack" ]; then
    success "terraform-localstack/ removido"
    REMOVED_ITEMS=$((REMOVED_ITEMS + 1))
fi

if [ ! -d "localstack-data" ]; then
    success "localstack-data/ removido"
    REMOVED_ITEMS=$((REMOVED_ITEMS + 1))
fi

if [ ! -d "localstack-kubeconfig" ]; then
    success "localstack-kubeconfig/ removido"
    REMOVED_ITEMS=$((REMOVED_ITEMS + 1))
fi

info "Total de itens desnecessários removidos: $REMOVED_ITEMS"

# Verificar configuração Terraform
info "5. Validando configuração Terraform"
cd infra/terraform
if terraform validate > /dev/null 2>&1; then
    success "Configuração Terraform válida"
else
    error "Configuração Terraform inválida"
    terraform validate
fi
cd ../..

# Verificar estrutura final
info "6. Resumo da estrutura final"
echo ""
echo "Diretórios criados:"
echo "  argo/"
echo "  plataforma/"
echo "  infra/terraform/modules/"
echo ""

success "VALIDAÇÃO CONCLUÍDA"
echo ""
echo "Próximos passos:"
echo "1. terraform plan (validar infraestrutura)"
echo "2. terraform apply (provisionar recursos)"
echo "3. Instalar Argo CD no cluster"
echo "4. Aplicar App of Apps (kubectl apply -f argo/root.yaml)"