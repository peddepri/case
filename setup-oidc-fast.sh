#!/bin/bash

# Script otimizado para criar IAM Role para GitHub Actions OIDC no Git Bash
set -e

# Variáveis
AWS_ACCOUNT_ID="918859180133"
REPO_OWNER="peddepri"
REPO_NAME="case"
ROLE_NAME="GitHubActionsRole"

echo "==================================="
echo " CRIANDO IAM ROLE PARA GITHUB ACTIONS"
echo "==================================="

# Função otimizada para AWS CLI
run_aws() {
    cmd.exe /c "aws $*" 2>/dev/null || {
        echo "Erro executando: aws $*"
        return 1
    }
}

# 1. Verificar e criar OIDC Provider
echo " Verificando OIDC Provider..."
OIDC_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

if ! run_aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN" >/dev/null 2>&1; then
    echo " Criando OIDC Provider..."
    run_aws iam create-open-id-connect-provider \
        --url "https://token.actions.githubusercontent.com" \
        --client-id-list "sts.amazonaws.com" \
        --thumbprint-list "6938fd4d98bab03faadb97b34396831e3780aea1"
    echo " OIDC Provider criado"
else
    echo " OIDC Provider já existe"
fi

# 2. Criar Trust Policy em arquivo temporário local
echo " Criando Trust Policy..."
TRUST_POLICY=$(cat << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${OIDC_ARN}"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:${REPO_OWNER}/${REPO_NAME}:*"
          ]
        }
      }
    }
  ]
}
EOF
)

# Salvar policy em arquivo temporário
echo "$TRUST_POLICY" > ./trust-policy-temp.json

# 3. Criar ou atualizar IAM Role
echo " Criando/Atualizando IAM Role..."
if run_aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document "file://trust-policy-temp.json" \
    --description "Role for GitHub Actions OIDC" >/dev/null 2>&1; then
    echo " Role $ROLE_NAME criado"
else
    echo " Role $ROLE_NAME já existe, atualizando trust policy..."
    run_aws iam update-assume-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-document "file://trust-policy-temp.json"
fi

# 4. Anexar policies AWS gerenciadas essenciais
echo " Anexando policies..."
POLICIES=(
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
)

for policy in "${POLICIES[@]}"; do
    echo "   Anexando $policy..."
    run_aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn "$policy" || echo "   Policy já anexada"
done

# 5. Criar policy customizada
echo " Criando policy customizada..."
CUSTOM_POLICY=$(cat << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:*",
        "ec2:Describe*",
        "ec2:CreateTags",
        "iam:GetRole",
        "iam:PassRole",
        "ecr:*",
        "logs:*",
        "s3:GetObject",
        "s3:PutObject",
        "dynamodb:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
)

echo "$CUSTOM_POLICY" > ./custom-policy-temp.json

run_aws iam put-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-name "GitHubActionsCustomPolicy" \
    --policy-document "file://custom-policy-temp.json"

# 6. Limpar arquivos temporários
rm -f ./trust-policy-temp.json ./custom-policy-temp.json

# 7. Mostrar resultado
echo ""
echo "========================================="
echo " SETUP COMPLETO COM SUCESSO!"
echo "========================================="
echo ""
echo "PRÓXIMO PASSO OBRIGATÓRIO:"
echo "Configure este secret no GitHub Repository:"
echo ""
echo "Nome do Secret: AWS_ROLE_TO_ASSUME"
echo "Valor: arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"
echo ""
echo "URL: https://github.com/${REPO_OWNER}/${REPO_NAME}/settings/secrets/actions"
echo ""
echo "Após configurar o secret, suas pipelines do GitHub Actions"
echo "poderão se autenticar automaticamente na AWS!"
echo ""