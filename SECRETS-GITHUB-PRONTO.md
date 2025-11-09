# ✅ CONFIGURAÇÃO COMPLETA - SECRETS DO GITHUB

## 🎯 Status: IAM Role Criado com Sucesso!

**Account ID AWS**: `918859180133`  
**Role ARN**: `arn:aws:iam::918859180133:role/GitHubActionsRole`

---

## 🔐 Configure os Secrets no GitHub

### 🔗 URL de Configuração:
**https://github.com/peddepri/case/settings/secrets/actions**

### 1. **AWS_ROLE_TO_ASSUME**
```
arn:aws:iam::918859180133:role/GitHubActionsRole
```

### 2. **DD_API_KEY** (Datadog API Key)
```
[COLOQUE_SUA_DATADOG_API_KEY_AQUI]
```

### 3. **BACKEND_IRSA_ROLE_ARN** (Para EKS Service Account)
```
arn:aws:iam::918859180133:role/backend-irsa-role
```

---

## 📋 Como Configurar os Secrets

### Passo a Passo:

1. **Acesse**: https://github.com/peddepri/case/settings/secrets/actions
2. **Clique**: "New repository secret"
3. **Configure cada secret**:
   - **Name**: `AWS_ROLE_TO_ASSUME`
   - **Secret**: `arn:aws:iam::918859180133:role/GitHubActionsRole`
   - Clique "Add secret"

4. **Repita para DD_API_KEY e BACKEND_IRSA_ROLE_ARN**

---

## 🔑 Como Obter a Datadog API Key

### Método 1: Via Console Datadog
1. Acesse: https://app.datadoghq.com/organization-settings/api-keys
2. Clique "New Key"
3. Nome: `GitHub Actions Key`
4. Copie o valor gerado

### Método 2: Via CLI (se já tiver)
```bash
# Listar keys existentes
curl -X GET "https://api.datadoghq.com/api/v1/api_key" \
  -H "DD-API-KEY: {your_api_key}" \
  -H "DD-APPLICATION-KEY: {your_app_key}"
```

---

## 🚀 Próximos Passos

### 1. Teste a Configuração
```bash
# Fazer commit para testar workflows
git add .
git commit -m "Configure GitHub Actions secrets"
git push origin main
```

### 2. Monitorar Execução
- **Actions**: https://github.com/peddepri/case/actions
- **Logs**: Verifique se a autenticação AWS funciona

### 3. Deploy da Infraestrutura
```bash
# Depois que os secrets funcionarem
cd domains/infra/terraform/environments/dev
terraform init
terraform plan
terraform apply
```

---

## 🛠️ Troubleshooting

### ❌ Erro: "could not assume role"
- ✅ **Verificar**: Secret `AWS_ROLE_TO_ASSUME` está correto
- ✅ **Verificar**: Repository está em `peddepri/case`
- ✅ **Verificar**: Branch é `main` ou `refactor/*`

### ❌ Erro: "access denied"  
- ✅ **Verificar**: Role tem todas as policies anexadas
- ✅ **Verificar**: Custom policy foi criada

### ❌ Erro: Datadog connection failed
- ✅ **Verificar**: `DD_API_KEY` é válida e ativa
- ✅ **Verificar**: Key tem permissões para criar recursos

---

## 📊 Validação Final

### Comandos para Verificar:
```bash
# Verificar Role existe
aws iam get-role --role-name GitHubActionsRole

# Verificar policies anexadas
aws iam list-attached-role-policies --role-name GitHubActionsRole

# Verificar OIDC Provider
aws iam list-open-id-connect-providers
```

### Status Esperado:
- ✅ OIDC Provider: `token.actions.githubusercontent.com`
- ✅ IAM Role: `GitHubActionsRole`
- ✅ Policies: EKS, ECR, VPC, IAM + Custom
- ✅ Secrets GitHub: 3 secrets configurados

---

## 🎉 Tudo Pronto!

Agora você pode executar os workflows do GitHub Actions que irão:
1. **Provisionar infraestrutura** via Terraform
2. **Fazer build e push** das imagens Docker  
3. **Sincronizar Argo CD** para deploy
4. **Executar testes** automatizados

**Boa sorte com o deploy! 🚀**