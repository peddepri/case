# Ambiente de Desenvolvimento Local

## Visão Geral

O ambiente local utiliza uma combinação de **kind** (Kubernetes in Docker) + **LocalStack** (AWS emulator) + **Stack Grafana** (observabilidade) para simular completamente a infraestrutura de produção sem custos AWS.

## Arquitetura Local

```
┌─────────────────────────────────────────────────────────────────┐
│                    DOCKER DESKTOP (HOST)                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────────┐ │
│  │   LocalStack     │  │   kind Cluster   │  │  Observability │ │
│  │  (AWS Services)  │  │   (Kubernetes)   │  │     Stack      │ │
│  │                  │  │                  │  │                │ │
│  │ • DynamoDB       │  │ • Backend Pods   │  │ • Prometheus   │ │
│  │ • S3 Buckets     │  │ • Frontend Pods  │  │ • Grafana      │ │
│  │ • ECR Registry   │  │ • Mobile Pods    │  │ • Loki (Logs)  │ │
│  │ • IAM Roles      │  │ • Services       │  │ • Tempo        │ │
│  │ • Secrets Mgr    │  │ • Ingress        │  │ • Promtail     │ │
│  │ • CloudWatch     │  │ • ConfigMaps     │  │ • Datadog Opt  │ │
│  └──────────────────┘  └──────────────────┘  └────────────────┘ │
│         :4566               kubectl              :9090-3102     │
└─────────────────────────────────────────────────────────────────┘
```

## Componentes

### 1. LocalStack (AWS Emulator)
- **Endpoint:** http://localhost:4566
- **Versão:** LocalStack Pro (4.9.3+)
- **Token:** Requer LOCALSTACK_AUTH_TOKEN para funcionalidades Pro

**Serviços Disponíveis:**
- **DynamoDB** - Tabela `orders` para persistência
- **S3** - Buckets para artefatos e Terraform state
- **ECR** - Registros Docker para backend/frontend
- **IAM** - Roles e policies (IRSA simulation)
- **Secrets Manager** - API keys do Datadog
- **CloudWatch Logs** - Log groups
- **VPC/EC2** - Networking simulation
- **EKS** - Pro feature que falha no Windows (K3D issue)

### 2. kind Cluster (Kubernetes)
- **Cluster:** case-local
- **Versão:** Kubernetes 1.33+
- **Acesso:** kubectl config use-context kind-case-local

**Resources Kubernetes:**
- **Deployments:** backend (2 replicas), frontend, mobile
- **Services:** ClusterIP para cada aplicação
- **Ingress:** nginx controller (:8080)
- **ConfigMaps:** env-config com variáveis
- **Secrets:** datadog API key
- **Namespace:** case (isolamento)

### 3. Stack de Observabilidade
Baseado no Grafana ecosystem para observabilidade completa:

**Componentes:**
- **Prometheus** (:9090) - Coleta métricas dos pods
- **Grafana** (:3100) - Dashboards e visualização
- **Loki** (:3101) - Agregação de logs
- **Tempo** (:3102) - Traces distribuídos (OTLP)
- **Promtail** - Coleta logs dos containers
- **Datadog Agent** (opcional) - APM alternativo

## Fluxo de Dados

### Tráfego HTTP
```
Developer → Ingress (:8080) → Services → Pods
```

### Dados (Backend → AWS)
```
Backend Pod → AWS SDK → host.docker.internal:4566 → LocalStack DynamoDB
```

### Observabilidade
```
Backend Pod → /metrics → Prometheus → Grafana (dashboards)
Backend Pod → OTLP → Tempo → Grafana (traces)
Containers → logs → Promtail → Loki → Grafana (logs)
```

## Como Executar

### 1. Pré-requisitos
```bash
# Instalar kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind

# Verificar Docker
docker --version
kubectl version --client
```

### 2. Subir LocalStack
```bash
# Com token LocalStack Pro
export LOCALSTACK_AUTH_TOKEN="ls-rOhOqaQe-9209-3474-kAto-faXUpetu092e"

# Subir LocalStack + DynamoDB
docker compose -f docker-compose.localstack.yml up -d

# Verificar saúde
curl http://localhost:4566/_localstack/health
```

### 3. Criar kind Cluster
```bash
# Usar script existente que funciona
./scripts/localstack-eks-simple.sh

# Ou manual:
kind create cluster --name case-local --config kind-config.yaml
```

### 4. Deploy das Aplicações
```bash
# Configurar kubectl
kubectl config use-context kind-case-local

# Criar namespace e recursos
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/env-config.yaml
kubectl apply -f k8s/datadog-secret.yaml

# Deploy das aplicações
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/frontend-deployment.yaml
kubectl apply -f k8s/mobile-deployment.yaml
kubectl apply -f k8s/ingress.yaml

# Verificar pods
kubectl get pods -n case
```

### 5. Subir Observabilidade
```bash
# Stack Grafana completa
docker compose -f docker-compose.observability.yml up -d

# Verificar serviços
docker ps | grep -E "(prometheus|grafana|loki|tempo)"
```

### 6. Port-forwards para Acesso Local
```bash
# Aplicações via Ingress
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80 &

# Ou individual
kubectl port-forward -n case svc/backend 3002:3000 &
kubectl port-forward -n case svc/frontend 5173:80 &
kubectl port-forward -n case svc/mobile 19007:19006 &
```

## Testes e Validação

### 1. Teste de Conectividade
```bash
# Backend health
curl http://localhost:8080/api/healthz

# Criar order (vai para DynamoDB LocalStack)
curl -X POST http://localhost:8080/api/orders \
  -H "Content-Type: application/json" \
  -d '{"item":"laptop","price":2500,"customer":"dev-user"}'

# Listar orders
curl http://localhost:8080/api/orders
```

### 2. Verificar LocalStack
```bash
# Listar tabelas DynamoDB
aws --endpoint-url=http://localhost:4566 dynamodb list-tables

# Scan tabela orders
aws --endpoint-url=http://localhost:4566 dynamodb scan --table-name orders

# Verificar buckets S3
aws --endpoint-url=http://localhost:4566 s3 ls
```

### 3. Observabilidade
```bash
# Prometheus targets
open http://localhost:9090/targets

# Grafana dashboards (admin/admin)
open http://localhost:3100

# Tempo traces
open http://localhost:3102
```

## Endpoints de Acesso

| Serviço | URL Local | Descrição |
|---------|-----------|-----------|
| **Frontend** | http://localhost:8080 | React app via Ingress |
| **Backend API** | http://localhost:8080/api | API endpoints |
| **Mobile** | http://localhost:8080/mobile | Expo web |
| **Prometheus** | http://localhost:9090 | Métricas |
| **Grafana** | http://localhost:3100 | Dashboards (admin/admin) |
| **Loki** | http://localhost:3101 | Logs |
| **Tempo** | http://localhost:3102 | Traces |
| **LocalStack** | http://localhost:4566 | AWS API |

## Troubleshooting

### LocalStack Issues
```bash
# Container não sobe
docker logs localstack-main

# Serviços não disponíveis
curl http://localhost:4566/_localstack/health | jq

# Token inválido
docker logs localstack-main | grep -i "token\|auth"
```

### kind Issues
```bash
# Cluster não cria
kind get clusters

# Pods não iniciam
kubectl get pods -n case
kubectl describe pod <pod-name> -n case

# Images não carregadas
kind load docker-image case-backend:latest --name case-local
```

### Networking Issues
```bash
# Backend não acessa LocalStack
kubectl exec -n case deployment/backend -- curl http://host.docker.internal:4566/_localstack/health

# Port-forward travado
ps aux | grep kubectl
kill -9 <pid>
```

### Observability Issues
```bash
# Prometheus não coleta métricas
curl http://localhost:8080/api/metrics

# Grafana sem dados
docker logs case-grafana
```

## Vantagens do Ambiente Local

**Zero custos AWS** - Tudo roda localmente  
**Desenvolvimento offline** - Sem dependência de internet  
**Iteração rápida** - Deploy em segundos  
**Paridade com produção** - Mesmos manifests K8s  
**Observabilidade completa** - Métricas, logs e traces  
**Testes de integração** - DynamoDB + S3 simulados  

## Limitações Conhecidas

Limitação: **EKS LocalStack Pro** - Falha no Windows (K3D nginx issue)  
Atenção: **Performance** - Não reflete latências reais da AWS  
Compatibilidade - Algumas APIs LocalStack podem diferir  
Recursos - Requer Docker com CPU/RAM suficientes  

## Próximos Passos

1. **GitOps:** Implementar ArgoCD para deploy automático
2. **Service Mesh:** Istio/Linkerd para networking avançado
3. **Chaos Engineering:** Litmus/Chaos Mesh para testes de resiliência
4. **Security:** Falco + OPA Gatekeeper para policies
5. **Advanced Observability:** Jaeger, OpenTelemetry Collector