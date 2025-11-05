#!/bin/bash
# Script para gerar tráfego contínuo durante a demo
# Uso: ./generate-demo-traffic.sh [duração_em_minutos]

DURATION=${1:-10}  # Default 10 minutos
END_TIME=$(($(date +%s) + $DURATION * 60))

echo " Gerando tráfego de demo por $DURATION minutos..."
echo "  Pressione Ctrl+C para parar"

cleanup() {
    echo -e "\n Parando geração de tráfego..."
    exit 0
}

trap cleanup INT TERM

# Função para requisições do backend
backend_requests() {
    while [ $(date +%s) -lt $END_TIME ]; do
        # Requisições normais
        curl -s http://localhost:3002/ > /dev/null 2>&1
        curl -s http://localhost:3002/healthz > /dev/null 2>&1
        
        # Requisições de API
        curl -s http://localhost:3002/api/orders > /dev/null 2>&1
        
        # Criar alguns pedidos
        if [ $((RANDOM % 10)) -eq 0 ]; then
            curl -s -X POST http://localhost:3002/api/orders \
                -H "Content-Type: application/json" \
                -d '{"item":"demo-item","price":'"$((RANDOM % 100))"'}' > /dev/null 2>&1
        fi
        
        # Simular alguns erros ocasionais  
        if [ $((RANDOM % 20)) -eq 0 ]; then
            curl -s http://localhost:3002/nonexistent > /dev/null 2>&1
        fi
        
        sleep 1
    done
}

# Função para requisições do frontend
frontend_requests() {
    while [ $(date +%s) -lt $END_TIME ]; do
        curl -s http://localhost:3003/ > /dev/null 2>&1
        
        # Simular navegação
        if [ $((RANDOM % 5)) -eq 0 ]; then
            curl -s http://localhost:3003/metrics > /dev/null 2>&1
        fi
        
        sleep 3
    done
}

# Função para requisições do mobile
mobile_requests() {
    while [ $(date +%s) -lt $END_TIME ]; do
        curl -s http://localhost:3004/ > /dev/null 2>&1
        sleep 5
    done
}

# Status monitor
status_monitor() {
    local request_count=0
    while [ $(date +%s) -lt $END_TIME ]; do
        request_count=$((request_count + 1))
        if [ $((request_count % 10)) -eq 0 ]; then
            remaining=$(( (END_TIME - $(date +%s)) / 60 ))
            echo " Requests enviados: ~$((request_count * 3)) | Tempo restante: ${remaining}min"
            
            # Mostrar métricas básicas
            if command -v jq >/dev/null 2>&1; then
                targets_up=$(curl -s http://localhost:9090/api/v1/targets 2>/dev/null | jq -r '.data.activeTargets[] | select(.health=="up") | .scrapePool' 2>/dev/null | wc -l)
                echo "    Targets UP no Prometheus: $targets_up"
            fi
        fi
        sleep 1
    done
}

echo " Iniciando geração de tráfego de demo..."

# Executar em paralelo
backend_requests &
BACKEND_PID=$!

frontend_requests &  
FRONTEND_PID=$!

mobile_requests &
MOBILE_PID=$!

status_monitor &
STATUS_PID=$!

# Aguardar término ou interrupção
wait $STATUS_PID

# Limpar processos
kill $BACKEND_PID $FRONTEND_PID $MOBILE_PID 2>/dev/null || true

echo " Tráfego de demo concluído!"
echo " Verifique os dashboards em: http://localhost:3100"