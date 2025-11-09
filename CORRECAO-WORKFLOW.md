# Correcao do Workflow Build & Push Images

## Problema Identificado

O erro "Credentials could not be loaded" indica que o secret `AWS_ROLE_TO_ASSUME` nao esta configurado no GitHub ou o IAM Role nao existe na AWS.

## Solucoes

### 1. Verificar se o IAM Role existe na AWS

Execute localmente (com AWS CLI configurado):

```bash
aws sts get-caller-identity
# Anote o Account ID

aws iam get-role --role-name GitHubActionsRole
# Se retornar erro, execute o setup
```

### 2. Executar setup do OIDC (se necessario)

```bash
chmod +x setup-github-oidc.sh
./setup-github-oidc.sh
```

Este script cria:
- OIDC Identity Provider no IAM
- Role "GitHubActionsRole" 
- Trust policy para o repositorio peddepri/case
- Policies necessarias para EKS, ECR, etc.

### 3. Configurar Secret no GitHub

1. Va para: https://github.com/peddepri/case/settings/secrets/actions
2. Clique "New repository secret"
3. Name: `AWS_ROLE_TO_ASSUME`
4. Value: `arn:aws:iam::918859180133:role/GitHubActionsRole`
5. Clique "Add secret"

### 4. Testar o Workflow

Apos configurar o secret, execute o workflow manualmente:

1. Va para Actions tab
2. Selecione "Build & Push Images"  
3. Click "Run workflow"
4. Escolha service: "all"
5. Click "Run workflow"

## Workflow Corrigido

O workflow foi atualizado para:
- Incluir aplicacao mobile
- Usar caminhos corretos: `domains/apps/app/backend`
- Tags corretas no ECR: `case-backend`, `case-frontend`, `case-mobile`
- Melhor tratamento de erros

## Verificacao Final

Se ainda houver problemas:

1. Verifique logs do job que falhou
2. Confirme que o secret esta visivel em Settings > Secrets
3. Verifique se o Account ID esta correto (918859180133)
4. Confirme que o role tem as permissions necessarias

O erro devera ser resolvido apos configurar o secret `AWS_ROLE_TO_ASSUME` corretamente.