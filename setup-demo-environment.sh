#!/bin/bash
# Script completo para subir ambiente local para demo
# Uso: ./setup-demo-environment.sh

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
step() { echo -e "${PURPLE} $1${NC}"; }

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

# 4. Preparar builds (otimizado para demo)
step "4. Preparando aplicações para build..."
info "Instalando dependências do frontend..."
(cd app/frontend && npm install --silent 2>/dev/null || true)
(cd app/frontend && npm run build --silent 2>/dev/null || true)

info "Preparando mobile (servidor simples)..."
# Mobile já tem Dockerfile otimizado

success "Aplicações preparadas para build"

# 5. Build e carregar imagens no Kind  
step "5. Fazendo build e carregamento das imagens..."

# Fazer build das imagens locais (sem registry)
info "Fazendo build das imagens locais..."
docker build -t case-backend:latest app/backend || fail "Erro no build do backend"
docker build -t case-frontend:latest app/frontend || fail "Erro no build do frontend"
docker build -t case-mobile:latest app/mobile || fail "Erro no build do mobile"

# Carregar imagens no Kind
info "Carregando imagens no cluster Kind..."
kind load docker-image case-backend:latest --name case-local || fail "Erro carregando backend"
kind load docker-image case-frontend:latest --name case-local || fail "Erro carregando frontend"  
kind load docker-image case-mobile:latest --name case-local || fail "Erro carregando mobile"

success "Imagens carregadas no Kind"

# 6. Deploy no Kubernetes
step "6. Fazendo deploy no Kubernetes..."
kubectl create namespace case --dry-run=client -o yaml | kubectl apply -f -

# Criar secret do Datadog (para demo)
info "Criando secret do Datadog..."
kubectl create secret generic datadog --from-literal=api-key=demo-key-123 -n case --dry-run=client -o yaml | kubectl apply -f -

# Aplicar manifests em ordem
kubectl apply -f k8s/env-config.yaml
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/backend-serviceaccount.yaml  
kubectl apply -f k8s/frontend-deployment.yaml
kubectl apply -f k8s/mobile-deployment.yaml

# Corrigir deployments para usar imagens locais
info "Atualizando deployments para usar imagens locais..."
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

# Aguardar e verificar pods com feedback detalhado
info "Verificando status inicial dos pods..."
kubectl get pods -n case 2>/dev/null || info "Namespace ainda sendo criado..."

info "Aguardando todos os pods ficarem prontos (até 300s)..."
echo -e "${BLUE}  Pods esperados: backend, frontend, mobile${NC}"

# Função para mostrar progresso dos pods
check_pod_status() {
    local ready_count=0
    local total_pods=0
    
    while read -r line; do
        if [[ $line == *"case-"* ]]; then
            total_pods=$((total_pods + 1))
            if [[ $line == *"1/1"* && $line == *"Running"* ]]; then
                ready_count=$((ready_count + 1))
            fi
        fi
    done <<< "$(kubectl get pods -n case --no-headers 2>/dev/null || echo '')"
    
    echo "$ready_count/$total_pods"
}

# Aguardar com feedback de progresso
timeout=300
elapsed=0
echo -ne "${BLUE}  Iniciando verificação...${NC}"

while [ $elapsed -lt $timeout ]; do
    status=$(check_pod_status)
    echo -ne "\r${BLUE}  Progresso: $status pods prontos | Tempo: ${elapsed}s/${timeout}s${NC}"
    
    # Verificar se todos os pods estão prontos
    if kubectl get pods -n case --no-headers 2>/dev/null | grep "case-" | grep -v "1/1.*Running" > /dev/null; then
        sleep 5
        elapsed=$((elapsed + 5))
    else
        # Verificar se temos pelo menos os pods esperados
        pod_count=$(kubectl get pods -n case --no-headers 2>/dev/null | grep "case-" | wc -l)
        if [ "$pod_count" -ge 3 ]; then
            echo ""
            success "Todos os pods estão prontos!"
            break
        else
            sleep 5
            elapsed=$((elapsed + 5))
        fi
    fi
done

# Verificação final
if [ $elapsed -ge $timeout ]; then
    echo ""
    warn "Timeout de ${timeout}s atingido. Verificando status final..."
    kubectl get pods -n case
    
    # Verificar se pelo menos alguns pods estão funcionando
    ready_pods=$(kubectl get pods -n case --no-headers 2>/dev/null | grep "1/1.*Running" | wc -l)
    if [ "$ready_pods" -gt 0 ]; then
        warn "  $ready_pods pod(s) funcionando. Continuando com demo..."
    else
        fail " Nenhum pod está pronto após ${timeout}s"
    fi
fi

# Mostrar status final
echo ""
step "Status final do cluster:"
kubectl get pods -n case
kubectl get svc -n case

# 7. Configurar métricas e port-forwards
step "7. Configurando coleta de métricas..."

# Aguardar deployments estabilizarem
sleep 10

# Iniciar port-forwards individuais para maior confiabilidade
info "Iniciando port-forwards para métricas..."
kubectl port-forward -n case svc/backend 3002:3000 >/dev/null 2>&1 &
kubectl port-forward -n case svc/frontend 3003:80 >/dev/null 2>&1 &
kubectl port-forward -n case svc/mobile 3004:19006 >/dev/null 2>&1 &

sleep 15

# Testar conectividade
info "Testando conectividade..."
if curl -s http://localhost:3002/healthz > /dev/null; then
    success "Backend acessível"
else
    warn "Backend não acessível via port-forward"
fi

if curl -s -I http://localhost:3003/ > /dev/null; then
    success "Frontend acessível"  
else
    warn "Frontend não acessível via port-forward"
fi

# 8. Gerar tráfego inicial
step "8. Gerando tráfego inicial para dashboards..."

info "Gerando requests no backend..."
for i in {1..20}; do
    curl -s http://localhost:3002/ > /dev/null 2>&1 || true
    curl -s http://localhost:3002/healthz > /dev/null 2>&1 || true 
    curl -s http://localhost:3002/api/orders > /dev/null 2>&1 || true
    echo -n "."
    sleep 0.2
done

info "\nGerando requests no frontend/mobile..."
for i in {1..10}; do
    curl -s http://localhost:3003/ > /dev/null 2>&1 || true
    curl -s http://localhost:3004/ > /dev/null 2>&1 || true
    echo -n "."
    sleep 0.3  
done

echo ""
success "Tráfego inicial gerado"

# 9. Verificar coleta de métricas
step "9. Verificando coleta de métricas..."
sleep 20

# Verificar targets
info "Verificando targets no Prometheus..."
TARGETS=$(curl -s http://localhost:9090/api/v1/targets 2>/dev/null | jq -r '.data.activeTargets[] | select(.health=="up") | .scrapePool' 2>/dev/null | wc -l)
info "Targets UP: $TARGETS"

# Testar endpoints de métricas
info "Testando endpoints de métricas..."
curl -s http://localhost:3002/metrics | head -1 | grep -q "#" && success " Backend metrics OK" || warn " Backend metrics com problema"
curl -s http://localhost:3003/metrics | head -1 | grep -q "#" && success " Frontend metrics OK" || warn " Frontend metrics com problema"  
curl -s http://localhost:3004/metrics | head -1 | grep -q "#" && success " Mobile metrics OK" || warn " Mobile metrics com problema"

# 10. Finalização
echo ""
success " AMBIENTE DEMO CONFIGURADO COM SUCESSO!"
echo ""
step " URLs para Demo:"
echo "   • Grafana: http://localhost:3100 (admin/admin)"
echo "   • Prometheus: http://localhost:9090"  
echo "   • Backend API: http://localhost:3002"
echo "   • Frontend: http://localhost:3003"
echo "   • Mobile: http://localhost:3004"
echo ""
step " Dashboards Principais:"
echo "   • Golden Signals: http://localhost:3100/d/golden-signals"
echo "   • Business Metrics: http://localhost:3100/d/business-metrics"
echo "   • Frontend: http://localhost:3100/d/frontend-golden-signals"  
echo "   • Mobile: http://localhost:3100/d/mobile-golden-signals"
echo ""
step " Para testar coleta de métricas:"
echo "   ./test-metrics-collection.sh"
echo ""
warn "  Para manter métricas ativas durante demo, execute:"
echo "   ./generate-demo-traffic.sh 15  # 15 minutos de tráfego"
echo ""
info "  Para limpar após demo: kind delete cluster --name case-local"
echo ""
success " PRONTO PARA GRAVAÇÃO!"