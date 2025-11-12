#!/bin/bash

# Setup GitHub OIDC Provider for AWS
# Este script verifica se o OIDC provider existe e cria se necessário

set -e

AWS_REGION="us-east-1"
OIDC_URL="https://token.actions.githubusercontent.com"

echo "🔍 Verificando OIDC Provider existente..."

# Verificar se o provider já existe
if aws iam list-open-id-connect-providers --region $AWS_REGION --query "OpenIDConnectProviderList[?contains(Url, 'token.actions.githubusercontent.com')]" --output text | grep -q token.actions.githubusercontent.com; then
    echo " OIDC Provider já existe"
    PROVIDER_ARN=$(aws iam list-open-id-connect-providers --region $AWS_REGION --query "OpenIDConnectProviderList[?contains(Url, 'token.actions.githubusercontent.com')].Arn" --output text)
    echo "📋 Provider ARN: $PROVIDER_ARN"
else
    echo " OIDC Provider não encontrado. Criando..."
    
    # Obter o certificado thumbprint do GitHub
    echo "🔐 Obtendo thumbprint do certificado..."
    THUMBPRINT=$(echo | openssl s_client -servername token.actions.githubusercontent.com -connect token.actions.githubusercontent.com:443 2>/dev/null | openssl x509 -fingerprint -noout -sha1 | sed 's/://g' | cut -d= -f2 | tr '[:upper:]' '[:lower:]')
    
    # Criar o OIDC Provider
    echo "🏗 Criando OIDC Provider..."
    PROVIDER_ARN=$(aws iam create-open-id-connect-provider \
        --url $OIDC_URL \
        --client-id-list sts.amazonaws.com \
        --thumbprint-list $THUMBPRINT \
        --tags Key=Name,Value="GitHub Actions OIDC" Key=Purpose,Value="GitHub Actions Authentication" \
        --query 'OpenIDConnectProviderArn' \
        --output text)
    
    echo " OIDC Provider criado com sucesso!"
    echo "📋 Provider ARN: $PROVIDER_ARN"
fi

echo ""
echo "🔧 Verificando role GitHubActionsRole..."

# Verificar se o role existe
if aws iam get-role --role-name GitHubActionsRole --region $AWS_REGION >/dev/null 2>&1; then
    echo " Role GitHubActionsRole já existe"
    
    # Verificar a trust policy do role
    echo "🔍 Verificando trust policy do role..."
    TRUST_POLICY=$(aws iam get-role --role-name GitHubActionsRole --query 'Role.AssumeRolePolicyDocument' --output json)
    
    if echo "$TRUST_POLICY" | grep -q "token.actions.githubusercontent.com"; then
        echo " Trust policy configurada corretamente"
    else
        echo " Trust policy precisa ser atualizada"
        echo "🔧 Atualizando trust policy..."
        
        # Criar a nova trust policy
        cat > /tmp/github-trust-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "$PROVIDER_ARN"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                },
                "StringLike": {
                    "token.actions.githubusercontent.com:sub": [
                        "repo:peddepri/case:ref:refs/heads/*",
                        "repo:peddepri/case:ref:refs/tags/*",
                        "repo:peddepri/case:environment:*",
                        "repo:peddepri/case:pull_request"
                    ]
                }
            }
        }
    ]
}
EOF
        
        aws iam update-assume-role-policy \
            --role-name GitHubActionsRole \
            --policy-document file:///tmp/github-trust-policy.json
        
        echo " Trust policy atualizada"
        rm /tmp/github-trust-policy.json
    fi
else
    echo " Role GitHubActionsRole não existe. Execute o Terraform primeiro."
    exit 1
fi

echo ""
echo "🎉 Configuração OIDC concluída!"
echo "📋 Role ARN: arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/GitHubActionsRole"
echo ""
echo "  Certifique-se de que o GitHub Actions tem as seguintes configurações:"
echo "   - role-to-assume: arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/GitHubActionsRole"
echo "   - aws-region: $AWS_REGION"
echo "   - permissions: id-token: write, contents: read"