#!/bin/bash
# Script de validação completa do ambiente
# Autor: Kiro  Assistant
# Data: 2025-10-25

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Contadores
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Função para testes
test_endpoint() {
    local name="$1"
    local url="$2"
    local expected_code="${3:-200}"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if curl -sf -o /dev/null -w "%{http_code}" "$url" | grep -q "$expected_code"; then
        echo -e "   $name: ${GREEN}OK${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "   $name: ${RED}FALHA${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_command() {
    local name="$1"
    local command="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if eval "$command" >/dev/null 2>&1; then
        echo -e "   $name: ${GREEN}OK${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "   $name: ${RED}FALHA${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

cd "$(dirname "$0")/.."

echo ""
echo "🔍 VALIDAÇÃO COMPLETA DO AMBIENTE"
echo "================================="
echo ""

# 1. LocalStack
echo -e "${BLUE}1. LocalStack${NC}"
test_endpoint "Gateway" "http://localhost:4566/_localstack/health"
test_command "DynamoDB" "bash scripts/awslocal.sh dynamodb list-tables"
test_command "ECR" "bash scripts/awslocal.sh ecr describe-repositories"
test_command "IAM" "bash scripts/awslocal.sh iam list-roles"

# 2. Aplicações LocalStack
echo ""
echo -e "${BLUE}2. Aplicações LocalStack${NC}"
test_endpoint "Backend Health" "http://localhost:3001/healthz"
test_endpoint "Backend API" "http://localhost:3001/api/orders"
test_endpoint "Frontend" "http://localhost:5174"

# 3. Observabilidade
echo ""
echo -e "${BLUE}3. Observabilidade${NC}"
test_endpoint "Prometheus" "http://localhost:9090/-/healthy"
test_endpoint "Grafana" "http://localhost:3100/api/health"
test_endpoint "Loki" "http://localhost:3101/ready"
test_endpoint "Tempo" "http://localhost:3102/ready"

# 4. Kubernetes (se disponível)
echo ""
echo -e "${BLUE}4. Kubernetes${NC}"
if kind get clusters 2>/dev/null | grep -q "case-local"; then
    test_command "Cluster" "kubectl get nodes"
    test_command "Namespace" "kubectl get ns case"
    test_command "Pods" "kubectl get pods -n case"
    
    # Testar ingress se disponível
    if kubectl get ingress -n case >/dev/null 2>&1; then
        test_endpoint "Ingress Frontend" "http://localhost:8080"
        test_endpoint "Ingress API" "http://localhost:8080/api/orders"
    fi
else
    echo -e "    Cluster kind não encontrado: ${YELLOW}SKIP${NC}"
fi

# 5. Testes Funcionais
echo ""
echo -e "${BLUE}5. Testes Funcionais${NC}"

# Criar order
ORDER_DATA='{"item":"validation-test","price":999}'
ORDER_RESULT=$(curl -sf -X POST http://localhost:3001/api/orders \
    -H "Content-Type: application/json" \
    -d "$ORDER_DATA" 2>/dev/null || echo "")

TESTS_TOTAL=$((TESTS_TOTAL + 1))
if [ -n "$ORDER_RESULT" ] && echo "$ORDER_RESULT" | grep -q "id"; then
    echo -e "   Criar Order: ${GREEN}OK${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    
    # Extrair ID da order
    ORDER_ID=$(echo "$ORDER_RESULT" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
    
    # Verificar no DynamoDB
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    if bash scripts/awslocal.sh dynamodb get-item \
        --table-name orders \
        --key "{\"id\":{\"S\":\"$ORDER_ID\"}}" >/dev/null 2>&1; then
        echo -e "   Verificar DynamoDB: ${GREEN}OK${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "   Verificar DynamoDB: ${RED}FALHA${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    echo -e "   Criar Order: ${RED}FALHA${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Testar métricas
TESTS_TOTAL=$((TESTS_TOTAL + 1))
if curl -sf http://localhost:3001/metrics | grep -q "orders_created_total"; then
    echo -e "   Métricas Prometheus: ${GREEN}OK${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "   Métricas Prometheus: ${RED}FALHA${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# 6. Performance básica
echo ""
echo -e "${BLUE}6. Performance${NC}"

# Teste de latência
TESTS_TOTAL=$((TESTS_TOTAL + 1))
LATENCY=$(curl -sf -o /dev/null -w "%{time_total}" http://localhost:3001/healthz 2>/dev/null || echo "999")
if (( $(echo "$LATENCY < 1.0" | bc -l) )); then
    echo -e "   Latência Backend (<1s): ${GREEN}${LATENCY}s${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "   Latência Backend (>1s): ${RED}${LATENCY}s${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Teste de carga básica
echo ""
echo -e "${BLUE}7. Teste de Carga Básica${NC}"
echo "  Executando 10 requests..."

TESTS_TOTAL=$((TESTS_TOTAL + 1))
SUCCESS_COUNT=0
for i in {1..10}; do
    if curl -sf http://localhost:3001/api/orders >/dev/null 2>&1; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    fi
done

if [ $SUCCESS_COUNT -eq 10 ]; then
    echo -e "   Carga Básica (10/10): ${GREEN}OK${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "   Carga Básica ($SUCCESS_COUNT/10): ${RED}FALHA${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Resumo
echo ""
echo " RESUMO DA VALIDAÇÃO"
echo "====================="
echo ""
echo -e "Total de testes: ${BLUE}$TESTS_TOTAL${NC}"
echo -e "Sucessos: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Falhas: ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo ""
    echo -e " ${GREEN}TODOS OS TESTES PASSARAM!${NC}"
    echo ""
    echo " Ambiente está funcionando perfeitamente"
    echo ""
    echo " Próximos passos:"
    echo "   • Acessar Grafana: http://localhost:3100 (admin/admin)"
    echo "   • Ver dashboards de observabilidade"
    echo "   • Executar testes de carga: bash scripts/load-test.sh"
    echo "   • Deploy em produção: bash scripts/up.sh eks"
    
    exit 0
else
    echo ""
    echo -e "  ${YELLOW}ALGUNS TESTES FALHARAM${NC}"
    echo ""
    echo "🔧 Troubleshooting:"
    echo "   • Verificar logs: docker compose -f docker-compose.localstack.yml logs"
    echo "   • Reiniciar serviços: bash scripts/stop-all.sh && bash scripts/start-localstack-pro-full.sh"
    echo "   • Verificar recursos: docker stats"
    
    exit 1
fi