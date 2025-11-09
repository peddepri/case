#!/bin/bash

# Script para criar IAM Role para GitHub Actions OIDC
# Execute este script antes de configurar os secrets

set -e

# Variáveis
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "REPLACE_WITH_YOUR_ACCOUNT_ID")
REPO_OWNER="peddepri"
REPO_NAME="case"
ROLE_NAME="GitHubActionsRole"

echo "==================================="
echo "  CRIANDO IAM ROLE PARA GITHUB ACTIONS"
echo "==================================="

# 1. Criar OIDC Identity Provider (se não existir)
echo "📋 Verificando OIDC Provider..."
if ! aws iam get-open-id-connect-provider --open-id-connect-provider-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com" >/dev/null 2>&1; then
    echo "📝 Criando OIDC Provider..."
    aws iam create-open-id-connect-provider \
        --url https://token.actions.githubusercontent.com \
        --client-id-list sts.amazonaws.com \
        --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
    echo "✅ OIDC Provider criado"
else
    echo "✅ OIDC Provider já existe"
fi

# 2. Criar Trust Policy
echo "📋 Criando Trust Policy..."
cat > /tmp/trust-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
            },
            "Action": "sts:AssumeRole",
            "Condition": {
                "StringEquals": {
                    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                },
                "StringLike": {
                    "token.actions.githubusercontent.com:sub": [
                        "repo:${REPO_OWNER}/${REPO_NAME}:ref:refs/heads/main",
                        "repo:${REPO_OWNER}/${REPO_NAME}:ref:refs/heads/refactor/*",
                        "repo:${REPO_OWNER}/${REPO_NAME}:environment:dev",
                        "repo:${REPO_OWNER}/${REPO_NAME}:environment:prod"
                    ]
                }
            }
        }
    ]
}
EOF

# 3. Criar IAM Role
echo "📋 Criando IAM Role..."
if aws iam create-role \
    --role-name "${ROLE_NAME}" \
    --assume-role-policy-document file:///tmp/trust-policy.json \
    --description "Role for GitHub Actions OIDC" >/dev/null 2>&1; then
    echo "✅ Role ${ROLE_NAME} criado"
else
    echo "⚠️  Role ${ROLE_NAME} já existe, atualizando trust policy..."
    aws iam update-assume-role-policy \
        --role-name "${ROLE_NAME}" \
        --policy-document file:///tmp/trust-policy.json
fi

# 4. Anexar policies necessárias
echo "📋 Anexando policies..."
POLICIES=(
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
    "arn:aws:iam::aws:policy/AmazonVPCFullAccess"
    "arn:aws:iam::aws:policy/IAMFullAccess"
)

for policy in "${POLICIES[@]}"; do
    aws iam attach-role-policy --role-name "${ROLE_NAME}" --policy-arn "${policy}" || true
done

# 5. Criar policy customizada para EKS e Terraform
echo "📋 Criando policy customizada..."
cat > /tmp/custom-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "eks:*",
                "ec2:*",
                "iam:*",
                "dynamodb:*",
                "ecr:*",
                "logs:*",
                "s3:*",
                "kms:*"
            ],
            "Resource": "*"
        }
    ]
}
EOF

aws iam put-role-policy \
    --role-name "${ROLE_NAME}" \
    --policy-name "GitHubActionsCustomPolicy" \
    --policy-document file:///tmp/custom-policy.json

# 6. Mostrar informações finais
echo ""
echo "✅ SETUP COMPLETO!"
echo ""
echo "📋 Configure estes secrets no GitHub:"
echo "   AWS_ROLE_TO_ASSUME: arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"
echo ""
echo "🔗 URL para configurar secrets:"
echo "   https://github.com/${REPO_OWNER}/${REPO_NAME}/settings/secrets/actions"
echo ""
echo "⚡ Próximos passos:"
echo "   1. Configure os secrets no GitHub"
echo "   2. Execute: cd domains/infra/terraform/environments/dev"
echo "   3. Execute: terraform init && terraform apply"
echo ""

# Limpar arquivos temporários
rm -f /tmp/trust-policy.json /tmp/custom-policy.json