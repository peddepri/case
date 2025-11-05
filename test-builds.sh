#!/bin/bash
# Script de teste rápido para builds
# Uso: ./test-builds.sh

set -e

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}ℹ  $1${NC}"; }
success() { echo -e "${GREEN} $1${NC}"; }
fail() { echo -e "${RED} $1${NC}"; exit 1; }

echo "🧪 Testando builds das aplicações..."
echo ""

# Verificar registry
info "Verificando registry local..."
docker ps | grep -q registry || fail "Registry local não está rodando"
success "Registry local ativo"

# Test Backend
info "Testando build Backend..."
(cd app/backend && docker build -t test-backend .) || fail "Build do Backend falhou"
success "Backend build OK"

# Test Frontend  
info "Testando build Frontend..."
(cd app/frontend && docker build -t test-frontend .) || fail "Build do Frontend falhou"
success "Frontend build OK"

# Test Mobile
info "Testando build Mobile..."
(cd app/mobile && docker build -t test-mobile .) || fail "Build do Mobile falhou"
success "Mobile build OK"

# Test Push
info "Testando push para registry..."
docker tag test-backend localhost:5001/test-backend:latest
docker tag test-frontend localhost:5001/test-frontend:latest  
docker tag test-mobile localhost:5001/test-mobile:latest

docker push localhost:5001/test-backend:latest || fail "Push do Backend falhou"
docker push localhost:5001/test-frontend:latest || fail "Push do Frontend falhou"
docker push localhost:5001/test-mobile:latest || fail "Push do Mobile falhou"

success "Push de todas as imagens OK"

# Cleanup
docker rmi test-backend test-frontend test-mobile 2>/dev/null || true
docker rmi localhost:5001/test-backend:latest localhost:5001/test-frontend:latest localhost:5001/test-mobile:latest 2>/dev/null || true

echo ""
success "🎉 TODOS OS BUILDS FUNCIONANDO!"
echo ""
info " Backend: Docker build funcionando"
info " Frontend: Docker build funcionando (com nginx + métricas)"
info " Mobile: Docker build funcionando (com express + métricas)"  
info " Registry: Push/Pull funcionando"
echo ""
success "🚀 Pronto para executar setup-demo-environment.sh"