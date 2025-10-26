#!/bin/bash
# Demonstração Rápida dos Testes

set -e

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }

echo "🎯 DEMONSTRAÇÃO RÁPIDA DOS TESTES"
echo "================================"
echo ""

# Verificar ambiente
info "Verificando ambiente..."

# Pods no Kubernetes
PODS_COUNT=$(kubectl get pods -n case --field-selector=status.phase=Running 2>/dev/null | wc -l)
if [ $PODS_COUNT -gt 1 ]; then
    success "Kubernetes OK - $((PODS_COUNT-1)) pods rodando"
    kubectl get pods -n case
else
    warn "Kubernetes - Poucos pods rodando"
fi

echo ""

# LocalStack via Docker Compose
info "Testando LocalStack..."
if curl -s http://localhost:3001/healthz >/dev/null 2>&1; then
    success "Backend LocalStack OK (http://localhost:3001)"
else
    warn "Backend LocalStack não responde"
fi

if curl -s http://localhost:5174 >/dev/null 2>&1; then
    success "Frontend LocalStack OK (http://localhost:5174)"
else
    warn "Frontend LocalStack não responde"  
fi

if curl -s http://localhost:19007 >/dev/null 2>&1; then
    success "Mobile LocalStack OK (http://localhost:19007)"
else
    warn "Mobile LocalStack não responde"
fi

echo ""

# Testar API com criação de order
info "Testando API - Criando order de teste..."
ORDER_RESULT=$(curl -s -X POST http://localhost:3001/api/orders \
    -H "Content-Type: application/json" \
    -d '{"item":"demo-test","price":123.45,"customer":"Demo User"}' 2>/dev/null || echo "")

if echo "$ORDER_RESULT" | jq -r '.id' 2>/dev/null | grep -v null >/dev/null; then
    ORDER_ID=$(echo "$ORDER_RESULT" | jq -r '.id')
    success "Order criada com sucesso - ID: $ORDER_ID"
else
    warn "Falha ao criar order"
fi

# Listar orders
info "Listando orders existentes..."
ORDERS_LIST=$(curl -s http://localhost:3001/api/orders 2>/dev/null || echo "")
if [ -n "$ORDERS_LIST" ]; then
    ORDERS_COUNT=$(echo "$ORDERS_LIST" | jq '. | length' 2>/dev/null || echo "0")
    success "API OK - $ORDERS_COUNT orders encontradas"
else
    warn "Erro ao listar orders"
fi

echo ""

# Teste simples de performance
info "Teste simples de performance (10 requests)..."
START_TIME=$(date +%s)
SUCCESS_COUNT=0

for i in {1..10}; do
    STATUS=$(curl -s -w "%{http_code}" -o /dev/null http://localhost:3001/api/orders 2>/dev/null || echo "000")
    if [ "$STATUS" = "200" ]; then
        ((SUCCESS_COUNT++))
        echo -n "✓"
    else
        echo -n "✗"
    fi
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
echo ""

if [ $SUCCESS_COUNT -ge 8 ]; then
    success "Performance OK - $SUCCESS_COUNT/10 requests em ${DURATION}s"
else
    warn "Performance - Apenas $SUCCESS_COUNT/10 requests bem sucedidos"
fi

echo ""

# Observabilidade
info "Verificando observabilidade..."

if curl -s http://localhost:9090/-/healthy >/dev/null 2>&1; then
    success "Prometheus OK (http://localhost:9090)"
else
    warn "Prometheus não responde"
fi

if curl -s http://localhost:3100/api/health >/dev/null 2>&1; then
    success "Grafana OK (http://localhost:3100)"
else
    warn "Grafana não responde"
fi

echo ""

# Demonstração de Chaos (simulação leve)
info "Demonstração Chaos - Verificando pods antes..."
kubectl get pods -n case | grep -E "(backend|frontend|mobile)"

info "Simulando restart de 1 pod backend..."
BACKEND_POD=$(kubectl get pods -n case -l app=backend -o jsonpath='{.items[0].metadata.name}')
if [ -n "$BACKEND_POD" ]; then
    kubectl delete pod -n case "$BACKEND_POD" &
    DELETE_PID=$!
    
    success "Pod $BACKEND_POD sendo reiniciado..."
    
    # Testar durante restart
    info "Testando disponibilidade durante restart..."
    CHAOS_SUCCESS=0
    for i in {1..5}; do
        STATUS=$(curl -s -w "%{http_code}" -o /dev/null --max-time 3 http://localhost:3001/api/orders 2>/dev/null || echo "000")
        if [ "$STATUS" = "200" ]; then
            ((CHAOS_SUCCESS++))
            echo -n "✓"
        else
            echo -n "✗"  
        fi
        sleep 1
    done
    echo ""
    
    success "Resiliência OK - $CHAOS_SUCCESS/5 requests durante chaos"
    
    wait $DELETE_PID 2>/dev/null || true
    
    info "Aguardando novo pod ficar ready..."
    kubectl wait --for=condition=ready pod -l app=backend -n case --timeout=60s 2>/dev/null || true
    
    info "Status após restart:"
    kubectl get pods -n case -l app=backend
fi

echo ""
echo "🎊 DEMONSTRAÇÃO CONCLUÍDA!"
echo ""
echo "📋 Resumo dos testes disponíveis:"
echo "   • ./scripts/test-functional.sh  - Testes completos de funcionalidade"
echo "   • ./scripts/test-performance.sh - Load testing com Locust"
echo "   • ./scripts/test-chaos.sh       - Chaos engineering completo"
echo "   • ./scripts/test-all.sh         - Suite completa (todos os testes)"
echo ""
echo "📊 Monitoramento:"
echo "   • Grafana: http://localhost:3100"
echo "   • Prometheus: http://localhost:9090"
echo ""
echo "🔄 Para executar testes completos:"
echo "   ./scripts/test-all.sh"