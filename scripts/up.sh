#!/usr/bin/env bash
set -euo pipefail

MODE=${1:-local}
ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)

echo "[up] mode=${MODE}"

need_docker() {
  if ! docker info >/dev/null 2>&1; then
    echo "Docker engine não está em execução. Abra o Docker Desktop e tente novamente." >&2
    exit 1
  fi
}

wait_http() {
  local url=$1; local tries=${2:-60}
  for i in $(seq 1 "$tries"); do
    if curl -sf "$url" >/dev/null 2>&1; then
      echo "OK: $url"; return 0; fi
    printf '.'; sleep 2
  done
  echo "\nTimeout aguardando $url" >&2
  return 1
}

case "$MODE" in
  local)
    need_docker
    echo "[up] Subindo stack local (backend, frontend, dynamodb-local, datadog-agent)..."
    (cd "$ROOT_DIR" && docker compose up -d --build)
    echo "[up] Aguardando backend ficar saudável..."
    wait_http "http://localhost:3000/healthz"
    echo "[up] Frontend disponível em http://localhost:5173"
    ;;
  eks)
    echo "[up] Executando via toolbox (terraform/kubectl dentro do container)"
    # Build toolbox (terraform+awscli+kubectl+helm)
    docker compose -f "$ROOT_DIR/docker-compose.tools.yml" build tools
    # Terraform init/plan/apply
    "$ROOT_DIR/scripts/tf.sh" init -input=false
    "$ROOT_DIR/scripts/tf.sh" validate
    "$ROOT_DIR/scripts/tf.sh" plan -input=false
    "$ROOT_DIR/scripts/tf.sh" apply -input=false
    # Atualiza kubeconfig (grava em ~/.kube do host via volume)
    if [ -z "${EKS_CLUSTER_NAME:-}" ] || [ -z "${AWS_REGION:-}" ]; then
      echo "Defina EKS_CLUSTER_NAME e AWS_REGION no ambiente para configurar o kubeconfig." >&2
    else
      "$ROOT_DIR/scripts/aws.sh" eks update-kubeconfig --name "$EKS_CLUSTER_NAME" --region "$AWS_REGION"
      # Aplica namespace e manifests básicos (substitui placeholders de conta/região)
      "$ROOT_DIR/scripts/kubectl.sh" apply -f /workspace/k8s/namespace.yaml
      sed -e "s#<AWS_ACCOUNT_ID>#${AWS_ACCOUNT_ID:-000000000000}#g" -e "s#<AWS_REGION>#${AWS_REGION}#g" "$ROOT_DIR/k8s/backend-deployment.yaml" | "$ROOT_DIR/scripts/kubectl.sh" apply -f -
      sed -e "s#<AWS_ACCOUNT_ID>#${AWS_ACCOUNT_ID:-000000000000}#g" -e "s#<AWS_REGION>#${AWS_REGION}#g" "$ROOT_DIR/k8s/frontend-deployment.yaml" | "$ROOT_DIR/scripts/kubectl.sh" apply -f -
      "$ROOT_DIR/scripts/kubectl.sh" apply -f /workspace/k8s/ingress.yaml || true
      echo "[up] Deploy aplicado no EKS. Verifique rollout: ./scripts/kubectl.sh -n case get deploy,pods"
    fi
    ;;
  *)
    echo "Uso: $0 [local|eks]" >&2; exit 2;
    ;;
esac

echo "[up] Concluído."
