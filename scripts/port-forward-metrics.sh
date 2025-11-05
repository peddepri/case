#!/bin/bash
# Script para configurar port-forwards necessários para coleta de métricas

set -e

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; }

echo ""
info "Configurando port-forwards para coleta de métricas..."
echo ""

# Função para matar port-forwards anteriores de métricas
cleanup() {
    info "Parando port-forwards de métricas anteriores..."
    pkill -f "kubectl.*port-forward.*300[1-2]" 2>/dev/null || true
    sleep 2
}

# Cleanup inicial
cleanup

# Trap para cleanup no exit
trap cleanup EXIT

info "Configurando port-forwards para observabilidade:"
echo "   • Backend Kubernetes: localhost:3002 -> backend:3000/metrics"
echo "   • Frontend Kubernetes: localhost:3003 -> frontend:80/metrics"  
echo "   • Mobile Kubernetes: localhost:3004 -> mobile:19006/metrics"
echo ""

# Verificar se pods estão rodando
if ! kubectl get pods -n case -l app=backend --no-headers | grep -q Running; then
    fail "Nenhum pod backend encontrado rodando no namespace 'case'"
    exit 1
fi

# Port-forward para backend (métricas Prometheus)
info "Configurando port-forward para backend (métricas)..."
kubectl port-forward -n case svc/backend 3002:3000 > /dev/null 2>&1 &
BACKEND_PF_PID=$!

# Port-forward para frontend (métricas via Vite)
info "Configurando port-forward para frontend (métricas)..."
kubectl port-forward -n case svc/frontend 3003:80 > /dev/null 2>&1 &
FRONTEND_PF_PID=$!

# Port-forward para mobile (métricas via Expo)
info "Configurando port-forward para mobile (métricas)..."
kubectl port-forward -n case svc/mobile 3004:19006 > /dev/null 2>&1 &
MOBILE_PF_PID=$!

# Aguardar port-forward estar ativo
sleep 3

# Testar conectividade
info "Testando conectividade com métricas..."
if curl -s http://localhost:3002/metrics | head -1 | grep -q "#"; then
    success "Backend métricas acessíveis em http://localhost:3002/metrics"
else
    fail "Não foi possível acessar métricas do backend"
fi

# Testar frontend (pode não ter /metrics endpoint, então testamos se responde)
if curl -s http://localhost:3003/ | head -1 | grep -q -E "(html|<!doctype|react)"; then
    success "Frontend acessível em http://localhost:3003/ (métricas em desenvolvimento)"
else
    warn "Frontend não acessível em http://localhost:3003/"
fi

# Testar mobile (similar ao frontend)
if curl -s http://localhost:3004/ > /dev/null 2>&1; then
    success "Mobile acessível em http://localhost:3004/ (métricas em desenvolvimento)"  
else
    warn "Mobile não acessível em http://localhost:3004/"
fi

# Verificar se Prometheus está coletando
info "Verificando coleta no Prometheus..."
sleep 5
TARGET_STATUS=$(curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.scrapePool == "backend-kubernetes") | .health' 2>/dev/null || echo "unknown")
if [ "$TARGET_STATUS" = "up" ]; then
    success "Prometheus coletando métricas do backend-kubernetes"
else
    warn "Prometheus ainda não detectou target como 'up' (status: $TARGET_STATUS)"
    warn "Aguarde alguns segundos e verifique em http://localhost:9090/targets"
fi

echo ""
success "Port-forwards configurados para observabilidade!"
echo ""
info "URLs para verificação:"
echo "   • Métricas Backend: http://localhost:3002/metrics"
echo "   • Frontend App: http://localhost:3003/"
echo "   • Mobile App: http://localhost:3004/"
echo "   • Prometheus Targets: http://localhost:9090/targets" 
echo "   • Grafana Dashboards: http://localhost:3100 (admin/admin)"
echo ""
info "Pressione Ctrl+C para parar todos os port-forwards de métricas"

# Aguardar sinal para parar
wait