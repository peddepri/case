#!/bin/bash
# Testes de Performance - Load Testing com Locust

set -e

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}ℹ  $1${NC}"; }
success() { echo -e "${GREEN} $1${NC}"; }
warn() { echo -e "${YELLOW}  $1${NC}"; }
fail() { echo -e "${RED} $1${NC}"; }

echo " INICIANDO TESTES DE PERFORMANCE"
echo "=================================="
echo ""

# Verificar se Locust está instalado
if ! python -c "import locust" >/dev/null 2>&1; then
    warn "Locust não encontrado. Instalando..."
    pip install locust
fi

# Configurar port-forwards
info "Configurando acessos..."
pkill -f "kubectl.*port-forward.*case" 2>/dev/null || true
sleep 2

kubectl port-forward -n case svc/backend 3002:3000 > /dev/null 2>&1 &
BACKEND_PF_PID=$!

cleanup() {
    info "Limpando recursos..."
    kill $BACKEND_PF_PID 2>/dev/null || true
    pkill -f "locust" 2>/dev/null || true
}
trap cleanup EXIT

sleep 3

# Criar arquivo de configuração do Locust
cat > scripts/locustfile-performance.py << 'EOF'
from locust import HttpUser, task, between
import json
import random

class OrderUser(HttpUser):
    wait_time = between(0.5, 2.0)  # Pausa entre requests
    
    def on_start(self):
        """Executado quando user inicia"""
        # Testar conectividade
        response = self.client.get("/healthz", catch_response=True)
        if response.status_code != 200:
            response.failure("Health check failed")
    
    @task(3)  # 60% dos requests
    def get_orders(self):
        """Buscar lista de orders"""
        with self.client.get("/api/orders", catch_response=True) as response:
            if response.status_code == 200:
                try:
                    data = response.json()
                    response.success()
                except json.JSONDecodeError:
                    response.failure("Invalid JSON response")
            else:
                response.failure(f"Got status {response.status_code}")
    
    @task(2)  # 40% dos requests  
    def create_order(self):
        """Criar nova order"""
        order_data = {
            "item": f"product-{random.randint(1, 1000)}",
            "price": round(random.uniform(10, 500), 2),
            "customer": f"user-{random.randint(1, 100)}"
        }
        
        with self.client.post("/api/orders", 
                             json=order_data, 
                             catch_response=True) as response:
            if response.status_code == 201:
                try:
                    data = response.json()
                    if "id" in data:
                        response.success()
                    else:
                        response.failure("No ID in response")
                except json.JSONDecodeError:
                    response.failure("Invalid JSON response")
            else:
                response.failure(f"Got status {response.status_code}")
    
    @task(1)  # 20% dos requests
    def health_check(self):
        """Health check"""
        with self.client.get("/healthz", catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Health check failed: {response.status_code}")

class StressUser(HttpUser):
    """User para testes de stress mais intensos"""
    wait_time = between(0.1, 0.5)  # Requests mais rápidos
    
    @task
    def rapid_requests(self):
        endpoints = ["/api/orders", "/healthz"]
        endpoint = random.choice(endpoints)
        
        with self.client.get(endpoint, catch_response=True) as response:
            if response.status_code in [200, 201]:
                response.success()
            else:
                response.failure(f"Got {response.status_code}")
EOF

echo ""
echo " FASE 1: TESTE DE CARGA MODERADO"
echo "=================================="

info "Executando: 10 usuários por 60 segundos..."
python -m locust -f scripts/locustfile-performance.py \
    --host=http://localhost:3002 \
    --users=10 \
    --spawn-rate=2 \
    --run-time=60s \
    --headless \
    --html=reports/performance-moderate.html \
    --csv=reports/performance-moderate

if [ $? -eq 0 ]; then
    success "Teste moderado concluído - relatório em reports/performance-moderate.html"
else
    fail "Teste moderado falhou"
fi

echo ""
echo " FASE 2: TESTE DE STRESS INTENSO"
echo "================================="

info "Executando: 50 usuários por 2 minutos..."
python -m locust -f scripts/locustfile-performance.py \
    --host=http://localhost:3002 \
    --users=50 \
    --spawn-rate=5 \
    --run-time=120s \
    --headless \
    --html=reports/performance-stress.html \
    --csv=reports/performance-stress

if [ $? -eq 0 ]; then
    success "Teste de stress concluído - relatório em reports/performance-stress.html"
else
    fail "Teste de stress falhou"
fi

echo ""
echo " FASE 3: TESTE DE PICO (SPIKE)"
echo "=============================="

info "Executando: 100 usuários por 30 segundos..."
python -m locust -f scripts/locustfile-performance.py \
    --host=http://localhost:3002 \
    --users=100 \
    --spawn-rate=20 \
    --run-time=30s \
    --headless \
    --html=reports/performance-spike.html \
    --csv=reports/performance-spike

if [ $? -eq 0 ]; then
    success "Teste de pico concluído - relatório em reports/performance-spike.html"
else
    fail "Teste de pico falhou"
fi

echo ""
echo " ANÁLISE DE MÉTRICAS"
echo "===================="

# Verificar métricas no Prometheus
info "Coletando métricas do Prometheus..."

METRICS_QUERIES=(
    "rate(http_requests_total[5m])"
    "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))"
    "up{job=\"kubernetes-pods\"}"
    "container_memory_usage_bytes{container=\"backend\"}"
)

for query in "${METRICS_QUERIES[@]}"; do
    result=$(curl -s "http://localhost:9090/api/v1/query?query=$(echo "$query" | sed 's/ /%20/g')" | jq -r '.data.result | length')
    if [ "$result" != "0" ] && [ "$result" != "null" ]; then
        success "Métrica encontrada: $query ($result pontos)"
    else
        warn "Métrica sem dados: $query"
    fi
done

echo ""
echo " RESUMO DOS TESTES"
echo "==================="

# Processar resultados dos CSVs se existirem
if [ -f "reports/performance-moderate_stats.csv" ]; then
    info " Resultado Teste Moderado:"
    tail -n 1 reports/performance-moderate_stats.csv | awk -F',' '
    {
        printf "   Requests: %s | Falhas: %s | Median: %s ms | P95: %s ms\n", 
        $3, $4, $6, $8
    }'
fi

if [ -f "reports/performance-stress_stats.csv" ]; then
    info " Resultado Teste Stress:"
    tail -n 1 reports/performance-stress_stats.csv | awk -F',' '
    {
        printf "   Requests: %s | Falhas: %s | Median: %s ms | P95: %s ms\n", 
        $3, $4, $6, $8
    }'
fi

if [ -f "reports/performance-spike_stats.csv" ]; then
    info " Resultado Teste Pico:"
    tail -n 1 reports/performance-spike_stats.csv | awk -F',' '
    {
        printf "   Requests: %s | Falhas: %s | Median: %s ms | P95: %s ms\n", 
        $3, $4, $6, $8
    }'
fi

success " TESTES DE PERFORMANCE CONCLUÍDOS!"
echo ""
echo " Relatórios disponíveis:"
echo "   • reports/performance-moderate.html"
echo "   • reports/performance-stress.html" 
echo "   • reports/performance-spike.html"
echo ""
echo " Para análise detalhada:"
echo "   • Abra os arquivos HTML em um navegador"
echo "   • Verifique métricas no Grafana: http://localhost:3100"
echo "   • Analise logs: kubectl logs -n case -l app=backend"