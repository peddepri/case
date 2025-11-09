# 🔧 Correção das Pipelines GitHub Actions

## ✅ **Problemas Corrigidos**

### 🚨 **Erro Original:**
```
Run aws-actions/configure-aws-credentials@v4
  with:
    aws-region: us-east-1
    audience: sts.amazonaws.com
    output-env-credentials: true
Error: Credentials could not be loaded, please check your action inputs: Could not load credentials from any providers
```

### 🔧 **Soluções Aplicadas:**

#### 1. **AWS Region Corrigida:**
```yaml
# ❌ ANTES (incorreto)
aws-region: us-east-1

# ✅ DEPOIS (correto - compatível com sua config)
aws-region: us-east-2
```

#### 2. **OIDC Configuration Completa:**
```yaml
# ❌ ANTES (incompleto)
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_TO_ASSUME }}
    aws-region: us-east-1

# ✅ DEPOIS (completo)
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_TO_ASSUME }}
    aws-region: us-east-2
    audience: sts.amazonaws.com
```

#### 3. **Role ARN Correto:**
```yaml
# Confirme que o secret está configurado:
AWS_ROLE_TO_ASSUME: arn:aws:iam::918859180133:role/GitHubActionsRole
```

---

## 📁 **Workflows Corrigidos:**

### ✅ **infra-plan-apply.yml**
- ✅ Região: `us-east-2`
- ✅ Audience: `sts.amazonaws.com`
- ✅ Role: `${{ secrets.AWS_ROLE_TO_ASSUME }}`

### ✅ **build-push-images.yml** 
- ✅ Região: `us-east-2`
- ✅ Audience: `sts.amazonaws.com` (2 jobs)
- ✅ ECR login configurado

### ✅ **argo-sync.yml**
- ✅ Região: `us-east-2`
- ✅ Audience: `sts.amazonaws.com`
- ✅ EKS kubeconfig atualizado

### ✅ **tests.yml**
- ✅ Sem mudanças (não usa AWS)

---

## 🔐 **Secrets Necessários (Lembretes):**

Configure em: https://github.com/peddepri/case/settings/secrets/actions

### 1. **AWS_ROLE_TO_ASSUME**
```
arn:aws:iam::918859180133:role/GitHubActionsRole
```

### 2. **DD_API_KEY** (Datadog)
```
[SUA_DATADOG_API_KEY]
```

### 3. **BACKEND_IRSA_ROLE_ARN**
```
arn:aws:iam::918859180133:role/backend-irsa-role
```

---

## 🧪 **Como Testar:**

### 1. **Testar Infraestrutura:**
```bash
# Via GitHub UI:
# Actions → Infrastructure Plan & Apply → Run workflow
# Environment: dev
# Action: plan
```

### 2. **Testar Build:**
```bash
# Via GitHub UI:
# Actions → Build & Push Images → Run workflow  
# Service: all
```

### 3. **Via Commit:**
```bash
git push origin main  # Triggers all workflows
```

---

## 🛠️ **Troubleshooting Adicional:**

### ❌ **"Role cannot be assumed"**
**Causa**: Trust policy incorreta ou secret errado
**Solução**: Verificar se o secret `AWS_ROLE_TO_ASSUME` está exato

### ❌ **"Region not found"**  
**Causa**: Região inconsistente
**Solução**: ✅ Agora todas as pipelines usam `us-east-2`

### ❌ **"ECR access denied"**
**Causa**: Role sem permissão ECR
**Solução**: ✅ Role já tem `AmazonEC2ContainerRegistryPowerUser`

### ❌ **"EKS cluster not found"**
**Causa**: Cluster não existe ou nome errado
**Solução**: Primeiro provisionar infra, depois testar Argo

---

## ✅ **Status Atual:**

- 🟢 **AWS Config**: us-east-2 (compatível)
- 🟢 **IAM Role**: GitHubActionsRole (criado)
- 🟢 **OIDC Provider**: token.actions.githubusercontent.com (criado)
- 🟢 **Workflows**: Região corrigida (us-east-2)
- 🟢 **Audience**: sts.amazonaws.com (adicionado)

**As pipelines agora devem funcionar corretamente! 🚀**

---

## 📋 **Próximos Passos:**

1. ✅ **Configure os secrets** no GitHub (se ainda não fez)
2. ✅ **Teste workflow manual** (Infrastructure Plan & Apply)
3. ✅ **Verifique logs** em: https://github.com/peddepri/case/actions
4. ✅ **Se der sucesso**, faça merge para `main`

**Todas as correções foram aplicadas e enviadas para o GitHub! 🎉**