#!/bin/bash
# Script completo para subir LocalStack + EKS + Apps + Observabilidade

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log colorido
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARN:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ERROR:${NC} $1"
}

info() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] INFO:${NC} $1"
}

# Ir para o diretório raiz do projeto
cd "$(dirname "$0")/.."

echo ""
echo " INICIANDO AMBIENTE COMPLETO"
echo "=============================="
echo "LocalStack Pro + EKS + Apps + Observabilidade"
echo ""

# Verificar pré-requisitos
log "Verificando pré-requisitos..."

if ! docker info >/dev/null 2>&1; then
    error "Docker não está rodando. Inicie o Docker Desktop e tente novamente."
    exit 1
fi

if ! command -v kind >/dev/null 2>&1; then
    error "kind não está instalado. Instale com: choco install kind"
    exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
    error "kubectl não está instalado. Instale com: choco install kubernetes-cli"
    exit 1
fi

# Verificar se .env.localstack existe
if [ ! -f .env.localstack ]; then
    warn "Arquivo .env.localstack não encontrado. Criando..."
    cp .env.example .env.localstack 2>/dev/null || cat > .env.localstack << 'EOF'
# LocalStack Configuration
LOCALSTACK_AUTH_TOKEN=ls-rOhOqaQe-9209-3474-kAto-faXUpetu092e

# AWS Credentials (fake for LocalStack)
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
AWS_DEFAULT_REGION=us-east-1

# Datadog (opcional)
DD_API_KEY=
DD_SITE=us5.datadoghq.com

# LocalStack Settings
DEBUG=0
LOCALSTACK_VOLUME_DIR=./localstack-data
EOF
fi

# Carregar variáveis
export $(grep -v '^#' .env.localstack | xargs)

# Criar diretórios necessários
log "Criando diretórios..."
mkdir -p localstack-data
mkdir -p localstack-kubeconfig

# ETAPA 1: LocalStack Pro
log "ETAPA 1/6: Iniciando LocalStack Pro..."
docker compose -f docker-compose.localstack.yml up -d localstack

info "Aguardando LocalStack ficar pronto..."
TIMEOUT=120
COUNT=0
until curl -s http://localhost:4566/_localstack/health | grep -q '"dynamodb": "available"'; do
    if [ $COUNT -ge $TIMEOUT ]; then
        error "Timeout aguardando LocalStack (${TIMEOUT}s)"
        exit 1
    fi
    echo -n "."
    sleep 2
    COUNT=$((COUNT + 2))
done
echo ""
log "LocalStack Pro iniciado com sucesso!"

# ETAPA 2: Provisionar recursos AWS
log "ETAPA 2/6: Provisionando recursos AWS no LocalStack..."
bash scripts/localstack-provision-simple.sh

# ETAPA 3: Stack de Observabilidade
log "ETAPA 3/6: Iniciando stack de observabilidade..."
docker compose -f docker-compose.observability.yml up -d

info "Aguardando Prometheus ficar pronto..."
until curl -s http://localhost:9090/-/healthy >/dev/null 2>&1; do
    echo -n "."
    sleep 2
done
echo ""

info "Aguardando Grafana ficar pronto..."
until curl -s http://localhost:3100/api/health >/dev/null 2>&1; do
    echo -n "."
    sleep 2
done
echo ""
log "Stack de observabilidade iniciada!"

# ETAPA 4: Aplicações LocalStack
log "ETAPA 4/6: Iniciando aplicações (Backend + Frontend + Mobile)..."
docker compose -f docker-compose.localstack.yml up -d backend-localstack frontend-localstack mobile-localstack datadog-agent-localstack

info "Aguardando backend ficar pronto..."
until curl -s http://localhost:3001/healthz >/dev/null 2>&1; do
    echo -n "."
    sleep 2
done
echo ""
log "Aplicações LocalStack iniciadas!"

# ETAPA 5: Cluster Kubernetes (kind)
log "ETAPA 5/6: Configurando cluster Kubernetes..."

CLUSTER_NAME="case-local"

if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    info "Criando cluster kind..."
    cat <<EOF | kind create cluster --name "$CLUSTER_NAME" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 80
    hostPort: 8080
  - containerPort: 443
    hostPort: 8443
  extraMounts:
  - hostPath: /var/run/docker.sock
    containerPath: /var/run/docker.sock
EOF
    log "Cluster kind criado!"
else
    info "Cluster kind já existe"
fi

# Build e carregar imagens
info "Verificando imagens existentes..."

# Verificar se imagens já existem
NEED_BACKEND_BUILD=false
NEED_FRONTEND_BUILD=false
NEED_MOBILE_BUILD=false

if ! docker images case-backend:latest -q | grep -q .; then
    NEED_BACKEND_BUILD=true
fi
if ! docker images case-frontend:latest -q | grep -q .; then
    NEED_FRONTEND_BUILD=true
fi
if ! docker images case-mobile:latest -q | grep -q .; then
    NEED_MOBILE_BUILD=true
fi

info "Construindo imagens Docker..."
# Build em paralelo apenas as que precisam
if [ "$NEED_BACKEND_BUILD" = true ]; then
    info "   Construindo backend..."
    docker build -t case-backend:latest app/backend &
    BACKEND_BUILD_PID=$!
fi

if [ "$NEED_FRONTEND_BUILD" = true ]; then
    info "   Construindo frontend..."
    docker build -t case-frontend:latest app/frontend &
    FRONTEND_BUILD_PID=$!
fi

if [ "$NEED_MOBILE_BUILD" = true ]; then
    info "   Construindo mobile..."
    docker build -t case-mobile:latest app/mobile &
    MOBILE_BUILD_PID=$!
fi

# Aguardar builds completarem
if [ "$NEED_BACKEND_BUILD" = true ] && [ -n "${BACKEND_BUILD_PID:-}" ]; then
    wait $BACKEND_BUILD_PID
    info "   Backend build concluído "
fi

if [ "$NEED_FRONTEND_BUILD" = true ] && [ -n "${FRONTEND_BUILD_PID:-}" ]; then
    wait $FRONTEND_BUILD_PID
    info "   Frontend build concluído "
fi

if [ "$NEED_MOBILE_BUILD" = true ] && [ -n "${MOBILE_BUILD_PID:-}" ]; then
    wait $MOBILE_BUILD_PID
    info "   Mobile build concluído "
fi

info "Builds concluídos!"

info "Carregando imagens no kind..."

# Verificar se imagens já estão no kind
EXISTING_IMAGES=$(docker exec "$CLUSTER_NAME-control-plane" crictl images | grep "case-" | awk '{print $1":"$2}' | sort) 2>/dev/null || true

# Carregar apenas imagens que não estão no kind
if ! echo "$EXISTING_IMAGES" | grep -q "case-backend:latest"; then
    info "   Carregando backend no kind..."
    kind load docker-image case-backend:latest --name "$CLUSTER_NAME" &
    BACKEND_LOAD_PID=$!
fi

if ! echo "$EXISTING_IMAGES" | grep -q "case-frontend:latest"; then
    info "   Carregando frontend no kind..."
    kind load docker-image case-frontend:latest --name "$CLUSTER_NAME" &
    FRONTEND_LOAD_PID=$!
fi

if ! echo "$EXISTING_IMAGES" | grep -q "case-mobile:latest"; then
    info "   Carregando mobile no kind..."
    kind load docker-image case-mobile:latest --name "$CLUSTER_NAME" &
    MOBILE_LOAD_PID=$!
fi

# Aguardar carregamentos completarem
[ -n "${BACKEND_LOAD_PID:-}" ] && wait $BACKEND_LOAD_PID && info "   Backend carregado "
[ -n "${FRONTEND_LOAD_PID:-}" ] && wait $FRONTEND_LOAD_PID && info "   Frontend carregado "
[ -n "${MOBILE_LOAD_PID:-}" ] && wait $MOBILE_LOAD_PID && info "   Mobile carregado "

info "Imagens disponíveis no kind!"

# Verificar se imagens foram carregadas corretamente
info "Verificando imagens no kind..."
docker exec "$CLUSTER_NAME-control-plane" crictl images | grep "case-" || error "Falha ao carregar imagens no kind"

# ETAPA 6: Deploy no Kubernetes
log "ETAPA 6/6: Deploy das aplicações no Kubernetes..."

# Namespace
kubectl apply -f k8s/namespace.yaml

# ConfigMap
kubectl create configmap env-config \
    --from-literal=AWS_REGION=us-east-1 \
    --from-literal=DDB_TABLE=orders \
    --from-literal=DD_SITE=us5.datadoghq.com \
    --from-literal=DYNAMODB_ENDPOINT=http://host.docker.internal:4566 \
    --from-literal=AWS_ACCESS_KEY_ID=test \
    --from-literal=AWS_SECRET_ACCESS_KEY=test \
    -n case --dry-run=client -o yaml | kubectl apply -f -

# Secret
kubectl create secret generic datadog \
    --from-literal=api-key="${DD_API_KEY:-dummy}" \
    -n case --dry-run=client -o yaml | kubectl apply -f -

# ServiceAccount
kubectl apply -f k8s/backend-serviceaccount.yaml

# Aplicar deployments com imagens locais diretamente
info "Aplicando deployments com imagens locais..."

# Criar deployments temporários com imagens corretas
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Backend deployment
sed -e "s#<AWS_ACCOUNT_ID>#000000000000#g" \
    -e "s#<AWS_REGION>#us-east-1#g" \
    -e "s#image: .*backend.*#image: case-backend:latest#g" \
    -e "s#imagePullPolicy: IfNotPresent#imagePullPolicy: Never#g" \
    k8s/backend-deployment.yaml > "$TEMP_DIR/backend-deployment.yaml"

# Frontend deployment  
sed -e "s#<AWS_ACCOUNT_ID>#000000000000#g" \
    -e "s#<AWS_REGION>#us-east-1#g" \
    -e "s#image: .*frontend.*#image: case-frontend:latest#g" \
    -e "s#imagePullPolicy: IfNotPresent#imagePullPolicy: Never#g" \
    k8s/frontend-deployment.yaml > "$TEMP_DIR/frontend-deployment.yaml"

# Mobile deployment
sed -e "s#<AWS_ACCOUNT_ID>#000000000000#g" \
    -e "s#<AWS_REGION>#us-east-1#g" \
    -e "s#image: .*mobile.*#image: case-mobile:latest#g" \
    -e "s#imagePullPolicy: IfNotPresent#imagePullPolicy: Never#g" \
    k8s/mobile-deployment.yaml > "$TEMP_DIR/mobile-deployment.yaml"

# Aplicar deployments corrigidos
kubectl apply -f "$TEMP_DIR/backend-deployment.yaml"
kubectl apply -f "$TEMP_DIR/frontend-deployment.yaml" 
kubectl apply -f "$TEMP_DIR/mobile-deployment.yaml"

# Aguardar pods ficarem prontos (em paralelo)
info "Aguardando pods ficarem prontos..."
kubectl wait --for=condition=ready pod -l app=backend -n case --timeout=120s &
BACKEND_WAIT_PID=$!
kubectl wait --for=condition=ready pod -l app=frontend -n case --timeout=120s &
FRONTEND_WAIT_PID=$!
kubectl wait --for=condition=ready pod -l app=mobile -n case --timeout=120s &
MOBILE_WAIT_PID=$!

# Aguardar todos os pods
wait $BACKEND_WAIT_PID && echo "   Backend:  Pronto"
wait $FRONTEND_WAIT_PID && echo "   Frontend:  Pronto" 
wait $MOBILE_WAIT_PID && echo "   Mobile:  Pronto"

info "Verificando status final dos pods..."
kubectl get pods -n case

# Acesso simplificado para desenvolvimento local
info "Configurando acesso local às aplicações..."

# Para desenvolvimento local, usaremos port-forward ao invés de Ingress
# Isso evita dependências externas e simplifica o setup

# Criar script helper para port-forward
cat > scripts/port-forward-apps.sh << 'EOF'
#!/bin/bash
echo " Iniciando port-forwards para acesso local..."
echo ""

# Função para matar port-forwards anteriores
cleanup() {
    echo " Parando port-forwards anteriores..."
    pkill -f "kubectl.*port-forward.*case" 2>/dev/null || true
    sleep 2
}

# Cleanup inicial
cleanup

# Trap para cleanup no exit
trap cleanup EXIT

echo " Configurando acessos:"
echo "   • Backend:  http://localhost:8081"
echo "   • Frontend: http://localhost:8082"  
echo "   • Mobile:   http://localhost:8083"
echo ""

# Port-forwards em background
kubectl port-forward -n case svc/backend 8081:3000 > /dev/null 2>&1 &
kubectl port-forward -n case svc/frontend 8082:80 > /dev/null 2>&1 &
kubectl port-forward -n case svc/mobile 8083:19006 > /dev/null 2>&1 &

echo " Port-forwards configurados!"
echo ""
echo " Acesse as aplicações em:"
echo "   • Backend:  http://localhost:8081"
echo "   • Frontend: http://localhost:8082"
echo "   • Mobile:   http://localhost:8083"
echo "   • API:      http://localhost:8081/api/orders"
echo ""
echo "  Pressione Ctrl+C para parar todos os port-forwards"

# Aguardar sinal para parar
wait
EOF

chmod +x scripts/port-forward-apps.sh
info "Script de port-forward criado: scripts/port-forward-apps.sh"

log "Deploy no Kubernetes concluído!"

# Teste de conectividade
log "Executando testes de conectividade..."

# Teste LocalStack
info "Testando LocalStack..."
if curl -sf --connect-timeout 5 --max-time 10 http://localhost:4566/_localstack/health >/dev/null; then
    echo "  [OK] LocalStack: OK"
else
    echo "  [ERROR] LocalStack: FALHA"
fi

# Teste Backend LocalStack
if curl -sf --connect-timeout 5 --max-time 10 http://localhost:3001/metrics >/dev/null; then
    echo "   Backend LocalStack: OK"
else
    echo "   Backend LocalStack: FALHA"
fi

# Teste Frontend LocalStack
if curl -sfI --connect-timeout 5 --max-time 10 http://localhost:5174 >/dev/null; then
    echo "   Frontend LocalStack: OK"
else
    echo "   Frontend LocalStack: FALHA"
fi

# Teste Mobile LocalStack
if curl -sfI --connect-timeout 5 --max-time 10 http://localhost:19007 >/dev/null; then
    echo "   Mobile LocalStack: OK"
else
    echo "   Mobile LocalStack: FALHA"
fi

# Teste Observabilidade
if curl -sf --connect-timeout 5 --max-time 10 http://localhost:9090/-/healthy >/dev/null; then
    echo "   Prometheus: OK"
else
    echo "   Prometheus: FALHA"
fi

if curl -sf --connect-timeout 5 --max-time 10 http://localhost:3100/api/health >/dev/null; then
    echo "   Grafana: OK"
else
    echo "   Grafana: FALHA"
fi

# Teste Kubernetes
if kubectl get pods -n case >/dev/null 2>&1; then
    echo "   Kubernetes: OK"
else
    echo "   Kubernetes: FALHA"
fi

# Criar uma order de teste
info "Criando order de teste..."
ORDER_RESULT=$(curl -sf --connect-timeout 5 --max-time 15 -X POST http://localhost:3001/api/orders \
    -H "Content-Type: application/json" \
    -d '{"item":"test-startup","price":100}' 2>/dev/null || echo "")

if [ -n "$ORDER_RESULT" ]; then
    echo "   Order criada: $ORDER_RESULT"
else
    echo "   Falha ao criar order"
fi

echo ""
echo " DEMONSTRAÇÃO LOCAL PRONTA!"
echo "============================="
echo ""
echo " APLICAÇÕES DISPONÍVEIS:"
echo ""
echo " LocalStack (Ambiente AWS Simulado):"
echo "   • Gateway: http://localhost:4566"
echo "   • Health: http://localhost:4566/_localstack/health"
echo ""
echo " Docker Compose (Acesso Direto):"
echo "   • Backend: http://localhost:3001"
echo "   • Frontend: http://localhost:5174"
echo "   • Mobile: http://localhost:19007"
echo "   • API: http://localhost:3001/api/orders"
echo ""
echo " Kubernetes (Precisa Port-Forward):"
echo "   Para acessar via Kubernetes, execute:"
echo "    ./scripts/port-forward-apps.sh"
echo "   • Backend: http://localhost:8081"
echo "   • Frontend: http://localhost:8082"
echo "   • Mobile: http://localhost:8083"
echo ""
echo " Observabilidade:"
echo "   • Prometheus: http://localhost:9090"
echo "   • Grafana: http://localhost:3100 (admin/admin)"
echo "   • Loki: http://localhost:3101"
echo "   • Tempo: http://localhost:3102"
echo ""
echo " COMANDOS ÚTEIS:"
echo ""
echo "# Status dos pods"
echo "kubectl get pods -n case"
echo ""
echo "# Logs do backend"
echo "kubectl logs -n case -l app=backend -f"
echo ""
echo "# Ver dados no DynamoDB"
echo "bash scripts/awslocal.sh dynamodb scan --table-name orders"
echo ""
echo "# Status dos containers"
echo "docker compose -f docker-compose.localstack.yml ps"
echo "docker compose -f docker-compose.observability.yml ps"
echo ""
echo "# Parar tudo"
echo "bash scripts/stop-all.sh"
echo ""
echo " DASHBOARDS GRAFANA:"
echo "   • 4 Golden Signals: http://localhost:3100/d/golden-signals-backend"
echo "   • Business Metrics: http://localhost:3100/d/business-orders"
echo ""
echo " Tempo total de inicialização: $(date)"
echo ""
