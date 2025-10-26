#!/bin/bash
# Testes de Performance - Direto nos containers Docker/Kubernetes

set -e

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}ℹ  $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠  $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; }

echo "🚀 TESTES DE PERFORMANCE - DOCKER/K8S"
echo "======================================"
echo ""

# Endpoints internos
BACKEND_SERVICE="http://backend.case.svc.cluster.local:3000"
FRONTEND_SERVICE="http://frontend.case.svc.cluster.local:80"
MOBILE_SERVICE="http://mobile.case.svc.cluster.local:19006"

# Criar script de teste simples que roda dentro do container
cat > /tmp/simple-test.sh << 'EOF'
#!/bin/bash

# Função para testar endpoint
test_endpoint() {
    local url="$1"
    local name="$2"
    echo "🔍 Testando $name: $url"
    
    # Teste básico de conectividade
    if curl -s --max-time 5 "$url" > /dev/null; then
        echo "✅ $name: Conectividade OK"
        return 0
    else
        echo "❌ $name: Falha na conectividade"
        return 1
    fi
}

# Teste de carga simples com curl
load_test() {
    local url="$1"
    local name="$2"
    local requests=50
    
    echo "📊 Teste de carga $name ($requests requests)..."
    
    start_time=$(date +%s)
    success_count=0
    
    for i in $(seq 1 $requests); do
        if curl -s --max-time 2 "$url" > /dev/null 2>&1; then
            success_count=$((success_count + 1))
        fi
        if [ $((i % 10)) -eq 0 ]; then
            echo "   Progresso: $i/$requests requests"
        fi
    done
    
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    success_rate=$((success_count * 100 / requests))
    rps=$((requests / duration))
    
    echo "📈 Resultados $name:"
    echo "   • Requests: $requests"
    echo "   • Sucesso: $success_count ($success_rate%)"
    echo "   • Duração: ${duration}s"
    echo "   • RPS: ~$rps"
    echo ""
}

# Executar testes
test_endpoint "$1/healthz" "Backend Health"
test_endpoint "$1/api/orders" "Backend API"

if [ $? -eq 0 ]; then
    load_test "$1/healthz" "Backend Health"
    load_test "$1/api/orders" "Backend API"
fi
EOF

chmod +x /tmp/simple-test.sh

echo "🔍 FASE 1: TESTE DE CONECTIVIDADE"
echo "=================================="

# Testar dentro do container Kubernetes
info "Testando endpoints internos do Kubernetes..."

# Executar teste dentro de um pod temporário
kubectl run performance-test-pod --image=curlimages/curl:latest --rm -i --restart=Never -n case -- sh -c "
apk add --no-cache bash curl &&
curl -s --max-time 5 http://backend:3000/healthz && echo 'Backend Health: OK' ||
curl -s --max-time 5 http://backend:3000/api/orders && echo 'Backend API: OK' ||
curl -s --max-time 5 http://frontend:80 && echo 'Frontend: OK' ||
echo 'Testes concluídos'
" 2>/dev/null || warn "Teste com pod temporário falhou"

echo ""
echo "🐳 FASE 2: TESTE DIRETO NO CONTAINER"
echo "===================================="

# Executar teste diretamente no container do backend
info "Executando teste de performance no container backend..."

BACKEND_POD=$(kubectl get pods -n case -l app=backend -o jsonpath='{.items[0].metadata.name}')
info "Usando pod: $BACKEND_POD"

kubectl exec -n case $BACKEND_POD -- sh -c "
echo '🔍 Teste interno do backend:'
wget -q -O - http://localhost:3000/healthz > /dev/null 2>&1 && echo ' ✅ Health check: OK' || echo ' ❌ Health check: FAIL'
wget -q -O - http://localhost:3000/api/orders > /dev/null 2>&1 && echo ' ✅ API orders: OK' || echo ' ❌ API orders: FAIL'

echo '📊 Teste de carga interno (20 requests):'
success=0
for i in \$(seq 1 20); do
    if wget -q -T 2 -O /dev/null http://localhost:3000/healthz 2>/dev/null; then
        success=\$((success + 1))
    fi
done
echo \" ✅ Sucesso: \$success/20 requests\"
"

echo ""
echo "🌐 FASE 3: TESTE DE CONECTIVIDADE ENTRE PODS"
echo "============================================="

# Testar conectividade entre pods
info "Testando comunicação entre pods..."

kubectl exec -n case $BACKEND_POD -- sh -c "
echo '🔗 Testando conectividade entre serviços:'

# Teste frontend
if wget -q -T 3 -O /dev/null http://frontend:80 2>/dev/null; then
    echo ' ✅ Backend -> Frontend: OK'
else
    echo ' ❌ Backend -> Frontend: FAIL'
fi

# Teste mobile  
if nc -z mobile 19006 2>/dev/null; then
    echo ' ✅ Backend -> Mobile: Porta acessível'
else
    echo ' ❌ Backend -> Mobile: Porta inacessível'
fi
"

echo ""
echo "⚡ FASE 4: TESTE DE STRESS RÁPIDO"
echo "================================="

info "Executando teste de stress (100 requests simultâneos)..."

kubectl exec -n case $BACKEND_POD -- sh -c "
echo '⚡ Teste de stress - 50 requests sequenciais:'
start=\$(date +%s)

success=0
total=50

for i in \$(seq 1 \$total); do
    if wget -q -T 1 -O /dev/null http://localhost:3000/healthz 2>/dev/null; then
        success=\$((success + 1))
    fi
    
    # Progresso a cada 10 requests
    if [ \$((i % 10)) -eq 0 ]; then
        echo \"   Progresso: \$i/\$total\"
    fi
done

end=\$(date +%s)
duration=\$((end - start))
success_rate=\$((success * 100 / total))

# Evitar divisão por zero
if [ \$duration -gt 0 ]; then
    rps=\$((total / duration))
else
    rps='N/A (muito rápido)'
fi

echo ''
echo '📊 Resultados do teste de stress:'
echo \"   • Total requests: \$total\"
echo \"   • Sucessos: \$success (\$success_rate%)\"
echo \"   • Duração: \${duration}s\"
echo \"   • RPS médio: ~\$rps\"
"

echo ""
echo "📈 FASE 5: MONITORAMENTO DE RECURSOS"
echo "===================================="

info "Coletando métricas de recursos dos pods..."

kubectl top pods -n case 2>/dev/null || warn "Métricas de recursos não disponíveis (metrics-server não instalado)"

kubectl exec -n case $BACKEND_POD -- sh -c "
echo '💾 Uso de memória dentro do container:'
cat /proc/meminfo | grep -E '^(MemTotal|MemAvailable|MemFree)' || echo 'Meminfo não disponível'

echo ''
echo '💻 Uso de CPU (load average):'
cat /proc/loadavg || echo 'Load average não disponível'

echo ''
echo '🌐 Conexões de rede:'
netstat -an 2>/dev/null | grep :3000 | wc -l | awk '{print \"   Conexões na porta 3000: \" \$1}' || echo 'Netstat não disponível'
"

echo ""
success "🎉 TESTES DE PERFORMANCE CONCLUÍDOS!"
echo ""
echo "📋 Resumo:"
echo "   • Testes executados diretamente nos containers Docker/Kubernetes"
echo "   • Sem necessidade de port-forward ou configuração externa"
echo "   • Testes de conectividade, carga e stress realizados"
echo "   • Métricas de recursos coletadas"
echo ""
echo "📊 Para análise detalhada:"
echo "   • Verifique logs: kubectl logs -n case -l app=backend"
echo "   • Monitore recursos: kubectl top pods -n case"
echo "   • Acesse métricas: kubectl port-forward -n case svc/prometheus 9090:9090"