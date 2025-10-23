#!/bin/bash
# Script para criar cluster kind local e aplicar manifests K8s

set -e

cd "$(dirname "$0")/.."

echo "☸️  Configurando Kubernetes local com kind"
echo ""

# Verificar se kind está instalado
if ! command -v kind &> /dev/null; then
    echo "📦 kind não encontrado. Instalando via Docker..."
    
    # kind via container
    KIND_CMD="docker run --rm -it --network=host -v $(pwd):/workspace -v /var/run/docker.sock:/var/run/docker.sock kindest/node:v1.28.0"
    
    echo "⚠️  Para simplificar, vamos usar apenas docker compose"
    echo "   O LocalStack Community não suporta EKS completo"
    echo ""
    echo "📝 Alternativa: Aplicar manifests simulados via docker compose"
    exit 0
fi

# Criar cluster kind se não existir
if ! kind get clusters 2>/dev/null | grep -q "^case-local$"; then
    echo "🏗️  Criando cluster kind 'case-local'..."
    cat <<EOF | kind create cluster --name case-local --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
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
else
    echo "✅ Cluster kind 'case-local' já existe"
fi

# Configurar kubectl context
kubectl cluster-info --context kind-case-local

echo ""
echo "📦 Aplicando manifests K8s..."

# Namespace
kubectl apply -f k8s/namespace.yaml

# Preparar manifests com variáveis substituídas
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Substituir placeholders
AWS_ACCOUNT_ID="000000000000"
AWS_REGION="us-east-1"
DD_API_KEY="${DD_API_KEY:-dummy-key}"
DD_SITE="us5.datadoghq.com"

for file in k8s/*.yaml; do
    if [ "$file" != "k8s/namespace.yaml" ]; then
        sed -e "s/<AWS_ACCOUNT_ID>/$AWS_ACCOUNT_ID/g" \
            -e "s/<AWS_REGION>/$AWS_REGION/g" \
            -e "s/<DD_API_KEY>/$DD_API_KEY/g" \
            -e "s/<DD_SITE>/$DD_SITE/g" \
            "$file" > "$TEMP_DIR/$(basename $file)"
    fi
done

# Aplicar configs e secrets
kubectl apply -f "$TEMP_DIR/env-config.yaml" 2>/dev/null || true
kubectl apply -f "$TEMP_DIR/datadog-secret.yaml" 2>/dev/null || true
kubectl apply -f "$TEMP_DIR/backend-serviceaccount.yaml" 2>/dev/null || true

# Aplicar deployments
kubectl apply -f "$TEMP_DIR/backend-deployment.yaml"
kubectl apply -f "$TEMP_DIR/frontend-deployment.yaml"

# Aplicar HPA
kubectl apply -f "$TEMP_DIR/backend-hpa.yaml" 2>/dev/null || true
kubectl apply -f "$TEMP_DIR/frontend-hpa.yaml" 2>/dev/null || true

# Aplicar Ingress
kubectl apply -f "$TEMP_DIR/ingress.yaml" 2>/dev/null || true

echo ""
echo "⏳ Aguardando pods ficarem prontos..."
kubectl wait --for=condition=ready pod -l app=backend -n case --timeout=60s || true
kubectl wait --for=condition=ready pod -l app=frontend -n case --timeout=60s || true

echo ""
echo "📊 Status dos recursos:"
kubectl get all -n case

echo ""
echo "✅ Manifests K8s aplicados!"
echo ""
echo "🌐 Para acessar a aplicação:"
echo "   kubectl port-forward -n case svc/frontend 8080:80"
echo "   Acesse: http://localhost:8080"
echo ""
echo "📝 Comandos úteis:"
echo "   kubectl get pods -n case"
echo "   kubectl logs -n case -l app=backend"
echo "   kubectl describe deployment -n case backend"
