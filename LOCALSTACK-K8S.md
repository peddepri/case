# Ambiente LocalStack + Kubernetes (kind)

Ambiente local completo simulando AWS EKS com LocalStack.

## Arquitetura

```
┌─────────────────────────────────────────────┐
│            localhost:8080 (Ingress)         │
└──────────────────┬──────────────────────────┘
                   │
    ┌──────────────┴──────────────┐
    │                             │
┌───▼────┐                   ┌────▼───┐
│Frontend│                   │Backend │
│Pod     │◄──────────────────│Pod     │
│        │  Service Discovery│        │
└────────┘                   └────┬───┘
                                  │
                                  │ AWS SDK
                                  │
                            ┌─────▼──────┐
                            │ LocalStack │
                            │ :4566      │
                            ├────────────┤
                            │ DynamoDB   │
                            │ IAM        │
                            │ S3         │
                            │ Secrets    │
                            └────────────┘
```

## Quick Start

### Pre-requisitos

- Docker Desktop rodando
- kubectl instalado
- kind instalado ([instruções](https://kind.sigs.k8s.io/docs/user/quick-start/#installation))

#### Instalar kind (Windows):

```bash
# Via Chocolatey
choco install kind

# Ou baixar binário
curl.exe -Lo kind-windows-amd64.exe https://kind.sigs.k8s.io/dl/v0.20.0/kind-windows-amd64
move kind-windows-amd64.exe C:\Windows\System32\kind.exe
```

#### Instalar kubectl (Windows):

```bash
# Via Chocolatey
choco install kubernetes-cli

# Ou baixar binário
curl.exe -LO "https://dl.k8s.io/release/v1.28.0/bin/windows/amd64/kubectl.exe"
move kubectl.exe C:\Windows\System32\
```

### Iniciar Ambiente Completo

```bash
# Script simplificado (recomendado para Windows)
bash scripts/localstack-eks-simple.sh

# Ou script completo com validações
bash scripts/localstack-eks-full.sh
```

O script irá:
1. Iniciar LocalStack (porta 4566)
2. Provisionar recursos AWS (DynamoDB, IAM, S3, Secrets)
3. Criar cluster kind
4. Build imagens Docker (backend + frontend)
5. Carregar imagens no kind
6. Aplicar manifests K8s (namespace, ConfigMap, Secret, Deployments, Services)
7. Instalar Nginx Ingress
8. Configurar Ingress rules

## Endpoints

| Serviço | URL | Descrição |
|---------|-----|-----------|
| **Aplicação** | http://localhost:8080 | Frontend via Ingress |
| **API** | http://localhost:8080/api/orders | Backend API via Ingress |
| **LocalStack** | http://localhost:4566 | AWS API emulator |
| **Health** | http://localhost:4566/_localstack/health | LocalStack status |

## Comandos Uteis

### Kubernetes

```bash
# Ver pods
kubectl get pods -n case

# Ver todos os recursos
kubectl get all -n case

# Logs do backend
kubectl logs -n case -l app=backend -f

# Logs do frontend
kubectl logs -n case -l app=frontend -f

# Descrever pod
kubectl describe pod -n case <pod-name>

# Port-forward direto (bypass Ingress)
kubectl port-forward -n case svc/backend 3000:3000
kubectl port-forward -n case svc/frontend 8081:80

# Exec no pod
kubectl exec -it -n case <pod-name> -- sh

# Ver eventos
kubectl get events -n case --sort-by='.lastTimestamp'
```

### LocalStack (AWS)

```bash
# DynamoDB - listar tabelas
bash scripts/awslocal.sh dynamodb list-tables

# DynamoDB - scan tabela orders
bash scripts/awslocal.sh dynamodb scan --table-name orders

# S3 - listar buckets
bash scripts/awslocal.sh s3 ls

# IAM - listar roles
bash scripts/awslocal.sh iam list-roles

# Secrets Manager - listar secrets
bash scripts/awslocal.sh secretsmanager list-secrets
```

### Testar API

```bash
# Health check
curl http://localhost:8080/api/healthz

# Criar pedido
curl -X POST http://localhost:8080/api/orders \
  -H "Content-Type: application/json" \
  -d '{"item": "laptop", "price": 3000}'

# Listar pedidos
curl http://localhost:8080/api/orders

# Verificar no DynamoDB
bash scripts/awslocal.sh dynamodb scan --table-name orders
```

## Troubleshooting

### Pods não iniciam

```bash
# Ver status detalhado
kubectl describe pod -n case <pod-name>

# Ver logs
kubectl logs -n case <pod-name>

# Verificar imagens carregadas no kind
docker exec -it case-local-control-plane crictl images
```

### Backend não conecta no LocalStack

O endpoint correto dentro do pod é `http://host.docker.internal:4566`:

```bash
# Verificar ConfigMap
kubectl get configmap env-config -n case -o yaml

# Deve conter:
# DYNAMODB_ENDPOINT: http://host.docker.internal:4566
```

Se não funcionar, use `host.k3d.internal` ou o IP do host:

```bash
# Descobrir IP do host (Windows)
ipconfig | findstr "IPv4"

# Atualizar ConfigMap
kubectl create configmap env-config \
    --from-literal=DYNAMODB_ENDPOINT=http://<HOST_IP>:4566 \
    -n case --dry-run=client -o yaml | kubectl apply -f -

# Reiniciar pods
kubectl rollout restart deployment/backend -n case
```

### Ingress retorna 503

```bash
# Verificar se Ingress Controller está rodando
kubectl get pods -n ingress-nginx

# Ver logs do Ingress
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller

# Verificar Ingress rules
kubectl describe ingress case-ingress -n case
```

### LocalStack não responde

```bash
# Verificar se está rodando
docker ps | grep localstack

# Ver logs
docker logs localstack

# Restart
docker compose -f docker-compose.localstack.yml restart localstack

# Health check
curl http://localhost:4566/_localstack/health
```

## Limpeza

### Deletar apenas cluster kind

```bash
kind delete cluster --name case-local
```

### Parar LocalStack

```bash
docker compose -f docker-compose.localstack.yml down

# Com volumes
docker compose -f docker-compose.localstack.yml down --volumes
```

### Deletar tudo

```bash
kind delete cluster --name case-local
docker compose -f docker-compose.localstack.yml down --volumes
```

## Arquitetura dos Componentes

### LocalStack

```yaml
Services Emulados:
  - DynamoDB (tabela "orders")
  - IAM (role "case-backend-sa-role")
  - S3 (bucket "case-artifacts")
  - Secrets Manager (secret "datadog/api-key")
  - CloudWatch Logs
  - ECR (limitado - Pro feature)
```

### Kubernetes (kind)

```yaml
Namespaces:
  - case (aplicação)
  - ingress-nginx (ingress controller)

Deployments:
  - backend (1 replica)
  - frontend (1 replica)

Services:
  - backend (ClusterIP :3000)
  - frontend (ClusterIP :80)

Ingress:
  - /api/* → backend:3000
  - /* → frontend:80
```

### Networking

```
Internet
   ↓
localhost:8080 (Ingress hostPort)
   ↓
Nginx Ingress Controller (Pod)
   ↓
   ├─ /api → backend Service → backend Pod(s)
   └─ / → frontend Service → frontend Pod(s)
          
backend Pod → host.docker.internal:4566 → LocalStack
```

## Variaveis de Ambiente

### Backend Pod

```bash
PORT=3000
AWS_REGION=us-east-1
DDB_TABLE=orders
DYNAMODB_ENDPOINT=http://host.docker.internal:4566
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
DD_ENV=kind
DD_SERVICE=backend
DD_VERSION=0.1.0
```

### Frontend Pod

```bash
VITE_BACKEND_URL=http://backend.case.svc.cluster.local:3000
```

## Conceitos

### kind vs Minikube

- **kind**: Kubernetes in Docker - usa containers Docker como nodes
- **Minikube**: Usa VM ou container para cluster completo
- **Escolha**: kind é mais leve e rápido para CI/CD

### host.docker.internal

- Permite containers no kind acessarem serviços no host (LocalStack)
- No Linux, pode ser necessário usar IP do host diretamente

### imagePullPolicy: Never

- Força uso de imagens locais (não tenta baixar do registry)
- Importante para imagens carregadas com `kind load docker-image`

## Proximos Passos

1. Ambiente local funcionando
2. Conectar Datadog Agent no kind
3. Blue/Green deployment local
4. Auto-scaling com HPA
5. Network Policies
6. Service Mesh (Istio/Linkerd)

## Referências

- [kind Documentation](https://kind.sigs.k8s.io/)
- [LocalStack Docs](https://docs.localstack.cloud/)
- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
