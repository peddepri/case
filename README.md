# Case: Cloud-Native AWS on EKS Fargate with Datadog, DynamoDB, Blue/Green CI/CD

This repo implements an end-to-end reference for a cost-aware, secure, observable, cloud-native app on AWS:
- Frontend (React + Vite), Mobile (Expo/React Native minimal)
- Backend (Node.js + TypeScript, Express)
- Persistence: DynamoDB (serverless, pay-per-request)
# Case: Aplicação Cloud-Native na AWS (EKS Fargate) com Datadog, DynamoDB e CI/CD Blue/Green

Este repositório entrega uma solução ponta a ponta, observável e com custos sob controle, totalmente em contêineres e pronta para AWS:
- Frontend (React + Vite), Mobile (Expo/React Native – modo web no Docker opcional)
- Backend (Node.js + TypeScript, Express)
- Persistência: DynamoDB (serverless, PAY_PER_REQUEST)
- IaC (Infrastructure as Code): Terraform (VPC, EKS com Fargate, ECR, IRSA, DynamoDB, Datadog Cluster Agent)
- Kubernetes: Deployments, Services, Ingress, ConfigMap, ServiceAccount com IRSA e rótulos Blue/Green
- CI/CD: GitHub Actions para build/push de imagens e deploy Blue/Green em EKS
- Observabilidade: Datadog (APM agentless no EKS, logs via CloudWatch, métricas de cluster via Cluster Agent), dashboards e monitores prontos
- Qualidade: Testes unitários, teste de integração com WireMock (Testcontainers), scripts de carga e caos
- Governança: Recomendações de FinOps e segurança (least privilege, tags, HPA, IRSA)

## Pré-requisitos
- Docker & Docker Compose
- Conta AWS (com permissões para VPC, EKS, ECR, IAM OIDC/roles)
- Conta Datadog e API key (trial serve) para APM/métricas
- Opcional localmente: Node.js 20+ e Terraform 1.8+ (não obrigatórios, pois há toolbox em Docker)

## Início rápido (local)
1) Copie `.env.example` para `.env` e ajuste se necessário. Para enviar dados ao Datadog SaaS, defina `DD_API_KEY` e `DD_SITE`.
2) Suba tudo com o script (recomendado):

```bash
./scripts/up.sh local
```

Ou diretamente com Docker Compose:

```bash
docker compose up --build
```

Logs são exibidos nos contêineres; métricas/traces vão para o Datadog Agent. Com `DD_API_KEY` + `DD_SITE`, o Agent encaminha para o Datadog SaaS.

3) Teste de fumaça ponta a ponta:

```bash
./scripts/test.sh local
```

4) (Opcional) Subir o app Mobile (Expo web) em perfil dedicado:

```bash
docker compose --profile mobile up -d --build mobile
# Acesse: http://localhost:19006
```

## Estrutura do projeto
- `app/frontend`: App React + Vite
- `app/backend`: Serviço Express + TypeScript com dd-trace, logs pino, métricas prom-client e métricas de negócio (DogStatsD)
- `app/mobile`: App Expo mínimo (consome o backend; roda no modo web via Docker)
- `k8s`: Manifests Kubernetes de frontend e backend (Deployments, Services, Ingress)
- `infra/terraform`: Terraform para AWS (VPC, EKS, ECR, OIDC/IRSA, Helm: Datadog)
- `observabilidade/datadog`: Dashboards de 4 Golden Signals e métricas de negócio, e monitores exemplo
- `.github/workflows`: CI (testes) e CD (build/push/deploy)

## Testes
Execute localmente nos diretórios de cada app; o CI executa em PRs e pushes:
- Backend: Jest (`npm test`)
- Frontend: Vitest (`npm test`)

## Provisionar infra AWS (Terraform)
Sem instalar nada na máquina, usando o toolbox em Docker:

```bash
# Construir imagem de ferramentas (terraform+awscli+kubectl+helm)
docker compose -f docker-compose.tools.yml build tools

# Terraform 100% dentro do container
./scripts/tf.sh init -input=false
./scripts/tf.sh validate
./scripts/tf.sh plan -input=false
./scripts/tf.sh apply -input=false

# kubeconfig (grava em ~/.kube montado)
./scripts/aws.sh eks update-kubeconfig --name "$EKS_CLUSTER_NAME" --region "$AWS_REGION"

# Verificar acesso ao cluster
./scripts/kubectl.sh get ns
```

Variáveis importantes (veja `infra/terraform/variables.tf`):
- `region`, `project_name`, `eks_cluster_name`
- `dd_api_key`, `dd_site` (para Datadog Cluster Agent e APM agentless)
- `dynamodb_table_name` (padrão `orders`)

Recursos criados:
- VPC (2 AZs, subnets públicas/privadas, 1 NAT)
- EKS (Fargate profiles para namespace `case` e CoreDNS)
- OIDC provider (IRSA)
- ECR repos: `backend`, `frontend`
- Tabela DynamoDB `orders` (PAY_PER_REQUEST)
- IAM Role para ServiceAccount `backend-sa` com acesso mínimo (IRSA)
- Datadog Cluster Agent via Helm (sem node agents no Fargate)

## Deploy no EKS (Blue/Green)
1) CI/CD faz build/push das imagens para ECR ao dar merge em `main`.
2) Manifests do `k8s` são aplicados no cluster.

Blue/Green funciona assim:
1) Criar deployments “-green” com rótulo `color: green` e nova imagem
2) Aguardar rollout
3) Trocar selector do Service de `color: blue` para `color: green`
4) Remover o antigo “blue” após validação

CI/CD usa OIDC do GitHub para assumir um role na AWS. Configure no repositório:
- Repository Variables: `AWS_REGION`, `AWS_ACCOUNT_ID`, `EKS_CLUSTER_NAME`, `DD_SITE`, `DDB_TABLE`
- Repository Secrets: `AWS_ROLE_TO_ASSUME`, `DD_API_KEY`, `BACKEND_IRSA_ROLE_ARN` (saída do Terraform)

## Observabilidade (Datadog)
- 4 Golden Signals (latência, tráfego, erros, saturação) via métricas Prometheus e APM spans
- Métricas de negócio (`orders.created`, `orders.failed`) via DogStatsD (desativado por padrão no Fargate; habilite com `DD_ENABLE_DOGSTATSD=true` se tiver endpoint)
- Dashboards e monitores prontos em `observabilidade/datadog/`

No EKS Fargate:
- Sem DaemonSet do Agent; usamos Cluster Agent para telemetria do cluster
- APM da aplicação em modo agentless (ver `k8s/backend-deployment.yaml`: `DD_TRACE_AGENTLESS=true`, `DD_SITE`, `DD_API_KEY`)
- Logs: stdout/stderr; habilite a integração Datadog-AWS para ingerir via CloudWatch Logs

Opções bônus:
- Prometheus/Grafana: scrape de `/metrics` via Prometheus Operator; importar dashboards ou federar no Datadog
- AppDynamics: APM alternativo (opcional, ver seção abaixo)

Dashboards inclusos:
- `observabilidade/datadog/dashboards/golden_signals_backend.json`
- `observabilidade/datadog/dashboards/business_metrics.json`

Criação via API (scripts prontos):

```bash
DD_API_KEY=<key> DD_APP_KEY=<appkey> DD_SITE=datadoghq.com ./scripts/datadog-apply-dashboards.sh
DD_API_KEY=<key> DD_APP_KEY=<appkey> DD_SITE=datadoghq.com ./scripts/datadog-apply-monitors.sh
```

## Testes, carga e caos
- Unitários do backend: `npm test` em `app/backend`
- Teste de integração com WireMock (Testcontainers): `tests/orders.wiremock.test.ts`
- Carga (Locust): `scripts/locustfile.py` – endpoints `GET/POST /api/orders`
- Caos: `scripts/chaos_kill_random_pod.py` remove um pod aleatório no namespace

Locust local (opcional):

```bash
pip install locust
locust -f scripts/locustfile.py --host "http://<ingress-host>"
```

Smoke tests rápidos (local ou EKS):

```bash
# Local
./scripts/test.sh local

# EKS (usa host do Ingress se houver; senão faz port-forward temporário)
./scripts/test.sh eks
```

## AppDynamics (opcional)
O backend inicializa o agente AppDynamics quando `APPD_ENABLED=true` e as variáveis estão definidas (sem quebrar quando ausentes):

- APPD_CONTROLLER_HOST, APPD_CONTROLLER_PORT, APPD_SSL_ENABLED
- APPD_ACCOUNT_NAME, APPD_ACCESS_KEY
- APPD_APP_NAME, APPD_TIER_NAME, APPD_NODE_NAME

Defina-as no deployment (K8s/Compose) antes de iniciar o serviço. Se não habilitado, a app ignora o agente.

## Toolbox: tudo dentro de contêiner
Para garantir que nada seja instalado na máquina local, use os scripts que executam tudo via Docker:

- Terraform/AWS/kubectl/Helm:
	- `./scripts/tf.sh` / `./scripts/aws.sh` / `./scripts/kubectl.sh` / `./scripts/helm.sh`
- Node/NPM (para gerar lockfiles, instalar deps etc.):
	- `./scripts/node.sh "cd /workspace/app/backend && npm ci"`
	- `./scripts/generate-lockfiles.sh` (gera package-lock.json em todos os apps)
- Subir/validar rápido:
	- `./scripts/up.sh local` e `./scripts/test.sh local`
	- `EKS_CLUSTER_NAME=<nome> AWS_REGION=<regiao> AWS_ACCOUNT_ID=<conta> ./scripts/up.sh eks`

## Checklist de validação
- [ ] Local: Frontend abre e consome `/api/orders`
- [ ] Local: Backend `/healthz` retorna 200
- [ ] Local: `/metrics` expõe métricas; Datadog Agent recebe metrics/traces/logs
- [ ] Terraform apply cria EKS Fargate + DynamoDB + Datadog Cluster Agent
- [ ] CI passa os testes
- [ ] CD faz deploy no EKS e o serviço responde via Ingress

## Segurança, Dados e FinOps
Segurança
- IRSA: backend usa ServiceAccount atrelado a IAM Role com acesso mínimo ao DynamoDB
- Subnets privadas para pods no Fargate; NAT para egress
- Image scanning: ECR com scan-on-push
- Segredos: API key do Datadog via Secret K8s; considerar AWS Secrets Manager + CSI driver
- NetworkPolicies: considerar default-deny e allow-lists por ambiente
- Alertas: monitores em `observabilidade/datadog/monitors/` (aplicar via scripts)

Gestão de dados
- DynamoDB `orders` (PK: `id`) – serverless, escala automática
- Controle de acesso via IAM (IRSA); sem credenciais estáticas
- Lifecycle: PAY_PER_REQUEST com custo sob demanda; avaliar TTL para dados transitórios
- Backups/exports: habilitar PITR ou exports agendados se necessário

FinOps
- Fargate reduz custo ocioso; utilize requests/limits adequados
- HPA incluso (70% CPU) – considere automações para scale-to-zero fora do horário
- Tags do Terraform aplicadas para alocação de custos
- NAT tem custo fixo – avaliar VPC endpoints p/ Datadog intake (avançado)

## Datadog trial: como usar
1) Crie conta trial em datadoghq.com e copie sua API key
2) Configure o secret `DD_API_KEY` no repositório
3) Configure `DD_SITE` em repo variables (ex.: `datadoghq.com` ou `datadoghq.eu`)
4) Faça merge em `main` e veja traces, métricas e dashboards

## Troubleshooting
- Docker com recursos suficientes (CPU/RAM)
- Sem dados no Datadog? Verifique `DD_API_KEY` + `DD_SITE` e logs do Agent
- Em K8s, confira eventos, permissões e image pulls

Nota de manutenção: este arquivo foi atualizado para acionar o pipeline de CI/CD em 2025-10-23.
- Backups/exports: enable PITR or scheduled exports if needed

FinOps
- Fargate removes node management and reduces idle costs; use right-sized requests/limits
- HPA manifests provided (CPU 70%) – scale to zero out-of-hours by automation if permissible
- Terraform tags (`local.tags`) applied across resources for cost allocation
- NAT gateway is a fixed cost – consider VPC endpoints for Datadog intake to reduce egress (advanced)

## How to use Datadog trial
1) Sign up for a free trial at datadoghq.com and copy your API key
2) Set repository secret `DD_API_KEY`
3) Set `DD_SITE` repository variable (e.g., `datadoghq.com` or `datadoghq.eu`)
4) Merge to `main` to trigger CI/CD and view APM traces, cluster telemetry, and dashboards

## Troubleshooting
- Ensure Docker has enough resources (CPU/RAM)
- If Datadog data doesn’t show up, confirm `DD_API_KEY` + `DD_SITE` and Agent logs
- Check Kubernetes events and pod logs for image pulls and permissions
