#!/bin/bash
# Script para corrigir imagens do Kubernetes para usar imagens locais
# Autor: Kiro  Assistant
# Data: 2025-10-25

set -e

cd "$(dirname "$0")/.."

echo "🔧 Corrigindo imagens do Kubernetes para usar imagens locais..."

# Verificar se cluster existe
if ! kind get clusters 2>/dev/null | grep -q "case-local"; then
    echo " Cluster kind 'case-local' não encontrado"
    exit 1
fi

# Verificar se namespace existe
if ! kubectl get namespace case >/dev/null 2>&1; then
    echo " Namespace 'case' não encontrado"
    exit 1
fi

echo " Reconstruindo e carregando imagens..."

# Build imagens
docker build -t case-backend:latest app/backend
docker build -t case-frontend:latest app/frontend  
docker build -t case-mobile:latest app/mobile

# Carregar no kind
kind load docker-image case-backend:latest --name case-local
kind load docker-image case-frontend:latest --name case-local
kind load docker-image case-mobile:latest --name case-local

echo " Atualizando deployments para usar imagens locais..."

# Patch Backend Deployment
kubectl patch deployment backend -n case -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "backend",
          "image": "case-backend:latest",
          "imagePullPolicy": "Never"
        }]
      }
    }
  }
}'

# Patch Frontend Deployment  
kubectl patch deployment frontend -n case -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "frontend", 
          "image": "case-frontend:latest",
          "imagePullPolicy": "Never"
        }]
      }
    }
  }
}'

# Patch Mobile Deployment (se existir)
if kubectl get deployment mobile -n case >/dev/null 2>&1; then
  kubectl patch deployment mobile -n case -p '{
    "spec": {
      "template": {
        "spec": {
          "containers": [{
            "name": "mobile",
            "image": "case-mobile:latest", 
            "imagePullPolicy": "Never"
          }]
        }
      }
    }
  }'
fi

echo " Aguardando rollout dos deployments..."

# Aguardar rollout
kubectl rollout status deployment/backend -n case --timeout=120s
kubectl rollout status deployment/frontend -n case --timeout=120s

if kubectl get deployment mobile -n case >/dev/null 2>&1; then
  kubectl rollout status deployment/mobile -n case --timeout=120s
fi

echo " Deployments atualizados com sucesso!"

echo ""
echo " Status dos pods:"
kubectl get pods -n case

echo ""
echo " Verificando se pods estão rodando..."
kubectl wait --for=condition=ready pod -l app=backend -n case --timeout=60s
kubectl wait --for=condition=ready pod -l app=frontend -n case --timeout=60s

echo ""
echo " Todos os pods estão rodando!"

echo ""
echo " Testando conectividade..."

# Port-forward temporário para testar
kubectl port-forward -n case svc/backend 3002:3000 &
PF_PID=$!
sleep 3

if curl -sf http://localhost:3002/healthz >/dev/null; then
    echo " Backend respondendo via Kubernetes"
else
    echo " Backend não está respondendo"
fi

# Matar port-forward
kill $PF_PID 2>/dev/null || true

echo ""
echo " Endpoints disponíveis:"
echo "   • Kubernetes Ingress: http://localhost:8080"
echo "   • Backend API: http://localhost:8080/api/orders"
echo "   • Frontend: http://localhost:8080"
echo ""
echo " Comandos úteis:"
echo "   kubectl get pods -n case"
echo "   kubectl logs -n case -l app=backend -f"
echo "   kubectl describe ingress case-ingress -n case"
echo ""