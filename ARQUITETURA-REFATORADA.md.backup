# Arquitetura Refatorada - EKS + Argo CD + Observabilidade

## Estrutura Final

```
case/
├── infra/terraform/           # Infraestrutura como código
│   ├── modules/              # Módulos reutilizáveis
│   │   ├── eks/             # Cluster EKS
│   │   ├── fargate/         # Fargate Profiles
│   │   ├── irsa/            # IAM Roles for Service Accounts
│   │   └── alb/             # AWS Load Balancer Controller
│   ├── main.tf              # Configuração principal
│   ├── variables.tf         # Variáveis
│   └── outputs.tf           # Outputs
├── argo/                    # Argo CD App of Apps
│   ├── root.yaml           # Aplicação raiz
│   └── apps/               # Aplicações por domínio
│       ├── backend.yaml    # Apps backend (dev/prod)
│       └── plataforma.yaml # Apps de plataforma
├── plataforma/             # Recursos de plataforma
│   ├── ingress/           # ALB Controller
│   └── observabilidade/   # Grafana Stack + Datadog
├── app/                   # Aplicações
│   ├── backend/
│   ├── frontend/
│   └── mobile/
└── k8s/                   # Manifests Kubernetes
```

## Decisões Arquiteturais

### Terraform - Apenas Infraestrutura Core
- **VPC/Networking**: Subnets públicas e privadas
- **EKS + Fargate**: Cluster sem EC2 nodes
- **IAM/OIDC/IRSA**: Roles para Service Accounts
- **ECR**: Repositórios de container
- **Route 53**: DNS (quando necessário)
- **Datadog**: Integração via Helm

### Argo CD - Controle Declarativo
- **App of Apps**: Pattern para gestão de aplicações
- **CI**: Apenas atualiza versão de imagem/values
- **Deploy**: Argo CD gerencia estado desejado
- **GitOps**: Baseado em Git como fonte da verdade

### Observabilidade Simplificada
- **Datadog**: APM, RUM, infraestrutura, alertas
- **Grafana Stack**: Prometheus + Loki + Tempo + Grafana
- **OpenTelemetry**: Collector + SDKs para instrumentação

### Ingress Padronizado
- **AWS Load Balancer Controller**: Único controlador
- **ALB Ingress**: Application Load Balancer
- **IRSA**: Permissões via Service Account

## Recursos Removidos

### Ferramentas de Orquestração
- ECS, EC2 ASG para workloads
- Cluster Autoscaler (não aplicável ao Fargate)
- Docker Compose de desenvolvimento

### Ingress Alternativos
- NGINX Ingress Controller
- Traefik
- HAProxy

### CI/CD de Outras Plataformas
- .gitlab-ci.yml
- Jenkinsfile
- .circleci/

### Observabilidade Duplicada
- APMs alternativos
- Coletores duplicados
- Dashboards redundantes

### Infraestrutura Legacy
- terraform-localstack/
- docker-compose.localstack.yml
- Configurações LocalStack

## Fluxo de Deploy

### 1. Provisionar Infraestrutura
```bash
cd infra/terraform
terraform init
terraform plan
terraform apply
```

### 2. Instalar Argo CD
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### 3. Deploy App of Apps
```bash
kubectl apply -f argo/root.yaml
```

### 4. CI/CD Pipeline
```yaml
# .github/workflows/deploy.yml
- name: Build & Push
  run: docker build -t $ECR_URI:$GITHUB_SHA .
  
- name: Update Image Tag
  run: |
    sed -i 's/tag:.*/tag: "'$GITHUB_SHA'"/' app/backend/helm/values-prod.yaml
    git commit -am "Update image tag to $GITHUB_SHA"
    git push
```

## Próximos Passos

1. **Validar Terraform**: `terraform validate && terraform plan`
2. **Testar Módulos**: Deploy em ambiente de teste
3. **Configurar Argo CD**: Instalar e configurar
4. **Migrar Aplicações**: Mover para nova estrutura
5. **Configurar Pipelines**: Atualizar GitHub Actions

## Padrões e Práticas

### Terraform
- State remoto: S3 + DynamoDB
- Workspaces por ambiente
- Modules versionados
- tflint + pre-commit hooks

### Kubernetes
- Helm por serviço
- Kustomize para overlays
- Labels/annotations padronizadas
- OTEL instrumentação obrigatória

### Observabilidade
- Datadog para APM/RUM/alertas
- Grafana para métricas/logs/traces
- OpenTelemetry como padrão de coleta
- Dashboards como código