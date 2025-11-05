#!/bin/bash
# Script de verificação rápida do ambiente demo
# Uso: ./check-demo-status.sh

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

check() {
    if $1 > /dev/null 2>&1; then
        echo -e "  ✅ $2"
        return 0
    else
        echo -e "  ❌ $2"
        return 1
    fi
}

info() { echo -e "${BLUE}$1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }

echo "🔍 =========================================="  
echo "🔍  VERIFICAÇÃO DO AMBIENTE DEMO"
echo "🔍 =========================================="
echo ""

# 1. Infraestrutura Kubernetes
info "📋 1. Kubernetes Cluster"
check "kind get clusters | grep -q case-local" "Kind cluster 'case-local' existe"
check "kubectl get nodes --no-headers | grep -q Ready" "Nodes do cluster prontos"
check "kubectl get namespace case" "Namespace 'case' existe"

echo ""

# 2. Pods das Aplicações  
info "📋 2. Aplicações (Pods)"
PODS_READY=$(kubectl get pods -n case --no-headers 2>/dev/null | grep -c Running || echo "0")
PODS_TOTAL=$(kubectl get pods -n case --no-headers 2>/dev/null | wc -l || echo "0")
echo "  📊 Pods Running: $PODS_READY/$PODS_TOTAL"

check "kubectl get pods -n case | grep -q 'backend.*Running'" "Backend pods rodando"
check "kubectl get pods -n case | grep -q 'frontend.*Running'" "Frontend pods rodando"  
check "kubectl get pods -n case | grep -q 'mobile.*Running'" "Mobile pods rodando"

echo ""

# 3. Observabilidade (Docker)
info "📋 3. Stack de Observabilidade"
check "docker ps | grep -q case-prometheus" "Prometheus container ativo"
check "docker ps | grep -q case-grafana" "Grafana container ativo"
check "docker ps | grep -q case-loki" "Loki container ativo"
check "docker ps | grep -q case-tempo" "Tempo container ativo"

echo ""

# 4. Conectividade
info "📋 4. Conectividade via Port-Forward"
check "curl -s http://localhost:3002/healthz" "Backend acessível (3002)"
check "curl -s -I http://localhost:3003/" "Frontend acessível (3003)"
check "curl -s -I http://localhost:3004/" "Mobile acessível (3004)"

echo ""

# 5. Observabilidade Web UI
info "📋 5. Interfaces Web"
check "curl -s http://localhost:9090/-/healthy" "Prometheus UI (9090)"
check "curl -s http://localhost:3100/api/health" "Grafana UI (3100)"
check "curl -s http://localhost:3101/ready" "Loki API (3101)"
check "curl -s http://localhost:3102/ready" "Tempo API (3102)"

echo ""

# 6. Métricas e Dados
info "📋 6. Coleta de Métricas"
if command -v jq >/dev/null 2>&1; then
    TARGETS_UP=$(curl -s http://localhost:9090/api/v1/targets 2>/dev/null | jq -r '.data.activeTargets[] | select(.health=="up") | .scrapePool' 2>/dev/null | wc -l)
    TARGETS_TOTAL=$(curl -s http://localhost:9090/api/v1/targets 2>/dev/null | jq -r '.data.activeTargets[] | .scrapePool' 2>/dev/null | wc -l)
    echo "  🎯 Targets Prometheus: $TARGETS_UP/$TARGETS_TOTAL UP"
    
    HTTP_METRICS=$(curl -s 'http://localhost:9090/api/v1/query?query=http_requests_total' 2>/dev/null | jq '.data.result | length' 2>/dev/null)
    echo "  📈 Métricas HTTP coletadas: ${HTTP_METRICS:-0}"
    
    UP_METRICS=$(curl -s 'http://localhost:9090/api/v1/query?query=up' 2>/dev/null | jq '.data.result | length' 2>/dev/null)  
    echo "  📊 Métricas 'up' ativas: ${UP_METRICS:-0}"
else
    warn "jq não encontrado - não foi possível verificar métricas detalhadas"
fi

echo ""

# 7. Port-forwards ativos
info "📋 7. Port-Forwards Ativos"
PORT_FORWARDS=$(ps aux 2>/dev/null | grep -c "port-forward" | grep -v grep || echo "0")
echo "  🔗 Processos port-forward ativos: $PORT_FORWARDS"

echo ""

# 8. URLs para Demo
info "🎬 URLs PRINCIPAIS PARA DEMO:"
echo ""
echo "   📊 DASHBOARDS:"
echo "      • Grafana: http://localhost:3100 (admin/admin)"
echo "      • Golden Signals: http://localhost:3100/d/golden-signals"
echo "      • Business Metrics: http://localhost:3100/d/business-metrics"
echo ""
echo "   🔍 MONITORAMENTO:"  
echo "      • Prometheus: http://localhost:9090"
echo "      • Targets: http://localhost:9090/targets"
echo "      • Métricas: http://localhost:9090/graph"
echo ""
echo "   🚀 APLICAÇÕES:"
echo "      • Backend API: http://localhost:3002"
echo "      • Frontend: http://localhost:3003"  
echo "      • Mobile: http://localhost:3004"
echo ""

# Status geral
ISSUES=0
echo "🏁 =========================================="

# Contabilizar problemas
kubectl get nodes --no-headers 2>/dev/null | grep -q Ready || ((ISSUES++))
docker ps | grep -q case-prometheus || ((ISSUES++))
curl -s http://localhost:3002/healthz > /dev/null || ((ISSUES++))
curl -s http://localhost:3100/api/health > /dev/null || ((ISSUES++))

if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}🎉 AMBIENTE DEMO PRONTO! Todos os sistemas funcionando.${NC}"
    echo ""
    echo "🎬 Para iniciar gravação:"
    echo "   1. Abrir Grafana: http://localhost:3100"  
    echo "   2. Gerar tráfego: ./generate-demo-traffic.sh"
    echo "   3. Iniciar gravação!"
else
    echo -e "${RED}⚠️  AMBIENTE COM $ISSUES PROBLEMA(S). Verifique os itens marcados com ❌${NC}"
    echo ""
    echo "🔧 Para corrigir, execute: ./setup-demo-environment.sh"
fi

echo "🏁 =========================================="