#!/bin/bash
# Script completo para subir ambiente local para demo - VERSÃO CORRIGIDA
# Uso: ./setup-demo-environment-fixed.sh

set -e

# Cores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

info() { echo -e "${BLUE}  $1${NC}"; }
success() { echo -e "${GREEN} $1${NC}"; }
warn() { echo -e "${YELLOW}  $1${NC}"; }
fail() { echo -e "${RED} $1${NC}"; exit 1; }
step() { echo -e "${PURPLE}🔧 $1${NC}"; }

echo ""
echo " =========================================="
echo "  SETUP AMBIENTE DEMO - OBSERVABILIDADE"
echo " =========================================="
echo ""

# Verificar pré-requisitos
step "Verificando pré-requisitos..."
command -v docker >/dev/null 2>&1 || fail "Docker não encontrado"
command -v kind >/dev/null 2>&1 || fail "Kind não encontrado" 
command -v kubectl >/dev/null 2>&1 || fail "kubectl não encontrado"
command -v node >/dev/null 2>&1 || fail "Node.js não encontrado"
success "Pré-requisitos OK"

# 1. Limpar ambiente anterior
step "1. Limpando ambiente anterior..."
kind delete cluster --name case-local 2>/dev/null || true
docker compose -f docker-compose.observability.yml down -v 2>/dev/null || true
pkill -f "port-forward" 2>/dev/null || true
docker rm -f registry 2>/dev/null || true
success "Ambiente limpo"

# 2. Criar cluster Kind
step "2. Criando cluster Kubernetes..."
if kind create cluster --name case-local --config kind-config.yaml; then
    success "Cluster Kind criado"
else
    fail "Erro ao criar cluster Kind"
fi

# Aguardar cluster estar pronto
sleep 10
kubectl cluster-info --context kind-case-local

# 3. Subir observabilidade
step "3. Iniciando stack de observabilidade..."
docker compose -f docker-compose.observability.yml up -d

info "Aguardando serviços ficarem prontos (45s)..."
sleep 45

# Verificar serviços
docker ps | grep -E "(prometheus|grafana|loki|tempo)" || fail "Serviços de observabilidade não subiram"
success "Stack de observabilidade ativa"

# 4. Preparar aplicações
step "4. Preparando aplicações para build..."
info "Instalando dependências do frontend..."
(cd app/frontend && npm install --silent 2>/dev/null || true)
(cd app/frontend && npm run build --silent 2>/dev/null || true)

success "Aplicações preparadas para build"

# 5. Build das imagens
step "5. Fazendo build das imagens..."

info "Building backend..."
docker build -t case-backend:latest app/backend || fail "Erro no build do backend"

info "Building frontend..."
docker build -t case-frontend:latest app/frontend || fail "Erro no build do frontend"

info "Building mobile..."
docker build -t case-mobile:latest app/mobile || fail "Erro no build do mobile"

success "Imagens construídas"

# 6. Carregar imagens no Kind
step "6. Carregando imagens no cluster Kind..."
kind load docker-image case-backend:latest --name case-local || fail "Erro carregando backend"
kind load docker-image case-frontend:latest --name case-local || fail "Erro carregando frontend"  
kind load docker-image case-mobile:latest --name case-local || fail "Erro carregando mobile"

success "Imagens carregadas no Kind"

# 7. Deploy no Kubernetes
step "7. Fazendo deploy no Kubernetes..."

# Criar namespace
kubectl create namespace case --dry-run=client -o yaml | kubectl apply -f -
success "Namespace 'case' criado"

# Criar secret do Datadog
info "Criando secret do Datadog..."
kubectl create secret generic datadog --from-literal=api-key=demo-key-123 -n case --dry-run=client -o yaml | kubectl apply -f -
success "Secret Datadog criado"

# Aplicar manifests
info "Aplicando manifests..."
kubectl apply -f k8s/env-config.yaml
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/backend-serviceaccount.yaml  
kubectl apply -f k8s/frontend-deployment.yaml
kubectl apply -f k8s/mobile-deployment.yaml

success "Manifests aplicados"

# 8. Atualizar deployments para usar imagens locais
step "8. Atualizando deployments para usar imagens locais..."

kubectl patch deployment backend -n case -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "backend",
          "image": "case-backend:latest",
          "imagePullPolicy": "Never"
        }]
      }
    }
  }
}'

kubectl patch deployment frontend -n case -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "frontend", 
          "image": "case-frontend:latest",
          "imagePullPolicy": "Never"
        }]
      }
    }
  }
}'

kubectl patch deployment mobile -n case -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "mobile",
          "image": "case-mobile:latest", 
          "imagePullPolicy": "Never"
        }]
      }
    }
  }
}'

success "Deployments atualizados com imagens locais"

# 9. Aguardar pods ficarem prontos
step "9. Aguardando pods ficarem prontos..."

info "Verificando status inicial dos pods..."
kubectl get pods -n case 2>/dev/null || info "Aguardando pods serem criados..."

info "Aguardando todos os pods ficarem prontos (até 180s)..."
echo -e "${BLUE}  Pods esperados: backend, frontend, mobile${NC}"

# Aguardar com timeout mais realista
timeout=180
elapsed=0

while [ $elapsed -lt $timeout ]; do
    ready_pods=$(kubectl get pods -n case --no-headers 2>/dev/null | grep "1/1.*Running" | wc -l)
    total_pods=$(kubectl get pods -n case --no-headers 2>/dev/null | grep "case-" | wc -l)
    
    echo -ne "\r${BLUE}  Progresso: $ready_pods/$total_pods pods prontos | Tempo: ${elapsed}s/${timeout}s${NC}"
    
    # Verificar se pelo menos 2 pods estão prontos (backend + frontend é suficiente para demo)
    if [ "$ready_pods" -ge 2 ]; then
        echo ""
        success "Pods principais estão prontos!"
        break
    fi
    
    sleep 5
    elapsed=$((elapsed + 5))
done

# Verificação final
if [ $elapsed -ge $timeout ]; then
    echo ""
    warn "Timeout atingido. Verificando status final..."
fi

echo ""
step "Status final do cluster:"
kubectl get pods -n case

# 10. Configurar port-forwards
step "10. Configurando port-forwards..."

info "Iniciando port-forwards para acesso aos serviços..."
kubectl port-forward -n case svc/backend 3002:3000 >/dev/null 2>&1 &
kubectl port-forward -n case svc/frontend 3003:80 >/dev/null 2>&1 &
kubectl port-forward -n case svc/mobile 3004:19006 >/dev/null 2>&1 &

sleep 10

# 11. Testar conectividade
step "11. Testando conectividade..."

if curl -s -f http://localhost:3002/healthz >/dev/null 2>&1; then
    success "Backend acessível"
else
    warn "Backend não acessível via port-forward"
fi

if curl -s -I http://localhost:3003/ >/dev/null 2>&1; then
    success "Frontend acessível"  
else
    warn "Frontend não acessível via port-forward"
fi

if curl -s -I http://localhost:3100/ >/dev/null 2>&1; then
    success "Grafana acessível"
else
    warn "Grafana não acessível"
fi

# 12. Gerar tráfego inicial
step "12. Gerando tráfego inicial para dashboards..."

info "Gerando requests no backend..."
for i in {1..15}; do
    curl -s http://localhost:3002/ > /dev/null 2>&1 || true
    curl -s http://localhost:3002/healthz > /dev/null 2>&1 || true 
    echo -n "."
    sleep 0.2
done

echo ""
info "Gerando requests no frontend..."
for i in {1..10}; do
    curl -s http://localhost:3003/ > /dev/null 2>&1 || true
    echo -n "."
    sleep 0.3  
done

echo ""
success "Tráfego inicial gerado"

# 13. Verificação final
step "13. Verificação final do ambiente..."

# Testar endpoints de métricas
info "Testando endpoints de métricas..."
sleep 10

if curl -s http://localhost:3002/metrics 2>/dev/null | head -1 | grep -q "#"; then
    success "Backend metrics OK"
else
    warn "Backend metrics com problema"
fi

if curl -s http://localhost:3003/metrics 2>/dev/null | head -1 | grep -q "#"; then
    success "Frontend metrics OK"
else
    warn "Frontend metrics com problema"
fi

# Finalização
echo ""
success "🎉 AMBIENTE DEMO CONFIGURADO COM SUCESSO! 🎉"
echo ""
step "URLs para Demo:"
echo "   • Grafana: http://localhost:3100 (admin/admin)"
echo "   • Prometheus: http://localhost:9090"  
echo "   • Backend API: http://localhost:3002"
echo "   • Frontend: http://localhost:3003"
echo "   • Mobile: http://localhost:3004"
echo ""
step "Dashboards Principais:"
echo "   • Golden Signals: http://localhost:3100/d/golden-signals"
echo "   • Business Metrics: http://localhost:3100/d/business-metrics"
echo "   • Frontend: http://localhost:3100/d/frontend-golden-signals"  
echo "   • Mobile: http://localhost:3100/d/mobile-golden-signals"
echo ""
warn "Para manter métricas ativas durante demo, execute:"
echo "   ./generate-demo-traffic.sh 15  # 15 minutos de tráfego"
echo ""
info "Para validar ambiente: ./validate-demo-environment.sh"
info "Para limpar após demo: ./cleanup-and-restart.sh"
echo ""
success "🎬 PRONTO PARA GRAVAÇÃO! 🚀"