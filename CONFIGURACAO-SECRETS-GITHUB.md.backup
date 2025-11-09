# 🔐 Configuração de Secrets do GitHub

## Pré-requisitos

Você precisa criar um **IAM Role** na AWS para autenticação OIDC do GitHub Actions.

## 1. 🏗️ Criar IAM Role na AWS (Fazer uma vez)

### Via AWS CLI:

```bash
# 1. Obter Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Account ID: $AWS_ACCOUNT_ID"

# 2. Criar OIDC Provider (se não existir)
aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# 3. Criar Trust Policy
cat > trust-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::$AWS_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
            },
            "Action": "sts:AssumeRole",
            "Condition": {
                "StringEquals": {
                    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                },
                "StringLike": {
                    "token.actions.githubusercontent.com:sub": [
                        "repo:peddepri/case:ref:refs/heads/main",
                        "repo:peddepri/case:ref:refs/heads/refactor/*",
                        "repo:peddepri/case:environment:dev",
                        "repo:peddepri/case:environment:prod"
                    ]
                }
            }
        }
    ]
}
EOF

# 4. Criar Role
aws iam create-role \
    --role-name GitHubActionsRole \
    --assume-role-policy-document file://trust-policy.json \
    --description "Role for GitHub Actions OIDC"

# 5. Anexar policies
aws iam attach-role-policy --role-name GitHubActionsRole --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
aws iam attach-role-policy --role-name GitHubActionsRole --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser
aws iam attach-role-policy --role-name GitHubActionsRole --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess
aws iam attach-role-policy --role-name GitHubActionsRole --policy-arn arn:aws:iam::aws:policy/IAMFullAccess

# 6. Criar policy customizada
cat > custom-policy.json << EOF
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
    --role-name GitHubActionsRole \
    --policy-name GitHubActionsCustomPolicy \
    --policy-document file://custom-policy.json
```

### Via Console AWS:

1. **Acesse IAM Console**: https://console.aws.amazon.com/iam/
2. **Identity Providers** → Create Provider
   - Provider Type: `OpenID Connect`
   - Provider URL: `https://token.actions.githubusercontent.com`
   - Audience: `sts.amazonaws.com`
3. **Roles** → Create Role
   - Trusted Entity: `Web identity`
   - Identity Provider: `token.actions.githubusercontent.com`
   - Audience: `sts.amazonaws.com`
   - GitHub Organization: `peddepri`
   - GitHub Repository: `case`

## 2. 🔑 Configurar Secrets no GitHub

### Acesse: https://github.com/peddepri/case/settings/secrets/actions

Configure os seguintes **Repository Secrets**:

### **AWS_ROLE_TO_ASSUME**
```
arn:aws:iam::[SEU_ACCOUNT_ID]:role/GitHubActionsRole
```

### **DD_API_KEY** (Datadog)
```
[SUA_DATADOG_API_KEY]
```

### **BACKEND_IRSA_ROLE_ARN** (Para EKS)
```
arn:aws:iam::[SEU_ACCOUNT_ID]:role/backend-irsa-role
```

## 3. 📋 Como Obter os Valores

### AWS Account ID:
```bash
aws sts get-caller-identity --query Account --output text
```

### Datadog API Key:
1. Acesse: https://app.datadoghq.com/organization-settings/api-keys
2. Crie uma nova API Key
3. Copie o valor

### Role ARN (depois de criar a role):
```bash
aws iam get-role --role-name GitHubActionsRole --query Role.Arn --output text
```

## 4. ✅ Validação

Depois de configurar tudo, teste com:

```bash
# Test infrastructure workflow
git push origin main

# Verifique nos Actions:
# https://github.com/peddepri/case/actions
```

## 5. 🛠️ Troubleshooting

### Erro "could not assume role":
- Verifique se o OIDC Provider foi criado
- Confirme se o repository está correto na trust policy
- Verifique se o secret AWS_ROLE_TO_ASSUME está correto

### Erro "access denied":
- Verifique se as policies estão anexadas à role
- Confirme se a custom policy foi criada

### Erro Datadog:
- Verifique se DD_API_KEY é válida
- Confirme se tem permissões para criar recursos no Datadog