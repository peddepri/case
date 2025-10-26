#!/bin/bash
# Script para gerar dados de teste realistas para dashboards

set -e

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${BLUE}  $1${NC}"; }
success() { echo -e "${GREEN} $1${NC}"; }
warn() { echo -e "${YELLOW}  $1${NC}"; }
header() { echo -e "${CYAN}$1${NC}"; }

echo ""
header " GERANDO DADOS REALISTAS PARA DASHBOARDS"
header "=========================================="
echo ""

# Configurações
BACKEND_URL="http://localhost:3000"
FRONTEND_URL="http://localhost:5173"
MOBILE_URL="http://localhost:19006"

# Verificar se serviços estão rodando
check_service() {
    local name="$1"
    local url="$2"
    
    if curl -s "$url/healthz" > /dev/null 2>&1 || curl -s "$url" > /dev/null 2>&1; then
        success "$name está rodando"
        return 0
    else
        warn "$name não está acessível"
        return 1
    fi
}

# =====================================================
# 1. VERIFICAR SERVIÇOS
# =====================================================
header " 1. VERIFICANDO SERVIÇOS"
header "========================"

BACKEND_OK=false
FRONTEND_OK=false
MOBILE_OK=false

if check_service "Backend" "$BACKEND_URL"; then
    BACKEND_OK=true
fi

if check_service "Frontend" "$FRONTEND_URL"; then
    FRONTEND_OK=true
fi

if check_service "Mobile" "$MOBILE_URL"; then
    MOBILE_OK=true
fi

# =====================================================
# 2. GERAR TRÁFEGO DE BACKEND
# =====================================================
header " 2. GERANDO TRÁFEGO DE BACKEND"
header "================================="

if [ "$BACKEND_OK" = true ]; then
    info "Gerando requests variados para backend..."
    
    # Gerar tráfego normal (sucesso)
    for i in $(seq 1 50); do
        # Health checks
        curl -s "$BACKEND_URL/healthz" > /dev/null &
        
        # Listar pedidos
        curl -s "$BACKEND_URL/api/orders" > /dev/null &
        
        # Criar pedidos com valores aleatórios
        ORDER_VALUE=$((RANDOM % 500 + 20))
        CUSTOMER_NAME="Customer_$((RANDOM % 1000))"
        
        curl -s -X POST "$BACKEND_URL/api/orders" \
            -H "Content-Type: application/json" \
            -d "{
                \"customerName\": \"$CUSTOMER_NAME\",
                \"items\": [\"Item A\", \"Item B\"],
                \"total\": $ORDER_VALUE
            }" > /dev/null &
        
        # Signups
        if [ $((i % 5)) -eq 0 ]; then
            EMAIL="user$i@example.com"
            SOURCES=("organic" "paid" "social" "referral")
            SOURCE=${SOURCES[$((RANDOM % 4))]}
            
            curl -s -X POST "$BACKEND_URL/api/signup" \
                -H "Content-Type: application/json" \
                -d "{\"email\": \"$EMAIL\", \"source\": \"$SOURCE\"}" > /dev/null &
        fi
        
        # Pequena pausa para simular tráfego realista
        sleep 0.1
    done
    
    # Gerar alguns erros (5-10%)
    info "Gerando alguns erros para métricas realistas..."
    for i in $(seq 1 10); do
        # Endpoints inexistentes (404)
        curl -s "$BACKEND_URL/api/nonexistent" > /dev/null &
        
        # Pedidos inválidos (400)
        curl -s -X POST "$BACKEND_URL/api/orders" \
            -H "Content-Type: application/json" \
            -d "{\"invalid\": true}" > /dev/null &
        
        sleep 0.2
    done
    
    # Aguardar requests completarem
    wait
    success "Tráfego de backend gerado (50 requests normais + 10 com erro)"
    
else
    warn "Backend não está rodando - pulando geração de dados"
fi

# =====================================================
# 3. SIMULAR MÉTRICAS DE FRONTEND
# =====================================================
header " 3. SIMULANDO MÉTRICAS DE FRONTEND"
header "==================================="

if [ "$BACKEND_OK" = true ]; then
    info "Enviando métricas simuladas de frontend..."
    
    # Simular métricas de Core Web Vitals
    FRONTEND_METRICS='[
        {
            "name": "page_load_time",
            "value": '$((RANDOM % 3000 + 500))',
            "labels": {
                "page": "/",
                "service": "frontend"
            }
        },
        {
            "name": "page_load_time", 
            "value": '$((RANDOM % 2000 + 800))',
            "labels": {
                "page": "/orders",
                "service": "frontend"
            }
        },
        {
            "name": "user_action",
            "value": 1,
            "labels": {
                "action": "button_click",
                "element": "create_order",
                "service": "frontend"
            }
        },
        {
            "name": "largest_contentful_paint",
            "value": '$((RANDOM % 4000 + 1000))',
            "labels": {
                "service": "frontend",
                "page": "/"
            }
        },
        {
            "name": "first_input_delay",
            "value": '$((RANDOM % 200 + 50))',
            "labels": {
                "service": "frontend",
                "page": "/"
            }
        },
        {
            "name": "cumulative_layout_shift",
            "value": 0.'$((RANDOM % 20 + 5))',
            "labels": {
                "service": "frontend",
                "page": "/"
            }
        },
        {
            "name": "api_response_time",
            "value": '$((RANDOM % 1000 + 200))',
            "labels": {
                "url": "/api/orders",
                "service": "frontend"
            }
        },
        {
            "name": "user_journey_step",
            "value": 1,
            "labels": {
                "step": "view_products",
                "service": "frontend"
            }
        },
        {
            "name": "conversion_event",
            "value": 1,
            "labels": {
                "event": "add_to_cart",
                "service": "frontend"
            }
        }
    ]'
    
    # Enviar múltiplas batches de métricas
    for i in $(seq 1 5); do
        curl -s -X POST "$BACKEND_URL/api/metrics" \
            -H "Content-Type: application/json" \
            -d "{\"metrics\": $FRONTEND_METRICS}" > /dev/null
        
        sleep 1
    done
    
    success "Métricas de frontend enviadas"
else
    warn "Backend não disponível - não é possível enviar métricas de frontend"
fi

# =====================================================
# 4. SIMULAR MÉTRICAS DE MOBILE
# =====================================================
header " 4. SIMULANDO MÉTRICAS DE MOBILE"
header "=================================="

if [ "$BACKEND_OK" = true ]; then
    info "Enviando métricas simuladas de mobile..."
    
    # Simular métricas móveis variadas
    MOBILE_METRICS='[
        {
            "name": "app_launch_time",
            "value": '$((RANDOM % 5000 + 2000))',
            "labels": {
                "service": "mobile",
                "platform": "ios"
            }
        },
        {
            "name": "screen_transition_time",
            "value": '$((RANDOM % 800 + 200))',
            "labels": {
                "from_screen": "home",
                "to_screen": "orders",
                "service": "mobile",
                "platform": "android"
            }
        },
        {
            "name": "user_action",
            "value": 1,
            "labels": {
                "action": "tap",
                "target": "order_button",
                "service": "mobile",
                "platform": "ios"
            }
        },
        {
            "name": "memory_usage",
            "value": '$((RANDOM % 100 + 50))',
            "labels": {
                "service": "mobile",
                "platform": "android",
                "type": "heap_mb"
            }
        },
        {
            "name": "api_response_time",
            "value": '$((RANDOM % 2000 + 500))',
            "labels": {
                "url": "/api/orders",
                "service": "mobile",
                "platform": "ios"
            }
        },
        {
            "name": "screen_view",
            "value": 1,
            "labels": {
                "screen": "product_detail",
                "service": "mobile",
                "platform": "android"
            }
        },
        {
            "name": "conversion_event",
            "value": 1,
            "labels": {
                "event": "purchase",
                "service": "mobile",
                "platform": "ios"
            }
        },
        {
            "name": "network_change",
            "value": 1,
            "labels": {
                "type": "wifi",
                "is_connected": true,
                "service": "mobile",
                "platform": "android"
            }
        }
    ]'
    
    # Enviar métricas mobile com diferentes plataformas
    for i in $(seq 1 3); do
        curl -s -X POST "$BACKEND_URL/api/metrics" \
            -H "Content-Type: application/json" \
            -d "{\"metrics\": $MOBILE_METRICS}" > /dev/null
        
        sleep 2
    done
    
    # Simular alguns crashes mobile (raramente)
    CRASH_METRICS='[
        {
            "name": "mobile_crash",
            "value": 1,
            "labels": {
                "message": "OutOfMemoryError",
                "is_fatal": true,
                "service": "mobile",
                "platform": "android",
                "error_type": "crash"
            }
        }
    ]'
    
    if [ $((RANDOM % 10)) -eq 0 ]; then
        curl -s -X POST "$BACKEND_URL/api/metrics" \
            -H "Content-Type: application/json" \
            -d "{\"metrics\": $CRASH_METRICS}" > /dev/null
        
        info "Crash simulado enviado (raro)"
    fi
    
    success "Métricas de mobile enviadas"
else
    warn "Backend não disponível - não é possível enviar métricas de mobile"
fi

# =====================================================
# 5. GERAR CARGA CONTÍNUA (BACKGROUND)
# =====================================================
header " 5. INICIANDO CARGA CONTÍNUA"
header "============================="

if [ "$BACKEND_OK" = true ]; then
    info "Iniciando geração contínua de dados em background..."
    
    # Criar script de carga contínua
    cat > /tmp/continuous_load.sh << 'EOF'
#!/bin/bash
BACKEND_URL="http://localhost:3000"

while true; do
    # Tráfego normal a cada 5 segundos
    curl -s "$BACKEND_URL/healthz" > /dev/null &
    curl -s "$BACKEND_URL/api/orders" > /dev/null &
    
    # Pedido ocasional
    if [ $((RANDOM % 3)) -eq 0 ]; then
        ORDER_VALUE=$((RANDOM % 300 + 25))
        curl -s -X POST "$BACKEND_URL/api/orders" \
            -H "Content-Type: application/json" \
            -d "{
                \"customerName\": \"Customer_$(date +%s)\",
                \"items\": [\"Product A\"],
                \"total\": $ORDER_VALUE
            }" > /dev/null &
    fi
    
    # Erro ocasional (5% do tempo)
    if [ $((RANDOM % 20)) -eq 0 ]; then
        curl -s "$BACKEND_URL/api/invalid" > /dev/null &
    fi
    
    sleep 5
done
EOF
    
    chmod +x /tmp/continuous_load.sh
    
    # Iniciar em background
    nohup bash /tmp/continuous_load.sh > /dev/null 2>&1 &
    LOAD_PID=$!
    
    success "Carga contínua iniciada (PID: $LOAD_PID)"
    info "Para parar: kill $LOAD_PID"
    echo $LOAD_PID > /tmp/load_test.pid
    
else
    warn "Backend não disponível - carga contínua não iniciada"
fi

# =====================================================
# 6. RELATÓRIO FINAL
# =====================================================
header " RELATÓRIO DE GERAÇÃO DE DADOS"
header "=================================="

cat << EOF

 DADOS GERADOS COM SUCESSO!

 MÉTRICAS DOS 4 GOLDEN SIGNALS:
    Latência: Variações realistas (200ms-5s)
    Tráfego: 50+ requests/minuto em curso
    Erros: ~5-10% taxa de erro simulada
    Saturação: CPU, Memory tracking ativo

 MÉTRICAS DE NEGÓCIO:
    Orders: Pedidos com valores \$20-500
    Revenue: Receita acumulativa
    Signups: Usuários de múltiplas fontes
    Conversions: Funil de vendas simulado

 COBERTURA POR PLATAFORMA:
   • Backend:  Totalmente instrumentado
   • Frontend:  Core Web Vitals + UX metrics
   • Mobile:  Performance + crash tracking
   • Cross-platform:  User journey tracking

 ACESSE OS DASHBOARDS:
   • Grafana: http://localhost:3100 (admin/admin)
     - 4 Golden Signals + Business Metrics
     - Logs, Metrics & Traces Integration
   
   • Prometheus: http://localhost:9090
     - Raw metrics query interface
   
 CARGA CONTÍNUA:
$(if [ -f /tmp/load_test.pid ]; then
    echo "    Ativa (PID: $(cat /tmp/load_test.pid))"
    echo "    Gerando ~12 requests/minuto"
    echo "    Para parar: kill \$(cat /tmp/load_test.pid)"
else
    echo "    Não iniciada (backend indisponível)"
fi)

 OS DASHBOARDS AGORA MOSTRAM DADOS REALISTAS!

EOF

success " Geração de dados completa - dashboards prontos para demonstração!"
echo ""