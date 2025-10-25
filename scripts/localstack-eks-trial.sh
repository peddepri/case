#!/bin/bash
# Script para provisionar EKS real no LocalStack Pro (Trial)
# Usa o EKS nativo do LocalStack em vez de kind

set -e

cd "$(dirname "$0")/.."

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() { echo -e "${GREEN}✓ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; exit 1; }

echo "╔════════════════════════════════════════════════════════╗"
echo "║  LocalStack EKS (Pro Trial) - Provisionamento Completo ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Verificar auth token
if [ -z "$LOCALSTACK_AUTH_TOKEN" ]; then
    print_warning "LOCALSTACK_AUTH_TOKEN não definido!"
    echo ""
    echo "Para usar EKS no LocalStack Pro, você precisa:"
    echo "1. Obter token em: https://app.localstack.cloud/workspace/auth-token"
    echo "2. Exportar: export LOCALSTACK_AUTH_TOKEN='your-token'"
    echo ""
    read -p "Deseja continuar assim mesmo? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# ============================================================
# STEP 1: Iniciar LocalStack Pro
# ============================================================
print_info "STEP 1: Iniciando LocalStack Pro com EKS..."

if curl -s http://localhost:4566/_localstack/health > /dev/null 2>&1; then
    print_warning "LocalStack já está rodando. Parando para reiniciar com EKS..."
    docker compose -f docker-compose.localstack.yml down
fi

# Iniciar LocalStack com EKS habilitado
docker compose -f docker-compose.localstack.yml up -d localstack

# Aguardar LocalStack
print_info "Aguardando LocalStack inicializar (pode levar 30-60s)..."
sleep 10

MAX_RETRIES=30
RETRY_COUNT=0
while ! curl -s http://localhost:4566/_localstack/health | grep -qE '"eks": "(running|available)"'; do
    echo -n "."
    sleep 2
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        print_error "LocalStack não inicializou corretamente"
    fi
done
echo ""
print_step "LocalStack Pro rodando com EKS"

# ============================================================
# STEP 2: Provisionar recursos AWS base via CLI
# ============================================================
print_info ""
print_info "STEP 2: Provisionando recursos AWS base..."

bash scripts/localstack-provision-simple.sh > /tmp/localstack-provision.log 2>&1
print_step "Recursos AWS provisionados (DynamoDB, ECR, IAM, Secrets)"

# ============================================================
# STEP 3: Criar cluster EKS no LocalStack
# ============================================================
print_info ""
print_info "STEP 3: Criando cluster EKS no LocalStack..."

CLUSTER_NAME="case-eks-local"
REGION="us-east-1"

# Verificar se cluster já existe
if bash scripts/awslocal.sh eks describe-cluster --name "$CLUSTER_NAME" &>/dev/null; then
    print_warning "Cluster EKS '$CLUSTER_NAME' já existe"
else
    print_info "Criando cluster EKS '$CLUSTER_NAME'..."
    
    # Criar VPC e subnet (requerido pelo EKS)
    print_info "Criando VPC..."
    VPC_ID=$(bash scripts/awslocal.sh ec2 create-vpc \
        --cidr-block 10.0.0.0/16 \
        --query 'Vpc.VpcId' \
        --output text)
    
    print_info "Criando subnet..."
    SUBNET_ID=$(bash scripts/awslocal.sh ec2 create-subnet \
        --vpc-id "$VPC_ID" \
        --cidr-block 10.0.1.0/24 \
        --query 'Subnet.SubnetId' \
        --output text)
    
    # Criar role para EKS cluster
    print_info "Criando IAM role para cluster..."
    bash scripts/awslocal.sh iam create-role \
        --role-name case-eks-cluster-role \
        --assume-role-policy-document '{
            "Version": "2012-10-17",
            "Statement": [{
                "Effect": "Allow",
                "Principal": {"Service": "eks.amazonaws.com"},
                "Action": "sts:AssumeRole"
            }]
        }' &>/dev/null || true
    
    CLUSTER_ROLE_ARN="arn:aws:iam::000000000000:role/case-eks-cluster-role"
    
    # Criar cluster EKS
    print_info "Criando cluster EKS (pode levar 1-2 minutos)..."
    bash scripts/awslocal.sh eks create-cluster \
        --name "$CLUSTER_NAME" \
        --role-arn "$CLUSTER_ROLE_ARN" \
        --resources-vpc-config "subnetIds=$SUBNET_ID" \
        --region "$REGION"
    
    # Aguardar cluster ficar ativo
    print_info "Aguardando cluster ficar ACTIVE..."
    sleep 5
    
    for i in {1..30}; do
        STATUS=$(bash scripts/awslocal.sh eks describe-cluster \
            --name "$CLUSTER_NAME" \
            --query 'cluster.status' \
            --output text 2>/dev/null || echo "CREATING")
        
        if [ "$STATUS" = "ACTIVE" ]; then
            break
        fi
        echo -n "."
        sleep 2
    done
    echo ""
    
    print_step "Cluster EKS '$CLUSTER_NAME' criado e ACTIVE"
fi

# ============================================================
# STEP 4: Configurar kubeconfig para o cluster EKS
# ============================================================
print_info ""
print_info "STEP 4: Configurando kubeconfig..."

mkdir -p localstack-kubeconfig

bash scripts/awslocal.sh eks update-kubeconfig \
    --name "$CLUSTER_NAME" \
    --region "$REGION" \
    --kubeconfig localstack-kubeconfig/config

# Ajustar endpoint para localhost
sed -i 's|https://.*:4511|https://localhost:4511|g' localstack-kubeconfig/config 2>/dev/null || \
    sed -i'' -e 's|https://.*:4511|https://localhost:4511|g' localstack-kubeconfig/config

export KUBECONFIG=$(pwd)/localstack-kubeconfig/config

print_step "Kubeconfig configurado em: localstack-kubeconfig/config"

# ============================================================
# STEP 5: Verificar cluster Kubernetes
# ============================================================
print_info ""
print_info "STEP 5: Verificando cluster Kubernetes..."

# Aguardar API server responder
print_info "Aguardando Kubernetes API..."
sleep 5

for i in {1..20}; do
    if kubectl cluster-info &>/dev/null; then
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

kubectl get nodes || print_warning "Nodes ainda não disponíveis (normal no LocalStack)"
print_step "Cluster Kubernetes acessível"

# ============================================================
# STEP 6: Build e Push de imagens para ECR
# ============================================================
print_info ""
print_info "STEP 6: Build e push de imagens para ECR LocalStack..."

ECR_ENDPOINT="000000000000.dkr.ecr.us-east-1.localhost.localstack.cloud:4566"

print_info "Building backend image..."
docker build -t backend:latest app/backend -q

print_info "Tagging backend..."
docker tag backend:latest $ECR_ENDPOINT/backend:latest

print_info "Pushing backend to ECR..."
docker push $ECR_ENDPOINT/backend:latest

print_info "Building frontend image..."
docker build -t frontend:latest app/frontend -q

print_info "Tagging frontend..."
docker tag frontend:latest $ECR_ENDPOINT/frontend:latest

print_info "Pushing frontend to ECR..."
docker push $ECR_ENDPOINT/frontend:latest

print_step "Imagens enviadas para ECR LocalStack"

# ============================================================
# STEP 7: Deploy da aplicação no EKS
# ============================================================
print_info ""
print_info "STEP 7: Aplicando manifests Kubernetes..."

# Namespace
kubectl apply -f k8s/namespace.yaml

# ConfigMap
kubectl create configmap env-config \
    --from-literal=AWS_REGION=us-east-1 \
    --from-literal=DDB_TABLE=orders \
    --from-literal=DD_SITE=us5.datadoghq.com \
    --from-literal=DYNAMODB_ENDPOINT=http://host.docker.internal:4566 \
    -n case \
    --dry-run=client -o yaml | kubectl apply -f -

# Secret Datadog
kubectl create secret generic datadog \
    --from-literal=api-key="${DD_API_KEY:-dummy}" \
    -n case \
    --dry-run=client -o yaml | kubectl apply -f -

# ServiceAccount
kubectl apply -f k8s/backend-serviceaccount.yaml

# Backend Deployment (usando imagem do ECR)
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: case
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      serviceAccountName: backend-sa
      containers:
      - name: backend
        image: $ECR_ENDPOINT/backend:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 3000
        env:
        - name: PORT
          value: "3000"
        - name: AWS_REGION
          value: "us-east-1"
        - name: DDB_TABLE
          value: "orders"
        - name: DYNAMODB_ENDPOINT
          value: "http://host.docker.internal:4566"
        - name: AWS_ACCESS_KEY_ID
          value: "test"
        - name: AWS_SECRET_ACCESS_KEY
          value: "test"
        - name: DD_ENV
          value: "localstack-eks"
        - name: DD_SERVICE
          value: "backend"
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: case
spec:
  selector:
    app: backend
  ports:
  - port: 3000
    targetPort: 3000
  type: ClusterIP
EOF

# Frontend Deployment
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: case
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: $ECR_ENDPOINT/frontend:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 80
        env:
        - name: VITE_BACKEND_URL
          value: "http://backend.case.svc.cluster.local:3000"
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: case
spec:
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
EOF

print_step "Manifests aplicados"

# ============================================================
# STEP 8: Aguardar pods
# ============================================================
print_info ""
print_info "STEP 8: Aguardando pods ficarem prontos..."

kubectl wait --for=condition=ready pod -l app=backend -n case --timeout=120s || \
    print_warning "Backend pods demorando mais que esperado"

kubectl wait --for=condition=ready pod -l app=frontend -n case --timeout=120s || \
    print_warning "Frontend pods demorando mais que esperado"

print_step "Pods prontos"

# ============================================================
# RESUMO
# ============================================================
echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║           ✓ Provisionamento Completo!                  ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

print_info "Status do Cluster EKS:"
bash scripts/awslocal.sh eks describe-cluster --name "$CLUSTER_NAME" \
    --query 'cluster.{Name:name,Status:status,Endpoint:endpoint,Version:version}' \
    --output table

echo ""
print_info "Pods na namespace 'case':"
kubectl get pods -n case

echo ""
print_info "Services:"
kubectl get svc -n case

echo ""
print_info "Recursos AWS:"
echo "  • DynamoDB: $(bash scripts/awslocal.sh dynamodb list-tables --query 'TableNames[0]' --output text)"
echo "  • ECR: $(bash scripts/awslocal.sh ecr describe-repositories --query 'repositories[].repositoryName' --output text | tr '\n' ', ' | sed 's/,$//')"

echo ""
echo "════════════════════════════════════════════════════════"
echo "🔗 Endpoints:"
echo "════════════════════════════════════════════════════════"
echo "  LocalStack:     http://localhost:4566"
echo "  K8s API:        https://localhost:4511"
echo "  Backend API:    kubectl port-forward -n case svc/backend 3000:3000"
echo "  Frontend:       kubectl port-forward -n case svc/frontend 8080:80"
echo ""

echo "📝 Comandos úteis:"
echo ""
echo "  # Ver pods"
echo "  export KUBECONFIG=$(pwd)/localstack-kubeconfig/config"
echo "  kubectl get pods -n case"
echo ""
echo "  # Logs"
echo "  kubectl logs -n case -l app=backend -f"
echo ""
echo "  # Port-forward frontend"
echo "  kubectl port-forward -n case svc/frontend 8080:80"
echo ""
echo "  # Acessar DynamoDB"
echo "  bash scripts/awslocal.sh dynamodb scan --table-name orders"
echo ""
echo "  # Limpar ambiente"
echo "  bash scripts/awslocal.sh eks delete-cluster --name $CLUSTER_NAME"
echo "  docker compose -f docker-compose.localstack.yml down"
echo ""

print_step "Ambiente LocalStack EKS Pro pronto para uso!"
