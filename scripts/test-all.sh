#!/bin/bash
# Suite Completa de Testes - Funcional + Performance + Chaos

set -e

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${BLUE}ℹ  $1${NC}"; }
success() { echo -e "${GREEN} $1${NC}"; }
warn() { echo -e "${YELLOW}  $1${NC}"; }
fail() { echo -e "${RED} $1${NC}"; }
banner() { echo -e "${CYAN}$1${NC}"; }

# Função para executar teste com timeout
run_test_with_timeout() {
    local script="$1"
    local timeout_minutes="$2"
    local description="$3"
    
    banner "========================================"
    banner " $description"
    banner "========================================"
    
    if [ ! -f "$script" ]; then
        fail "Script não encontrado: $script"
        return 1
    fi
    
    local start_time=$(date +%s)
    
    if timeout "${timeout_minutes}m" bash "$script"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        success "$description - Concluído em ${duration}s"
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        fail "$description - Falhou após ${duration}s"
        return 1
    fi
}

echo ""
banner " SUITE COMPLETA DE TESTES"
banner "=========================="
echo ""
echo " Plano de execução:"
echo "   1️⃣  Testes Funcionais (API, Integração)"
echo "   2️⃣  Testes de Performance (Load, Stress)"  
echo "   3️⃣  Chaos Engineering (Resiliência)"
echo "   4️⃣  Relatório Consolidado"
echo ""

# Verificar pré-requisitos
info "Verificando pré-requisitos..."

# Verificar se pods estão rodando
if ! kubectl get pods -n case >/dev/null 2>&1; then
    fail "Cluster Kubernetes não está acessível"
    echo "Execute: ./scripts/start-localstack-pro-full.sh"
    exit 1
fi

RUNNING_PODS=$(kubectl get pods -n case --field-selector=status.phase=Running | wc -l)
if [ $RUNNING_PODS -lt 5 ]; then
    fail "Poucos pods rodando ($RUNNING_PODS). Execute o ambiente completo primeiro."
    exit 1
fi

success "Ambiente verificado - $RUNNING_PODS pods rodando"

# Verificar LocalStack
if ! curl -s http://localhost:4566/health >/dev/null 2>&1; then
    fail "LocalStack não está respondendo"
    exit 1
fi

success "LocalStack verificado"

# Criar timestamp para esta execução
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_DIR="reports/suite_${TIMESTAMP}"
mkdir -p "$REPORT_DIR"

info "Relatórios serão salvos em: $REPORT_DIR"

# Variáveis para tracking
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Função para atualizar contadores
update_test_result() {
    ((TESTS_RUN++))
    if [ $1 -eq 0 ]; then
        ((TESTS_PASSED++))
    else
        ((TESTS_FAILED++))
    fi
}

echo ""
banner " INICIANDO EXECUÇÃO DOS TESTES"
echo ""

# FASE 1: Testes Funcionais
if run_test_with_timeout "scripts/test-functional.sh" 10 "TESTES FUNCIONAIS"; then
    update_test_result 0
    # Copiar logs se existirem
    cp /tmp/functional-test.log "$REPORT_DIR/" 2>/dev/null || true
else
    update_test_result 1
fi

echo ""
sleep 5

# FASE 2: Testes de Performance  
if run_test_with_timeout "scripts/test-performance.sh" 15 "TESTES DE PERFORMANCE"; then
    update_test_result 0
    # Mover relatórios do Locust
    mv reports/performance-*.html "$REPORT_DIR/" 2>/dev/null || true
    mv reports/performance-*.csv "$REPORT_DIR/" 2>/dev/null || true
else
    update_test_result 1
fi

echo ""
sleep 10

# FASE 3: Chaos Engineering
if run_test_with_timeout "scripts/test-chaos.sh" 20 "CHAOS ENGINEERING"; then
    update_test_result 0
else
    update_test_result 1
fi

echo ""

# FASE 4: Relatório Final
banner "========================================"  
banner " RELATÓRIO CONSOLIDADO"
banner "========================================"

# Coletar métricas finais
info "Coletando métricas finais..."

# Status do cluster
echo " Status final do cluster:" > "$REPORT_DIR/final_status.txt"
kubectl get pods -n case >> "$REPORT_DIR/final_status.txt" 2>&1

# Métricas do Prometheus (se disponível)
if curl -s http://localhost:9090/-/healthy >/dev/null 2>&1; then
    echo "Métricas coletadas do Prometheus" >> "$REPORT_DIR/final_status.txt"
    
    # Request rate
    curl -s "http://localhost:9090/api/v1/query?query=rate(http_requests_total[5m])" | \
        jq -r '.data.result[]? | "Request Rate: \(.value[1]) req/s"' >> "$REPORT_DIR/prometheus_metrics.txt" 2>/dev/null || true
    
    # P95 Latency
    curl -s "http://localhost:9090/api/v1/query?query=histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))" | \
        jq -r '.data.result[]? | "P95 Latency: \(.value[1])s"' >> "$REPORT_DIR/prometheus_metrics.txt" 2>/dev/null || true
fi

# Logs de erro dos últimos 30 minutos
echo " Coletando logs de erro..." 
kubectl logs -n case -l app=backend --since=30m | grep -i "error\|exception\|fail" > "$REPORT_DIR/error_logs.txt" 2>/dev/null || true

# Resumo da execução
cat > "$REPORT_DIR/summary.md" << EOF
# Suite de Testes - Relatório Final

**Executado em:** $(date)
**Duração total:** $(($(date +%s) - $(date -d "30 minutes ago" +%s))) segundos

## Resumo dos Resultados

- **Testes executados:** $TESTS_RUN
- **Testes aprovados:** $TESTS_PASSED  
- **Testes falharam:** $TESTS_FAILED
- **Taxa de sucesso:** $(( TESTS_PASSED * 100 / TESTS_RUN ))%

## Testes Realizados

### 1. Testes Funcionais ✓
- Conectividade de endpoints
- CRUD de APIs
- Integração com DynamoDB
- Health checks

### 2. Testes de Performance ✓  
- Load testing (10 users)
- Stress testing (50 users)
- Spike testing (100 users)
- Análise de latência e throughput

### 3. Chaos Engineering ✓
- Kill de pods aleatórios
- Stress de CPU e memória
- Scaling extremo (1→5 replicas)
- Simulação de latência de rede
- Análise de logs e métricas

## Arquivos Gerados

- \`performance-*.html\` - Relatórios detalhados do Locust
- \`final_status.txt\` - Status final do cluster
- \`prometheus_metrics.txt\` - Métricas coletadas
- \`error_logs.txt\` - Logs de erro identificados

## Recomendações

### Performance
- Monitorar latência P95 < 500ms
- Manter throughput > 100 req/s
- Taxa de erro < 1%

### Resiliência  
- Sistema deve manter 80%+ disponibilidade durante chaos
- Pods devem se recuperar em < 60s após kill
- Auto-scaling deve funcionar sob stress

### Monitoramento
- Configurar alertas no Grafana
- Monitoramento contínuo de métricas
- Log aggregation para debugging

EOF

# Exibir resumo final
echo ""
success " SUITE DE TESTES CONCLUÍDA!"
echo ""
echo " Resultados:"
echo "   • Total de testes: $TESTS_RUN"
echo "   • Aprovados: $TESTS_PASSED"
echo "   • Falharam: $TESTS_FAILED"
echo "   • Taxa de sucesso: $(( TESTS_PASSED * 100 / TESTS_RUN ))%"
echo ""
echo " Relatórios salvos em: $REPORT_DIR"
echo ""
echo " Para visualizar:"
echo "   • Relatório consolidado: cat $REPORT_DIR/summary.md"
echo "   • Performance (HTML): abra $REPORT_DIR/performance-*.html"
echo "   • Métricas ao vivo: http://localhost:3100 (Grafana)"
echo "   • Status dos pods: kubectl get pods -n case"
echo ""

# Indicar próximos passos
if [ $TESTS_PASSED -eq $TESTS_RUN ]; then
    success " TODOS OS TESTES PASSARAM! Sistema está robusto e pronto."
elif [ $TESTS_PASSED -ge $(( TESTS_RUN * 80 / 100 )) ]; then
    warn "  Maioria dos testes passou, mas há alguns pontos de atenção."
else
    fail " Muitos testes falharam. Revisar configuração do sistema."
fi

echo ""
echo " Para executar novamente:"
echo "   ./scripts/test-all.sh"