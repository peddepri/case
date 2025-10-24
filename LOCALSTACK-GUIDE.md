# Guia LocalStack - AWS Local

Este guia explica como usar o LocalStack para simular a infraestrutura AWS localmente.

## O que é LocalStack?

LocalStack é um emulador de serviços AWS que roda localmente, permitindo:
- ✅ Testar infraestrutura sem custos AWS
- ✅ Desenvolvimento offline
- ✅ Testes de integração rápidos
- ✅ CI/CD sem credenciais reais

## Pré-requisitos

- Docker Desktop rodando
- Token LocalStack (Pro opcional para EKS completo)
- Mínimo 4GB RAM, 2 CPUs

## Serviços Suportados

### Gratuitos (Community Edition)
- DynamoDB ✓
- S3 ✓
- ECR (básico) ✓
- IAM ✓
- Secrets Manager ✓
- CloudWatch Logs ✓
- STS ✓

### Pro (requer licença - NÃO DISPONÍVEL na Community)
- **EKS** - ERRO: "API for service 'eks' not yet implemented or pro feature"
- ECR avançado
- RDS
- Lambda layers
- Etc.

**IMPORTANTE:** Este projeto usa **LocalStack Community**, que NÃO inclui EKS. Para desenvolvimento local:
1. Use **kind** (Kubernetes in Docker) para simular cluster Kubernetes - JÁ CONFIGURADO
2. LocalStack provê apenas DynamoDB, S3, IAM e outros serviços básicos
3. Para EKS real, use AWS diretamente (via Terraform)

## Início Rápido

### 1. Configurar variáveis

O arquivo `.env.localstack` já está configurado com seu token:

```bash
LOCALSTACK_AUTH_TOKEN=ls-rOhOqaQe-9209-3474-kAto-faXUpetu092e
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
AWS_DEFAULT_REGION=us-east-1
```

### 2. Subir ambiente

```bash
# Dar permissão aos scripts
chmod +x scripts/localstack-*.sh
chmod +x scripts/localstack-init/ready.d/*.sh

# Subir LocalStack + Backend + Frontend
./scripts/localstack-up.sh
```

**Tempo:** ~30-60 segundos para inicializar

### 3. Verificar recursos criados

```bash
# Rodar testes automáticos
./scripts/localstack-test.sh
```

### 4. Testar aplicação

```bash
# Backend
curl http://localhost:3001/healthz

# Criar order
curl -X POST http://localhost:3001/api/orders \
  -H "Content-Type: application/json" \
  -d '{"item":"notebook","price":2500}'

# Listar orders
curl http://localhost:3001/api/orders

# Frontend
# Abrir no navegador: http://localhost:5174
```

## Recursos Criados Automaticamente

O script `scripts/localstack-init/ready.d/01-init-resources.sh` cria:

1. **DynamoDB Table**: `orders`
   - Key: `id` (String)
   - Billing: PAY_PER_REQUEST

2. **IAM Role**: `backend-sa-role`
   - Simula IRSA (ServiceAccount)
   - Política: Acesso DynamoDB

3. **ECR Repositories**:
   - `backend`
   - `frontend`

4. **Secrets Manager**:
   - `datadog/api-key`

5. **S3 Bucket**:
   - `case-terraform-state`

6. **CloudWatch Log Group**:
   - `/aws/eks/case-eks/cluster`

**NÃO CRIADO (Pro feature):**
- **EKS Cluster** - Erro: "API for service 'eks' not yet implemented or pro feature"
- Para Kubernetes local, use **kind** (Kubernetes in Docker) que JÁ ESTÁ configurado neste projeto

## Alternativa ao EKS: kind (Kubernetes in Docker)

Como EKS não está disponível no LocalStack Community, este projeto usa **kind** para simular um cluster Kubernetes local:

```bash
# Verificar se kind está instalado
kind version

# Cluster já configurado no projeto
kind get clusters
# Output esperado: case-local

# Verificar pods no namespace case
kubectl get pods -n case

# Port-forward para acessar serviços
kubectl port-forward -n case svc/backend 3002:3000
kubectl port-forward -n case svc/frontend 5173:80
kubectl port-forward -n case svc/mobile 19007:19006
```

**Vantagens do kind:**
- Gratuito e open-source
- Cluster Kubernetes real (não emulado)
- Suporta todos os recursos K8s (deployments, services, ingress, etc.)
- Usa apenas Docker (sem VMs)
- Rápido de criar e destruir

## Comandos AWS CLI

Todos os comandos AWS devem usar `--endpoint-url`:

```bash
# Configurar alias (opcional)
alias awslocal='aws --endpoint-url=http://localhost:4566'

# Exemplos
awslocal dynamodb list-tables
awslocal dynamodb scan --table-name orders
awslocal ecr describe-repositories
awslocal iam list-roles
awslocal s3 ls
awslocal secretsmanager get-secret-value --secret-id datadog/api-key
```

## Uso com Terraform

Configure o backend S3 local:

```hcl
# infra/terraform/backend-localstack.tf
terraform {
  backend "s3" {
    bucket         = "case-terraform-state"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    endpoint       = "http://localhost:4566"
    
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    use_path_style              = true
  }
}

provider "aws" {
  region     = "us-east-1"
  access_key = "test"
  secret_key = "test"
  
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  
  endpoints {
    dynamodb       = "http://localhost:4566"
    ec2            = "http://localhost:4566"
    ecr            = "http://localhost:4566"
    eks            = "http://localhost:4566"
    iam            = "http://localhost:4566"
    s3             = "http://localhost:4566"
    secretsmanager = "http://localhost:4566"
    sts            = "http://localhost:4566"
  }
}
```

Aplicar:

```bash
cd infra/terraform
terraform init -backend-config="endpoint=http://localhost:4566"
terraform plan
terraform apply
```

## Teste de Carga

LocalStack suporta os mesmos testes que AWS real:

```bash
# Locust contra backend LocalStack
locust -f scripts/locustfile.py \
  --host "http://localhost:3001" \
  --users 50 \
  --spawn-rate 5 \
  --run-time 2m \
  --headless
```

## Logs e Debug

### Ver logs do LocalStack

```bash
docker compose -f docker-compose.localstack.yml logs -f localstack
```

### Ativar debug

Edite `.env.localstack`:

```bash
DEBUG=1
LS_LOG=debug
```

Reinicie:

```bash
./scripts/localstack-down.sh
./scripts/localstack-up.sh
```

### Logs do backend

```bash
docker compose -f docker-compose.localstack.yml logs -f backend-localstack
```

## Health Check

```bash
# Status geral
curl http://localhost:4566/_localstack/health

# Status formatado
curl http://localhost:4566/_localstack/health | jq

# Verificar se serviço específico está disponível
curl http://localhost:4566/_localstack/health | jq '.services.dynamodb'
```

## Persistência de Dados

Por padrão, dados são salvos em `./localstack-data`.

Para limpar:

```bash
./scripts/localstack-down.sh
# Responder 's' quando perguntado sobre remover dados
```

## Comparação: LocalStack vs AWS Real

| Recurso | LocalStack Community | LocalStack Pro | AWS Real |
|---------|---------------------|----------------|----------|
| DynamoDB | ✅ | ✅ | ✅ |
| S3 | ✅ | ✅ | ✅ |
| ECR | ⚠️ Básico | ✅ | ✅ |
| EKS | ❌ | ✅ | ✅ |
| IAM | ✅ | ✅ | ✅ |
| Secrets Manager | ✅ | ✅ | ✅ |
| CloudWatch | ⚠️ Logs only | ✅ | ✅ |
| Custo | Grátis | ~$50/mês | Variável |
| Latência | <10ms | <10ms | 20-100ms |
| Offline | ✅ | ✅ | ❌ |

## Limitações

### Community Edition

- EKS: Não suporta pods reais (apenas API mock)
- ECR: Push funciona, mas imagens não são persistidas totalmente
- CloudWatch: Apenas Logs, sem métricas/dashboards
- RDS: Não disponível

### Soluções

- **EKS local**: Use `kind` ou `minikube` separadamente
- **ECR**: Use Docker Hub ou registry local
- **Métricas**: Use Prometheus local

## Troubleshooting

### LocalStack não inicia

```bash
# Verificar logs
docker compose -f docker-compose.localstack.yml logs localstack

# Verificar portas em uso
netstat -ano | findstr "4566"

# Limpar volumes
docker compose -f docker-compose.localstack.yml down -v
rm -rf localstack-data
```

### Backend não conecta ao DynamoDB

```bash
# Verificar network
docker compose -f docker-compose.localstack.yml exec backend-localstack \
  curl http://localstack:4566/_localstack/health

# Verificar variável DYNAMODB_ENDPOINT
docker compose -f docker-compose.localstack.yml exec backend-localstack env | grep DYNAMODB
```

### Recursos não criados

```bash
# Re-executar init script manualmente
docker compose -f docker-compose.localstack.yml exec localstack \
  bash /etc/localstack/init/ready.d/01-init-resources.sh
```

### Token inválido (Pro features)

Se você não tem LocalStack Pro, remova referências a EKS do script de init.

## Parar Ambiente

```bash
# Parar containers (preservar dados)
docker compose -f docker-compose.localstack.yml down

# Parar e remover dados
./scripts/localstack-down.sh
```

## Portas Usadas

| Porta | Serviço |
|-------|---------|
| 4566 | LocalStack Gateway (todos os serviços AWS) |
| 3001 | Backend (LocalStack) |
| 5174 | Frontend (LocalStack) |
| 8127 | Datadog APM |
| 8126 | Datadog StatsD |

## Próximos Passos

Depois de validar com LocalStack:

1. ✅ Ambiente local funcionando
2. ➡️ Provisionar AWS real (Seção 2 do GUIA-VALIDACAO-PRE-DEMO.md)
3. ➡️ Deploy no EKS real
4. ➡️ Datadog observabilidade completa

## Recursos Úteis

- Docs LocalStack: https://docs.localstack.cloud
- AWS CLI Docs: https://docs.aws.amazon.com/cli/
- LocalStack Pro: https://localstack.cloud/pricing
- Dashboard: https://app.localstack.cloud (Pro)

---

**💡 Dica:** Use LocalStack para desenvolvimento/testes e AWS real para staging/produção.
