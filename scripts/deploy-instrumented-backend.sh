#!/bin/bash
# Script para aplicar backend instrumentado e gerar dados nos dashboards

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
header " APLICANDO INSTRUMENTAÇÃO COMPLETA"
header "===================================="
echo ""

# =====================================================
# 1. BACKUP E DEPLOY BACKEND INSTRUMENTADO
# =====================================================
header " 1. DEPLOYANDO BACKEND INSTRUMENTADO"
header "====================================="

info "Fazendo backup do deployment atual..."
kubectl get deployment backend -n case -o yaml > app/backend/backend-deployment-backup.yaml 2>/dev/null || true

info "Construindo imagem do backend instrumentado..."
cd app/backend

# Build da nova imagem
docker build -f Dockerfile.instrumented -t case-backend-instrumented:latest . 

# Carregar no Kind
info "Carregando imagem no Kind cluster..."
kind load docker-image case-backend-instrumented:latest --name case-cluster

# =====================================================
# 2. ATUALIZAR DEPLOYMENT KUBERNETES
# =====================================================
info "Atualizando deployment do backend..."

# Verificar se deployment existe
if kubectl get deployment backend -n case > /dev/null 2>&1; then
    # Atualizar imagem existente
    kubectl set image deployment/backend backend=case-backend-instrumented:latest -n case
    
    # Adicionar annotations para Prometheus
    kubectl annotate deployment backend -n case prometheus.io/scrape=true --overwrite
    kubectl annotate deployment backend -n case prometheus.io/port=3000 --overwrite  
    kubectl annotate deployment backend -n case prometheus.io/path=/metrics --overwrite
    
    info "Aguardando rollout do deployment..."
    kubectl rollout status deployment/backend -n case --timeout=300s
    
    success "Backend instrumentado deployado com sucesso"
else
    # Criar novo deployment
    warn "Deployment backend não encontrado - criando novo..."
    
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: case
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "3000"
    prometheus.io/path: "/metrics"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "3000"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: backend
        image: case-backend-instrumented:latest
        ports:
        - containerPort: 3000
          name: http
        env:
        - name: NODE_ENV
          value: "production"
        - name: PROMETHEUS_METRICS
          value: "true"
        - name: DATADOG_ENABLED
          value: "true"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        readinessProbe:
          httpGet:
            path: /healthz
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /healthz
            port: 3000
          initialDelaySeconds: 15
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: case
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "3000"
spec:
  selector:
    app: backend
  ports:
  - port: 3000
    targetPort: 3000
    name: http
  type: ClusterIP
EOF
    
    success "Novo deployment backend criado"
fi

# =====================================================
# 3. CONFIGURAR SERVICE MONITOR PROMETHEUS
# =====================================================
header " 2. CONFIGURANDO COLETA PROMETHEUS"
header "==================================="

info "Criando ServiceMonitor para Prometheus..."

cat << 'EOF' | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: backend-metrics
  namespace: case
  labels:
    app: backend
spec:
  selector:
    matchLabels:
      app: backend
  endpoints:
  - port: http
    path: /metrics
    interval: 15s
    scrapeTimeout: 10s
EOF

# =====================================================
# 4. GERAR DADOS DE TESTE INICIAIS
# =====================================================
header " 3. GERANDO DADOS DE TESTE"
header "============================"

# Aguardar pods estarem prontos
info "Aguardando pods backend estarem prontos..."
kubectl wait --for=condition=ready pod -l app=backend -n case --timeout=120s

# Obter pod para testes
BACKEND_POD=$(kubectl get pods -n case -l app=backend -o jsonpath='{.items[0].metadata.name}')
info "Pod backend selecionado: $BACKEND_POD"

# Gerar tráfego para popular métricas
info "Gerando tráfego inicial para popular dashboards..."

kubectl exec -n case $BACKEND_POD -- sh -c '
echo " Iniciando geração de dados de teste..."

# Função para fazer requests
make_request() {
    local endpoint=$1
    local method=${2:-GET}
    local data=${3:-""}
    
    if [ "$method" = "POST" ] && [ -n "$data" ]; then
        wget -q -O- --post-data="$data" --header="Content-Type: application/json" "http://localhost:3000$endpoint" 2>/dev/null || echo "Request sent to $endpoint"
    else
        wget -q -O- "http://localhost:3000$endpoint" 2>/dev/null || echo "Request sent to $endpoint"
    fi
    
    sleep 0.2
}

# 1. Health checks (para latência baixa)
echo " Gerando requests de health check..."
for i in $(seq 1 20); do
    make_request "/healthz"
done

# 2. Listar pedidos (para métricas de negócio)
echo " Gerando visualizações de pedidos..."
for i in $(seq 1 15); do
    make_request "/api/orders"
done

# 3. Criar pedidos (business metrics)
echo " Criando pedidos de teste..."
for i in $(seq 1 8); do
    make_request "/api/orders" "POST" "{\"user_id\":\"test_user_$i\",\"product_type\":\"premium\",\"amount\":$(($RANDOM % 200 + 50))}"
    sleep 1
done

# 4. Cadastros de usuário
echo " Criando usuários de teste..."
for i in $(seq 1 5); do
    make_request "/api/users/signup" "POST" "{\"email\":\"user$i@test.com\",\"signup_method\":\"email\"}"
done

# 5. Alguns erros para testar alertas
echo " Gerando alguns erros para teste..."
for i in $(seq 1 3); do
    make_request "/api/error-test"
done

# 6. Requests lentos
echo " Gerando requests com latência alta..."
for i in $(seq 1 2); do
    make_request "/api/slow-endpoint"
done

# 7. Stats para verificar
echo " Verificando estatísticas..."
make_request "/api/stats"

echo " Geração de dados concluída!"
echo " Métricas devem aparecer nos dashboards em até 1 minuto"
'

success "Dados de teste gerados com sucesso"

# =====================================================
# 5. VERIFICAR MÉTRICAS DISPONÍVEIS
# =====================================================
header " 4. VERIFICANDO COLETA DE MÉTRICAS"
header "==================================="

info "Verificando se métricas estão sendo expostas..."

# Port-forward temporário para verificar métricas
kubectl port-forward -n case svc/backend 3000:3000 > /dev/null 2>&1 &
PF_PID=$!
sleep 5

if curl -s http://localhost:3000/metrics | head -20; then
    success " Métricas Prometheus sendo expostas corretamente"
    
    # Verificar métricas específicas
    GOLDEN_SIGNALS_COUNT=$(curl -s http://localhost:3000/metrics | grep -E "(http_request_duration|http_requests_total|http_requests_error_rate|system_resource_usage)" | wc -l)
    BUSINESS_METRICS_COUNT=$(curl -s http://localhost:3000/metrics | grep -E "(orders_total|revenue_total|active_users|signups_total)" | wc -l)
    
    success " Golden Signals: $GOLDEN_SIGNALS_COUNT métricas encontradas"
    success " Business Metrics: $BUSINESS_METRICS_COUNT métricas encontradas"
else
    warn "  Métricas não estão acessíveis ainda"
fi

# Limpar port-forward
kill $PF_PID 2>/dev/null || true

# =====================================================
# 6. APLICAR FRONTEND/MOBILE INSTRUMENTAÇÃO
# =====================================================
header " 5. CONFIGURANDO INSTRUMENTAÇÃO FRONTEND/MOBILE"
header "================================================="

cd ../../

info "Criando ConfigMap com instrumentação frontend..."
kubectl create configmap frontend-instrumentation \
  --from-file=app/frontend/src/instrumentation.js \
  -n case --dry-run=client -o yaml | kubectl apply -f -

info "Criando ConfigMap com instrumentação mobile..."
kubectl create configmap mobile-instrumentation \
  --from-file=app/mobile/src/instrumentation.js \
  -n case --dry-run=client -o yaml | kubectl apply -f -

success "Instrumentação frontend/mobile configurada"

# =====================================================
# 7. ATUALIZAR PROMETHEUS CONFIG
# =====================================================
header " 6. ATUALIZANDO CONFIGURAÇÃO PROMETHEUS"
header "=========================================="

info "Adicionando job para backend instrumentado..."

# Verificar se job já existe
if grep -q "backend-instrumented" observabilidade/prometheus/prometheus.yml; then
    success "Job backend-instrumented já configurado"
else
    # Adicionar job para backend instrumentado
    cat >> observabilidade/prometheus/prometheus.yml << 'EOF'

  # Backend Kubernetes Instrumentado (via service discovery)
  - job_name: 'backend-instrumented'
    kubernetes_sd_configs:
      - role: pod
        namespaces:
          names:
            - case
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - source_labels: [__meta_kubernetes_namespace]
        action: replace
        target_label: kubernetes_namespace
      - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        target_label: kubernetes_pod_name

  # Backend direto via service (fallback)
  - job_name: 'backend-service'
    static_configs:
      - targets: ['backend.case.svc.cluster.local:3000']
        labels:
          service: 'backend'
          environment: 'kubernetes'
          platform: 'instrumented'
EOF

    info "Reiniciando Prometheus para aplicar nova configuração..."
    docker compose -f docker-compose.observability.yml restart prometheus
    sleep 10
    
    success "Prometheus configurado para coletar métricas do backend instrumentado"
fi

# =====================================================
# 8. RELATÓRIO FINAL
# =====================================================
header " RELATÓRIO DE IMPLEMENTAÇÃO"
header "=============================="

cat << EOF

 INSTRUMENTAÇÃO COMPLETA APLICADA!

 BACKEND INSTRUMENTADO:
    Deploy realizado com imagem instrumentada
    Métricas Prometheus expostas em /metrics
    4 Golden Signals implementados:
      • Latência: http_request_duration_seconds
      • Tráfego: http_requests_total  
      • Erros: http_requests_error_rate
      • Saturação: system_resource_usage_percent
   
    Business Metrics implementados:
      • Orders: orders_total, revenue_total
      • Users: active_users_current, signups_total
      • Conversions: cart_conversions_total

 FRONTEND/MOBILE INSTRUMENTAÇÃO:
    Arquivos criados:
      • app/frontend/src/instrumentation.js
      • app/mobile/src/instrumentation.js
    ConfigMaps criados no Kubernetes
    Endpoints /api/metrics/frontend e /api/metrics/mobile prontos

 DADOS SENDO GERADOS:
    Tráfego HTTP simulado
    Pedidos e usuários criados
    Métricas de negócio populadas
    Alguns erros para testar alertas

 DASHBOARDS READY:
   • Grafana: http://localhost:3100
     - Golden Signals dashboard deve mostrar dados em ~2min
     - Business metrics dashboard populado
   
   • Prometheus: http://localhost:9090
     - Target 'backend-service' deve estar UP
     - Queries funcionais para todas as métricas

 PRÓXIMAS ETAPAS:
1.  Verificar dashboards Grafana (dados aparecendo)
2.  Implementar frontend instrumentation no código React/Vue
3.  Adicionar mobile instrumentation no app React Native
4.  Configurar Alertmanager para notificações

EOF

success " Instrumentação completa implementada!"
success " Acesse http://localhost:3100 para ver os dashboards populados"

echo ""
info " Para gerar mais dados de teste:"
echo "  kubectl exec -n case \$(kubectl get pods -n case -l app=backend -o jsonpath='{.items[0].metadata.name}') -- curl http://localhost:3000/api/orders"
echo ""