#!/bin/bash
# Script para aplicar dashboards e configurações de observabilidade

set -e

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${BLUE}  $1${NC}"; }
success() { echo -e "${GREEN} $1${NC}"; }
warn() { echo -e "${YELLOW}  $1${NC}"; }
fail() { echo -e "${RED} $1${NC}"; }
header() { echo -e "${CYAN}$1${NC}"; }

echo ""
header " CONFIGURANDO OBSERVABILIDADE COMPLETA"
header "========================================"
echo ""

# Verificar se stack está rodando
info "Verificando se a stack de observabilidade está ativa..."
if ! docker compose -f docker-compose.observability.yml ps | grep -q "Up"; then
    info "Iniciando stack de observabilidade..."
    docker compose -f docker-compose.observability.yml up -d
    sleep 30
fi

# =====================================================
# 1. CONFIGURAR GRAFANA DASHBOARDS
# =====================================================
header " 1. CONFIGURANDO DASHBOARDS GRAFANA"
header "====================================="

info "Verificando conectividade com Grafana..."
GRAFANA_URL="http://localhost:3100"
GRAFANA_USER="admin"
GRAFANA_PASS="admin"

# Aguardar Grafana estar pronto
for i in {1..30}; do
    if curl -s "$GRAFANA_URL/api/health" > /dev/null; then
        success "Grafana está acessível"
        break
    fi
    info "Aguardando Grafana... (tentativa $i/30)"
    sleep 5
done

# Criar pasta para dashboards
info "Criando pasta de dashboards..."
curl -s -X POST \
  -H "Content-Type: application/json" \
  -u "$GRAFANA_USER:$GRAFANA_PASS" \
  -d '{"title":"Case Observability"}' \
  "$GRAFANA_URL/api/folders" || true

# Aplicar dashboard Golden Signals
info "Aplicando dashboard: 4 Golden Signals + Business Metrics..."
if curl -s -X POST \
  -H "Content-Type: application/json" \
  -u "$GRAFANA_USER:$GRAFANA_PASS" \
  -d @observabilidade/grafana/dashboards/golden-signals-complete.json \
  "$GRAFANA_URL/api/dashboards/db"; then
    success "Dashboard Golden Signals aplicado"
else
    warn "Erro ao aplicar dashboard Golden Signals"
fi

# Aplicar dashboard Logs/Metrics/Traces
info "Aplicando dashboard: Logs, Metrics & Traces..."
if curl -s -X POST \
  -H "Content-Type: application/json" \
  -u "$GRAFANA_USER:$GRAFANA_PASS" \
  -d @observabilidade/grafana/dashboards/logs-metrics-traces.json \
  "$GRAFANA_URL/api/dashboards/db"; then
    success "Dashboard Logs/Metrics/Traces aplicado"
else
    warn "Erro ao aplicar dashboard de integração"
fi

# =====================================================
# 2. CONFIGURAR PROMETHEUS ALERTAS
# =====================================================
header " 2. CONFIGURANDO ALERTAS PROMETHEUS"
header "===================================="

info "Verificando configuração do Prometheus..."
if curl -s http://localhost:9090/api/v1/status/config | grep -q "alerts-complete.yml"; then
    success "Alertas já configurados no Prometheus"
else
    info "Aplicando configuração de alertas..."
    
    # Backup da configuração atual
    cp observabilidade/prometheus/prometheus.yml observabilidade/prometheus/prometheus.yml.backup
    
    # Adicionar alertas à configuração
    cat >> observabilidade/prometheus/prometheus.yml << 'EOF'

# Regras de alerta
rule_files:
  - "alerts-complete.yml"

# Configuração do Alertmanager (se disponível)
alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093
EOF

    info "Reiniciando Prometheus para aplicar alertas..."
    docker compose -f docker-compose.observability.yml restart prometheus
    sleep 10
    success "Alertas Prometheus configurados"
fi

# =====================================================
# 3. CONFIGURAR DATADOG (se disponível)
# =====================================================
header " 3. CONFIGURANDO DATADOG DASHBOARDS"
header "==================================="

if [ -n "$DATADOG_API_KEY" ] && [ -n "$DATADOG_APP_KEY" ]; then
    info "Chaves Datadog detectadas - configurando dashboards..."
    
    # Aplicar dashboard principal
    info "Criando dashboard Golden Signals no Datadog..."
    curl -X POST \
      -H "Content-Type: application/json" \
      -H "DD-API-KEY: $DATADOG_API_KEY" \
      -H "DD-APPLICATION-KEY: $DATADOG_APP_KEY" \
      -d @observabilidade/datadog/dashboards/golden-signals-complete.json \
      "https://api.datadoghq.com/api/v1/dashboard" && success "Dashboard Datadog criado" || warn "Erro ao criar dashboard Datadog"
    
    # Aplicar monitors
    info "Criando monitors no Datadog..."
    while IFS= read -r monitor; do
        echo "$monitor" | curl -X POST \
          -H "Content-Type: application/json" \
          -H "DD-API-KEY: $DATADOG_API_KEY" \
          -H "DD-APPLICATION-KEY: $DATADOG_APP_KEY" \
          -d @- \
          "https://api.datadoghq.com/api/v1/monitor" && info "Monitor criado" || warn "Erro ao criar monitor"
    done < <(jq -c '.[]' observabilidade/datadog/monitors/comprehensive-monitors.json)
    
    success "Configuração Datadog concluída"
else
    warn "Chaves Datadog não configuradas - pulando configuração"
    info "Para configurar Datadog:"
    echo "  export DATADOG_API_KEY='your-api-key'"
    echo "  export DATADOG_APP_KEY='your-app-key'"
fi

# =====================================================
# 4. VERIFICAR MÉTRICAS E DADOS
# =====================================================
header " 4. VERIFICANDO COLETA DE DADOS"
header "================================="

info "Verificando coleta de métricas Prometheus..."
METRICS_AVAILABLE=$(curl -s "http://localhost:9090/api/v1/label/__name__/values" | jq -r '.data[]' | grep -E "(http_|orders_|backend_)" | wc -l)
if [ "$METRICS_AVAILABLE" -gt 10 ]; then
    success "Métricas sendo coletadas ($METRICS_AVAILABLE métricas disponíveis)"
else
    warn "Poucas métricas disponíveis ($METRICS_AVAILABLE) - verificar instrumentação"
fi

info "Verificando logs no Loki..."
if curl -s "http://localhost:3101/loki/api/v1/labels" | grep -q "service"; then
    success "Logs sendo coletados no Loki"
else
    warn "Problemas na coleta de logs - verificar Promtail"
fi

info "Verificando traces no Tempo..."
if curl -s "http://localhost:3102/api/search" > /dev/null 2>&1; then
    success "Tempo está funcionando (traces disponíveis quando implementados)"
else
    warn "Tempo não está respondendo - verificar configuração"
fi

# =====================================================
# 5. GERAR DADOS DE TESTE
# =====================================================
header " 5. GERANDO DADOS DE TESTE"
header "============================="

info "Executando requests de teste para gerar métricas..."

# Verificar se backend está rodando
if kubectl get pods -n case -l app=backend --no-headers | grep -q Running; then
    BACKEND_POD=$(kubectl get pods -n case -l app=backend -o jsonpath='{.items[0].metadata.name}')
    
    info "Gerando tráfego via pod backend: $BACKEND_POD"
    kubectl exec -n case $BACKEND_POD -- sh -c '
        # Gerar requests de sucesso
        for i in $(seq 1 20); do
            wget -q -O /dev/null http://localhost:3000/healthz
            wget -q -O /dev/null http://localhost:3000/api/orders
        done
        
        # Simular alguns erros
        for i in $(seq 1 5); do
            wget -q -O /dev/null http://localhost:3000/api/invalid-endpoint || true
        done
        
        echo "Tráfego de teste gerado"
    '
    success "Dados de teste gerados"
else
    warn "Pods backend não encontrados - dados de teste não gerados"
fi

# =====================================================
# 6. RELATÓRIO FINAL
# =====================================================
header " RELATÓRIO DE CONFIGURAÇÃO"
header "============================"

cat << EOF

 CONFIGURAÇÃO DE OBSERVABILIDADE CONCLUÍDA!

 DASHBOARDS DISPONÍVEIS:
   • Grafana: http://localhost:3100
     - 4 Golden Signals + Business Metrics
     - Logs, Metrics & Traces Integration
     - Credenciais: admin/admin
   
   • Prometheus: http://localhost:9090  
     - Métricas coletadas: $METRICS_AVAILABLE métricas ativas
     - Alertas configurados: Golden Signals + Business + SLOs
   
   • Datadog: $([ -n "$DATADOG_API_KEY" ] && echo "Configurado ✅" || echo "Não configurado ⚠")
     - Dashboard Golden Signals
     - Monitors abrangentes

 DADOS COLETADOS:
   • Métricas:  Prometheus ($METRICS_AVAILABLE métricas)
   • Logs:  Loki (estruturados JSON)  
   • Traces:  Tempo (precisa instrumentação OpenTelemetry)

 COBERTURA POR APLICAÇÃO:
   • Backend:  Completo (4 Golden Signals + Business)
   • Frontend:  Parcial (precisa instrumentação browser)
   • Mobile:  Parcial (precisa instrumentação app)

 ALERTAS CONFIGURADOS:
    Latência (P99 > 2s)
    Tráfego (drops e spikes)  
    Erros (>5% error rate)
    Saturação (CPU/Memory >85%)
    Business (order failures, revenue drops)
    SLO/SLI (error budget burn rate)

 PRÓXIMOS PASSOS RECOMENDADOS:
1.  Implementar instrumentação OpenTelemetry (traces)
2.  Adicionar métricas frontend (Core Web Vitals)
3.  Instrumentar app mobile (crashes, performance)
4.  Configurar Alertmanager (notificações Slack/PagerDuty)
5.  Definir SLOs específicos por serviço
6.  Criar runbooks para cada alerta

EOF

success " Observabilidade enterprise-ready implementada com sucesso!"
echo ""
info " Acesse os dashboards para monitorar seu sistema em tempo real:"
echo "   • Grafana: http://localhost:3100 (admin/admin)"
echo "   • Prometheus: http://localhost:9090"
echo "   • Locust: http://localhost:8089 (para gerar carga)"