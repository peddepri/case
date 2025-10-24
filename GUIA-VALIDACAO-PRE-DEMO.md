# Guia de Validação Pré-Demo: Case Cloud-Native AWS EKS

Este guia orienta a validação completa do ambiente antes da apresentação.

## Pré-requisitos

- [ ] Docker Desktop rodando (mínimo 4GB RAM, 2 CPUs)
- [ ] Conta AWS com permissões (VPC, EKS, ECR, IAM, DynamoDB)
- [ ] Conta Datadog (trial) com API key e Application key
- [ ] Repositório GitHub configurado (github.com/peddepri/case)
- [ ] AWS CLI configurado (`aws configure` com credenciais válidas)

## 1. Validação Local (15 minutos)

### 1.1 Subir stack local

```bash
cd C:/Users/prisc/Projetos/case

# Subir todos os serviços
./scripts/up.sh local

# Ou via compose direto
docker compose up -d --build

# Verificar containers rodando
docker compose ps
```

**Esperado:** 5 containers UP (backend, frontend, datadog-agent, dynamodb-local, dynamodb-init)

### 1.2 Smoke tests locais

```bash
# Rodar testes automatizados
./scripts/test.sh local
```

**Esperado:**
- ✅ Backend health: 200
- ✅ GET /api/orders: 200
- ✅ POST /api/orders (válido): 201
- ✅ POST /api/orders (inválido): 400
- ✅ Metrics endpoint: 200

### 1.3 Validação manual

```bash
# Backend
curl http://localhost:3000/healthz
curl http://localhost:3000/api/orders
curl http://localhost:3000/metrics

# Frontend (abrir no navegador)
# http://localhost:5173
```

**Checklist:**
- [ ] Backend responde em http://localhost:3000
- [ ] Frontend carrega em http://localhost:5173
- [ ] Frontend consome /api/orders (lista vazia ou com dados)
- [ ] Métricas Prometheus expostas em /metrics
- [ ] Logs aparecem no `docker compose logs backend`

### 1.4 Validar Datadog local (opcional)

Se configurou `DD_API_KEY` no `.env`:

```bash
# Ver logs do agent
docker compose logs datadog-agent | grep "Datadog Agent is running"

# Verificar envio de métricas
docker compose logs datadog-agent | grep "Sent payload"
```

**Esperado:** Agent conectado ao Datadog SaaS e enviando métricas/traces.

---

## 2. Provisionar Infraestrutura AWS (30-45 minutos)

### 2.1 Preparar variáveis Terraform

Edite `infra/terraform/terraform.tfvars` (crie se não existir):

```hcl
region              = "us-east-1"  # ou sua região preferida
project_name        = "case"
eks_cluster_name    = "case-eks"
dd_api_key          = "<sua-DD-API-KEY>"
dd_site             = "datadoghq.com"
dynamodb_table_name = "orders"
```

### 2.2 Executar Terraform (via toolbox Docker)

```bash
# Build toolbox
docker compose -f docker-compose.tools.yml build tools

# Terraform init
./scripts/tf.sh init -input=false

# Terraform plan (revisar recursos a criar)
./scripts/tf.sh plan -input=false

# Terraform apply (aprovar quando solicitado)
./scripts/tf.sh apply
```

**Tempo estimado:** 20-30 minutos (criação do EKS)

**Recursos criados:**
- VPC (2 AZs, subnets públicas/privadas, NAT gateway)
- EKS cluster (Fargate profiles: `case`, `coredns`)
- OIDC provider (para IRSA)
- ECR repos: `backend`, `frontend`
- DynamoDB table `orders`
- IAM Role `backend-sa-role` (IRSA com acesso DynamoDB)
- Datadog Cluster Agent (Helm)

### 2.3 Capturar outputs

```bash
# Obter outputs
./scripts/tf.sh output

# Anotar:
# - backend_irsa_role_arn
# - eks_cluster_name
# - ecr_backend_repo
# - ecr_frontend_repo
# - oidc_provider_arn (para GitHub Actions OIDC)
```

### 2.4 Configurar kubeconfig

```bash
export AWS_REGION="us-east-1"
export EKS_CLUSTER_NAME="case-eks"

./scripts/aws.sh eks update-kubeconfig --name "$EKS_CLUSTER_NAME" --region "$AWS_REGION"

# Verificar acesso
./scripts/kubectl.sh get nodes
./scripts/kubectl.sh get ns
```

**Esperado:** Namespace `case` e `kube-system` listados; Fargate nodes não aparecem até que pods sejam criados.

---

## 3. Configurar GitHub Actions (10 minutos)

### 3.1 Criar OIDC role na AWS (se ainda não fez via Terraform)

Se o Terraform não criou, você precisa:
1. No console AWS IAM, criar um Identity Provider (OIDC) para `token.actions.githubusercontent.com`
2. Criar uma role que confia nesse provider, com política para ECR push, EKS describe, etc.
3. Anotar o ARN da role

Ou adicione ao Terraform e re-aplique.

### 3.2 Configurar Repository Variables

No GitHub (Settings > Secrets and variables > Actions > Variables), adicionar:

| Nome | Valor (exemplo) |
|------|-----------------|
| `AWS_REGION` | `us-east-1` |
| `AWS_ACCOUNT_ID` | `123456789012` (sua conta AWS) |
| `EKS_CLUSTER_NAME` | `case-eks` |
| `ECR_REPO_BACKEND` | `backend` |
| `ECR_REPO_FRONTEND` | `frontend` |
| `DD_SITE` | `datadoghq.com` |
| `DDB_TABLE` | `orders` |
| `OIDC_IAM_ROLE_ARN` | `arn:aws:iam::123456789012:role/GitHubActionsRole` |

### 3.3 Configurar Repository Secrets

| Nome | Valor |
|------|-------|
| `AWS_ROLE_TO_ASSUME` | (mesmo ARN da role OIDC acima) |
| `DD_API_KEY` | (Datadog API key) |
| `DD_APP_KEY` | (Datadog Application key, para dashboards/monitors) |
| `BACKEND_IRSA_ROLE_ARN` | (output do Terraform: `backend_irsa_role_arn`) |

---

## 4. Deploy Blue/Green no EKS (20 minutos)

### 4.1 Acionar pipeline CI/CD

```bash
# Fazer um commit/push para disparar pipeline
git add .
git commit --allow-empty -m "chore: trigger CI/CD for EKS deploy"
git push origin main
```

Acompanhar em: https://github.com/peddepri/case/actions

**Esperado:**
- CI: testes backend/frontend passam
- CD (se auto-triggered) ou CI-CD:
  - Build e push de imagens para ECR
  - Apply manifests K8s
  - Blue/Green rollout
  - LitmusChaos pod-delete
  - (Opcional) Datadog dashboards/monitors apply

### 4.2 Validar deploy manual (alternativa)

Se preferir deploy manual:

```bash
# Aplicar namespace e configs
./scripts/kubectl.sh apply -f k8s/namespace.yaml

# Substituir placeholders e aplicar
sed -e "s/<AWS_REGION>/$AWS_REGION/g" \
    -e "s/<DD_API_KEY>/$DD_API_KEY/g" \
    k8s/datadog-secret.yaml | ./scripts/kubectl.sh apply -f -

sed -e "s#<BACKEND_IRSA_ROLE_ARN>#arn:aws:iam::123456789012:role/backend-sa-role#g" \
    k8s/backend-serviceaccount.yaml | ./scripts/kubectl.sh apply -f -

# Deploy backend e frontend
sed -e "s/<AWS_ACCOUNT_ID>/123456789012/g" \
    -e "s/<AWS_REGION>/$AWS_REGION/g" \
    k8s/backend-deployment.yaml | ./scripts/kubectl.sh apply -f -

sed -e "s/<AWS_ACCOUNT_ID>/123456789012/g" \
    -e "s/<AWS_REGION>/$AWS_REGION/g" \
    k8s/frontend-deployment.yaml | ./scripts/kubectl.sh apply -f -

./scripts/kubectl.sh apply -f k8s/ingress.yaml

# Aguardar rollout
./scripts/kubectl.sh rollout status deploy/backend -n case
./scripts/kubectl.sh rollout status deploy/frontend -n case
```

### 4.3 Verificar pods e services

```bash
./scripts/kubectl.sh get pods -n case
./scripts/kubectl.sh get svc -n case
./scripts/kubectl.sh get ingress -n case

# Logs do backend
./scripts/kubectl.sh logs -n case -l app=backend --tail=50
```

**Esperado:**
- Pods `backend-xxx` e `frontend-xxx` em estado `Running`
- Services `backend` e `frontend` com ClusterIP
- Ingress com ADDRESS (pode demorar alguns minutos para provisionar ALB)

### 4.4 Testar via Ingress

```bash
# Obter host do Ingress
INGRESS_HOST=$(./scripts/kubectl.sh get ingress -n case -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')

echo "Ingress: http://$INGRESS_HOST"

# Smoke tests no EKS
./scripts/test.sh eks
```

Ou acessar no navegador: `http://<INGRESS_HOST>`

**Checklist:**
- [ ] Backend health: `curl http://$INGRESS_HOST/healthz`
- [ ] Orders API: `curl http://$INGRESS_HOST/api/orders`
- [ ] Frontend carrega: abrir `http://$INGRESS_HOST` no navegador

---

## 5. Validar Observabilidade Datadog (15 minutos)

### 5.1 Aplicar dashboards e monitors

```bash
export DD_API_KEY="<sua-key>"
export DD_APP_KEY="<sua-app-key>"
export DD_SITE="datadoghq.com"

./scripts/datadog-apply-dashboards.sh
./scripts/datadog-apply-monitors.sh
```

### 5.2 Verificar no Datadog SaaS

Acesse https://app.datadoghq.com

**Infrastructure:**
- [ ] Host/pods listados em Infrastructure > Containers
- [ ] Cluster `case-eks` aparece em Kubernetes

**APM:**
- [ ] Service `backend` listado em APM > Services
- [ ] Traces de requisições GET/POST /api/orders
- [ ] Latência p95/p99 visível

**Dashboards:**
- [ ] Dashboard "4 Golden Signals - Backend" criado
- [ ] Dashboard "Business Metrics" criado
- [ ] Métricas populadas (pode levar 1-2 minutos)

**Logs:**
- [ ] Integração AWS CloudWatch configurada (se habilitou)
- [ ] Logs do backend aparecem em Logs Explorer

**Monitors:**
- [ ] Monitor de erro rate ativo
- [ ] Monitor de latência ativo
- [ ] Alertas configurados (Slack/email)

---

## 6. Testes de Resiliência (15 minutos)

### 6.1 Teste de carga (Locust)

```bash
# Instalar locust (ou rodar em Docker)
pip install locust

# Rodar teste de carga
locust -f scripts/locustfile.py --host "http://$INGRESS_HOST" --users 10 --spawn-rate 2 --run-time 2m --headless
```

**Observar:**
- [ ] Backend responde consistentemente
- [ ] HPA (se configurado) escala pods acima do mínimo
- [ ] Métricas de latência/throughput no Datadog

### 6.2 Teste de caos (LitmusChaos)

Se o pipeline aplicou LitmusChaos:

```bash
# Verificar ChaosEngine
./scripts/kubectl.sh get chaosengine -n case
./scripts/kubectl.sh describe chaosengine backend-pod-delete -n case

# Ver resultado
./scripts/kubectl.sh get chaosresult -n case -o jsonpath='{.items[0].status.experimentStatus.verdict}'
```

**Esperado:** `Pass` (pods recriados pelo Fargate após delete)

Ou executar manualmente:

```bash
# Matar pod aleatório
./scripts/kubectl.sh delete pod -n case -l app=backend --field-selector=status.phase=Running --force --grace-period=0

# Verificar recriação
./scripts/kubectl.sh get pods -n case -w
```

### 6.3 Validar rollback Blue/Green (simulação)

```bash
# Trocar service de volta para "blue" (se houver deployment blue)
./scripts/kubectl.sh patch svc/backend -n case -p '{"spec":{"selector":{"app":"backend","color":"blue"}}}'

# Aguardar alguns segundos e reverter para green
./scripts/kubectl.sh patch svc/backend -n case -p '{"spec":{"selector":{"app":"backend","color":"green"}}}'
```

**Observar:** Transição sem downtime (service continua respondendo).

---

## 7. Checklist Final de Apresentação

### 7.1 URLs e credenciais organizados

Preparar documento/slide com:
- [ ] Repositório GitHub: https://github.com/peddepri/case
- [ ] Ingress URL: `http://<ALB-DNS>`
- [ ] Datadog dashboards: links diretos
- [ ] GitHub Actions: https://github.com/peddepri/case/actions

### 7.2 Roteiro de demo (sugestão)

1. **Intro (2 min):** Arquitetura na tela (README seção Arquitetura)
2. **Local (3 min):** `./scripts/up.sh local` → smoke tests → mostrar frontend
3. **IaC (2 min):** Mostrar Terraform outputs, kubeconfig, cluster EKS no console AWS
4. **CI/CD (3 min):** Commit fictício → acompanhar pipeline GitHub Actions → Blue/Green
5. **Observabilidade (5 min):** Datadog dashboards (golden signals), traces APM, monitors
6. **Resiliência (3 min):** Locust → HPA scaling; chaos delete pod → auto-recovery
7. **FinOps/Segurança (2 min):** Slides sobre IRSA, Fargate cost, tags, HPA

### 7.3 Plano B (rollback/troubleshooting)

- [ ] Se deploy falhar: usar `./scripts/kubectl.sh rollout undo deploy/backend -n case`
- [ ] Se Ingress não provisionar: `kubectl port-forward svc/backend 8080:80 -n case`
- [ ] Se Datadog não aparecer: mostrar métricas Prometheus em `/metrics`
- [ ] Se cluster não criar: demo apenas local + slides da arquitetura

### 7.4 Backup de evidências

Capturar screenshots/vídeos antes da apresentação:
- [ ] Pipeline GitHub Actions verde
- [ ] Pods rodando no EKS (`kubectl get pods`)
- [ ] Dashboards Datadog populados
- [ ] Frontend funcionando no navegador
- [ ] Terraform outputs

---

## 8. Limpeza Pós-Demo (opcional)

Para evitar custos:

```bash
# Destruir infra AWS
./scripts/tf.sh destroy

# Parar stack local
docker compose down -v
```

**Atenção:** EKS + NAT gateway custam ~$0.10/hora. DynamoDB PAY_PER_REQUEST é barato. Datadog trial é gratuito.

---

## Troubleshooting Rápido

### Pipeline falha com "AWS variables missing"
- Confirme Variables/Secrets no GitHub
- Se não tiver AWS, o bypass está ativo; CI passa mas CD pula

### Pods não iniciam no EKS
```bash
./scripts/kubectl.sh describe pod -n case <pod-name>
```
Verificar: image pull, IRSA annotation, Fargate profile

### Datadog sem dados
- Confirme `DD_API_KEY` e `DD_SITE` corretos
- Verifique logs do Cluster Agent: `./scripts/kubectl.sh logs -n datadog -l app=datadog`

### Ingress sem ADDRESS
- Aguardar 5-10 minutos para ALB provisionar
- Verificar eventos: `./scripts/kubectl.sh describe ingress -n case`

### Testes locais falham
- Verificar containers UP: `docker compose ps`
- Logs: `docker compose logs backend`
- DynamoDB init: `docker compose logs dynamodb-init`

---

