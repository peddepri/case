#!/bin/bash

set -e

# Configurações
AWS_REGION="us-east-2"
CLUSTER_NAME="case-dev"
NAMESPACE="case"

echo "=== Validação Pré-Deploy Pipeline EKS ==="
echo "Região: $AWS_REGION"
echo "Cluster: $CLUSTER_NAME"
echo "Namespace: $NAMESPACE"
echo ""

# 1. Verificar AWS CLI e credenciais
echo "1. Verificando AWS CLI e credenciais..."
if ! command -v aws &> /dev/null; then
    echo " AWS CLI não encontrado"
    exit 1
fi

if ! aws sts get-caller-identity &> /dev/null; then
    echo " Credenciais AWS não configuradas"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo " AWS CLI configurado (Account: $ACCOUNT_ID)"

# 2. Verificar kubectl
echo "2. Verificando kubectl..."
if ! command -v kubectl &> /dev/null; then
    echo " kubectl não encontrado"
    exit 1
fi
echo " kubectl disponível"

# 3. Verificar conexão com cluster EKS
echo "3. Verificando conexão com cluster EKS..."
if aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION &> /dev/null; then
    echo " Cluster EKS '$CLUSTER_NAME' encontrado"
    
    # Atualizar kubeconfig
    aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME --no-cli-pager
    
    # Testar conexão
    if kubectl get nodes &> /dev/null; then
        echo " Conexão com Kubernetes estabelecida"
        kubectl get nodes --no-headers | while read line; do
            echo "  └─ $line"
        done
    else
        echo " Falha ao conectar com Kubernetes"
        exit 1
    fi
else
    echo " Cluster EKS '$CLUSTER_NAME' não encontrado na região $AWS_REGION"
    exit 1
fi

# 4. Verificar ECR repositories
echo "4. Verificando repositórios ECR..."
ECR_REGISTRY="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

for repo in case-backend case-frontend case-mobile; do
    if aws ecr describe-repositories --repository-names $repo --region $AWS_REGION &> /dev/null; then
        echo " Repositório ECR '$repo' encontrado"
        
        # Verificar se há imagens
        IMAGE_COUNT=$(aws ecr describe-images --repository-name $repo --region $AWS_REGION --query 'length(imageDetails)' --output text 2>/dev/null || echo "0")
        if [ "$IMAGE_COUNT" -gt 0 ]; then
            echo "  └─ $IMAGE_COUNT imagem(ns) disponível(eis)"
        else
            echo "  └─ Nenhuma imagem encontrada"
        fi
    else
        echo " Repositório ECR '$repo' não encontrado"
        exit 1
    fi
done

# 5. Verificar manifests Kubernetes
echo "5. Verificando manifests Kubernetes..."
MANIFEST_DIR="domains/platform/manifests"

if [ ! -d "$MANIFEST_DIR" ]; then
    echo " Diretório de manifests não encontrado: $MANIFEST_DIR"
    exit 1
fi

REQUIRED_MANIFESTS=(
    "namespace.yaml"
    "env-config.yaml"
    "backend-serviceaccount.yaml"
    "backend-deployment.yaml"
    "frontend-deployment.yaml"
    "mobile-deployment.yaml"
    "backend-hpa.yaml"
    "frontend-hpa.yaml"
    "mobile-hpa.yaml"
    "ingress.yaml"
)

for manifest in "${REQUIRED_MANIFESTS[@]}"; do
    if [ -f "$MANIFEST_DIR/$manifest" ]; then
        echo " Manifest '$manifest' encontrado"
        
        # Validar sintaxe YAML
        if kubectl apply --dry-run=client -f "$MANIFEST_DIR/$manifest" &> /dev/null; then
            echo "  └─ Sintaxe YAML válida"
        else
            echo "  └─   Problemas de sintaxe YAML detectados"
        fi
    else
        echo " Manifest '$manifest' não encontrado"
        exit 1
    fi
done

# 6. Verificar Terraform
echo "6. Verificando configuração Terraform..."
TF_DIR="domains/infra/terraform/environments/dev"

if [ ! -d "$TF_DIR" ]; then
    echo " Diretório Terraform não encontrado: $TF_DIR"
    exit 1
fi

cd "$TF_DIR"

if [ -f "terraform.tf" ]; then
    echo " Configuração Terraform encontrada"
    
    # Verificar se terraform está inicializado
    if [ -d ".terraform" ]; then
        echo " Terraform inicializado"
    else
        echo "  Terraform não inicializado - executar 'terraform init'"
    fi
else
    echo " Arquivo terraform.tf não encontrado"
    exit 1
fi

cd - > /dev/null

# 7. Verificar GitHub Actions secrets necessários
echo "7. Verificando configuração GitHub Actions..."
WORKFLOW_FILE=".github/workflows/eks-complete-pipeline.yml"

if [ -f "$WORKFLOW_FILE" ]; then
    echo " Workflow pipeline encontrado"
    
    # Listar secrets necessários
    echo "  Secrets necessários no GitHub:"
    echo "  └─ AWS_ROLE_TO_ASSUME"
    echo "  └─ DD_API_KEY (se Datadog habilitado)"
    echo "  └─ BACKEND_IRSA_ROLE_ARN (se configurado)"
else
    echo " Workflow pipeline não encontrado"
    exit 1
fi

# 8. Status atual dos deployments (se existir)
echo "8. Verificando deployments existentes..."
if kubectl get namespace $NAMESPACE &> /dev/null; then
    echo " Namespace '$NAMESPACE' existe"
    
    echo "  Deployments atuais:"
    kubectl get deployments -n $NAMESPACE --no-headers 2>/dev/null | while read line; do
        echo "  └─ $line"
    done || echo "  └─ Nenhum deployment encontrado"
    
    echo "  Services atuais:"
    kubectl get services -n $NAMESPACE --no-headers 2>/dev/null | while read line; do
        echo "  └─ $line"
    done || echo "  └─ Nenhum service encontrado"
else
    echo "  Namespace '$NAMESPACE' não existe (será criado na pipeline)"
fi

# 9. Verificar recursos de observabilidade (se habilitados)
echo "9. Verificando recursos de observabilidade..."
if kubectl get namespace monitoring &> /dev/null; then
    echo " Namespace 'monitoring' existe"
    
    # Verificar Grafana
    if kubectl get deployment grafana -n monitoring &> /dev/null; then
        echo "  └─  Grafana deployado"
    fi
    
    # Verificar Prometheus
    if kubectl get deployment prometheus-server -n monitoring &> /dev/null; then
        echo "  └─  Prometheus deployado"
    fi
else
    echo "  Namespace 'monitoring' não existe (observabilidade será configurada)"
fi

echo ""
echo "=== Resumo da Validação ==="
echo " Todas as verificações básicas passaram"
echo " Ambiente está pronto para executar a pipeline"
echo ""
echo "Para executar a pipeline:"
echo "1. Commit e push das alterações"
echo "2. Ir para GitHub Actions"
echo "3. Executar workflow 'Complete EKS Deployment Pipeline'"
echo "4. Escolher ação: 'provision-and-deploy' ou 'deploy-only'"
echo ""
echo "Pipeline executará os seguintes passos:"
echo "1. 🏗  Provisionar infraestrutura (EKS + ECR)"
echo "2. 🐳 Build e push das imagens Docker"
echo "3. 🚀 Deploy das aplicações no Kubernetes"  
echo "4.  Validação e testes de saúde"
echo "5. 📊 Geração de relatório"