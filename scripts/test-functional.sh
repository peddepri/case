#!/bin/bash
# Testes Funcionais - APIs, Endpoints e Integração

set -e

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Contadores
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Funções de log
success() {
    echo -e "${GREEN} $1${NC}"
    ((PASSED_TESTS++))
}

fail() {
    echo -e "${RED} $1${NC}"
    ((FAILED_TESTS++))
}

info() {
    echo -e "${BLUE}ℹ  $1${NC}"
}

warn() {
    echo -e "${YELLOW}  $1${NC}"
}

test_start() {
    ((TOTAL_TESTS++))
    echo -e "${BLUE} Teste $TOTAL_TESTS: $1${NC}"
}

# Função para testar endpoint
test_endpoint() {
    local name="$1"
    local url="$2"
    local expected_code="${3:-200}"
    
    test_start "$name"
    
    local response_code=$(curl -s -w "%{http_code}" -o /dev/null "$url" || echo "000")
    
    if [ "$response_code" = "$expected_code" ]; then
        success "$name - Status: $response_code"
        return 0
    else
        fail "$name - Status: $response_code (esperado: $expected_code)"
        return 1
    fi
}

# Função para testar API com JSON
test_api_json() {
    local name="$1"
    local url="$2"
    local method="${3:-GET}"
    local data="${4:-}"
    local expected_field="${5:-}"
    
    test_start "$name"
    
    local response=""
    if [ "$method" = "POST" ] && [ -n "$data" ]; then
        response=$(curl -s -X POST "$url" \
            -H "Content-Type: application/json" \
            -d "$data" 2>/dev/null || echo "")
    else
        response=$(curl -s "$url" 2>/dev/null || echo "")
    fi
    
    if [ -n "$response" ] && echo "$response" | jq . >/dev/null 2>&1; then
        if [ -n "$expected_field" ]; then
            if echo "$response" | jq -r ".$expected_field" | grep -v "null" >/dev/null 2>&1; then
                success "$name - Campo '$expected_field' presente"
                echo "   Resposta: $(echo "$response" | jq -c .)"
                return 0
            else
                fail "$name - Campo '$expected_field' ausente"
                return 1
            fi
        else
            success "$name - JSON válido retornado"
            return 0
        fi
    else
        fail "$name - Resposta inválida ou vazia"
        return 1
    fi
}

echo " INICIANDO TESTES FUNCIONAIS"
echo "=============================="
echo ""

# Configurar port-forwards em background
info "Configurando acessos via port-forward..."
pkill -f "kubectl.*port-forward.*case" 2>/dev/null || true
sleep 2

kubectl port-forward -n case svc/backend 3002:3000 > /dev/null 2>&1 &
BACKEND_PF_PID=$!
kubectl port-forward -n case svc/frontend 8080:80 > /dev/null 2>&1 &
FRONTEND_PF_PID=$!
kubectl port-forward -n case svc/mobile 19006:19006 > /dev/null 2>&1 &
MOBILE_PF_PID=$!

# Cleanup ao sair
cleanup() {
    info "Limpando port-forwards..."
    kill $BACKEND_PF_PID $FRONTEND_PF_PID $MOBILE_PF_PID 2>/dev/null || true
}
trap cleanup EXIT

# Aguardar port-forwards ficarem ativos
info "Aguardando port-forwards..."
sleep 5

echo ""
echo " FASE 1: TESTES DE CONECTIVIDADE"
echo "=================================="

# LocalStack
test_endpoint "LocalStack Health" "http://localhost:4566/health"
test_endpoint "LocalStack Info" "http://localhost:4566/_localstack/info"

# Backend (Docker Compose)
test_endpoint "Backend LocalStack Health" "http://localhost:3001/healthz"
test_api_json "Backend LocalStack API" "http://localhost:3001/api/orders"

# Frontend (Docker Compose)
test_endpoint "Frontend LocalStack" "http://localhost:5174"

# Mobile (Docker Compose)  
test_endpoint "Mobile LocalStack" "http://localhost:19007"

# Kubernetes via port-forward
test_endpoint "Backend K8s Health" "http://localhost:3002/healthz"
test_api_json "Backend K8s API" "http://localhost:3002/api/orders"
test_endpoint "Frontend K8s" "http://localhost:8080"
test_endpoint "Mobile K8s" "http://localhost:19006"

echo ""
echo " FASE 2: TESTES DE API (CRUD)"
echo "=============================="

# Testar criação de orders
ORDER_DATA='{"item":"test-functional","price":99.99,"customer":"Test User"}'
test_api_json "Criar Order (LocalStack)" "http://localhost:3001/api/orders" "POST" "$ORDER_DATA" "id"
test_api_json "Criar Order (K8s)" "http://localhost:3002/api/orders" "POST" "$ORDER_DATA" "id"

# Testar listagem após criação
test_api_json "Listar Orders (LocalStack)" "http://localhost:3001/api/orders"
test_api_json "Listar Orders (K8s)" "http://localhost:3002/api/orders"

echo ""
echo " FASE 3: TESTES DE INTEGRAÇÃO"
echo "==============================="

# Testar DynamoDB via LocalStack
test_start "DynamoDB - Scan da tabela orders"
DYNAMO_RESULT=$(bash scripts/awslocal.sh dynamodb scan --table-name orders --max-items 5 2>/dev/null || echo "")
if echo "$DYNAMO_RESULT" | jq -r '.Items[]?' >/dev/null 2>&1; then
    success "DynamoDB - Dados encontrados na tabela"
    echo "   Items: $(echo "$DYNAMO_RESULT" | jq -r '.Count // 0')"
else
    fail "DynamoDB - Erro ao acessar tabela ou sem dados"
fi

echo ""
echo " FASE 4: TESTES DE OBSERVABILIDADE"
echo "==================================="

# Prometheus
test_endpoint "Prometheus Health" "http://localhost:9090/-/healthy"
test_api_json "Prometheus Targets" "http://localhost:9090/api/v1/targets"

# Grafana
test_endpoint "Grafana Health" "http://localhost:3100/api/health"
test_endpoint "Grafana Login" "http://localhost:3100/login"

# Testar métricas customizadas
test_start "Métricas customizadas no Prometheus"
METRICS_RESULT=$(curl -s "http://localhost:9090/api/v1/query?query=up" | jq -r '.data.result[] | .metric.job' 2>/dev/null | head -3)
if [ -n "$METRICS_RESULT" ]; then
    success "Métricas encontradas: $(echo "$METRICS_RESULT" | tr '\n' ', ' | sed 's/,$//')"
else
    fail "Nenhuma métrica encontrada"
fi

echo ""
echo " FASE 5: TESTES DE STRESS LEVE"
echo "==============================="

# Teste de múltiplas requisições
test_start "Stress leve - 10 requests simultâneos"
STRESS_RESULTS=()
for i in {1..10}; do
    curl -s -w "%{http_code}" -o /dev/null "http://localhost:3002/api/orders" &
    PIDS+=($!)
done

# Aguardar todos completarem
wait "${PIDS[@]}"
SUCCESS_COUNT=0
for pid in "${PIDS[@]}"; do
    wait $pid
    if [ $? -eq 0 ]; then
        ((SUCCESS_COUNT++))
    fi
done

if [ $SUCCESS_COUNT -ge 8 ]; then
    success "Stress leve - $SUCCESS_COUNT/10 requests bem sucedidos"
else
    fail "Stress leve - Apenas $SUCCESS_COUNT/10 requests bem sucedidos"
fi

echo ""
echo " RELATÓRIO FINAL"
echo "=================="
echo "Total de testes: $TOTAL_TESTS"
echo -e "Testes ${GREEN}aprovados${NC}: $PASSED_TESTS"
echo -e "Testes ${RED}falharam${NC}: $FAILED_TESTS"

SUCCESS_RATE=$(( PASSED_TESTS * 100 / TOTAL_TESTS ))
echo "Taxa de sucesso: $SUCCESS_RATE%"

if [ $SUCCESS_RATE -ge 80 ]; then
    echo -e "${GREEN}🎉 TESTES FUNCIONAIS APROVADOS!${NC}"
    exit 0
else
    echo -e "${RED} MUITOS TESTES FALHARAM!${NC}"
    exit 1
fi