#!/bin/bash
# Script simplificado para subir LocalStack Pro + Apps + Observabilidade
# Versão rápida sem Kubernetes para desenvolvimento local
# Autor: Kiro  Assistant
# Data: 2025-10-25

set -e

# Cores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Ir para o diretório raiz do projeto
cd "$(dirname "$0")/.."

echo ""
echo "🚀 AMBIENTE LOCALSTACK PRO SIMPLIFICADO"
echo "======================================="
echo "LocalStack Pro + Apps + Observabilidade (sem Kubernetes)"
echo ""

# Verificar Docker
if ! docker info >/dev/null 2>&1; then
    error "Docker não está rodando. Inicie o Docker Desktop."
    exit 1
fi

# Verificar .env.localstack
if [ ! -f .env.localstack ]; then
    warn "Criando .env.localstack..."
    cat > .env.localstack << 'EOF'
LOCALSTACK_AUTH_TOKEN=ls-rOhOqaQe-9209-3474-kAto-faXUpetu092e
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
AWS_DEFAULT_REGION=us-east-1
DD_API_KEY=
DD_SITE=us5.datadoghq.com
DEBUG=0
LOCALSTACK_VOLUME_DIR=./localstack-data
EOF
fi

# Carregar variáveis
export $(grep -v '^#' .env.localstack | xargs)

# Criar diretórios
mkdir -p localstack-data

# ETAPA 1: LocalStack Pro
log "1/4: Iniciando LocalStack Pro..."
docker compose -f docker-compose.localstack.yml up -d localstack

echo -n "Aguardando LocalStack"
until curl -s http://localhost:4566/_localstack/health | grep -q '"dynamodb": "available"'; do
    echo -n "."
    sleep 2
done
echo " "

# ETAPA 2: Provisionar AWS
log "2/4: Provisionando recursos AWS..."
bash scripts/localstack-provision-simple.sh | grep -E "(||Criando|Provisionamento)"

# ETAPA 3: Observabilidade
log "3/4: Iniciando observabilidade..."
docker compose -f docker-compose.observability.yml up -d

echo -n "Aguardando Prometheus"
until curl -s http://localhost:9090/-/healthy >/dev/null 2>&1; do
    echo -n "."
    sleep 2
done
echo " "

echo -n "Aguardando Grafana"
until curl -s http://localhost:3100/api/health >/dev/null 2>&1; do
    echo -n "."
    sleep 2
done
echo " "

# ETAPA 4: Aplicações
log "4/4: Iniciando aplicações..."
docker compose -f docker-compose.localstack.yml up -d backend-localstack frontend-localstack datadog-agent-localstack

echo -n "Aguardando backend"
until curl -s http://localhost:3001/healthz >/dev/null 2>&1; do
    echo -n "."
    sleep 2
done
echo " "

# Mobile (opcional)
read -p "Deseja iniciar o app mobile? (s/N): " START_MOBILE
if [[ "$START_MOBILE" =~ ^[Ss]$ ]]; then
    log "Iniciando mobile..."
    docker compose --profile mobile up -d mobile
fi

# Teste rápido
log "Executando teste rápido..."

# Criar order de teste
ORDER=$(curl -sf -X POST http://localhost:3001/api/orders \
    -H "Content-Type: application/json" \
    -d '{"item":"startup-test","price":50}' 2>/dev/null || echo "")

if [ -n "$ORDER" ]; then
    echo " Order criada com sucesso"
else
    echo " Falha ao criar order"
fi

echo ""
echo "🎉 AMBIENTE PRONTO!"
echo "=================="
echo ""
echo "📱 APLICAÇÕES:"
echo "   • Backend: http://localhost:3001"
echo "   • Frontend: http://localhost:5174"
echo "   • Mobile: http://localhost:19006 (se iniciado)"
echo ""
echo "📊 OBSERVABILIDADE:"
echo "   • Grafana: http://localhost:3100 (admin/admin)"
echo "   • Prometheus: http://localhost:9090"
echo ""
echo "🔧 AWS LOCAL:"
echo "   • LocalStack: http://localhost:4566"
echo ""
echo "⚡ TESTES RÁPIDOS:"
echo ""
echo "# Criar order"
echo 'curl -X POST http://localhost:3001/api/orders -H "Content-Type: application/json" -d '"'"'{"item":"test","price":100}'"'"
echo ""
echo "# Ver orders"
echo "curl http://localhost:3001/api/orders"
echo ""
echo "# Ver no DynamoDB"
echo "bash scripts/awslocal.sh dynamodb scan --table-name orders"
echo ""
echo "# Gerar tráfego para métricas"
echo "for i in {1..20}; do curl -s http://localhost:3001/api/orders > /dev/null; sleep 0.5; done"
echo ""
echo "# Parar tudo"
echo "bash scripts/stop-all.sh"
echo ""