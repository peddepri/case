#!/usr/bin/env bash
set -euo pipefail

OUT="scripts/aws-config.env"

read -rp "AWS Access Key ID: " AWS_ACCESS_KEY_ID
read -rsp "AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY; echo
read -rsp "AWS Session Token (leave empty if not using MFA/STS): " AWS_SESSION_TOKEN || true; echo
read -rp "AWS Default Region [us-east-1]: " AWS_DEFAULT_REGION; AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-us-east-1}
read -rp "AWS Profile [default]: " AWS_PROFILE; AWS_PROFILE=${AWS_PROFILE:-default}

mkdir -p scripts
{
  echo "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID"
  echo "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY"
  if [ -n "${AWS_SESSION_TOKEN:-}" ]; then echo "AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN"; fi
  echo "AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION"
  echo "AWS_PROFILE=$AWS_PROFILE"
} > "$OUT"

echo "Wrote $OUT (ignored by .gitignore)."
