#!/bin/bash
# Script simplificado para ambiente LocalStack + kind (Windows-friendly)

cd "$(dirname "$0")/.."

echo "Iniciando ambiente LocalStack + Kubernetes"
echo ""

# 1. LocalStack
echo "1. Iniciando LocalStack..."
docker compose -f docker-compose.localstack.yml up -d localstack

echo "   Aguardando LocalStack..."
until curl -s http://localhost:4566/_localstack/health > /dev/null 2>&1; do
    echo -n "."
    sleep 2
done
echo " OK"

# 2. Provisionar AWS
echo ""
echo "2. Provisionando recursos AWS..."
bash scripts/localstack-provision-simple.sh

# 3. Criar cluster kind
echo ""
echo "3. Criando cluster kind..."

CLUSTER_NAME="case-local"

if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    cat <<EOF | kind create cluster --name "$CLUSTER_NAME" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 80
    hostPort: 8080
  - containerPort: 443
    hostPort: 8443
EOF
    echo "   Cluster criado"
else
    echo "   Cluster ja existe"
fi

# 4. Build imagens
echo ""
echo "4. Construindo imagens Docker..."
docker build -t case-backend:latest app/backend
docker build -t case-frontend:latest app/frontend

# 5. Carregar no kind
echo ""
echo "5. Carregando imagens no kind..."
kind load docker-image case-backend:latest --name "$CLUSTER_NAME"
kind load docker-image case-frontend:latest --name "$CLUSTER_NAME"

# 6. Aplicar manifests
echo ""
echo "6. Aplicando manifests K8s..."

kubectl apply -f k8s/namespace.yaml

# ConfigMap
kubectl create configmap env-config \
    --from-literal=AWS_REGION=us-east-1 \
    --from-literal=DDB_TABLE=orders \
    --from-literal=DD_SITE=us5.datadoghq.com \
    --from-literal=DYNAMODB_ENDPOINT=http://host.docker.internal:4566 \
    -n case --dry-run=client -o yaml | kubectl apply -f -

# Secret
kubectl create secret generic datadog \
    --from-literal=api-key="${DD_API_KEY:-dummy}" \
    -n case --dry-run=client -o yaml | kubectl apply -f -

# ServiceAccount
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backend-sa
  namespace: case
EOF

# Backend
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: case
spec:
  replicas: 1
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
        image: case-backend:latest
        imagePullPolicy: Never
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
EOF

# Frontend
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: case
spec:
  replicas: 1
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
        image: case-frontend:latest
        imagePullPolicy: Never
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
EOF

# Ingress Nginx
echo ""
echo "7. Instalando Ingress..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s 2>/dev/null || echo "   Aviso: Ingress pode demorar mais"

# Ingress rules
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: case-ingress
  namespace: case
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

# Status
echo ""
echo "Ambiente pronto!"
echo ""
echo "Status:"
kubectl get pods -n case
echo ""
echo "Acesso:"
echo "   http://localhost:8080 (via Ingress)"
echo ""
echo "Comandos uteis:"
echo "   kubectl get pods -n case"
echo "   kubectl logs -n case -l app=backend -f"
echo "   bash scripts/awslocal.sh dynamodb scan --table-name orders"
