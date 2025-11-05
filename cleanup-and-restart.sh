#!/bin/bash
# Script para limpar e reiniciar ambiente completamente
# Uso: ./cleanup-and-restart.sh

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}ℹ  $1${NC}"; }
success() { echo -e "${GREEN} $1${NC}"; }
warn() { echo -e "${YELLOW}  $1${NC}"; }

echo ""
echo "=========================================="
echo "  LIMPEZA COMPLETA DO AMBIENTE"  
echo "=========================================="
echo ""

# 1. Parar port-forwards
info "Parando port-forwards..."
pkill -f "port-forward" 2>/dev/null || true
pkill -f "kubectl.*port-forward" 2>/dev/null || true

# 2. Deletar cluster Kind
info "Deletando cluster Kind..."
kind delete cluster --name case-local 2>/dev/null || true

# 3. Parar containers Docker
info "Parando stack de observabilidade..."
docker compose -f docker-compose.observability.yml down -v 2>/dev/null || true

# 4. Remover containers órfãos
info "Limpando containers órfãos..."
docker rm -f registry 2>/dev/null || true

# 5. Limpar imagens antigas (opcional)
warn "Removendo imagens antigas do projeto..."
docker rmi case-backend:latest case-frontend:latest case-mobile:latest 2>/dev/null || true

success "Limpeza completa!"
echo ""
echo "🚀 Agora execute: ./setup-demo-environment.sh"
echo ""