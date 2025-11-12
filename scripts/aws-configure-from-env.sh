#!/usr/bin/env bash
set -euo pipefail

# Configure AWS CLI (credentials and region) from a .env file
# Usage: ./scripts/aws-configure-from-env.sh [path-to-env]
# Default env path: scripts/aws-config.env

ENV_FILE="${1:-scripts/aws-config.env}"

info() { printf "\e[32m[INFO]\e[0m %s\n" "$*"; }
warn() { printf "\e[33m[WARN]\e[0m %s\n" "$*"; }
err()  { printf "\e[31m[ERROR]\e[0m %s\n" "$*"; }

if [ ! -f "$ENV_FILE" ]; then
  err "Env file not found: $ENV_FILE";
  echo "Create it from scripts/aws-config.env.example and fill your values.";
  exit 1;
fi

# Load variables (allow comments)
set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

AWS_PROFILE="${AWS_PROFILE:-default}"
AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

# Validate required vars
: "${AWS_ACCESS_KEY_ID:?AWS_ACCESS_KEY_ID is required in $ENV_FILE}"
: "${AWS_SECRET_ACCESS_KEY:?AWS_SECRET_ACCESS_KEY is required in $ENV_FILE}"

AWS_BIN=${AWS_CMD:-aws}
if ! command -v "$AWS_BIN" >/dev/null 2>&1; then
  warn "AWS CLI not found in PATH. If you have CLI v2, set AWS_CMD to its path, e.g.:"
  warn "  export AWS_CMD=\"/c/Program Files/Amazon/AWSCLIV2/aws.exe\""
fi

# Configure using aws configure set (supports session token if provided)
"$AWS_BIN" configure set aws_access_key_id "$AWS_ACCESS_KEY_ID" --profile "$AWS_PROFILE"
"$AWS_BIN" configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY" --profile "$AWS_PROFILE"
if [ -n "${AWS_SESSION_TOKEN:-}" ]; then
  "$AWS_BIN" configure set aws_session_token "$AWS_SESSION_TOKEN" --profile "$AWS_PROFILE"
fi
"$AWS_BIN" configure set region "$AWS_DEFAULT_REGION" --profile "$AWS_PROFILE"

info "Wrote credentials/region to profile '$AWS_PROFILE'"

# Show summary
"$AWS_BIN" configure list --profile "$AWS_PROFILE" || true

cat <<EOF

Next steps:
- Use the profile in this shell:
    export AWS_PROFILE=$AWS_PROFILE
- Update kubeconfig and verify access:
    $AWS_BIN eks update-kubeconfig --region $AWS_DEFAULT_REGION --name case-dev
    kubectl get nodes
- Build and push images (script will read scripts/aws-config.env automatically):
    ./build-and-push-images.sh
EOF
