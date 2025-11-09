#!/bin/bash

# Script para testar configuracao do GitHub Actions OIDC
set -e

echo "Testando configuracao GitHub Actions..."

# Verificar se o role existe
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ROLE_NAME="GitHubActionsRole"
ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"

echo "Account ID: ${AWS_ACCOUNT_ID}"
echo "Role ARN: ${ROLE_ARN}"

# Verificar se o role existe
if aws iam get-role --role-name "${ROLE_NAME}" >/dev/null 2>&1; then
    echo "Role ${ROLE_NAME} existe"
    
    # Verificar trust policy
    echo "Trust policy:"
    aws iam get-role --role-name "${ROLE_NAME}" --query 'Role.AssumeRolePolicyDocument'
    
    # Verificar policies anexadas
    echo "Policies anexadas:"
    aws iam list-attached-role-policies --role-name "${ROLE_NAME}"
    
else
    echo "ERRO: Role ${ROLE_NAME} nao existe"
    echo "Execute: ./setup-github-oidc.sh"
    exit 1
fi

echo ""
echo "Configure este secret no GitHub:"
echo "AWS_ROLE_TO_ASSUME=${ROLE_ARN}"
echo ""
echo "URL: https://github.com/peddepri/case/settings/secrets/actions"