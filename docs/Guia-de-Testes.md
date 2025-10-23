# Guia de Testes – Case Cloud-Native AWS EKS (Fargate) e Simulação em Docker

## 1. Objetivo
Descrever como testar os serviços (frontend, backend) localmente com Docker e em um cluster EKS (Fargate), incluindo verificação de saúde, criação/listagem de pedidos, testes de carga, caos e observabilidade (Datadog, CloudWatch, Prometheus).

## 2. Pré‑requisitos
- Docker Desktop em execução
- Conta AWS com permissões para EKS/ECR/IAM/DynamoDB (para EKS)
- (Opcional) DD_API_KEY e DD_SITE para Datadog

## 3. Testes Locais (Docker)
### 3.1 Subir o ambiente
- (Opcional) exporte:
  - Bash
    ```bash
    export DD_API_KEY="<sua_api_key>"
    export DD_SITE="datadoghq.com"
    ```
  - PowerShell
    ```powershell
    $env:DD_API_KEY="<sua_api_key>"
    $env:DD_SITE="datadoghq.com"
    ```
- Suba:
  ```bash
  docker compose up -d --build
  ```

### 3.2 Health check
```bash
curl -sf http://localhost:3000/healthz
```

### 3.3 Criar/Listar pedidos
```bash
curl -s -X POST http://localhost:3000/api/orders \
     -H "Content-Type: application/json" \
     -d '{"item":"book","price":10}'
curl -s http://localhost:3000/api/orders
```

### 3.4 Métricas/Observabilidade
- Prometheus: http://localhost:3000/metrics
- Datadog Agent local recebe traços/logs/metrics (se DD_API_KEY/DD_SITE definidos)

### 3.5 Frontend
- http://localhost:5173

## 4. Testes no EKS (Fargate)
### 4.1 Provisionamento via container de ferramentas
```bash
# Build da toolbox
docker compose -f docker-compose.tools.yml build tools
# Terraform (dentro do container)
./scripts/tf.sh init -input=false
./scripts/tf.sh plan -input=false
./scripts/tf.sh apply -input=false
# Kubeconfig
./scripts/aws.sh eks update-kubeconfig --name "$EKS_CLUSTER_NAME" --region "$AWS_REGION"
```

### 4.2 Deploy Blue/Green (GitHub Actions)
- Pipeline: .github/workflows/cd.yml (ou cicd.yml)
- Faz build/push, cria "green", troca Service, limpa "blue"

### 4.3 Validações pós‑deploy
```bash
./scripts/kubectl.sh -n case get deploy,svc,pods
./scripts/kubectl.sh -n case rollout status deploy/backend-green --timeout=180s
```
(Com Ingress) Health HTTP: `curl -sf http://<seu-host>/healthz`

### 4.4 Caos (LitmusChaos)
```bash
./scripts/kubectl.sh apply -f k8s/litmus/litmus-rbac.yaml
./scripts/kubectl.sh apply -f k8s/litmus/backend-pod-delete-engine.yaml
./scripts/kubectl.sh -n case get chaosresults
```

### 4.5 Observabilidade
- Datadog APM (agentless), métricas de cluster, logs via CloudWatch (integração AWS)
- Opcional: Prometheus/Grafana (ENABLE_PROMETHEUS=true)

## 5. Testes Automatizados
### 5.1 Backend unitários
```bash
cd app/backend
npm ci
npm test
```

### 5.2 WireMock (Testcontainers)
- `app/backend/tests/orders.wiremock.test.ts`
- Requer Docker ativo
```bash
npm test
```

### 5.3 Carga (Locust)
```bash
pip install locust
locust -f scripts/locustfile.py --host http://localhost:3000
```

### 5.4 Caos simples
```bash
pip install kubernetes
python scripts/chaos_kill_random_pod.py case app=backend
```

## 6. Painéis e Monitores (Datadog)
- Dashboards: `observabilidade/datadog/dashboards/*`
- Monitors: `observabilidade/datadog/monitors/monitors.json`

## 7. Critérios de Sucesso
- Local: healthz ok, pedidos funcionam, /metrics acessível
- EKS: rollout green ok, ChaosResult=Pass, serviços íntegros após caos
- Observabilidade: traços APM, métricas e logs presentes

## 8. Troubleshooting
- Docker: certifique-se que o engine está “running”
- Front 5173: confira mapeamento de portas e logs do container
- Datadog: valide DD_API_KEY/DD_SITE e integração AWS->Datadog
- EKS: verifique IRSA, eventos do namespace e permissões IAM
