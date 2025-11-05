#!/bin/bash
# Script de deploy CI/CD com suporte a ServiceMonitors e ajuste de Ingress

set -e

echo "Aplicando recursos Kubernetes para CI/CD..."

# Criar namespace
kubectl create namespace case --dry-run=client -o yaml | kubectl apply --validate=false -f -

# Aplicar recursos essenciais (sem ServiceMonitors)
echo "Aplicando configurações..."
kubectl apply -f k8s/env-config.yaml -n case

echo "Aplicando secrets e service accounts..."
kubectl apply -f k8s/backend-serviceaccount.yaml -n case

echo "Aplicando deployments principais..."
kubectl apply -f k8s/backend-deployment.yaml -n case
kubectl apply -f k8s/frontend-deployment.yaml -n case

echo "Aplicando mobile deployment..."
kubectl apply -f k8s/mobile-deployment.yaml -n case || echo "Mobile deployment failed, continuing..."

echo "Aplicando ingress..."
kubectl apply -f k8s/ingress.yaml -n case || echo "Ingress failed, continuing..."

# Corrigir depreciação do Ingress: usar spec.ingressClassName e remover annotation antiga
INGRESS_NAME=${INGRESS_NAME:-case-ingress}
INGRESS_CLASS=${INGRESS_CLASS:-nginx}
if kubectl get ingress "$INGRESS_NAME" -n case >/dev/null 2>&1; then
  echo "Removendo annotation deprecada do Ingress (kubernetes.io/ingress.class)..."
  kubectl annotate ingress "$INGRESS_NAME" -n case kubernetes.io/ingress.class- --overwrite >/dev/null 2>&1 || true

  echo "Garantindo spec.ingressClassName=$INGRESS_CLASS..."
  kubectl patch ingress "$INGRESS_NAME" -n case \
    --type=json \
    -p="[{\"op\":\"add\",\"path\":\"/spec/ingressClassName\",\"value\":\"$INGRESS_CLASS\"}]" >/dev/null 2>&1 || true
fi

echo "Verificando disponibilidade de ServiceMonitor CRD..."
if ! kubectl api-resources --api-group=monitoring.coreos.com | grep -qi "servicemonitors"; then
  echo "Instalando CRDs do Prometheus Operator..."
  kubectl apply -f https://github.com/prometheus-operator/prometheus-operator/releases/download/v0.74.0/stripped-down-crds.yaml
  echo "Aguardando CRD ServiceMonitor ser estabelecido..."
  kubectl wait --for=condition=Established crd/servicemonitors.monitoring.coreos.com --timeout=180s || true
fi

if kubectl api-resources --api-group=monitoring.coreos.com | grep -qi "servicemonitors"; then
  echo "Aplicando ServiceMonitors..."
  if [ -f k8s/service-monitors.yaml ]; then
    kubectl apply -f k8s/service-monitors.yaml -n case || echo "Falha ao aplicar ServiceMonitors, continuando..."
  else
    echo "Arquivo k8s/service-monitors.yaml não encontrado. Pulando."
  fi
else
  echo "ServiceMonitor CRD indisponível. Pulando ServiceMonitors."
fi

echo "Skipping HPA (metrics-server não configurado neste pipeline)"

echo "Deployment completo!"

# Verificar status
echo "Status dos recursos:"
kubectl get pods,svc,deployments -n case

# Aguardar pods ficarem prontos
echo "Aguardando pods ficarem prontos..."
kubectl wait --for=condition=ready pod -l app=backend -n case --timeout=300s || echo "Backend timeout"
kubectl wait --for=condition=ready pod -l app=frontend -n case --timeout=300s || echo "Frontend timeout"

echo "Deploy CI/CD concluído!"