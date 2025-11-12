#!/usr/bin/env bash
set -euo pipefail

# This script installs AWS CLI v2 on Windows (Git Bash) or Linux, updates PATH, and shows verification steps.
# Usage: ./scripts/setup-aws-cli-v2.sh

OS_LOWER="$(uname -s | tr '[:upper:]' '[:lower:]')"
AWS_V2_DIR="/c/Program Files/Amazon/AWSCLIV2"

info() { printf "\e[32m[INFO]\e[0m %s\n" "$*"; }
warn() { printf "\e[33m[WARN]\e[0m %s\n" "$*"; }
err()  { printf "\e[31m[ERROR]\e[0m %s\n" "$*"; }

already_v2() {
  if command -v aws >/dev/null 2>&1; then
    local ver
    ver=$(aws --version 2>&1 | head -n1)
    if echo "$ver" | grep -q 'aws-cli/2'; then
      info "AWS CLI v2 já instalado: $ver"
      return 0
    fi
  fi
  return 1
}

if already_v2; then
  exit 0
fi

if [[ "$OS_LOWER" == *mingw* || "$OS_LOWER" == *msys* ]]; then
  info "Detectado ambiente Windows (Git Bash).";
  if [[ -d "$AWS_V2_DIR" && -f "$AWS_V2_DIR/aws.exe" ]]; then
    info "Diretório do AWS CLI v2 já existe. Ajustando PATH temporário."
    export PATH="$AWS_V2_DIR:$PATH"
  else
    warn "AWS CLI v2 não encontrado. Baixando installer MSI (requer interação GUI)."
    warn "Baixe manualmente: https://awscli.amazonaws.com/AWSCLIV2.msi e execute o instalador."
    exit 1
  fi
else
  info "Tentando instalação para Linux/macos..."
  TMP_DIR="$(mktemp -d)"
  pushd "$TMP_DIR" >/dev/null
  curl -fsSLO "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
  unzip awscli-exe-linux-x86_64.zip >/dev/null
  sudo ./aws/install
  popd >/dev/null
fi

if ! command -v aws >/dev/null 2>&1; then
  err "AWS CLI v2 ainda não no PATH. Adicione manualmente: export PATH=\"$AWS_V2_DIR:$PATH\"";
  exit 1
fi

VER_OUT="$(aws --version 2>&1 | head -n1)"
info "Instalação/ajuste concluído: $VER_OUT"

cat <<'EOF'
Passos seguintes:
1. Atualize kubeconfig:
   aws eks update-kubeconfig --region us-east-1 --name case-dev
2. Teste cluster:
   kubectl get nodes
3. Deploy Helm:
   helm upgrade --install case-platform ./domains/platform/helm \
     --namespace case --create-namespace \
     -f ./domains/platform/helm/values-dev.yaml
EOF
