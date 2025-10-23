#!/usr/bin/env bash
set -euo pipefail

MODE=${1:-local}
ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)

BASE_URL="${BASE_URL:-}"

info() { echo "[test] $*"; }
fail() { echo "[test][ERRO] $*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Comando requerido não encontrado: $1"; }

do_smoke() {
  local base=$1
  info "Healthcheck"
  curl -sf "$base/healthz" >/dev/null || fail "Healthcheck falhou em $base/healthz"

  info "Criando pedido (POST /api/orders)"
  local payload='{"item":"widget","price":123.45}'
  resp=$(curl -s -w "\n%{http_code}" -H 'Content-Type: application/json' -d "$payload" "$base/api/orders")
  body=$(echo "$resp" | head -n1)
  http_code=$(echo "$resp" | tail -n1)
  if [ "$http_code" != "201" ] && [ "$http_code" != "200" ]; then
    fail "POST /api/orders retornou código $http_code"
  fi
  echo "$body" | grep -qi '"item"\s*:\s*"widget"' || fail "Resposta do POST não contém item=widget"

  info "Listando pedidos (GET /api/orders)"
  body=$(curl -sf "$base/api/orders")
  echo "$body" | grep -qi '"orders"' || fail "Lista de pedidos não contém campo orders"

  info "Verificando métricas (GET /metrics)"
  curl -sf "$base/metrics" | grep -qi "http_requests_total" || fail "Métrica http_requests_total não encontrada"

  info "Teste WireMock (GET /api/orders/price/widget)"
  # Esta rota deve funcionar mesmo sem WireMock; se não existir, apenas loga aviso
  if ! curl -sf "$base/api/orders/price/widget" >/dev/null; then
    info "Endpoint de preço indisponível (ok se WireMock não estiver ativo)."
  fi
}

case "$MODE" in
  local)
    need_cmd curl
    # Descobre base URL local
    BACKEND_URL=${BACKEND_URL:-http://localhost:3000}
    info "Testando ambiente local em ${BACKEND_URL}"
    # espera backend
    for i in {1..60}; do
      if curl -sf "$BACKEND_URL/healthz" >/dev/null 2>&1; then break; fi; sleep 2; done
    do_smoke "$BACKEND_URL"
    ;;
  eks)
    need_cmd kubectl
    NAMESPACE=${NAMESPACE:-case}
    SERVICE=${SERVICE:-backend}
    info "Descobrindo endpoint do serviço ${SERVICE} no namespace ${NAMESPACE}"
    # Tenta via ingress; se não houver, usa port-forward temporário
    if kubectl -n "$NAMESPACE" get ingress case-ingress >/dev/null 2>&1; then
      host=$(kubectl -n "$NAMESPACE" get ingress case-ingress -o jsonpath='{.spec.rules[0].host}')
      [ -n "$host" ] || fail "Ingress sem host configurado"
      BASE_URL="http://$host"
      do_smoke "$BASE_URL"
    else
      info "Ingress não encontrado. Usando port-forward do serviço ${SERVICE} -> 3000"
      # inicia port-forward em background
      kubectl -n "$NAMESPACE" port-forward svc/${SERVICE} 3000:3000 >/dev/null 2>&1 &
      PF_PID=$!
      trap 'kill $PF_PID >/dev/null 2>&1 || true' EXIT
      sleep 2
      do_smoke "http://localhost:3000"
    fi
    ;;
  *)
    echo "Uso: $0 [local|eks]" >&2; exit 2
    ;;
esac

info "Todos os testes passaram."
