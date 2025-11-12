#!/usr/bin/env bash
set -euo pipefail

# Idempotently import existing AWS resources into Terraform state to avoid AlreadyExists errors.
# Usage:
#   terraform-import-existing.sh [--skip-init] [--only=ecr,dynamodb,cw,kms] <tf_workdir> <aws_region> <project> <env> <cluster_name>
# Example:
#   terraform-import-existing.sh domains/infra/terraform/environments/dev us-east-1 case dev case-dev

SKIP_INIT=0
ONLY_SET="all"

# Parse optional flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-init)
      SKIP_INIT=1; shift ;;
    --only=*)
      ONLY_SET="${1#*=}"; shift ;;
    --help|-h)
      echo "Usage: $0 [--skip-init] [--only=ecr,dynamodb,cw,kms] <tf_workdir> <aws_region> <project> <env> <cluster_name>"; exit 0 ;;
    *) break ;;
  esac
done

TF_DIR=${1:-"domains/infra/terraform/environments/dev"}
AWS_REGION=${2:-"us-east-1"}
PROJECT=${3:-"case"}
ENV=${4:-"dev"}
CLUSTER_NAME=${5:-"${PROJECT}-${ENV}"}

cd "$TF_DIR"

echo "[import] Working dir: $(pwd)"
echo "[import] Region: $AWS_REGION | Project: $PROJECT | Env: $ENV | Cluster: $CLUSTER_NAME"

# Ensure Terraform plugins are installed
if ! command -v terraform >/dev/null 2>&1; then
  echo "[import] Error: terraform not found in PATH" >&2
  exit 1
fi

if [[ "$SKIP_INIT" != "1" ]]; then
  echo "[import] Initializing Terraform providers (upgrade lockfile)..."
  terraform init -input=false -upgrade -no-color
else
  echo "[import] Skipping terraform init (--skip-init)"
fi

state_has() {
  terraform state list 2>/dev/null | grep -Fx -- "$1" >/dev/null 2>&1
}

maybe_import() {
  local addr="$1" id="$2"
  if state_has "$addr"; then
    echo "[import] Skip (already in state): $addr"
  else
    echo "[import] Importing: $addr => $id"
    terraform import -no-color "$addr" "$id" || true
  fi
}

echo "[import] Ensuring AWS CLI region context..."
export AWS_REGION

if ! command -v aws >/dev/null 2>&1; then
  echo "[import] Error: aws CLI not found in PATH" >&2
  exit 1
fi

# Avoid MSYS2 path conversion breaking CloudWatch log group names like /aws/eks/...
export MSYS2_ARG_CONV_EXCL='*'

# Selectors for what to import
do_ecr=0; do_ddb=0; do_cw=0; do_kms=0
if [[ "$ONLY_SET" == "all" ]]; then do_ecr=1; do_ddb=1; do_cw=1; do_kms=1; else
  IFS=',' read -r -a parts <<< "$ONLY_SET"
  for p in "${parts[@]}"; do
    case "$p" in ecr) do_ecr=1 ;; dynamodb|ddb) do_ddb=1 ;; cw|logs) do_cw=1 ;; kms) do_kms=1 ;; esac
  done
fi

# ECR repositories
if [[ $do_ecr -eq 1 ]]; then
for repo in backend frontend mobile; do
  NAME="${PROJECT}-${repo}"
  if aws ecr describe-repositories --repository-names "$NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
    maybe_import "aws_ecr_repository.${repo}" "$NAME"
  else
    echo "[import] ECR repo not found (ok to create later): $NAME"
  fi
done
fi

# DynamoDB table (e.g., case-orders-dev)
if [[ $do_ddb -eq 1 ]]; then
  TABLE_NAME="${PROJECT}-orders-${ENV}"
  if aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
    maybe_import "aws_dynamodb_table.orders" "$TABLE_NAME"
  else
    echo "[import] DynamoDB table not found (ok to create later): $TABLE_NAME"
  fi
fi

# CloudWatch Log Group for EKS
if [[ $do_cw -eq 1 ]]; then
  LOG_GROUP="/aws/eks/${CLUSTER_NAME}/cluster"
  # Use exact match via JMESPath to avoid path conversion issues and false positives
  if aws logs describe-log-groups --log-group-name-prefix "/aws/eks/" --region "$AWS_REGION" \
    --query "logGroups[?logGroupName=='${LOG_GROUP}'].logGroupName" --output text | grep -Fx "$LOG_GROUP" >/dev/null 2>&1; then
    maybe_import "module.eks.module.eks.aws_cloudwatch_log_group.this[0]" "$LOG_GROUP"
  else
    echo "[import] CW log group not found (ok to create later): $LOG_GROUP"
  fi
fi

# KMS alias/key used by EKS encryption (alias/eks/<cluster>)
if [[ $do_kms -eq 1 ]]; then
  ALIAS="alias/eks/${CLUSTER_NAME}"
  # Extract TargetKeyId safely; returns 'None' if not found
  TARGET_KEY_ID=$(aws kms list-aliases --region "$AWS_REGION" \
    --query "Aliases[?AliasName=='${ALIAS}'].TargetKeyId | [0]" --output text 2>/dev/null || echo "None")
  if [[ -n "$TARGET_KEY_ID" && "$TARGET_KEY_ID" != "None" ]]; then
    # Import only the alias; the KMS key resource may not be explicitly configured in this stack
    maybe_import "module.eks.module.eks.module.kms.aws_kms_alias.this[\"cluster\"]" "$ALIAS"
  else
    echo "[import] KMS alias not found (module may create): $ALIAS"
  fi
fi

echo "[import] Done."
