# Arquitetura de Desenvolvimento Local

## Visão Geral

Este projeto usa uma combinação de ferramentas para simular a infraestrutura AWS localmente:

```
┌─────────────────────────────────────────────────────┐
│                 DESENVOLVIMENTO LOCAL                │
├─────────────────────────────────────────────────────┤
│                                                      │
│  ┌──────────────────┐     ┌─────────────────────┐  │
│  │   LocalStack     │     │   kind (K8s local)  │  │
│  │  (AWS Services)  │     │   Cluster K8s real  │  │
│  │                  │     │                     │  │
│  │  DynamoDB       │     │  Backend pods      │  │
│  │  S3             │     │  Frontend pods     │  │
│  │  IAM            │     │  Mobile pods       │  │
│  │  Secrets Mgr    │     │  Services          │  │
│  │  CloudWatch     │     │  Ingress           │  │
│  │                  │     │  ConfigMaps        │  │
│  │  EKS (Pro)      │     │  Namespaces        │  │
│  └──────────────────┘     └─────────────────────┘  │
│         :4566                   via kubectl         │
└─────────────────────────────────────────────────────┘
         ↓                           ↓
┌─────────────────────────────────────────────────────┐
│          Observabilidade (Docker Compose)            │
│                                                      │
│  Prometheus  Grafana  Dashboards                  │
│  Loki  Logs                                        │
│  Tempo  Traces                                     │
│  Datadog Agent (opcional)                           │
└─────────────────────────────────────────────────────┘
```

## Por que LocalStack NÃO tem EKS?

**Motivo:** EKS é uma funcionalidade **Pro** do LocalStack (paga), não está disponível na versão Community (gratuita).

**Erro comum:**
```
API for service 'eks' not yet implemented or pro feature - please check https://docs.localstack.cloud/references/coverage/
```

## Solução: kind (Kubernetes in Docker)

Este projeto usa **kind** como alternativa ao EKS:

### O que é kind?

- **k**ubernetes **in** **d**ocker
- Cluster Kubernetes REAL rodando em containers Docker
- Gratuito, open-source (CNCF)
- Usado por desenvolvedores K8s e para testes de CI/CD

### Vantagens do kind sobre LocalStack EKS

| Feature | kind | LocalStack EKS |
|---------|------|----------------|
| Custo | Gratuito | Pago (Pro) |
| Tipo | K8s real | Emulado |
| Recursos K8s | Todos | Limitado |
| Performance | Excelente | Variável |
| Comunidade | Grande | Média |

## Divisão de Responsabilidades

### LocalStack (AWS Services)
- **DynamoDB**: Tabela `orders` para persistência
- **S3**: Bucket para Terraform state (simulado)
- **IAM**: Roles e policies (simulado)
- **Secrets Manager**: API keys do Datadog
- **CloudWatch Logs**: Log groups

**Endpoint:** http://localhost:4566

**Comandos:**
```bash
# Listar tabelas DynamoDB
aws --endpoint-url=http://localhost:4566 dynamodb list-tables

# Scan tabela orders
aws --endpoint-url=http://localhost:4566 dynamodb scan --table-name orders

# Listar secrets
aws --endpoint-url=http://localhost:4566 secretsmanager list-secrets
```

### kind (Kubernetes)
- **Deployments**: backend, frontend, mobile
- **Services**: ClusterIP, NodePort
- **Ingress**: Roteamento HTTP
- **ConfigMaps**: Configuração dos apps
- **Secrets**: Credenciais K8s
- **Namespaces**: Isolamento (namespace `case`)

**Cluster:** case-local

**Comandos:**
```bash
# Verificar cluster
kind get clusters

# Listar pods
kubectl get pods -n case

# Port-forward para acessar serviços
kubectl port-forward -n case svc/backend 3002:3000

# Logs
kubectl logs -n case deployment/backend -f
```

### Docker Compose (Observabilidade)
- **Prometheus**: Coleta métricas de backend/frontend
- **Grafana**: Dashboards e visualização
- **Loki**: Agregação de logs
- **Tempo**: Traces distribuídos
- **Promtail**: Coleta logs dos containers

**Serviços:**
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3100 (admin/admin)
- Loki: http://localhost:3101
- Tempo: http://localhost:3102

## Fluxo de Dados

```
┌──────────┐
│ Frontend │ (kind pod)
└─────┬────┘
      │ HTTP
      ↓
┌──────────┐
│ Backend  │ (kind pod)
└─────┬────┘
      │ AWS SDK
      ↓
┌──────────────┐
│ DynamoDB     │ (LocalStack)
│ localhost    │
│ :4566        │
└──────────────┘
      │
      ↓ Metrics
┌──────────────┐
│ Prometheus   │ (Docker Compose)
└──────────────┘
      │
      ↓ Query
┌──────────────┐
│ Grafana      │ (Docker Compose)
│ Dashboards   │
└──────────────┘
```

## Como Rodar Tudo

### 1. LocalStack (AWS Services)
```bash
# Subir LocalStack com DynamoDB, S3, etc.
docker compose up -d localstack dynamodb-init

# Verificar recursos criados
./scripts/localstack-test.sh
```

### 2. kind (Kubernetes)
```bash
# Verificar cluster
kind get clusters
# Output: case-local

# Deploy aplicações
kubectl apply -f k8s/

# Verificar pods
kubectl get pods -n case
```

### 3. Observabilidade
```bash
# Subir stack Grafana
docker compose -f docker-compose.observability.yml up -d

# Acessar Grafana
open http://localhost:3100
```

### 4. Port-forwards para acesso local
```bash
# Backend
kubectl port-forward -n case svc/backend 3002:3000 &

# Frontend
kubectl port-forward -n case svc/frontend 5173:80 &

# Mobile
kubectl port-forward -n case svc/mobile 19007:19006 &
```

### 5. Testar
```bash
# Backend health
curl http://localhost:3002/healthz

# Criar order (vai para DynamoDB no LocalStack)
curl -X POST http://localhost:3002/api/orders \
  -H "Content-Type: application/json" \
  -d '{"item":"test","price":100}'

# Frontend
open http://localhost:5173

# Mobile
open http://localhost:19007
```

## Quando Usar AWS Real (EKS)?

Para **produção** ou testes de infraestrutura real, use:

```bash
# Provisionar EKS real na AWS via Terraform
cd infra/terraform
terraform init
terraform apply

# Configurar kubectl para EKS
aws eks update-kubeconfig --name case-eks --region us-east-1

# Deploy
kubectl apply -f k8s/
```

**Custos AWS (estimativa):**
- EKS Control Plane: ~$0.10/hora
- Fargate pods: ~$0.04/vCPU/hora + $0.004/GB/hora
- DynamoDB: Pay-per-request (mínimo)
- Total: ~$100-200/mês para ambiente dev/staging

## Troubleshooting

### "API for service 'eks' not yet implemented"
- **Causa:** Tentando usar EKS no LocalStack Community
- **Solução:** Use kind (já configurado)

### Pods não iniciam no kind
```bash
# Verificar imagens carregadas
kind get images --name case-local

# Carregar imagem manualmente
kind load docker-image case-backend:latest --name case-local
```

### LocalStack não conecta
```bash
# Verificar container
docker ps | grep localstack

# Verificar porta
curl http://localhost:4566/_localstack/health
```

### Backend não acessa DynamoDB
```bash
# Verificar endpoint no ConfigMap
kubectl get configmap -n case backend-config -o yaml

# Deve conter:
# AWS_ENDPOINT: "http://host.docker.internal:4566"
# ou IP do host: "http://192.168.x.x:4566"
```

## Referências

- **LocalStack Coverage**: https://docs.localstack.cloud/references/coverage/
- **kind Docs**: https://kind.sigs.k8s.io/
- **Kubernetes Docs**: https://kubernetes.io/docs/
- **AWS SDK for JavaScript**: https://docs.aws.amazon.com/sdk-for-javascript/

## Resumo

 **LocalStack** = Serviços AWS (DynamoDB, S3, IAM, etc.) - SEM EKS  
 **kind** = Cluster Kubernetes local - SUBSTITUI EKS  
 **Docker Compose** = Observabilidade (Prometheus, Grafana, Loki)  
 **AWS Real** = Produção via Terraform (EKS Fargate, DynamoDB real)  
