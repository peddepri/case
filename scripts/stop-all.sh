#!/bin/bash
# Script para parar todos os serviços do ambiente
# Autor: Kiro  Assistant
# Data: 2025-10-25

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

cd "$(dirname "$0")/.."

echo ""
echo "🛑 PARANDO TODOS OS SERVIÇOS"
echo "============================"
echo ""

# Parar LocalStack
log "Parando LocalStack e aplicações..."
docker compose -f docker-compose.localstack.yml down

# Parar Observabilidade
log "Parando stack de observabilidade..."
docker compose -f docker-compose.observability.yml down

# Parar aplicações locais (se estiverem rodando)
log "Parando aplicações locais..."
docker compose down 2>/dev/null || true

# Parar cluster kind (se existir)
CLUSTER_NAME="case-local"
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    log "Deletando cluster kind..."
    kind delete cluster --name "$CLUSTER_NAME"
fi

echo ""
read -p "🗑  Deseja remover dados persistentes? (s/N): " REMOVE_DATA

if [[ "$REMOVE_DATA" =~ ^[Ss]$ ]]; then
    log "Removendo dados persistentes..."
    
    # LocalStack data
    rm -rf localstack-data
    rm -rf localstack-kubeconfig
    
    # Docker volumes da observabilidade
    docker volume rm case_prometheus-data 2>/dev/null || true
    docker volume rm case_grafana-data 2>/dev/null || true
    docker volume rm case_loki-data 2>/dev/null || true
    docker volume rm case_tempo-data 2>/dev/null || true
    
    # Outros volumes
    docker volume prune -f
    
    log "Dados removidos!"
else
    warn "Dados preservados"
fi

# Limpar containers órfãos
log "Limpando containers órfãos..."
docker container prune -f >/dev/null 2>&1 || true

# Limpar imagens não utilizadas (opcional)
read -p "🧹 Deseja limpar imagens Docker não utilizadas? (s/N): " CLEAN_IMAGES
if [[ "$CLEAN_IMAGES" =~ ^[Ss]$ ]]; then
    log "Limpando imagens não utilizadas..."
    docker image prune -f
fi

echo ""
echo " TODOS OS SERVIÇOS PARADOS"
echo ""
echo "Para reiniciar:"
echo "   bash scripts/start-localstack-pro-full.sh    # Ambiente completo"
echo "   bash scripts/start-localstack-pro-simple.sh  # Ambiente simplificado"
echo ""