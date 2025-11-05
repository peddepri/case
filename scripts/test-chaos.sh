#!/bin/bash
# Chaos Engineering - Testes de Resiliência

set -e

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

info() { echo -e "${BLUE}ℹ  $1${NC}"; }
success() { echo -e "${GREEN} $1${NC}"; }
warn() { echo -e "${YELLOW}  $1${NC}"; }
fail() { echo -e "${RED} $1${NC}"; }
chaos() { echo -e "${PURPLE} $1${NC}"; }

echo " INICIANDO CHAOS ENGINEERING"
echo "=============================="
echo ""

# Configurar port-forward para monitoramento
info "Configurando monitoramento..."
pkill -f "kubectl.*port-forward.*case" 2>/dev/null || true
sleep 2

kubectl port-forward -n case svc/backend 3002:3000 > /dev/null 2>&1 &
BACKEND_PF_PID=$!

cleanup() {
    info "Restaurando ambiente..."
    kill $BACKEND_PF_PID 2>/dev/null || true
    # Garantir que temos pelo menos 2 replicas rodando
    kubectl scale deployment backend -n case --replicas=2 >/dev/null 2>&1 || true
    kubectl scale deployment frontend -n case --replicas=2 >/dev/null 2>&1 || true
    sleep 5
}
trap cleanup EXIT

sleep 3

# Função para testar disponibilidade
test_availability() {
    local test_name="$1"
    local duration="${2:-30}"
    local interval="${3:-2}"
    
    info "Testando disponibilidade: $test_name (${duration}s)"
    
    local total_requests=0
    local successful_requests=0
    local start_time=$(date +%s)
    local end_time=$((start_time + duration))
    
    while [ $(date +%s) -lt $end_time ]; do
        ((total_requests++))
        
        local status_code=$(curl -s -w "%{http_code}" -o /dev/null \
            --max-time 5 \
            "http://localhost:3002/api/orders" 2>/dev/null || echo "000")
        
        if [ "$status_code" = "200" ]; then
            ((successful_requests++))
            echo -n ""
        else
            echo -n ""
        fi
        
        sleep $interval
    done
    
    local availability=$(( successful_requests * 100 / total_requests ))
    echo ""
    
    if [ $availability -ge 80 ]; then
        success "$test_name - Disponibilidade: $availability% ($successful_requests/$total_requests)"
        return 0
    else
        fail "$test_name - Disponibilidade baixa: $availability% ($successful_requests/$total_requests)"
        return 1
    fi
}

# Função para estressar CPU de um pod
stress_cpu_pod() {
    local pod_name="$1"
    local duration="${2:-30}"
    
    chaos "Aplicando stress de CPU no pod: $pod_name"
    
    kubectl exec -n case "$pod_name" -- sh -c "
        # Stress de CPU usando dd e yes em background
        timeout ${duration}s yes > /dev/null &
        timeout ${duration}s dd if=/dev/zero of=/dev/null bs=1M count=1000 2>/dev/null &
        timeout ${duration}s yes | head -c 100MB > /dev/null &
        wait
    " 2>/dev/null || true
    
    info "Stress de CPU aplicado por ${duration}s no pod $pod_name"
}

# Função para estressar memória de um pod
stress_memory_pod() {
    local pod_name="$1"
    local duration="${2:-30}"
    
    chaos "Aplicando stress de memória no pod: $pod_name"
    
    kubectl exec -n case "$pod_name" -- sh -c "
        # Alocar memória usando head/tail
        timeout ${duration}s head -c 50MB < /dev/zero | tail -c 50MB > /tmp/stress1 &
        timeout ${duration}s head -c 50MB < /dev/zero | tail -c 50MB > /tmp/stress2 &  
        timeout ${duration}s head -c 50MB < /dev/zero | tail -c 50MB > /tmp/stress3 &
        wait
        rm -f /tmp/stress* 2>/dev/null || true
    " 2>/dev/null || true
    
    info "Stress de memória aplicado por ${duration}s no pod $pod_name"
}

echo ""
echo " FASE 1: BASELINE - DISPONIBILIDADE NORMAL"
echo "=========================================="

test_availability "Baseline Normal" 30 1

echo ""
echo " FASE 2: CHAOS - KILL POD RANDOM"
echo "================================="

# Obter lista de pods backend
BACKEND_PODS=($(kubectl get pods -n case -l app=backend -o jsonpath='{.items[*].metadata.name}'))
if [ ${#BACKEND_PODS[@]} -eq 0 ]; then
    fail "Nenhum pod backend encontrado!"
    exit 1
fi

chaos "Pods backend disponíveis: ${BACKEND_PODS[*]}"

# Matar um pod aleatório
RANDOM_POD=${BACKEND_PODS[$RANDOM % ${#BACKEND_PODS[@]}]}
chaos "Matando pod aleatório: $RANDOM_POD"

kubectl delete pod -n case "$RANDOM_POD" &
DELETE_PID=$!

# Testar disponibilidade durante recuperação
test_availability "Durante Kill Pod" 45 1

wait $DELETE_PID 2>/dev/null || true

# Aguardar novo pod ficar ready
info "Aguardando novo pod ficar ready..."
kubectl wait --for=condition=ready pod -l app=backend -n case --timeout=60s

echo ""
echo " FASE 3: CHAOS - STRESS DE CPU"
echo "==============================="

# Pegar primeiro pod backend para stress
BACKEND_PODS=($(kubectl get pods -n case -l app=backend -o jsonpath='{.items[*].metadata.name}'))
STRESS_POD=${BACKEND_PODS[0]}

chaos "Pod selecionado para stress: $STRESS_POD"

# Aplicar stress de CPU em background
stress_cpu_pod "$STRESS_POD" 45 &
STRESS_PID=$!

# Testar disponibilidade durante stress
test_availability "Durante Stress CPU" 50 1

wait $STRESS_PID 2>/dev/null || true

echo ""
echo " FASE 4: CHAOS - STRESS DE MEMÓRIA"
echo "==================================="

# Aplicar stress de memória
stress_memory_pod "$STRESS_POD" 45 &
MEMORY_STRESS_PID=$!

# Testar disponibilidade durante stress de memória
test_availability "Durante Stress Memória" 50 1

wait $MEMORY_STRESS_PID 2>/dev/null || true

echo ""
echo " FASE 5: CHAOS - SCALING EXTREMO"
echo "================================"

chaos "Testando escalabilidade - Scale Down para 1 replica"
kubectl scale deployment backend -n case --replicas=1

sleep 5
test_availability "Com 1 Replica" 30 1

chaos "Scale Up para 5 replicas"
kubectl scale deployment backend -n case --replicas=5

info "Aguardando todas as replicas ficarem ready..."
kubectl wait --for=condition=ready pod -l app=backend -n case --timeout=90s

test_availability "Com 5 Replicas" 30 1

echo ""
echo " FASE 6: CHAOS - NETWORK DELAY SIMULATION"
echo "========================================="

chaos "Simulando latência de rede com múltiplos requests simultâneos"

# Criar carga de trabalho com múltiplos processos
PIDS=()
RESULTS_FILE="/tmp/chaos_results.txt"
echo "" > "$RESULTS_FILE"

for i in {1..20}; do
    {
        local start_time=$(date +%s%N)
        local status_code=$(curl -s -w "%{http_code}" -o /dev/null \
            --max-time 10 "http://localhost:3002/api/orders" 2>/dev/null || echo "000")
        local end_time=$(date +%s%N)
        local duration_ms=$(( (end_time - start_time) / 1000000 ))
        
        echo "$status_code,$duration_ms" >> "$RESULTS_FILE"
    } &
    PIDS+=($!)
    
    # Pequeno delay entre requests
    sleep 0.1
done

info "Aguardando todos os requests completarem..."
wait "${PIDS[@]}"

# Analisar resultados
SUCCESS_COUNT=$(grep "^200," "$RESULTS_FILE" | wc -l)
TOTAL_COUNT=$(wc -l < "$RESULTS_FILE")
AVG_LATENCY=$(grep "^200," "$RESULTS_FILE" | cut -d',' -f2 | awk '{sum+=$1} END {print int(sum/NR)}')

info "Resultados da simulação de rede:"
echo "   Requests bem sucedidos: $SUCCESS_COUNT/$TOTAL_COUNT"
echo "   Latência média: ${AVG_LATENCY:-0} ms"

if [ $SUCCESS_COUNT -ge $((TOTAL_COUNT * 80 / 100)) ]; then
    success "Sistema resistiu bem à simulação de rede"
else
    fail "Sistema teve problemas com simulação de rede"
fi

echo ""
echo " FASE 7: CHAOS - ANÁLISE DE LOGS E MÉTRICAS"
echo "=========================================="

info "Analisando logs de erro dos últimos 5 minutos..."
ERROR_LOGS=$(kubectl logs -n case -l app=backend --since=5m | grep -i "error\|exception\|fail" | wc -l)
WARN_LOGS=$(kubectl logs -n case -l app=backend --since=5m | grep -i "warn\|warning" | wc -l)

echo "   Logs de erro encontrados: $ERROR_LOGS"
echo "   Logs de warning encontrados: $WARN_LOGS"

if [ $ERROR_LOGS -lt 10 ]; then
    success "Poucos erros nos logs - sistema estável"
else
    warn "Muitos erros detectados nos logs - verificar"
fi

# Verificar métricas de resource usage
info "Verificando uso de recursos dos pods..."
kubectl top pods -n case 2>/dev/null || warn "Metrics server não disponível"

echo ""
echo " RELATÓRIO FINAL DO CHAOS"
echo "=========================="

# Restaurar estado normal
chaos "Restaurando configuração normal..."
kubectl scale deployment backend -n case --replicas=2
kubectl scale deployment frontend -n case --replicas=2

info "Aguardando estabilização..."
sleep 10

# Teste final de sanidade
test_availability "Pós-Chaos Sanity Check" 20 1

success " CHAOS ENGINEERING CONCLUÍDO!"
echo ""
echo " Resumo dos testes:"
echo "    Kill de pod aleatório"
echo "    Stress de CPU"  
echo "    Stress de memória"
echo "    Scaling extremo (15 replicas)"
echo "    Simulação de latência de rede"
echo "    Análise de logs e métricas"
echo ""
echo " Para monitoramento contínuo:"
echo "   • Grafana: http://localhost:3100"
echo "   • Prometheus: http://localhost:9090"
echo "   • Logs: kubectl logs -n case -l app=backend -f"

# Cleanup do arquivo temporário
rm -f "$RESULTS_FILE" 2>/dev/null || true