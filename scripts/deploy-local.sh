#!/bin/bash

# Script para deploy local simplificado
set -e

echo "🚀 Iniciando deploy local simplificado..."

# 1. Namespace
echo "📝 Aplicando namespace..."
kubectl apply -f k8s/namespace.yaml

# 2. Configurações básicas
echo "⚙️ Configurando ambiente local..."
kubectl create configmap env-config -n case \
  --from-literal=DDB_TABLE=orders \
  --from-literal=AWS_REGION=us-east-1 \
  --from-literal=DD_SITE=datadoghq.com \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic datadog -n case \
  --from-literal=api-key=mock-dd-key \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create serviceaccount backend-sa -n case \
  --dry-run=client -o yaml | kubectl apply -f -

# 3. Build e load das imagens (se Docker estiver disponível)
if command -v docker &> /dev/null; then
  echo "🐳 Construindo imagens locais..."
  
  # Backend
  if [ -f "app/backend/Dockerfile" ]; then
    docker build -t case-backend:local app/backend/
    kind load docker-image case-backend:local --name case-local
  fi
  
  # Frontend  
  if [ -f "app/frontend/Dockerfile" ]; then
    docker build -t case-frontend:local app/frontend/
    kind load docker-image case-frontend:local --name case-local
  fi
  
  # Mobile
  if [ -f "app/mobile/Dockerfile" ]; then
    docker build -t case-mobile:local app/mobile/
    kind load docker-image case-mobile:local --name case-local
  fi
else
  echo "⚠️ Docker não encontrado, usando imagens padrão"
fi

# 4. Deploy backend com imagem local
echo "📦 Aplicando backend..."
cat k8s/backend-deployment.yaml | \
sed -e 's|<AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com/backend:latest|case-backend:local|g' | \
kubectl apply -f -

# 5. Deploy frontend com imagem local  
echo "📦 Aplicando frontend..."
cat k8s/frontend-deployment.yaml | \
sed -e 's|<AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com/frontend:latest|case-frontend:local|g' | \
kubectl apply -f -

# 6. Deploy mobile com imagem local
echo "📦 Aplicando mobile..."
cat k8s/mobile-deployment.yaml | \
sed -e 's|<AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com/mobile:latest|case-mobile:local|g' | \
kubectl apply -f -

# 7. Aplicar apenas componentes essenciais (sem HPA que pode causar problemas)
echo "📡 Aplicando ingress..."
kubectl apply -f k8s/ingress.yaml || echo "⚠️ Ingress falhou (normal se não tiver controller)"

# 8. Aguardar deployments
echo "⏳ Aguardando pods ficarem prontos..."
kubectl wait --for=condition=available deployment/backend -n case --timeout=120s || true
kubectl wait --for=condition=available deployment/frontend -n case --timeout=120s || true  
kubectl wait --for=condition=available deployment/mobile -n case --timeout=120s || true

# 9. Status final
echo "✅ Deploy concluído! Status:"
kubectl get pods -n case -o wide
echo ""
echo "🔍 Para acessar os serviços:"
echo "kubectl port-forward -n case svc/backend 8080:3000"  
echo "kubectl port-forward -n case svc/frontend 3000:3000"
echo "kubectl port-forward -n case svc/mobile 8081:3000"