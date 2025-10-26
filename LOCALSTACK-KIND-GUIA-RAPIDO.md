# LocalStack + kind - Guia Rápido (Windows)

## 🎯 Por que kind em vez de EKS LocalStack?

O EKS do LocalStack Pro tem limitações no Windows:
- ❌ Usa K3D que falha ao instalar nginx no Docker Desktop Windows
- ❌ Mais lento e instável
- ❌ Requer configuração complexa

**kind + LocalStack oferece:**
- ✅ Funciona perfeitamente no Windows
- ✅ Mais rápido e estável
- ✅ 100% compatível com Kubernetes real
- ✅ Integra com AWS services do LocalStack (DynamoDB, ECR, etc)

## 🚀 Setup Rápido (5 minutos)

### 1. Iniciar Ambiente Completo

```bash
# Inicia LocalStack + kind + deploy da aplicação
bash scripts/localstack-eks-simple.sh
```

Este script automaticamente:
1. ✅ Inicia LocalStack Pro com serviços AWS
2. ✅ Cria cluster kind local
3. ✅ Provisiona DynamoDB, ECR, IAM, Secrets
4. ✅ Build e load de imagens Docker
5. ✅ Deploy backend + frontend no Kubernetes
6. ✅ Configura Ingress Nginx

**Tempo:** 3-5 minutos

### 2. Verificar Status

```bash
# Ver pods
kubectl get pods -n case

# Ver services
kubectl get svc -n case

# Logs do backend
kubectl logs -n case -l app=backend -f
```

### 3. Acessar Aplicação

```bash
# Frontend e Backend via Ingress
# Acesse: http://localhost:8080

# Ou via port-forward direto
kubectl port-forward -n case svc/backend 3000:3000
kubectl port-forward -n case svc/frontend 8081:80
```

## 🔧 Comandos Úteis

### LocalStack (AWS Services)

```bash
# Ver DynamoDB
bash scripts/awslocal.sh dynamodb scan --table-name orders

# Ver ECR repositories
bash scripts/awslocal.sh ecr describe-repositories

# Listar imagens no ECR
bash scripts/awslocal.sh ecr list-images --repository-name backend

# Criar order via backend
curl -X POST http://localhost:8080/api/orders \
  -H "Content-Type: application/json" \
  -d '{"item":"test","price":99.99}'
```

### Kubernetes

```bash
# Context do kind
kubectl config use-context kind-case-local

# Todos os recursos
kubectl get all -n case

# Describe pod com problema
kubectl describe pod -n case <pod-name>

# Events
kubectl get events -n case --sort-by='.lastTimestamp'

# Executar comando em pod
kubectl exec -it -n case <pod-name> -- sh
```

### Rebuild e Redeploy

```bash
# Rebuild imagens
docker build -t case-backend:latest app/backend
docker build -t case-frontend:latest app/frontend

# Carregar no kind
kind load docker-image case-backend:latest --name case-local
kind load docker-image case-frontend:latest --name case-local

# Restart deployments
kubectl rollout restart deployment/backend -n case
kubectl rollout restart deployment/frontend -n case
```

## 🧪 Testar Aplicação

### Smoke Test

```bash
# Healthcheck
curl http://localhost:8080/healthz

# Criar pedido
curl -X POST http://localhost:8080/api/orders \
  -H "Content-Type: application/json" \
  -d '{"item":"widget","price":123.45}'

# Listar pedidos
curl http://localhost:8080/api/orders

# Ver no DynamoDB
bash scripts/awslocal.sh dynamodb scan --table-name orders
```

### Teste de Carga com Locust

```bash
# Via Docker (recomendado)
docker run --rm --network host \
  -v $(pwd)/scripts:/scripts \
  locustio/locust \
  -f /scripts/locustfile.py \
  --host=http://localhost:8080 \
  --users 10 --spawn-rate 2 --run-time 1m \
  --headless
```

### Chaos Engineering

```bash
# Aplicar experimento de caos (mata pods aleatórios)
kubectl apply -f k8s/litmus/backend-pod-delete-engine.yaml

# Ver experimentos
kubectl get chaosengine -n case

# Monitorar pods durante caos
watch kubectl get pods -n case
```

## 📊 Observabilidade

### Logs

```bash
# Backend logs
kubectl logs -n case -l app=backend -f

# Frontend logs
kubectl logs -n case -l app=frontend -f

# Todos os logs
kubectl logs -n case --all-containers=true -f
```

### Métricas

```bash
# Métricas da aplicação
curl http://localhost:8080/metrics

# Top pods (CPU/Memory)
kubectl top pods -n case

# Top nodes
kubectl top nodes
```

### Grafana (se stack de observabilidade estiver rodando)

```bash
# Iniciar stack de observabilidade
docker compose -f docker-compose.observability.yml up -d

# Acessar Grafana
open http://localhost:3100
# User: admin / Pass: admin
```

## 🧹 Limpeza

### Limpar apenas Kubernetes

```bash
# Deletar namespace (remove todos os recursos)
kubectl delete namespace case

# Deletar cluster kind
kind delete cluster --name case-local
```

### Limpar tudo (LocalStack + kind)

```bash
# Parar LocalStack
docker compose -f docker-compose.localstack.yml down

# Deletar cluster kind
kind delete cluster --name case-local

# Limpar dados persistidos (opcional)
rm -rf localstack-data/*
```

## 🔄 Workflow de Desenvolvimento

### 1. Fazer mudanças no código

```bash
# Editar app/backend/src/* ou app/frontend/src/*
```

### 2. Rebuild imagem

```bash
# Backend
docker build -t case-backend:latest app/backend

# Frontend
docker build -t case-frontend:latest app/frontend
```

### 3. Atualizar no kind

```bash
# Carregar nova imagem
kind load docker-image case-backend:latest --name case-local

# Restart pod
kubectl rollout restart deployment/backend -n case
kubectl rollout status deployment/backend -n case
```

### 4. Verificar logs

```bash
kubectl logs -n case -l app=backend -f
```

## 🆚 Diferença: kind vs EKS LocalStack

| Aspecto | kind + LocalStack | EKS LocalStack |
|---------|------------------|----------------|
| **Windows** | ✅ Funciona bem | ❌ Falha (nginx issue) |
| **Setup** | ✅ 3-5 min | ⏰ 10-15 min (quando funciona) |
| **Estabilidade** | ✅ Alta | ⚠️ Média/Baixa no Windows |
| **AWS Integration** | ✅ Via endpoint | ✅ Nativo |
| **Performance** | ✅ Rápido | ⏰ Mais lento |
| **Custo** | ✅ Grátis | 💰 Requer Pro |
| **Recomendado para** | Dev local | CI/CD / Linux |

## 💡 Dicas

1. **kind é suficiente** para 99% dos casos de desenvolvimento local
2. **LocalStack Pro** ainda é útil para serviços AWS (DynamoDB, ECR, etc)
3. **EKS LocalStack** só use se estiver no Linux ou CI/CD
4. **Docker Desktop** no Windows tem limitações para K3D/EKS

## 📚 Arquivos Importantes

- `scripts/localstack-eks-simple.sh` - Setup completo automatizado
- `scripts/localstack-provision-simple.sh` - Apenas AWS resources
- `kind-config.yaml` - Configuração do cluster kind
- `k8s/` - Manifests Kubernetes
- `docker-compose.localstack.yml` - LocalStack Pro config

## ❓ Troubleshooting

### Pods não sobem

```bash
# Ver motivo
kubectl describe pod -n case <pod-name>

# Verificar eventos
kubectl get events -n case

# Rebuild e reload imagem
docker build -t case-backend:latest app/backend
kind load docker-image case-backend:latest --name case-local
kubectl delete pod -n case -l app=backend
```

### LocalStack não conecta

```bash
# Verificar status
curl http://localhost:4566/_localstack/health

# Restart
docker compose -f docker-compose.localstack.yml restart localstack

# Logs
docker logs case-localstack -f
```

### Ingress não funciona

```bash
# Verificar ingress nginx
kubectl get pods -n ingress-nginx

# Restart ingress
kubectl delete pod -n ingress-nginx -l app.kubernetes.io/component=controller

# Port-forward direto (alternativa)
kubectl port-forward -n case svc/backend 3000:3000
```

## ✅ Checklist de Sucesso

Após executar `bash scripts/localstack-eks-simple.sh`, você deve ter:

- ✅ LocalStack rodando em http://localhost:4566
- ✅ Cluster kind `case-local` ativo
- ✅ Namespace `case` criado
- ✅ Pods `backend` e `frontend` em Running
- ✅ Ingress acessível em http://localhost:8080
- ✅ DynamoDB table `orders` criada
- ✅ Backend conectando com DynamoDB via LocalStack

**Teste final:**
```bash
curl http://localhost:8080/api/orders
# Deve retornar: {"orders":[]}
```

---

**🎉 Pronto! Você tem um ambiente Kubernetes + AWS local completo funcionando!**
