#!/bin/bash
# Script para testar se as métricas estão sendo coletadas corretamente
# Uso: ./test-metrics-collection.sh

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}  $1${NC}"; }
success() { echo -e "${GREEN} $1${NC}"; }
warn() { echo -e "${YELLOW}  $1${NC}"; }
fail() { echo -e "${RED} $1${NC}"; }

echo " =========================================="
echo "  TESTE DE COLETA DE MÉTRICAS"  
echo " =========================================="
echo ""

# 1. Testar endpoints de métricas
info "1. Testando endpoints de métricas..."

# Backend
if curl -s http://localhost:3002/metrics | head -3 | grep -q "# HELP"; then
    success "Backend metrics (/metrics) - OK"
    BACKEND_METRICS=$(curl -s http://localhost:3002/metrics | grep -c "^[a-z]")
    echo "   📊 Métricas encontradas: $BACKEND_METRICS"
else
    fail "Backend metrics não acessível"
fi

# Frontend  
if curl -s http://localhost:3003/metrics | head -3 | grep -q "# HELP"; then
    success "Frontend metrics (/metrics) - OK"
    FRONTEND_METRICS=$(curl -s http://localhost:3003/metrics | grep -c "^frontend_")
    echo "    Métricas encontradas: $FRONTEND_METRICS"
else
    fail "Frontend metrics não acessível"
fi

# Mobile
if curl -s http://localhost:3004/metrics | head -3 | grep -q "# HELP"; then
    success "Mobile metrics (/metrics) - OK"  
    MOBILE_METRICS=$(curl -s http://localhost:3004/metrics | grep -c "^mobile_")
    echo "    Métricas encontradas: $MOBILE_METRICS"
else
    fail "Mobile metrics não acessível"
fi

echo ""

# 2. Testar coleta no Prometheus
info "2. Verificando coleta no Prometheus..."

if command -v jq >/dev/null 2>&1; then
    # Verificar targets
    TARGETS_UP=$(curl -s http://localhost:9090/api/v1/targets 2>/dev/null | jq -r '.data.activeTargets[] | select(.health=="up") | .scrapePool' | wc -l)
    TARGETS_TOTAL=$(curl -s http://localhost:9090/api/v1/targets 2>/dev/null | jq -r '.data.activeTargets[] | .scrapePool' | wc -l)
    echo "    Targets UP: $TARGETS_UP/$TARGETS_TOTAL"
    
    # Verificar métricas específicas
    HTTP_METRICS=$(curl -s 'http://localhost:9090/api/v1/query?query=http_requests_total' 2>/dev/null | jq '.data.result | length')
    FRONTEND_COLLECTED=$(curl -s 'http://localhost:9090/api/v1/query?query=frontend_requests_total' 2>/dev/null | jq '.data.result | length')  
    MOBILE_COLLECTED=$(curl -s 'http://localhost:9090/api/v1/query?query=mobile_requests_total' 2>/dev/null | jq '.data.result | length')
    
    echo "    HTTP requests (backend): $HTTP_METRICS"
    echo "    Frontend requests: $FRONTEND_COLLECTED"
    echo "    Mobile requests: $MOBILE_COLLECTED"
    
    if [[ "$TARGETS_UP" -ge 3 ]]; then
        success "Prometheus coletando de múltiplos targets"
    else
        warn "Prometheus coletando de poucos targets ($TARGETS_UP)"
    fi
else
    warn "jq não encontrado - verificação limitada"
fi

echo ""

# 3. Gerar tráfego e verificar incremento
info "3. Gerando tráfego de teste..."

# Capturar métricas iniciais
if command -v jq >/dev/null 2>&1; then
    INITIAL_BACKEND=$(curl -s 'http://localhost:9090/api/v1/query?query=http_requests_total' 2>/dev/null | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "0")
    INITIAL_FRONTEND=$(curl -s 'http://localhost:9090/api/v1/query?query=frontend_requests_total' 2>/dev/null | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "0")
fi

# Gerar requests
for i in {1..10}; do
    curl -s http://localhost:3002/healthz > /dev/null 2>&1 || true
    curl -s http://localhost:3003/ > /dev/null 2>&1 || true  
    curl -s http://localhost:3004/ > /dev/null 2>&1 || true
    echo -n "."
    sleep 0.5
done

echo ""
info "Aguardando próxima coleta do Prometheus (15s)..."
sleep 15

# Verificar incremento
if command -v jq >/dev/null 2>&1; then
    FINAL_BACKEND=$(curl -s 'http://localhost:9090/api/v1/query?query=http_requests_total' 2>/dev/null | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "0")
    FINAL_FRONTEND=$(curl -s 'http://localhost:9090/api/v1/query?query=frontend_requests_total' 2>/dev/null | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "0")
    
    BACKEND_DIFF=$(echo "$FINAL_BACKEND - $INITIAL_BACKEND" | bc 2>/dev/null || echo "N/A")
    FRONTEND_DIFF=$(echo "$FINAL_FRONTEND - $INITIAL_FRONTEND" | bc 2>/dev/null || echo "N/A")
    
    echo "    Incremento Backend: +$BACKEND_DIFF"
    echo "    Incremento Frontend: +$FRONTEND_DIFF"
    
    if [[ "$BACKEND_DIFF" != "N/A" && "$BACKEND_DIFF" != "0" ]]; then
        success "Métricas do backend incrementando"
    else
        warn "Métricas do backend não incrementaram"
    fi
fi

echo ""

# 4. Verificar dashboards
info "4. URLs para verificar dashboards com dados..."
echo ""
echo "    DASHBOARDS PRINCIPAIS:"
echo "      • Golden Signals: http://localhost:3100/d/golden-signals"
echo "      • Frontend Signals: http://localhost:3100/d/frontend-golden-signals"
echo "      • Mobile Signals: http://localhost:3100/d/mobile-golden-signals"
echo "      • Business Metrics: http://localhost:3100/d/business-metrics"
echo ""
echo "    VERIFICAÇÃO DIRETA:"
echo "      • Prometheus Query: http://localhost:9090/graph"
echo "      • Targets Status: http://localhost:9090/targets"
echo ""

# Status final
echo " =========================================="

# Contabilizar sucessos
SERVICES_OK=0
curl -s http://localhost:3002/metrics | grep -q "# HELP" && ((SERVICES_OK++))
curl -s http://localhost:3003/metrics | grep -q "# HELP" && ((SERVICES_OK++))  
curl -s http://localhost:3004/metrics | grep -q "# HELP" && ((SERVICES_OK++))

if [[ "$SERVICES_OK" -eq 3 ]]; then
    success " TODOS OS SERVIÇOS EXPONDO MÉTRICAS ($SERVICES_OK/3)"
    echo ""
    echo "    Backend: Métricas Prometheus nativas"
    echo "    Frontend: Métricas simuladas via Nginx" 
    echo "    Mobile: Métricas simuladas via Express"
    echo ""
    echo " DASHBOARDS TERÃO DADOS! Pode iniciar gravação."
elif [[ "$SERVICES_OK" -ge 1 ]]; then
    warn "  ALGUNS SERVIÇOS EXPONDO MÉTRICAS ($SERVICES_OK/3)"
    echo "    Execute rebuild das imagens para corrigir"
else
    fail " NENHUM SERVIÇO EXPONDO MÉTRICAS"
    echo "    Verifique port-forwards e rebuilds"
fi

echo " =========================================="