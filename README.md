# Case: Cloud-Native AWS on EKS Fargate with Datadog, DynamoDB, Blue/Green CI/CD

This repo implements an end-to-end reference for a cost-aware, secure, observable, cloud-native app on AWS:
- Frontend (React + Vite), Mobile (Expo/React Native minimal)
- Backend (Node.js + TypeScript, Express)
- Persistence: DynamoDB (serverless, pay-per-request)
- Infrastructure as Code: Terraform (VPC, EKS Fargate profiles, ECR, IRSA, DynamoDB, Datadog Cluster Agent)
- Kubernetes: Deployments, Services, Ingress, ConfigMap, IRSA ServiceAccount, blue/green-ready labels
- CI/CD: GitHub Actions builds Docker images, pushes to ECR, and performs blue/green deployments to EKS
- Observability: Datadog (APM agentless, logs via CloudWatch integration, cluster metrics via Cluster Agent), dashboards and monitors
- Quality: Unit tests, WireMock integration test via Testcontainers, load and chaos scripts
- Governance: FinOps tips and security controls baked in (least privilege, tags, HPA, IRSA)

## Prerequisites
- Node.js 20+
- Docker & Docker Compose
- Terraform 1.8+
- AWS account + IAM permissions to create VPC, EKS, ECR, IAM OIDC, and roles
- Datadog account and API key (free trial ok) to send APM/metrics

## Quick start (local)
1) Copy `.env.example` to `.env` and set variables as needed. For full Datadog export to SaaS, set `DD_API_KEY` and `DD_SITE`.
2) Build & run with a single script (recommended):

```bash
./scripts/up.sh local
```

Alternatively, use Docker Compose directly:

```bash
docker compose up --build
```

3) Access services:
- Frontend: http://localhost:5173
- Backend: http://localhost:3000 (health: `/healthz`, metrics: `/metrics`)

Logs are printed in containers; traces/metrics go to the Datadog Agent. If `DD_API_KEY` + `DD_SITE` are set, the Agent forwards to Datadog.

3) Run smoke tests end-to-end:

```bash
./scripts/test.sh local
```

4) (Opcional) Subir o app Mobile (Expo web) em perfil dedicado:

```bash
docker compose --profile mobile up -d --build mobile
# Acesse: http://localhost:19006
```

## Project structure
- `app/frontend`: React + Vite app
- `app/backend`: Express + TypeScript service with dd-trace, pino logs, prom-client metrics, DogStatsD business metrics
- `app/mobile`: Minimal Expo app to consume backend endpoints
- `k8s`: Kubernetes manifests for frontend and backend (Deployments, Services, Ingress)
- `infra/terraform`: Terraform for AWS (VPC, EKS, ECR, OIDC/IRSA, Helm: Datadog)
- `observabilidade/datadog`: Example dashboards (4 golden signals + business KPIs) and monitors
- `.github/workflows`: CI (test) and CD (build/push/deploy)

## Tests
Run tests locally in each app folder (Node & PNPM/NPM supported). CI runs them automatically on PRs.
- Backend: Jest (`npm test`)
- Frontend: Vitest (`npm test`)

## Provision AWS infra (Terraform)
1) Configure AWS credentials in your shell (e.g., `AWS_PROFILE`, or access keys).
2) Create a `terraform.tfvars` (or pass `-var` flags) with region and required inputs.
3) From `infra/terraform`:

Container-only (no tools on host):

```bash
# Build tools image (terraform+awscli+kubectl+helm)
docker compose -f docker-compose.tools.yml build tools

# (Optional) set AWS_PROFILE/AWS_REGION and mount your ~/.aws by default via docker-compose.tools.yml
# Run terraform fully inside the tools container
./scripts/tf.sh init -input=false
./scripts/tf.sh validate
./scripts/tf.sh plan -input=false
./scripts/tf.sh apply -input=false

# Configure kubeconfig inside container (writes to mounted ~/.kube)
./scripts/aws.sh eks update-kubeconfig --name "$EKS_CLUSTER_NAME" --region "$AWS_REGION"

# Verify cluster access using kubectl in container
./scripts/kubectl.sh get ns
```

One-liner using the helper script (applies Terraform and deploys manifests):

```bash
EKS_CLUSTER_NAME=<name> AWS_REGION=<region> AWS_ACCOUNT_ID=<account> ./scripts/up.sh eks
```

Apply Datadog dashboards/monitors via API (requer DD_API_KEY, DD_APP_KEY e DD_SITE):

```bash
DD_API_KEY=<key> DD_APP_KEY=<appkey> DD_SITE=datadoghq.com ./scripts/datadog-apply-dashboards.sh
DD_API_KEY=<key> DD_APP_KEY=<appkey> DD_SITE=datadoghq.com ./scripts/datadog-apply-monitors.sh
```

Important inputs (see `infra/terraform/variables.tf`):
- `region`, `project_name`, `eks_cluster_name`
- `dd_api_key`, `dd_site` (for Datadog Cluster Agent and agentless APM)
- `dynamodb_table_name` (defaults to `orders`)

What gets created:
- VPC (2 AZs, public/private subnets, single NAT)
- EKS (Fargate profiles for namespace `case` and CoreDNS)
- OIDC provider (IRSA)
- ECR repos: `backend`, `frontend`
- DynamoDB table for orders (PAY_PER_REQUEST)
- IAM role for ServiceAccount `backend-sa` with least-privilege access to the table (IRSA)
- Datadog Cluster Agent via Helm (node agents disabled for Fargate)

## Deploy to EKS (Blue/Green)
1) Build and push images to ECR (done by CI/CD on merge to `main`).
2) Apply Kubernetes manifests from `k8s`.

Blue/green is implemented by:
1) Creating `-green` deployments from the base manifests with label `color: green` and new image tags
2) Waiting for rollout
3) Switching Service selectors from `color: blue` to `color: green`
4) Cleaning up old blue deployments

CI/CD uses GitHub OIDC to assume an AWS role; configure:
- Repository Variables: `AWS_REGION`, `AWS_ACCOUNT_ID`, `EKS_CLUSTER_NAME`, `DD_SITE`, `DDB_TABLE`
- Repository Secrets: `AWS_ROLE_TO_ASSUME`, `DD_API_KEY`, `BACKEND_IRSA_ROLE_ARN` (from Terraform output)

## Observability (Datadog)
- 4 Golden Signals (latency, traffic, errors, saturation) exposed via Prometheus metrics and APM spans
- Business metrics (`orders.created`, `orders.failed`) can be emitted via DogStatsD (disabled by default on Fargate; set `DD_ENABLE_DOGSTATSD=true` if you provide a DogStatsD endpoint)
- Example dashboards and monitors are in `observabilidade/datadog/`

EKS Fargate specifics:
- Datadog Agent DaemonSet is not supported; we install the Cluster Agent for cluster-level telemetry.
- Application APM is configured in agentless mode (see `k8s/backend-deployment.yaml`: `DD_TRACE_AGENTLESS=true`, `DD_SITE`, `DD_API_KEY`).
- Logs: keep container logs to stdout/stderr; enable Datadog AWS integration to ingest from CloudWatch Logs.

Bonus options:
- Prometheus/Grafana: scrape `/metrics` via Prometheus Operator; import dashboards or federate into Datadog.
- AppDynamics: alternative APM (not wired here) – keep as a pluggable choice.

Dashboards included:
- `observabilidade/datadog/dashboards/golden_signals_backend.json`
- `observabilidade/datadog/dashboards/business_metrics.json`

Para criar via API rapidamente, use os scripts em `scripts/datadog-apply-*.sh`.

## Tests, Load, and Chaos
- Backend unit tests: `npm test` in `app/backend`
- WireMock integration test (Testcontainers): `tests/orders.wiremock.test.ts`
- Load test (Locust): `scripts/locustfile.py` – hit `GET/POST /api/orders`
- Chaos: `scripts/chaos_kill_random_pod.py` deletes a random pod in a namespace

Run Locust locally (optional):

```bash
pip install locust
locust -f scripts/locustfile.py --host "http://<ingress-host>"
```

Quick smoke tests (local or EKS):

```bash
# Local
./scripts/test.sh local

# EKS (uses ingress host if present, otherwise temporary port-forward)
./scripts/test.sh eks
```

## Optional: AppDynamics

O backend pode inicializar o agente AppDynamics se `APPD_ENABLED=true` e as variáveis estiverem definidas (sem quebrar quando ausentes):

- APPD_CONTROLLER_HOST, APPD_CONTROLLER_PORT, APPD_SSL_ENABLED
- APPD_ACCOUNT_NAME, APPD_ACCESS_KEY
- APPD_APP_NAME, APPD_TIER_NAME, APPD_NODE_NAME

Basta definir as variáveis no deployment (K8s ou Compose) antes de iniciar o serviço. Quando não habilitado, a aplicação ignora o agente.

Chaos test (optional; requires Kubernetes Python client):

```bash
pip install kubernetes
python scripts/chaos_kill_random_pod.py case app=backend
```

## Validation checklist
- [ ] Local: Frontend loads and calls backend `/api/orders`
- [ ] Local: Backend `/healthz` returns 200
- [ ] Local: Backend `/metrics` exposes metrics; Datadog Agent receives metrics/traces/logs
- [ ] Terraform apply succeeds and creates EKS Fargate cluster + DynamoDB + Datadog Cluster Agent
- [ ] CI passes unit tests
- [ ] CD deploys to EKS and service is reachable via the Ingress

## Security, Data Management, and FinOps

Security
- IRSA: backend uses a ServiceAccount bound to an IAM role with least-privilege DynamoDB access
- Private subnets for Fargate pods; NAT for egress
- Image scanning: ECR scan-on-push enabled
- Secrets: Datadog API key via K8s Secret; consider AWS Secrets Manager + CSI driver for app secrets
- Network Policies: consider default-deny and allow-list policies (add per environment)
- Alerts: Datadog monitors in `observabilidade/datadog/monitors/` can be applied via API (automation script TBD)

Data Management
- Persistence in DynamoDB `orders` (PK: `id`) – serverless, scales automatically
- Access control via IAM (IRSA); no static credentials
- Lifecycle: PAY_PER_REQUEST and on-demand capacity keep costs low. Consider TTL attributes for transient data.
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
