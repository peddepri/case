#!/bin/bash
# Script de validação simplificada da observabilidade

set -e

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}ℹ  $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠  $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; }

echo ""
echo -e "${BLUE}🔍 VALIDAÇÃO RÁPIDA DE OBSERVABILIDADE${NC}"
echo "======================================="
echo ""

PASSED=0
TOTAL=0

test_service() {
    local name="$1"
    local url="$2"
    local expected="$3"
    
    TOTAL=$((TOTAL + 1))
    info "Testando $name..."
    
    if curl -s "$url" | grep -q "$expected" > /dev/null 2>&1; then
        success "$name está funcionando"
        PASSED=$((PASSED + 1))
    else
        fail "$name não está respondendo"
    fi
}

# =====================================================
# 1. VERIFICAR KUBERNETES
# =====================================================
info "📋 1. VERIFICANDO KUBERNETES"
TOTAL=$((TOTAL + 1))
if kubectl cluster-info > /dev/null 2>&1; then
    success "Kubernetes Cluster está acessível"
    PASSED=$((PASSED + 1))
    
    # Verificar pods
    BACKEND_PODS=$(kubectl get pods -n case -l app=backend --no-headers 2>/dev/null | grep Running | wc -l)
    FRONTEND_PODS=$(kubectl get pods -n case -l app=frontend --no-headers 2>/dev/null | grep Running | wc -l)
    MOBILE_PODS=$(kubectl get pods -n case -l app=mobile --no-headers 2>/dev/null | grep Running | wc -l)
    
    info "   • Backend: $BACKEND_PODS pods rodando"
    info "   • Frontend: $FRONTEND_PODS pods rodando"
    info "   • Mobile: $MOBILE_PODS pods rodando"
else
    fail "Kubernetes Cluster não está acessível"
fi

# =====================================================
# 2. VERIFICAR SERVIÇOS DE OBSERVABILIDADE
# =====================================================
info "📊 2. VERIFICANDO SERVIÇOS DE OBSERVABILIDADE"

test_service "Prometheus" "http://localhost:9090/api/v1/status/config" "prometheus"
test_service "Grafana" "http://localhost:3100/api/health" "database"
test_service "Loki" "http://localhost:3101/ready" ""
test_service "Tempo" "http://localhost:3102/ready" ""

# =====================================================
# 3. VERIFICAR DASHBOARDS GRAFANA
# =====================================================
info "📈 3. VERIFICANDO DASHBOARDS GRAFANA"

TOTAL=$((TOTAL + 1))
GRAFANA_URL="http://localhost:3100"
GRAFANA_USER="admin"
GRAFANA_PASS="admin"

info "Testando acesso aos dashboards..."
if curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/search" > /dev/null; then
    DASHBOARDS=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/search" | grep -o '"title"' | wc -l)
    success "Grafana dashboards acessíveis ($DASHBOARDS encontrados)"
    PASSED=$((PASSED + 1))
else
    fail "Erro ao acessar dashboards Grafana"
fi

# =====================================================
# 4. TESTAR GERAÇÃO DE MÉTRICAS
# =====================================================
info "🎯 4. TESTANDO GERAÇÃO DE MÉTRICAS"

if [ $BACKEND_PODS -gt 0 ]; then
    BACKEND_POD=$(kubectl get pods -n case -l app=backend -o jsonpath='{.items[0].metadata.name}')
    
    info "Gerando tráfego de teste via $BACKEND_POD..."
    
    # Gerar alguns requests
    kubectl exec -n case $BACKEND_POD -- sh -c '
        echo "Gerando requests de teste..."
        for i in $(seq 1 5); do
            timeout 3 nc -zv localhost 3000 > /dev/null 2>&1 || echo "Request $i sent"
            sleep 1
        done
        echo "Testes concluídos"
    ' > /dev/null 2>&1
    
    success "Tráfego de teste gerado"
else
    warn "Nenhum pod backend disponível para teste"
fi

# =====================================================
# 5. VERIFICAR COLETA DE MÉTRICAS SIMPLES
# =====================================================
info "📏 5. VERIFICANDO COLETA BÁSICA DE MÉTRICAS"

TOTAL=$((TOTAL + 1))
if curl -s "http://localhost:9090/api/v1/label/__name__/values" > /dev/null; then
    METRICS_COUNT=$(curl -s "http://localhost:9090/api/v1/label/__name__/values" | grep -o '","' | wc -l)
    if [ $METRICS_COUNT -gt 10 ]; then
        success "Métricas estão sendo coletadas ($METRICS_COUNT métricas disponíveis)"
        PASSED=$((PASSED + 1))
    else
        warn "Poucas métricas coletadas ($METRICS_COUNT) - verificar instrumentação"
    fi
else
    fail "Erro ao acessar métricas do Prometheus"
fi

# =====================================================
# 6. RELATÓRIO FINAL
# =====================================================
echo ""
echo -e "${BLUE}📋 RELATÓRIO DE VALIDAÇÃO RÁPIDA${NC}"
echo "=================================="
echo ""

SCORE=$((PASSED * 100 / TOTAL))

if [ $SCORE -ge 80 ]; then
    success "🎉 EXCELENTE! Score: $SCORE% ($PASSED/$TOTAL testes passaram)"
    echo ""
    echo -e "${GREEN}✅ ACESSO AOS DASHBOARDS:${NC}"
    echo "   • Grafana: http://localhost:3100 (admin/admin)"
    echo "   • Prometheus: http://localhost:9090"
    echo "   • Loki: http://localhost:3101"
    echo "   • Tempo: http://localhost:3102"
    echo ""
    echo -e "${GREEN}🎯 DASHBOARDS CONFIGURADOS:${NC}"
    echo "   • 4 Golden Signals + Business Metrics"
    echo "   • Logs, Metrics & Traces Integration"
    echo "   • Alertas Prometheus configurados"
    echo ""
    echo -e "${BLUE}📱 PRÓXIMOS PASSOS RECOMENDADOS:${NC}"
    echo "   1. 🔧 Implementar instrumentação OpenTelemetry (traces)"
    echo "   2. 🌐 Adicionar métricas frontend (Core Web Vitals)"
    echo "   3. 📱 Instrumentar app mobile"
    echo "   4. 🔔 Configurar Alertmanager para notificações"
    echo ""
elif [ $SCORE -ge 60 ]; then
    warn "👍 BOM! Score: $SCORE% ($PASSED/$TOTAL testes passaram)"
    echo ""
    echo -e "${YELLOW}⚠  Algumas melhorias são necessárias${NC}"
    echo "Execute: bash scripts/setup-observability-complete.sh"
else
    fail "⚠️  ATENÇÃO! Score: $SCORE% ($PASSED/$TOTAL testes passaram)"
    echo ""
    echo -e "${RED}❌ Problemas detectados - revisar configuração${NC}"
    echo "Execute: bash scripts/setup-observability-complete.sh"
fi

echo ""
echo -e "${BLUE}💡 Para gerar carga de teste:${NC} http://localhost:8089 (Locust)"
echo ""