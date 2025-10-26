#!/bin/bash
# Script de teste de carga para validar observabilidade
# Autor: Kiro AI Assistant
# Data: 2025-10-25

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

cd "$(dirname "$0")/.."

echo ""
echo "🚀 TESTE DE CARGA - OBSERVABILIDADE"
echo "==================================="
echo ""

# Verificar se backend está rodando
if ! curl -sf http://localhost:3001/healthz >/dev/null; then
    echo "❌ Backend não está rodando. Execute primeiro:"
    echo "   bash scripts/start-localstack-pro-simple.sh"
    exit 1
fi

# Configurações
BACKEND_URL="http://localhost:3001"
DURATION=${1:-60}  # Duração em segundos
CONCURRENT=${2:-5} # Requests concorrentes

log "Configuração do teste:"
echo "   • URL: $BACKEND_URL"
echo "   • Duração: ${DURATION}s"
echo "   • Concorrência: $CONCURRENT"
echo ""

info "Iniciando teste de carga..."
echo "   Abra Grafana para ver métricas em tempo real:"
echo "   http://localhost:3100/d/golden-signals-backend"
echo ""

# Função para fazer requests
make_requests() {
    local worker_id=$1
    local end_time=$(($(date +%s) + DURATION))
    local count=0
    
    while [ $(date +%s) -lt $end_time ]; do
        # Mix de requests
        case $((count % 4)) in
            0)
                # GET /api/orders
                curl -sf "$BACKEND_URL/api/orders" >/dev/null 2>&1 || true
                ;;
            1)
                # POST /api/orders (sucesso)
                curl -sf -X POST "$BACKEND_URL/api/orders" \
                    -H "Content-Type: application/json" \
                    -d "{\"item\":\"load-test-$worker_id-$count\",\"price\":$((10 + RANDOM % 100))}" \
                    >/dev/null 2>&1 || true
                ;;
            2)
                # GET /healthz
                curl -sf "$BACKEND_URL/healthz" >/dev/null 2>&1 || true
                ;;
            3)
                # POST /api/orders (erro simulado - preço inválido)
                curl -sf -X POST "$BACKEND_URL/api/orders" \
                    -H "Content-Type: application/json" \
                    -d "{\"item\":\"error-test\",\"price\":-1}" \
                    >/dev/null 2>&1 || true
                ;;
        esac
        
        count=$((count + 1))
        
        # Intervalo variável (50-200ms)
        sleep "0.$(printf "%02d" $((5 + RANDOM % 15)))"
    done
    
    echo "Worker $worker_id: $count requests"
}

# Iniciar workers em background
log "Iniciando $CONCURRENT workers..."
for i in $(seq 1 $CONCURRENT); do
    make_requests $i &
done

# Mostrar progresso
for i in $(seq 1 $DURATION); do
    echo -n "."
    sleep 1
    
    # A cada 10 segundos, mostrar estatísticas
    if [ $((i % 10)) -eq 0 ]; then
        echo ""
        info "Progresso: ${i}/${DURATION}s"
        
        # Métricas básicas
        ORDERS_CREATED=$(curl -sf "$BACKEND_URL/metrics" 2>/dev/null | grep "^orders_created_total" | awk '{print $2}' || echo "0")
        ORDERS_FAILED=$(curl -sf "$BACKEND_URL/metrics" 2>/dev/null | grep "^orders_failed_total" | awk '{print $2}' || echo "0")
        
        echo "   Orders criadas: $ORDERS_CREATED"
        echo "   Orders falharam: $ORDERS_FAILED"
        echo -n "   Continuando"
    fi
done

echo ""
log "Aguardando workers terminarem..."
wait

echo ""
log "Teste de carga concluído!"

# Estatísticas finais
echo ""
echo "📊 ESTATÍSTICAS FINAIS"
echo "====================="

# Métricas do Prometheus
METRICS=$(curl -sf "$BACKEND_URL/metrics" 2>/dev/null || echo "")

if [ -n "$METRICS" ]; then
    ORDERS_CREATED=$(echo "$METRICS" | grep "^orders_created_total" | awk '{print $2}' || echo "0")
    ORDERS_FAILED=$(echo "$METRICS" | grep "^orders_failed_total" | awk '{print $2}' || echo "0")
    HTTP_REQUESTS=$(echo "$METRICS" | grep "^http_requests_total" | awk '{sum += $2} END {print sum}' || echo "0")
    
    echo "📈 Métricas de Negócio:"
    echo "   • Orders criadas: $ORDERS_CREATED"
    echo "   • Orders falharam: $ORDERS_FAILED"
    echo "   • Taxa de sucesso: $(echo "scale=2; $ORDERS_CREATED * 100 / ($ORDERS_CREATED + $ORDERS_FAILED)" | bc -l 2>/dev/null || echo "N/A")%"
    echo ""
    echo "🌐 Métricas HTTP:"
    echo "   • Total requests: $HTTP_REQUESTS"
    echo "   • Requests/segundo: $(echo "scale=2; $HTTP_REQUESTS / $DURATION" | bc -l 2>/dev/null || echo "N/A")"
fi

# Verificar dados no DynamoDB
DYNAMO_COUNT=$(bash scripts/awslocal.sh dynamodb scan --table-name orders --select COUNT 2>/dev/null | grep '"Count"' | awk '{print $2}' | tr -d ',' || echo "0")
echo ""
echo "💾 DynamoDB:"
echo "   • Total de orders na tabela: $DYNAMO_COUNT"

echo ""
echo "📊 VISUALIZAÇÃO"
echo "==============="
echo ""
echo "Acesse os dashboards para ver os resultados:"
echo ""
echo "🎯 Golden Signals:"
echo "   http://localhost:3100/d/golden-signals-backend"
echo ""
echo "📈 Business Metrics:"
echo "   http://localhost:3100/d/business-orders"
echo ""
echo "🔍 Prometheus Queries:"
echo "   http://localhost:9090/graph"
echo ""
echo "Queries úteis:"
echo "   • rate(http_requests_total[5m])"
echo "   • histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))"
echo "   • rate(orders_created_total[5m])"
echo "   • orders_failed_total / (orders_created_total + orders_failed_total)"
echo ""

# Sugestão de próximos testes
echo "🚀 PRÓXIMOS TESTES"
echo "=================="
echo ""
echo "Teste com mais carga:"
echo "   bash scripts/load-test.sh 120 10  # 2 min, 10 workers"
echo ""
echo "Teste de stress:"
echo "   bash scripts/load-test.sh 300 20  # 5 min, 20 workers"
echo ""
echo "Teste de caos (matar pods):"
echo "   python scripts/chaos_kill_random_pod.py"
echo ""