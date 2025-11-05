# Ambiente de Produção AWS

## Visão Geral

O ambiente de produção utiliza **Amazon EKS Fargate** + **Serviços AWS Gerenciados** + **Datadog SaaS** para uma solução cloud-native, serverless e altamente observável.

## Arquitetura de Produção

### Diagramas da Arquitetura

Para visualizar e editar a arquitetura de produção:

#### **[Diagrama Draw.io](./arquitetura-aws-eks-datadog.drawio)** - **RECOMENDADO**
- **Stencils oficiais da AWS** com ícones autênticos
- **Editável** no VS Code (extensão Draw.io) ou em [app.diagrams.net](https://app.diagrams.net)  
- **Componentes detalhados**: VPC, EKS Fargate, serviços AWS, aplicações
- **Fluxos de dados** com setas coloridas e legendas
- **Métricas de performance** e informações técnicas
- **Exportável** para PNG, PDF, SVG

#### **[Diagrama Interativo HTML](./arquitetura-aws-eks-datadog.html)**
- Visualização web com animações CSS
- Elementos interativos com tooltips
- Métricas atualizadas em tempo real (simulação)

#### **[Diagramas Técnicos Mermaid](./arquitetura-diagramas-mermaid.md)**
- Documentação técnica com múltiplas visões
- Sequência de deploy Blue/Green
- Fluxos de observabilidade e segurança
- Tabelas de custos e SLAs

> **Dica**: Para editar o diagrama Draw.io no VS Code, instale a extensão "Draw.io Integration" e abra o arquivo `.drawio`.

### Visão Geral Textual

```
┌─────────────────────────────────────────────────────────────────────┐
│                           AWS CLOUD                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    VPC (10.0.0.0/16)                       │   │
│  │                                                             │   │
│  │  ┌─────────────────┐           ┌─────────────────┐         │   │
│  │  │ Public Subnets  │           │ Private Subnets │         │   │
│  │  │ • NAT Gateway   │           │ • EKS Fargate   │         │   │
│  │  │ • Internet GW   │           │ • Backend Pods  │         │   │
│  │  │                 │           │ • Frontend Pods │         │   │
│  │  └─────────────────┘           └─────────────────┘         │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  AWS Managed Services:                                              │
│  • DynamoDB (orders table)     • ECR (registries)                  │
│  • Secrets Manager (API keys)  • CloudWatch Logs                   │
│  • IAM (OIDC + IRSA)          • Route53 (opcional)                │
└─────────────────────────────────────────────────────────────────────┘
         ↕                              ↕
┌─────────────────────┐    ┌─────────────────────┐
│   GitHub Actions    │    │   Datadog SaaS      │
│   CI/CD Pipeline    │    │   APM + Metrics     │
│ • Build & Push ECR  │    │ • Agentless Traces  │
│ • Blue/Green Deploy │    │ • CloudWatch Logs   │
└─────────────────────┘    └─────────────────────┘
```

## Componentes AWS

### 1. Amazon EKS Fargate
- **Cluster:** case-eks (versão 1.30)
- **Compute:** Fargate profiles (serverless containers)
- **Namespaces:** case (apps), kube-system (CoreDNS)
- **Networking:** VPC CNI, CoreDNS

**Fargate Profiles:**
- `case` - Executa backend, frontend, mobile pods
- `kube-system` - Executa CoreDNS para resolução DNS

**Vantagens:**
- Zero gerenciamento de nós EC2
- Pay-per-pod (custo otimizado)
- Escalabilidade automática
- Menor superfície de ataque

### 2. Amazon VPC
- **CIDR:** 10.0.0.0/16
- **AZs:** us-east-1a, us-east-1b (multi-AZ)

**Subnets:**
- **Public (10.0.101.0/24, 10.0.102.0/24):** Internet Gateway, NAT Gateway
- **Private (10.0.1.0/24, 10.0.2.0/24):** EKS Fargate pods

**Networking:**
- **Internet Gateway:** Acesso à internet para subnets públicas
- **NAT Gateway:** Egress para pods privados (single NAT para economia)
- **Route Tables:** Roteamento otimizado

### 3. Serviços AWS Gerenciados

#### DynamoDB
- **Tabela:** orders
- **Billing:** PAY_PER_REQUEST (serverless)
- **Partição:** id (String)
- **Backup:** Point-in-time recovery (opcional)

#### Amazon ECR
- **Repositórios:** backend, frontend
- **Features:** Scan on push, image signing
- **Lifecycle:** Policies para limpeza automática

#### IAM + IRSA (Roles for Service Accounts)
- **OIDC Provider:** Integração EKS ↔ IAM
- **ServiceAccount:** backend-sa com role específico
- **Permissions:** Acesso mínimo ao DynamoDB (least privilege)

#### AWS Secrets Manager
- **Secrets:** DD_API_KEY, database credentials
- **Rotation:** Automática (quando aplicável)
- **Access:** Via CSI Secrets Store Driver (futuro)

#### CloudWatch Logs
- **Log Groups:** /aws/eks/case-eks/*
- **Retention:** 30 dias (configável)
- **Integration:** Datadog log forwarding

## Kubernetes Resources

### Deployments
```yaml
# Blue/Green Deployment Pattern
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  labels:
    app: backend
    color: blue  # ou green para deployment alternativo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
      color: blue
```

**Aplicações:**
- **Backend:** Node.js + Express + dd-trace APM
- **Frontend:** React + Vite + nginx
- **Mobile:** Expo web (opcional em produção)

### Services
- **Tipo:** ClusterIP (interno)
- **Selector:** app + color (Blue/Green switching)
- **Ports:** 3000 (backend), 80 (frontend), 19006 (mobile)

### Ingress
- **Controller:** nginx-ingress
- **SSL:** Certificados via cert-manager + Let's Encrypt
- **Routing:** Path-based para múltiplas apps

### ConfigMaps & Secrets
- **env-config:** Variáveis de ambiente
- **datadog:** API keys para observabilidade
- **tls-certs:** Certificados SSL

## CI/CD Pipeline (GitHub Actions)

### Workflow: Build & Deploy
```yaml
# .github/workflows/cicd.yml
on:
  push:
    branches: [main]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      # 1. Build & Push to ECR
      - name: Build backend
        run: |
          docker build -t $ECR_REGISTRY/backend:$GITHUB_SHA ./app/backend
          docker push $ECR_REGISTRY/backend:$GITHUB_SHA
      
      # 2. Blue/Green Deploy
      - name: Deploy to EKS
        run: |
          # Update deployment with new image
          kubectl set image deployment/backend-green \
            backend=$ECR_REGISTRY/backend:$GITHUB_SHA -n case
          
          # Switch service selector after validation
          kubectl patch service backend \
            -p '{"spec":{"selector":{"color":"green"}}}' -n case
```

### Estratégia Blue/Green
1. **Deploy Green:** Nova versão em deployment separado
2. **Health Check:** Validar pods healthy + smoke tests
3. **Switch Traffic:** Alterar Service selector blue→green
4. **Cleanup:** Remover deployment blue após validação
5. **Rollback:** Instant switch green→blue se necessário

### Secrets & Variables
**Repository Secrets:**
- `AWS_ROLE_TO_ASSUME` - IAM role para OIDC
- `DD_API_KEY` - Datadog API key
- `BACKEND_IRSA_ROLE_ARN` - Role ARN para IRSA

**Repository Variables:**
- `AWS_REGION` - us-east-1
- `AWS_ACCOUNT_ID` - Account ID
- `EKS_CLUSTER_NAME` - case-eks
- `DD_SITE` - datadoghq.com

## Observabilidade

### Opção 1: Datadog SaaS (Principal)

#### APM Agentless
```yaml
# Backend deployment com APM agentless
env:
  - name: DD_TRACE_ENABLED
    value: "true"
  - name: DD_TRACE_AGENTLESS
    value: "true"  # Fargate não suporta DaemonSet
  - name: DD_SITE
    value: "datadoghq.com"
  - name: DD_API_KEY
    valueFrom:
      secretKeyRef:
        name: datadog
        key: api-key
```

### Cluster Agent
```bash
# Helm chart para Datadog no EKS
helm install datadog datadog/datadog \
  --set datadog.site=datadoghq.com \
  --set datadog.apiKey=$DD_API_KEY \
  --set datadog.eksFargate=true \
  --set agents.enabled=false \
  --set clusterAgent.enabled=true
```

#### Dashboards & Monitors
- **4 Golden Signals:** Latency, Traffic, Errors, Saturation
- **Business Metrics:** orders.created, orders.failed
- **Infrastructure:** EKS cluster health, DynamoDB performance
- **Alerting:** PagerDuty integration para oncall

### Opção 2: Grafana Stack (Alternativa/Híbrida)

#### Arquitetura da Grafana Stack
```yaml
# Componentes implantados no EKS
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
spec:
  template:
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        args:
          - --config.file=/etc/prometheus/prometheus.yml
          - --storage.tsdb.path=/prometheus/
          - --web.console.libraries=/etc/prometheus/console_libraries
          - --web.console.templates=/etc/prometheus/consoles
        ports:
        - containerPort: 9090
```

#### Componentes da Stack

**Prometheus (Métricas)**
- **Scraping:** Backend `/metrics` endpoint a cada 15s
- **Storage:** TSDB local (7 dias) + remote write para S3
- **Alerting:** Rules para Golden Signals + Business Metrics
- **Targets:** backend:3000/metrics, node-exporter, kube-state-metrics

**Grafana (Visualização)**
- **Dashboards:** 4 Golden Signals, Business Metrics, Infrastructure
- **Datasources:** Prometheus (metrics), Loki (logs), Tempo (traces)
- **Alerting:** Integration com AlertManager → Slack/PagerDuty
- **Users:** OIDC integration com GitHub/AWS SSO

**Loki (Logs)**
- **Ingestion:** Promtail coleta logs via Docker socket
- **Storage:** S3 backend (30 dias de retenção)
- **Parsing:** JSON logs do backend (Pino format)
- **Queries:** LogQL para troubleshooting e alertas

**Tempo (Traces)**
- **Protocol:** OpenTelemetry OTLP (gRPC + HTTP)
- **Storage:** S3 backend com compactação
- **Integration:** Grafana Explore para trace correlation
- **Sampling:** Head-based sampling (1% production)

**Promtail (Log Shipper)**
- **Sources:** Docker containers via /var/log/containers
- **Labels:** Kubernetes metadata (namespace, pod, service)
- **Parsing:** JSON + multiline support
- **Target:** Loki push endpoint

**AlertManager (Notifications)**
- **Sources:** Prometheus alerts
- **Routing:** Por severity e team
- **Channels:** Slack, PagerDuty, email
- **Silencing:** Maintenance windows

#### Deployment no EKS

```bash
# Prometheus Operator (Helm)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.enabled=true \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi

# Loki Stack (Helm)
helm repo add grafana https://grafana.github.io/helm-charts
helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=20Gi \
  --set promtail.enabled=true

# Tempo (Helm)
helm install tempo grafana/tempo \
  --namespace monitoring \
  --set tempo.storage.trace.backend=s3 \
  --set tempo.storage.trace.s3.bucket=case-tempo-traces
```

#### Configuração Backend para Grafana Stack

```yaml
# Backend deployment com OpenTelemetry
env:
  # Prometheus metrics (já existente)
  - name: METRICS_ENABLED
    value: "true"
  
  # OpenTelemetry tracing
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://tempo:4317"
  - name: OTEL_SERVICE_NAME
    value: "backend"
  - name: OTEL_RESOURCE_ATTRIBUTES
    value: "service.version=1.0.0,environment=production"
  
  # Structured logging (já existente)
  - name: LOG_LEVEL
    value: "info"
  - name: LOG_FORMAT
    value: "json"
```

#### Comparação: Datadog vs Grafana Stack

| Aspecto | Datadog SaaS | Grafana Stack |
|---------|--------------|---------------|
| **Setup** | Simples (agentless) | Complexo (múltiplos componentes) |
| **Custo** | $$$$ (por host/trace) | $ (infra + operational) |
| **Maintenance** | Zero | Alto (upgrades, scaling, backup) |
| **Features** | Rica (correlação) | Boa (open source ecosystem) |
| **Vendor Lock-in** | Alto | Baixo |
| **Compliance** | Enterprise ready | Customizável |
| **Learning Curve** | Baixa | Alta |
| **Scaling** | Automático | Manual |

#### Estratégia Híbrida (Recomendada)

```yaml
# Usar ambas as stacks de forma complementar
Production:
  Primary: Datadog SaaS
    - Critical alerting (24/7 SLA)
    - Executive dashboards
    - APM correlação automática
    
  Secondary: Grafana Stack
    - Cost analysis e FinOps
    - Custom business metrics
    - Long-term historical data
    - Compliance e audit logs

Development/Staging:
  Primary: Grafana Stack
    - Cost-effective para desenvolvimento
    - Learning e experimentation
    - Custom integrations testing
```

#### Custos Estimados (Grafana Stack)

**EKS Resources:**
- Prometheus: 2 vCPU, 4GB RAM = ~$30/mês
- Grafana: 1 vCPU, 2GB RAM = ~$15/mês  
- Loki: 1 vCPU, 2GB RAM = ~$15/mês
- Tempo: 1 vCPU, 2GB RAM = ~$15/mês
- AlertManager: 0.5 vCPU, 1GB RAM = ~$7/mês

**Storage (S3):**
- Prometheus TSDB: 50GB = ~$1.15/mês
- Loki logs: 100GB = ~$2.30/mês
- Tempo traces: 200GB = ~$4.60/mês

**Total Grafana Stack:** ~$90/mês vs Datadog ~$300-500/mês

## Provisioning (Terraform)

### Estrutura IaC
```
infra/terraform/
├── main.tf              # VPC, EKS, Fargate profiles
├── dynamodb.tf          # DynamoDB table
├── ecr.tf              # ECR repositories  
├── iam.tf              # OIDC + IRSA roles
├── datadog.tf          # Helm chart deployment
├── variables.tf        # Input variables
├── outputs.tf          # ARNs, endpoints
└── versions.tf         # Provider versions
```

### Deploy Infrastructure
```bash
# Configurar credenciais AWS
export AWS_PROFILE=production
export AWS_REGION=us-east-1

# Deploy via toolbox (Docker)
./scripts/tf.sh init
./scripts/tf.sh plan -var="dd_api_key=$DD_API_KEY"
./scripts/tf.sh apply -auto-approve

# Configurar kubectl
./scripts/aws.sh eks update-kubeconfig --name case-eks --region us-east-1
```

### Outputs Importantes
```hcl
output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "backend_irsa_role_arn" {
  value = aws_iam_role.backend_irsa.arn
  sensitive = true
}

output "ecr_registry_url" {
  value = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com"
}
```

## Deployment em Produção

### 1. Provisionar Infraestrutura
```bash
# Deploy AWS resources
cd infra/terraform
terraform apply -var="dd_api_key=$DD_API_KEY"

# Configurar acesso ao cluster
aws eks update-kubeconfig --name case-eks --region us-east-1
```

### 2. Deploy das Aplicações
```bash
# Namespace e configuração
kubectl apply -f k8s/namespace.yaml
envsubst < k8s/env-config.yaml | kubectl apply -f -
envsubst < k8s/datadog-secret.yaml | kubectl apply -f -

# ServiceAccount com IRSA
envsubst < k8s/backend-serviceaccount.yaml | kubectl apply -f -

# Deployments iniciais (blue)
envsubst < k8s/backend-deployment.yaml | kubectl apply -f -
envsubst < k8s/frontend-deployment.yaml | kubectl apply -f -
envsubst < k8s/ingress.yaml | kubectl apply -f -
```

### 3. Validação
```bash
# Pods healthy
kubectl get pods -n case

# Services responding  
kubectl port-forward -n case svc/backend 8080:3000
curl http://localhost:8080/healthz

# Ingress accessible
curl http://$(kubectl get ing case-ingress -n case -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
```

## Monitoramento e Alertas

### SLIs (Service Level Indicators)
- **Availability:** 99.9% uptime
- **Latency:** P95 < 200ms (API responses)
- **Error Rate:** < 1% (HTTP 5xx)
- **Throughput:** Requests per second

### Alertas Críticos
1. **Pod Crash Loop** - Pods reiniciando constantemente
2. **High Error Rate** - > 5% HTTP 5xx em 5min
3. **High Latency** - P95 > 500ms por 2min
4. **DynamoDB Throttling** - Throttled requests > 0
5. **EKS Node Issues** - Fargate pods pending

### Dashboards
- **Application Dashboard:** Golden signals por serviço
- **Infrastructure Dashboard:** EKS cluster + AWS services
- **Business Dashboard:** Métricas de negócio (orders, revenue)

## Segurança

### Network Security
- **Private Subnets:** Pods sem IP público
- **Security Groups:** Minimal ingress rules
- **NACLs:** Subnet-level protection
- **VPC Flow Logs:** Network monitoring

### Identity & Access
- **IRSA:** Service accounts com IAM roles
- **OIDC:** GitHub Actions sem long-lived keys
- **Least Privilege:** Minimal permissions por service
- **Secrets Manager:** Encrypted credentials

### Container Security
- **Image Scanning:** ECR scan-on-push
- **Non-root User:** Containers run as non-root
- **Read-only Filesystem:** Immutable containers
- **Security Context:** Pod security standards

### Compliance
- **Encryption:** Data at rest + in transit
- **Audit Logs:** CloudTrail + EKS audit
- **Vulnerability Scanning:** Container images
- **Policy Enforcement:** OPA Gatekeeper (futuro)

## Custos e FinOps

### Estimativa Mensal (us-east-1)
- **EKS Control Plane:** ~$73 (24/7)
- **Fargate Pods:** ~$50-150 (2-6 pods, 0.25 vCPU, 0.5GB)
- **DynamoDB:** ~$5-25 (pay-per-request)
- **NAT Gateway:** ~$45 (single NAT)
- **CloudWatch Logs:** ~$5-15 (retention 30d)
- **ECR:** ~$1-5 (storage)
- **Total:** ~$179-318/mês

### Otimizações
- **Right-sizing:** Resource requests/limits adequados
- **HPA:** Horizontal Pod Autoscaler (70% CPU)
- **Fargate Spot:** Usar Spot instances quando disponível
- **Schedule Scaling:** Scale-to-zero em ambientes não-prod
- **Reserved Capacity:** DynamoDB RCU/WCU para workloads previsíveis

### Tags para Cost Allocation
```hcl
locals {
  tags = {
    Environment = "production"
    Project     = "case"
    Team        = "platform"
    CostCenter  = "engineering"
    Owner       = "platform-team"
  }
}
```

## Disaster Recovery

### Backup Strategy
- **DynamoDB:** Point-in-time recovery (35 dias)
- **ECR:** Cross-region replication
- **K8s Manifests:** GitOps (source of truth)
- **Secrets:** Backup para Secrets Manager

### Multi-AZ Deployment
- **EKS:** Control plane multi-AZ por default
- **Fargate:** Pods distribuídos entre AZs
- **DynamoDB:** Global tables (opcional)
- **Load Balancer:** ALB multi-AZ

### RTO/RPO Targets
- **RTO:** 15 minutos (Recovery Time Objective)
- **RPO:** 5 minutos (Recovery Point Objective)
- **Runbook:** Procedimentos automatizados de recovery

## Troubleshooting

### EKS Issues
```bash
# Pods não iniciam
kubectl describe pod <pod-name> -n case
kubectl logs <pod-name> -n case

# IRSA permissions
kubectl auth can-i get tables --as=system:serviceaccount:case:backend-sa

# Fargate profile issues
aws eks describe-fargate-profile --cluster-name case-eks --fargate-profile-name case
```

### DynamoDB Issues
```bash
# Table status
aws dynamodb describe-table --table-name orders

# CloudWatch metrics
aws logs tail /aws/dynamodb/orders --follow
```

### Networking Issues
```bash
# Security group rules
aws ec2 describe-security-groups --group-ids sg-xxx

# VPC endpoints
aws ec2 describe-vpc-endpoints --filters Name=service-name,Values=com.amazonaws.us-east-1.dynamodb
```

## Roadmap

### Próximas Features
1. **GitOps:** ArgoCD para continuous deployment
2. **Progressive Delivery:** Argo Rollouts para canary deployments
3. **Service Mesh:** App Mesh para advanced networking
4. **Multi-Environment:** Staging, QA environments
5. **Advanced Security:** Falco, OPA Gatekeeper, Pod Security Standards

### Otimizações Futuras
1. **VPC Endpoints:** Reduzir custos NAT Gateway
2. **Fargate Spot:** Economia em workloads fault-tolerant  
3. **Advanced Monitoring:** Custom metrics, SLO tracking
4. **Data Pipeline:** Kinesis para analytics real-time
5. **Multi-Region:** Disaster recovery + global distribution