#!/bin/bash
# Script completo para provisionar LocalStack + kind (EKS local) + Manifests K8s

set -e

cd "$(dirname "$0")/.."

echo "Provisionamento Completo: LocalStack + Kubernetes (kind)"
echo "============================================================"
echo ""

# Cores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Funções helper
print_step() {
    echo -e "${GREEN}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}AVISO: $1${NC}"
}

print_error() {
    echo -e "${RED}ERRO: $1${NC}"
}

# Passo 1: Verificar dependências
print_step "1. Verificando dependencias..."

if ! docker info > /dev/null 2>&1; then
    print_error "Docker não está rodando"
    exit 1
fi

if ! command -v kind &> /dev/null; then
    print_warning "kind não encontrado. Instalando..."
    
    # Detectar OS
    OS="$(uname -s)"
    case "$OS" in
        Linux*)     
            curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
            chmod +x ./kind
            sudo mv ./kind /usr/local/bin/kind
            ;;
        Darwin*)    
            brew install kind || curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-darwin-amd64
            ;;
        MINGW*|MSYS*|CYGWIN*)
            curl -Lo kind.exe https://kind.sigs.k8s.io/dl/v0.20.0/kind-windows-amd64
            print_warning "Mova kind.exe para PATH manualmente"
            ;;
    esac
fi

if ! command -v kubectl &> /dev/null; then
    print_warning "kubectl não encontrado. Usando via Docker..."
    KUBECTL_CMD="docker run --rm -v $(pwd):/workspace -w /workspace --network host bitnami/kubectl:1.28"
else
    KUBECTL_CMD="kubectl"
fi

echo "   Dependencias verificadas"

# Passo 2: Subir LocalStack
print_step ""
print_step "2. Iniciando LocalStack..."

if ! curl -s http://localhost:4566/_localstack/health > /dev/null 2>&1; then
    docker compose -f docker-compose.localstack.yml up -d localstack
    
    echo "   Aguardando LocalStack..."
    until curl -s http://localhost:4566/_localstack/health | grep -q '"dynamodb": "running"'; do
        echo -n "."
        sleep 2
    done
    echo " OK"
else
    echo "   LocalStack ja esta rodando"
fi

# Passo 3: Provisionar recursos AWS
print_step ""
print_step "3. Provisionando recursos AWS no LocalStack..."

bash scripts/localstack-provision-simple.sh > /tmp/localstack-provision.log 2>&1 || {
    print_warning "Erro ao provisionar. Ver log: /tmp/localstack-provision.log"
}

echo "   Recursos AWS provisionados"

# Passo 4: Criar cluster kind
print_step ""
print_step "4. Criando cluster Kubernetes (kind)..."

CLUSTER_NAME="case-local"

if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    print_warning "Cluster '$CLUSTER_NAME' ja existe. Usando existente."
else
    cat <<EOF | kind create cluster --name "$CLUSTER_NAME" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: "0.0.0.0"
  apiServerPort: 6443
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 8080
    protocol: TCP
  - containerPort: 443
    hostPort: 8443
    protocol: TCP
EOF
    echo "   Cluster criado"
fi

# Configurar kubeconfig
mkdir -p localstack-kubeconfig
kind get kubeconfig --name "$CLUSTER_NAME" > localstack-kubeconfig/config

# Verificar cluster
$KUBECTL_CMD cluster-info --context "kind-${CLUSTER_NAME}"
echo "   Cluster acessivel"

# Passo 5: Aplicar manifests K8s
print_step ""
print_step "5. Aplicando manifests Kubernetes..."

# Namespace
$KUBECTL_CMD apply -f k8s/namespace.yaml

# Preparar variáveis
export AWS_ACCOUNT_ID="000000000000"
export AWS_REGION="us-east-1"
export DD_API_KEY="${DD_API_KEY:-dummy-key}"
export DD_SITE="us5.datadoghq.com"
export BACKEND_IRSA_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/case-backend-sa-role"

# Criar ConfigMap
$KUBECTL_CMD create configmap env-config \
    --from-literal=AWS_REGION="$AWS_REGION" \
    --from-literal=DDB_TABLE="orders" \
    --from-literal=DD_SITE="$DD_SITE" \
    --from-literal=DYNAMODB_ENDPOINT="http://host.docker.internal:4566" \
    -n case \
    --dry-run=client -o yaml | $KUBECTL_CMD apply -f -

# Criar Secret para Datadog
$KUBECTL_CMD create secret generic datadog \
    --from-literal=api-key="$DD_API_KEY" \
    -n case \
    --dry-run=client -o yaml | $KUBECTL_CMD apply -f -

# ServiceAccount
cat <<EOF | $KUBECTL_CMD apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backend-sa
  namespace: case
  annotations:
    eks.amazonaws.com/role-arn: "$BACKEND_IRSA_ROLE_ARN"
EOF

# Backend Deployment (imagem local)
cat <<EOF | $KUBECTL_CMD apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: case
  labels:
    app: backend
    color: blue
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
      color: blue
  template:
    metadata:
      labels:
        app: backend
        color: blue
    spec:
      serviceAccountName: backend-sa
      containers:
      - name: backend
        image: case-backend:latest
        imagePullPolicy: Never
        ports:
        - containerPort: 3000
        env:
        - name: PORT
          value: "3000"
        - name: AWS_REGION
          valueFrom:
            configMapKeyRef:
              name: env-config
              key: AWS_REGION
        - name: DDB_TABLE
          valueFrom:
            configMapKeyRef:
              name: env-config
              key: DDB_TABLE
        - name: DYNAMODB_ENDPOINT
          valueFrom:
            configMapKeyRef:
              name: env-config
              key: DYNAMODB_ENDPOINT
        - name: AWS_ACCESS_KEY_ID
          value: "test"
        - name: AWS_SECRET_ACCESS_KEY
          value: "test"
        - name: DD_ENV
          value: "kind"
        - name: DD_SERVICE
          value: "backend"
        - name: DD_VERSION
          value: "0.1.0"
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: case
spec:
  selector:
    app: backend
    color: blue
  ports:
  - port: 3000
    targetPort: 3000
    protocol: TCP
    name: http
  type: ClusterIP
EOF

# Frontend Deployment
cat <<EOF | $KUBECTL_CMD apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: case
  labels:
    app: frontend
    color: blue
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
      color: blue
  template:
    metadata:
      labels:
        app: frontend
        color: blue
    spec:
      containers:
      - name: frontend
        image: case-frontend:latest
        imagePullPolicy: Never
        ports:
        - containerPort: 80
        env:
        - name: VITE_BACKEND_URL
          value: "http://backend.case.svc.cluster.local:3000"
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: case
spec:
  selector:
    app: frontend
    color: blue
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
    name: http
  type: ClusterIP
EOF

echo "   Manifests aplicados"

# Passo 6: Carregar imagens Docker no kind
print_step ""
print_step "6. Carregando imagens Docker no kind..."

# Build se necessário
if ! docker images | grep -q "case-backend.*latest"; then
    docker build -t case-backend:latest app/backend
fi

if ! docker images | grep -q "case-frontend.*latest"; then
    docker build -t case-frontend:latest app/frontend
fi

# Carregar no kind
kind load docker-image case-backend:latest --name "$CLUSTER_NAME"
kind load docker-image case-frontend:latest --name "$CLUSTER_NAME"

echo "   Imagens carregadas no kind"

# Passo 7: Aguardar pods
print_step ""
print_step "7. Aguardando pods ficarem prontos..."

$KUBECTL_CMD wait --for=condition=ready pod -l app=backend -n case --timeout=120s || print_warning "Backend pods nao ficaram prontos"
$KUBECTL_CMD wait --for=condition=ready pod -l app=frontend -n case --timeout=120s || print_warning "Frontend pods nao ficaram prontos"

# Passo 8: Configurar Ingress (Nginx)
print_step ""
print_step "8. Configurando Nginx Ingress..."

$KUBECTL_CMD apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

$KUBECTL_CMD wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s || print_warning "Ingress nao ficou pronto"

# Aplicar Ingress para aplicação
cat <<EOF | $KUBECTL_CMD apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: case-ingress
  namespace: case
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: backend
            port:
              number: 3000
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
EOF

echo "   Ingress configurado"

# Resumo final
print_step ""
print_step "============================================================"
print_step "Provisionamento Completo!"
print_step "============================================================"
echo ""

echo "Status do Ambiente:"
echo ""

echo "   LocalStack:"
echo "      http://localhost:4566"
curl -s http://localhost:4566/_localstack/health | grep -o '"dynamodb": "[^"]*"' || true
echo ""

echo "   Kubernetes (kind):"
$KUBECTL_CMD get nodes
echo ""

echo "   Pods:"
$KUBECTL_CMD get pods -n case
echo ""

echo "   Services:"
$KUBECTL_CMD get svc -n case
echo ""

echo "Endpoints:"
echo "   * Aplicacao (via Ingress): http://localhost:8080"
echo "   * Backend API: http://localhost:8080/api/orders"
echo "   * Frontend: http://localhost:8080"
echo "   * LocalStack: http://localhost:4566"
echo ""

echo "Comandos uteis:"
echo ""
echo "   # Ver pods"
echo "   kubectl get pods -n case"
echo ""
echo "   # Logs do backend"
echo "   kubectl logs -n case -l app=backend -f"
echo ""
echo "   # Port-forward backend direto"
echo "   kubectl port-forward -n case svc/backend 3000:3000"
echo ""
echo "   # Ver recursos AWS no LocalStack"
echo "   bash scripts/awslocal.sh dynamodb scan --table-name orders"
echo ""
echo "   # Destruir tudo"
echo "   kind delete cluster --name $CLUSTER_NAME"
echo "   docker compose -f docker-compose.localstack.yml down"
echo ""

print_step "Ambiente pronto para uso!"
