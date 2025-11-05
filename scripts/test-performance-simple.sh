#!/bin/bash
# Teste de Performance Simples - Docker/K8S

set -e

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}ℹ  $1${NC}"; }
success() { echo -e "${GREEN} $1${NC}"; }
fail() { echo -e "${RED} $1${NC}"; }

echo "🚀 TESTE DE PERFORMANCE RÁPIDO"
echo "==============================="
echo ""

# Obter pod backend
BACKEND_POD=$(kubectl get pods -n case -l app=backend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$BACKEND_POD" ]; then
    fail "Nenhum pod backend encontrado"
    exit 1
fi

info "Usando pod: $BACKEND_POD"
echo ""

# FASE 1: Teste básico de conectividade
echo "🔍 TESTE DE CONECTIVIDADE"
echo "========================="

info "Testando health check interno..."
kubectl exec -n case $BACKEND_POD -- wget -q -O - http://localhost:3000/healthz 2>/dev/null | head -1 && success "Health check: OK" || fail "Health check: FAIL"

info "Testando API orders..."
kubectl exec -n case $BACKEND_POD -- wget -q -O - http://localhost:3000/api/orders 2>/dev/null | head -1 && success "API orders: OK" || fail "API orders: FAIL"

echo ""

# FASE 2: Teste de carga simples
echo "📊 TESTE DE CARGA SIMPLES"
echo "=========================="

info "Executando 20 requests para /healthz..."

kubectl exec -n case $BACKEND_POD -c backend -- sh -c '
success=0
total=20
echo "Iniciando $total requests..."

for i in $(seq 1 $total); do
    if wget -q -T 2 -O /dev/null http://localhost:3000/healthz 2>/dev/null; then
        success=$((success + 1))
    fi
    if [ $((i % 5)) -eq 0 ]; then
        echo "  Progresso: $i/$total"
    fi
done

success_rate=$((success * 100 / total))
echo " Resultado: $success/$total requests bem-sucedidos ($success_rate%)"
'

echo ""

# FASE 3: Teste de conectividade entre serviços
echo "🌐 CONECTIVIDADE ENTRE SERVIÇOS"
echo "==============================="

info "Testando comunicação backend -> frontend..."
kubectl exec -n case $BACKEND_POD -c backend -- nc -z frontend 80 2>/dev/null && success "Frontend acessível" || fail "Frontend inacessível"

info "Testando comunicação backend -> mobile..."
kubectl exec -n case $BACKEND_POD -c backend -- nc -z mobile 19006 2>/dev/null && success "Mobile acessível" || fail "Mobile inacessível"

echo ""

# FASE 4: Informações do sistema
echo "💻 INFORMAÇÕES DO SISTEMA"
echo "========================="

kubectl exec -n case $BACKEND_POD -c backend -- sh -c '
echo "🔧 Informações do container:"
echo "  • Hostname: $(hostname)"
echo "  • Uptime: $(uptime | cut -d, -f1)"

if [ -f /proc/meminfo ]; then
    mem_total=$(grep "^MemTotal:" /proc/meminfo | awk "{print \$2}")
    mem_available=$(grep "^MemAvailable:" /proc/meminfo | awk "{print \$2}")
    mem_used=$((mem_total - mem_available))
    mem_percent=$((mem_used * 100 / mem_total))
    echo "  • Memória: ${mem_used}KB / ${mem_total}KB (${mem_percent}%)"
fi

echo "  • Processos ativos:"
ps aux | head -3
'

echo ""
success "🎉 TESTES CONCLUÍDOS!"
echo ""
echo "📋 Próximos passos:"
echo "   • Para teste de chaos: bash scripts/test-chaos.sh"
echo "   • Para logs detalhados: kubectl logs -n case -l app=backend"
echo "   • Para métricas: kubectl top pods -n case"