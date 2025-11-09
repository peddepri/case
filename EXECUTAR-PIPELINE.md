# 🚀 Guia de Execução da Pipeline EKS

## ✅ Status: PRONTO PARA EXECUÇÃO

A pipeline completa foi configurada e está pronta para provisionar a infraestrutura EKS na AWS e fazer deploy das aplicações.

## 📋 Pré-requisitos Confirmados

### AWS
- ✅ Account ID: `918859180133`
- ✅ Região: `us-east-2`
- ✅ EKS Cluster: `case-dev` (ATIVO)
- ✅ ECR: 3 repositórios com imagens latest
- ✅ IAM Role: `GitHubActionsRole` (OIDC configurado)

### GitHub
- ✅ Workflows criados e commitados
- ✅ Código pushado para repositório
- ⚠️ **PENDENTE**: Configurar secret `AWS_ROLE_TO_ASSUME`

## 🔧 Configuração Obrigatória no GitHub

### 1. Adicionar Secret no GitHub
1. Ir para: **Settings** → **Secrets and variables** → **Actions**
2. Clicar **New repository secret**
3. Nome: `AWS_ROLE_TO_ASSUME`
4. Valor: `arn:aws:iam::918859180133:role/GitHubActionsRole`
5. Salvar

### 2. Secrets Opcionais (se necessário)
```
DD_API_KEY = (sua chave API do Datadog)
BACKEND_IRSA_ROLE_ARN = (ARN do role IRSA se configurado)
```

## 🚀 Como Executar a Pipeline

### Opção 1: Pipeline Completa (RECOMENDADO)
1. **Ir para GitHub Actions**
   - Repository → Actions tab
   - Workflow: "Complete EKS Deployment Pipeline"

2. **Executar Workflow**
   - Clicar "Run workflow"
   - Action: `provision-and-deploy`
   - Environment: `dev`
   - Clicar "Run workflow" (botão verde)

3. **Acompanhar Execução**
   - Jobs executados em sequência:
     - 🏗️ `provision-infrastructure` (5-10 min)
     - 🐳 `build-images` (3-5 min)  
     - 🚀 `deploy-applications` (2-3 min)
     - ✅ `validate-deployment` (2-3 min)

### Opção 2: Deploy Apenas Apps (se infra já existir)
1. GitHub Actions → "Complete EKS Deployment Pipeline"
2. Action: `deploy-only`
3. Environment: `dev`
4. Executar

### Opção 3: Teste da Infraestrutura
1. GitHub Actions → "Test EKS Deployment"  
2. Test type: `full-validation`
3. Executar

## 📊 O que a Pipeline Fará

### 1. Provisionar Infraestrutura (5-10 min)
```bash
# Terraform aplicará:
- EKS Cluster "case-dev"
- VPC com subnets públicas/privadas  
- ECR repositories
- Security Groups
- IAM Roles e Policies
- DynamoDB table (se configurado)
```

### 2. Build e Push Imagens (3-5 min)
```bash
# Docker build e push:
- Backend: Node.js app (645MB)
- Frontend: React/Vite app (80MB)
- Mobile: Metrics service (215MB)
```

### 3. Deploy Kubernetes (2-3 min)
```bash
# Aplicará manifests:
- Namespace: case
- ConfigMaps e Secrets
- Deployments: backend, frontend, mobile
- Services e Ingress
- HPA (Horizontal Pod Autoscaler)
```

### 4. Validação (2-3 min)
```bash
# Testes executados:
- Health check: backend /health
- Availability: frontend /
- Metrics: mobile /healthz
- Resource utilization
- Pod status report
```

## 🔍 Como Validar Manualmente

### Após execução da pipeline, você pode testar:

```bash
# 1. Conectar ao cluster
aws eks update-kubeconfig --region us-east-2 --name case-dev

# 2. Verificar pods
kubectl get pods -n case

# 3. Testar backend
kubectl port-forward svc/backend 8080:3000 -n case &
curl http://localhost:8080/health

# 4. Testar frontend  
kubectl port-forward svc/frontend 8081:80 -n case &
curl http://localhost:8081/

# 5. Testar mobile
kubectl port-forward svc/mobile 8082:19006 -n case &
curl http://localhost:8082/healthz
```

## 📋 Artefatos Gerados

### Durante a execução:
- **Logs detalhados** de cada job
- **deployment-report.txt**: Relatório completo do deploy
- **test-report.txt**: Relatório de testes (se executado)

### Downloads disponíveis:
- GitHub Actions → Job → Artifacts section

## ⚠️ Troubleshooting

### Se algo falhar:

1. **Erro de permissão AWS**:
   - Verificar se `AWS_ROLE_TO_ASSUME` está configurado
   - Confirmar ARN do role: `arn:aws:iam::918859180133:role/GitHubActionsRole`

2. **Falha no Terraform**:
   - Verificar logs do job `provision-infrastructure`
   - Confirmar se recursos já existem na AWS

3. **Erro no Docker build**:
   - Verificar logs do job `build-images`
   - Confirmar se ECR repositories existem

4. **Falha no Deploy K8s**:
   - Verificar logs do job `deploy-applications`
   - Confirmar se cluster está acessível

### Cleanup (se necessário):
1. GitHub Actions → "Complete EKS Deployment Pipeline"
2. Action: `destroy`
3. Environment: `dev`
4. Executar (remove toda infraestrutura)

## 💰 Custos Estimados

### EKS Cluster:
- **Control Plane**: $0.10/hora ($72/mês)
- **Fargate Pods**: ~$0.04048/vCPU/hora + $0.004445/GB/hora
- **Estimativa total**: ~$80-100/mês (uso moderado)

### Como economizar:
- Use `destroy` action quando não precisar
- Configure autoscaling apropriadamente
- Monitore uso via AWS Cost Explorer

---

## 🎯 Próximos Passos

1. ✅ **Configurar secret** `AWS_ROLE_TO_ASSUME` no GitHub
2. ✅ **Executar pipeline** completa
3. ✅ **Validar deployment** das aplicações  
4. ✅ **Testar funcionalidades** das apps
5. ✅ **Configurar monitoramento** (Grafana)
6. ✅ **Testes de performance** (opcional)

**Tudo está pronto! Basta configurar o secret e executar a pipeline.** 🚀