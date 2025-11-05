#!/bin/bash
# Script para validar se o ambiente de demo está funcionando
# Uso: ./validate-demo-environment.sh

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

check() { echo -e "${BLUE}🔍 $1${NC}"; }
success() { echo -e "${GREEN} $1${NC}"; }
fail() { echo -e "${RED} $1${NC}"; }
warn() { echo -e "${YELLOW}  $1${NC}"; }

echo ""
echo "=========================================="
echo "  VALIDAÇÃO AMBIENTE DEMO"
echo "=========================================="
echo ""

# 1. Verificar cluster Kind
check "Verificando cluster Kind..."
if kind get clusters 2>/dev/null | grep -q "case-local"; then
    success "Cluster Kind ativo"
else
    fail "Cluster Kind não encontrado"
    exit 1
fi

# 2. Verificar namespace
check "Verificando namespace 'case'..."
if kubectl get namespace case >/dev/null 2>&1; then
    success "Namespace 'case' existe"
else
    fail "Namespace 'case' não encontrado"
    exit 1
fi

# 3. Verificar pods
check "Verificando status dos pods..."
kubectl get pods -n case
echo ""

ready_pods=$(kubectl get pods -n case --no-headers 2>/dev/null | grep "1/1.*Running" | wc -l)
total_pods=$(kubectl get pods -n case --no-headers 2>/dev/null | wc -l)

if [ "$ready_pods" -eq 3 ]; then
    success "Todos os 3 pods estão rodando"
elif [ "$ready_pods" -gt 0 ]; then
    warn "$ready_pods de $total_pods pods funcionando"
else
    fail "Nenhum pod está funcionando"
fi

# 4. Verificar serviços Docker
check "Verificando stack de observabilidade..."
running_services=$(docker ps --filter "name=observabilidade" --format "table {{.Names}}" | grep -c "observabilidade" || echo "0")

if [ "$running_services" -ge 4 ]; then
    success "Stack de observabilidade rodando ($running_services serviços)"
else
    warn "Stack de observabilidade parcial ($running_services serviços)"
fi

# 5. Testar conectividade
check "Testando conectividade dos serviços..."

# Backend
if curl -s -f http://localhost:3002/healthz >/dev/null 2>&1; then
    success "Backend acessível (http://localhost:3002)"
else
    warn "Backend não acessível"
fi

# Frontend  
if curl -s -I http://localhost:3003/ 2>/dev/null | head -1 | grep -q "200\|301\|302"; then
    success "Frontend acessível (http://localhost:3003)"
else
    warn "Frontend não acessível"
fi

# Mobile
if curl -s -I http://localhost:3004/ 2>/dev/null | head -1 | grep -q "200\|301\|302"; then
    success "Mobile acessível (http://localhost:3004)"
else
    warn "Mobile não acessível"
fi

# Grafana
if curl -s -I http://localhost:3100/ 2>/dev/null | head -1 | grep -q "200\|301\|302"; then
    success "Grafana acessível (http://localhost:3100)"
else
    warn "Grafana não acessível"
fi

# Prometheus
if curl -s -I http://localhost:9090/ 2>/dev/null | head -1 | grep -q "200\|301\|302"; then
    success "Prometheus acessível (http://localhost:9090)"
else
    warn "Prometheus não acessível"
fi

# 6. Testar endpoints de métricas
check "Testando endpoints de métricas..."

if curl -s http://localhost:3002/metrics 2>/dev/null | head -1 | grep -q "#"; then
    success "Backend metrics OK"
else
    warn "Backend metrics com problema"
fi

if curl -s http://localhost:3003/metrics 2>/dev/null | head -1 | grep -q "#"; then
    success "Frontend metrics OK"
else
    warn "Frontend metrics com problema"
fi

if curl -s http://localhost:3004/metrics 2>/dev/null | head -1 | grep -q "#"; then
    success "Mobile metrics OK"
else
    warn "Mobile metrics com problema"
fi

echo ""
echo "=========================================="
echo "  RESUMO PARA GRAVAÇÃO"
echo "=========================================="
echo ""
echo "📊 URLs principais:"
echo "   • Grafana: http://localhost:3100 (admin/admin)"
echo "   • Prometheus: http://localhost:9090"
echo "   • Backend: http://localhost:3002"
echo "   • Frontend: http://localhost:3003"
echo "   • Mobile: http://localhost:3004"
echo ""
echo "🎬 Dashboards para demo:"
echo "   • Golden Signals: http://localhost:3100/d/golden-signals"
echo "   • Business Metrics: http://localhost:3100/d/business-metrics"
echo "   • Frontend: http://localhost:3100/d/frontend-golden-signals"
echo "   • Mobile: http://localhost:3100/d/mobile-golden-signals"
echo ""
echo "🚦 Para gerar tráfego durante gravação:"
echo "   ./generate-demo-traffic.sh 20"
echo ""

# Verificação final
if [ "$ready_pods" -eq 3 ] && curl -s http://localhost:3100/ >/dev/null 2>&1; then
    echo -e "${GREEN}🎉 AMBIENTE PRONTO PARA GRAVAÇÃO! 🎉${NC}"
else
    echo -e "${YELLOW}  Ambiente parcialmente funcional - verifique os avisos acima${NC}"
fi
echo ""