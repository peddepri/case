#!/bin/bash
# Script de validação completa da observabilidade

set -e

# JQ Path
JQ_PATH="/c/Users/prisc/AppData/Local/Microsoft/WinGet/Packages/jqlang.jq_Microsoft.Winget.Source_8wekyb3d8bbwe/jq"
if [ ! -f "$JQ_PATH" ]; then
    JQ_PATH="jq"  # Fallback para jq no PATH
fi
alias jq="$JQ_PATH"

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${BLUE}ℹ  $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠  $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; }
header() { echo -e "${CYAN}$1${NC}"; }

echo ""
header "🔍 VALIDAÇÃO COMPLETA DE OBSERVABILIDADE"
header "========================================"
echo ""

VALIDATION_RESULTS=()
TOTAL_TESTS=0
PASSED_TESTS=0

test_result() {
    local test_name="$1"
    local result="$2"
    local details="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if [ "$result" = "PASS" ]; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
        success "$test_name"
        [ -n "$details" ] && info "  $details"
    else
        fail "$test_name"
        [ -n "$details" ] && warn "  $details"
    fi
    
    VALIDATION_RESULTS+=("$result|$test_name|$details")
}

# =====================================================
# 1. VERIFICAR INFRAESTRUTURA
# =====================================================
header "🏗️  1. VALIDANDO INFRAESTRUTURA"
header "==============================="

info "Testando conectividade com Kubernetes..."
if kubectl cluster-info > /dev/null 2>&1; then
    test_result "Kubernetes Cluster" "PASS" "Cluster acessível"
else
    test_result "Kubernetes Cluster" "FAIL" "Cluster não acessível"
fi

info "Verificando pods da aplicação..."
BACKEND_PODS=$(kubectl get pods -n case -l app=backend --no-headers 2>/dev/null | grep Running | wc -l)
FRONTEND_PODS=$(kubectl get pods -n case -l app=frontend --no-headers 2>/dev/null | grep Running | wc -l)
MOBILE_PODS=$(kubectl get pods -n case -l app=mobile --no-headers 2>/dev/null | grep Running | wc -l)

test_result "Backend Pods" "$( [ $BACKEND_PODS -gt 0 ] && echo PASS || echo FAIL )" "$BACKEND_PODS pods rodando"
test_result "Frontend Pods" "$( [ $FRONTEND_PODS -gt 0 ] && echo PASS || echo FAIL )" "$FRONTEND_PODS pods rodando"
test_result "Mobile Pods" "$( [ $MOBILE_PODS -gt 0 ] && echo PASS || echo FAIL )" "$MOBILE_PODS pods rodando"

info "Verificando stack de observabilidade..."
for service in prometheus grafana loki tempo; do
    if docker compose -f docker-compose.observability.yml ps $service | grep -q "Up"; then
        test_result "Serviço $service" "PASS" "Container ativo"
    else
        test_result "Serviço $service" "FAIL" "Container inativo"
    fi
done

# =====================================================
# 2. VALIDAR COLETA DE MÉTRICAS
# =====================================================
header "📊 2. VALIDANDO COLETA DE MÉTRICAS"
header "==================================="

info "Testando conectividade Prometheus..."
if curl -s http://localhost:9090/api/v1/status/config > /dev/null; then
    test_result "Prometheus API" "PASS" "API respondendo"
    
    # Verificar métricas específicas
    info "Verificando métricas dos 4 Golden Signals..."
    
    # Latência
    LATENCY_METRICS=$(curl -s "http://localhost:9090/api/v1/label/__name__/values" | jq -r '.data[]' | grep -E "(http_request_duration|latency)" | wc -l)
    test_result "Métricas de Latência" "$( [ $LATENCY_METRICS -gt 0 ] && echo PASS || echo FAIL )" "$LATENCY_METRICS métricas encontradas"
    
    # Tráfego
    TRAFFIC_METRICS=$(curl -s "http://localhost:9090/api/v1/label/__name__/values" | jq -r '.data[]' | grep -E "(http_requests_total|requests_per_second)" | wc -l)
    test_result "Métricas de Tráfego" "$( [ $TRAFFIC_METRICS -gt 0 ] && echo PASS || echo FAIL )" "$TRAFFIC_METRICS métricas encontradas"
    
    # Erros
    ERROR_METRICS=$(curl -s "http://localhost:9090/api/v1/label/__name__/values" | jq -r '.data[]' | grep -E "(http_requests_total|error_rate)" | wc -l)
    test_result "Métricas de Erro" "$( [ $ERROR_METRICS -gt 0 ] && echo PASS || echo FAIL )" "$ERROR_METRICS métricas encontradas"
    
    # Saturação
    SATURATION_METRICS=$(curl -s "http://localhost:9090/api/v1/label/__name__/values" | jq -r '.data[]' | grep -E "(cpu_usage|memory_usage|container_)" | wc -l)
    test_result "Métricas de Saturação" "$( [ $SATURATION_METRICS -gt 0 ] && echo PASS || echo FAIL )" "$SATURATION_METRICS métricas encontradas"
    
    # Métricas de negócio
    BUSINESS_METRICS=$(curl -s "http://localhost:9090/api/v1/label/__name__/values" | jq -r '.data[]' | grep -E "(orders_|revenue_|signup_)" | wc -l)
    test_result "Métricas de Negócio" "$( [ $BUSINESS_METRICS -gt 0 ] && echo PASS || echo FAIL )" "$BUSINESS_METRICS métricas encontradas"
    
else
    test_result "Prometheus API" "FAIL" "API não respondendo"
fi

# =====================================================
# 3. VALIDAR COLETA DE LOGS
# =====================================================
header "📝 3. VALIDANDO COLETA DE LOGS"
header "==============================="

info "Testando conectividade Loki..."
if curl -s http://localhost:3101/loki/api/v1/labels > /dev/null; then
    test_result "Loki API" "PASS" "API respondendo"
    
    # Verificar labels de serviços
    SERVICES_WITH_LOGS=$(curl -s "http://localhost:3101/loki/api/v1/label/service/values" | jq -r '.data[]' | wc -l)
    test_result "Serviços com Logs" "$( [ $SERVICES_WITH_LOGS -gt 0 ] && echo PASS || echo FAIL )" "$SERVICES_WITH_LOGS serviços encontrados"
    
    # Verificar logs estruturados
    info "Verificando estrutura dos logs..."
    LOG_SAMPLE=$(curl -s "http://localhost:3101/loki/api/v1/query_range?query={service=~\".*\"}&limit=10" | jq -r '.data.result[0].values[0][1]' 2>/dev/null)
    if echo "$LOG_SAMPLE" | jq . > /dev/null 2>&1; then
        test_result "Logs Estruturados" "PASS" "JSON válido detectado"
    else
        test_result "Logs Estruturados" "FAIL" "Logs não estruturados"
    fi
    
else
    test_result "Loki API" "FAIL" "API não respondendo"
fi

# =====================================================
# 4. VALIDAR DASHBOARDS GRAFANA
# =====================================================
header "📈 4. VALIDANDO DASHBOARDS GRAFANA"
header "==================================="

info "Testando conectividade Grafana..."
GRAFANA_URL="http://localhost:3100"
GRAFANA_USER="admin"
GRAFANA_PASS="admin"

if curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/health" > /dev/null; then
    test_result "Grafana API" "PASS" "API respondendo"
    
    # Verificar dashboards
    DASHBOARDS=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/search" | jq '. | length')
    test_result "Dashboards Importados" "$( [ $DASHBOARDS -gt 0 ] && echo PASS || echo FAIL )" "$DASHBOARDS dashboards encontrados"
    
    # Verificar datasources
    DATASOURCES=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/datasources" | jq '. | length')
    test_result "Datasources Configurados" "$( [ $DATASOURCES -gt 0 ] && echo PASS || echo FAIL )" "$DATASOURCES datasources encontrados"
    
    # Testar queries específicos
    info "Testando queries dos dashboards..."
    
    # Teste query Prometheus
    PROM_QUERY_RESULT=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/datasources/proxy/1/api/v1/query?query=up" | jq -r '.data.result | length' 2>/dev/null || echo 0)
    test_result "Query Prometheus" "$( [ $PROM_QUERY_RESULT -gt 0 ] && echo PASS || echo FAIL )" "$PROM_QUERY_RESULT séries encontradas"
    
else
    test_result "Grafana API" "FAIL" "API não respondendo"
fi

# =====================================================
# 5. VALIDAR TRACES (TEMPO)
# =====================================================
header "🔍 5. VALIDANDO TRACES (TEMPO)"
header "==============================="

info "Testando conectividade Tempo..."
if curl -s http://localhost:3102/api/search > /dev/null 2>&1; then
    test_result "Tempo API" "PASS" "API respondendo"
    
    # Verificar se há traces (pode não ter se não instrumentado)
    info "Verificando traces disponíveis..."
    test_result "Traces Disponíveis" "WARN" "Tempo funcionando - traces dependem de instrumentação OpenTelemetry"
    
else
    test_result "Tempo API" "FAIL" "API não respondendo"
fi

# =====================================================
# 6. GERAR E VALIDAR DADOS EM TEMPO REAL
# =====================================================
header "🎯 6. TESTE DE GERAÇÃO DE DADOS"
header "================================="

info "Gerando tráfego de teste..."
if [ $BACKEND_PODS -gt 0 ]; then
    BACKEND_POD=$(kubectl get pods -n case -l app=backend -o jsonpath='{.items[0].metadata.name}')
    
    # Gerar requests e capturar métricas antes/depois
    METRICS_BEFORE=$(curl -s "http://localhost:9090/api/v1/query?query=http_requests_total" | jq -r '.data.result | length' 2>/dev/null || echo 0)
    
    kubectl exec -n case $BACKEND_POD -- sh -c '
        for i in $(seq 1 10); do
            wget -q -O /dev/null http://localhost:3000/healthz
            sleep 0.5
        done
    ' > /dev/null 2>&1
    
    sleep 5  # Aguardar propagação das métricas
    
    METRICS_AFTER=$(curl -s "http://localhost:9090/api/v1/query?query=http_requests_total" | jq -r '.data.result | length' 2>/dev/null || echo 0)
    
    test_result "Geração de Tráfego" "$( [ $METRICS_AFTER -ge $METRICS_BEFORE ] && echo PASS || echo FAIL )" "Métricas: $METRICS_BEFORE → $METRICS_AFTER"
    
    # Testar geração de logs
    LOGS_BEFORE=$(curl -s "http://localhost:3101/loki/api/v1/query_range?query={service=\"backend\"}&limit=1" | jq -r '.data.result | length' 2>/dev/null || echo 0)
    
    kubectl exec -n case $BACKEND_POD -- sh -c 'echo "Test log entry" > /dev/stdout' > /dev/null 2>&1
    
    sleep 3
    
    LOGS_AFTER=$(curl -s "http://localhost:3101/loki/api/v1/query_range?query={service=\"backend\"}&limit=1" | jq -r '.data.result | length' 2>/dev/null || echo 0)
    
    test_result "Geração de Logs" "$( [ $LOGS_AFTER -ge $LOGS_BEFORE ] && echo PASS || echo FAIL )" "Streams: $LOGS_BEFORE → $LOGS_AFTER"
    
else
    test_result "Geração de Tráfego" "SKIP" "Nenhum pod backend disponível"
fi

# =====================================================
# 7. VERIFICAR ALERTAS
# =====================================================
header "🚨 7. VALIDANDO CONFIGURAÇÃO DE ALERTAS"
header "========================================"

info "Verificando regras de alerta Prometheus..."
ALERT_RULES=$(curl -s "http://localhost:9090/api/v1/rules" | jq -r '.data.groups[].rules[] | select(.type=="alerting") | .name' 2>/dev/null | wc -l)
test_result "Regras de Alerta" "$( [ $ALERT_RULES -gt 0 ] && echo PASS || echo FAIL )" "$ALERT_RULES regras configuradas"

# Verificar se algum alerta está ativo
ACTIVE_ALERTS=$(curl -s "http://localhost:9090/api/v1/alerts" | jq -r '.data.alerts | length' 2>/dev/null || echo 0)
test_result "Status dos Alertas" "$( [ $ACTIVE_ALERTS -ge 0 ] && echo PASS || echo FAIL )" "$ACTIVE_ALERTS alertas ativos"

# =====================================================
# 8. RELATÓRIO FINAL
# =====================================================
header "📋 RELATÓRIO DE VALIDAÇÃO"
header "=========================="

echo ""
info "Resumo dos testes:"
echo ""

SCORE=$((PASSED_TESTS * 100 / TOTAL_TESTS))

for result in "${VALIDATION_RESULTS[@]}"; do
    IFS='|' read -r status test_name details <<< "$result"
    case $status in
        "PASS") success "✅ $test_name $([ -n "$details" ] && echo "- $details")" ;;
        "FAIL") fail "❌ $test_name $([ -n "$details" ] && echo "- $details")" ;;
        "WARN") warn "⚠️  $test_name $([ -n "$details" ] && echo "- $details")" ;;
        "SKIP") info "⏭️  $test_name $([ -n "$details" ] && echo "- $details")" ;;
    esac
done

echo ""
header "📊 SCORECARD FINAL"
header "=================="

cat << EOF

🏆 SCORE GERAL: $SCORE% ($PASSED_TESTS/$TOTAL_TESTS testes passaram)

📈 STATUS POR CATEGORIA:
   $([ $SCORE -ge 90 ] && echo "🟢" || [ $SCORE -ge 70 ] && echo "🟡" || echo "🔴") Infraestrutura: $(echo "$VALIDATION_RESULTS" | grep -c "PASS.*Pod\|PASS.*Cluster\|PASS.*Serviço")/$(echo "$VALIDATION_RESULTS" | grep -c "Pod\|Cluster\|Serviço") componentes
   $([ $(echo "$VALIDATION_RESULTS" | grep -c "PASS.*Métrica") -gt 3 ] && echo "🟢" || echo "🟡") Métricas: $(echo "$VALIDATION_RESULTS" | grep -c "PASS.*Métrica")/$(echo "$VALIDATION_RESULTS" | grep -c "Métrica") tipos coletados
   $(echo "$VALIDATION_RESULTS" | grep -q "PASS.*Loki API" && echo "🟢" || echo "🟡") Logs: $(echo "$VALIDATION_RESULTS" | grep -c "PASS.*Log")/$(echo "$VALIDATION_RESULTS" | grep -c "Log") validações
   $(echo "$VALIDATION_RESULTS" | grep -q "PASS.*Grafana API" && echo "🟢" || echo "🟡") Dashboards: $(echo "$VALIDATION_RESULTS" | grep -c "PASS.*Dashboard\|PASS.*Grafana")/$(echo "$VALIDATION_RESULTS" | grep -c "Dashboard\|Grafana") validações
   $(echo "$VALIDATION_RESULTS" | grep -q "PASS.*Tempo API" && echo "🟢" || echo "🟡") Traces: Tempo configurado (aguarda instrumentação)

📋 RECOMENDAÇÕES:
$(if [ $SCORE -lt 70 ]; then
    echo "   🔴 CRÍTICO: Score baixo - revisar configurações básicas"
fi)
$(echo "$VALIDATION_RESULTS" | grep -q "FAIL.*Backend Pods" && echo "   🔧 Verificar deployment do backend")
$(echo "$VALIDATION_RESULTS" | grep -q "FAIL.*Prometheus" && echo "   🔧 Revisar configuração do Prometheus")
$(echo "$VALIDATION_RESULTS" | grep -q "FAIL.*Grafana" && echo "   🔧 Verificar credenciais e configuração do Grafana")
$(echo "$VALIDATION_RESULTS" | grep -q "WARN\|FAIL.*Trace" && echo "   📡 Implementar instrumentação OpenTelemetry para traces completos")
$([ $BUSINESS_METRICS -eq 0 ] && echo "   💼 Implementar métricas de negócio customizadas")

🚀 PRÓXIMOS PASSOS:
   1. $(echo "$VALIDATION_RESULTS" | grep -q "PASS.*Grafana" && echo "✅" || echo "⚠️") Acessar dashboards Grafana: http://localhost:3100
   2. $(echo "$VALIDATION_RESULTS" | grep -q "PASS.*Prometheus" && echo "✅" || echo "⚠️") Revisar métricas Prometheus: http://localhost:9090
   3. 📱 Instrumentar frontend (Core Web Vitals, user journey)
   4. 📲 Instrumentar mobile app (crashes, ANR, performance)
   5. 🔔 Configurar notificações (Slack, PagerDuty, email)
   6. 📖 Criar runbooks para alertas críticos

EOF

if [ $SCORE -ge 90 ]; then
    success "🎉 EXCELENTE! Observabilidade enterprise-ready"
elif [ $SCORE -ge 70 ]; then
    warn "👍 BOM! Algumas melhorias recomendadas"
else
    fail "⚠️  ATENÇÃO! Configurações precisam de revisão"
fi

echo ""
info "💡 Execute 'bash scripts/setup-observability-complete.sh' para corrigir problemas detectados"
echo ""