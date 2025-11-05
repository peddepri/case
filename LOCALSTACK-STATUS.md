# LocalStack: O que Funciona e O que Não Funciona

## Status Atual: LocalStack Community Edition

###  Funcionando (Gratuito)

| Serviço | Status | Uso no Projeto |
|---------|--------|----------------|
| DynamoDB |  OK | Tabela `orders` criada automaticamente |
| S3 |  OK | Bucket para Terraform state (simulado) |
| IAM |  OK | Role `backend-sa-role` para acesso DynamoDB |
| Secrets Manager |  OK | Secret `datadog/api-key` |
| CloudWatch Logs |  OK | Log group `/aws/eks/case-eks/cluster` |
| STS |  OK | Tokens temporários |
| ECR (básico) |  OK | Repos `backend` e `frontend` |

###  NÃO Funciona (Requer Pro)

| Serviço | Status | Alternativa |
|---------|--------|-------------|
| **EKS** |  ERRO | **kind** (Kubernetes in Docker) |
| RDS |  Pro | PostgreSQL/MySQL via Docker |
| Lambda |  Pro | Express local |
| ECS |  Pro | Docker Compose |

## Erro Esperado: EKS

Quando você tenta criar um cluster EKS no LocalStack Community, recebe este erro:

```
API for service 'eks' not yet implemented or pro feature
```

**Isso é NORMAL e ESPERADO!**

## Solução: kind (Já Configurado)

Este projeto usa **kind** em vez de LocalStack EKS:

```bash
# Verificar cluster kind
kind get clusters
# Output: case-local

# Ver pods
kubectl get pods -n case
# Output:
# NAME                        READY   STATUS    RESTARTS   AGE
# backend-xxx                 1/1     Running   0          5m
# frontend-xxx                1/1     Running   0          5m
# mobile-xxx                  1/1     Running   0          5m
```

## Como Usar LocalStack Corretamente

### 1. Apenas para serviços suportados

LocalStack é usado APENAS para:
- DynamoDB (banco de dados)
- S3 (storage)
- IAM (permissões)
- Secrets Manager (credenciais)

### 2. NÃO tente usar para Kubernetes

Para Kubernetes local:
-  Não use: LocalStack EKS
-  Use: **kind**

### 3. Teste de infraestrutura AWS

```bash
# Listar recursos LocalStack
aws --endpoint-url=http://localhost:4566 dynamodb list-tables
aws --endpoint-url=http://localhost:4566 iam list-roles
aws --endpoint-url=http://localhost:4566 s3 ls
```

## Comandos Úteis

### Verificar LocalStack

```bash
# Health check
curl http://localhost:4566/_localstack/health

# Ver serviços ativos
docker compose logs localstack | grep "Ready"
```

### Testar DynamoDB

```bash
# Criar item
aws --endpoint-url=http://localhost:4566 dynamodb put-item \
  --table-name orders \
  --item '{"id":{"S":"test-123"},"item":{"S":"notebook"},"price":{"N":"2500"}}'

# Scan tabela
aws --endpoint-url=http://localhost:4566 dynamodb scan --table-name orders
```

### Backend conectando ao LocalStack

O backend já está configurado para conectar ao LocalStack:

```javascript
// app/backend/src/index.ts
const dynamoClient = new DynamoDBClient({
  endpoint: process.env.AWS_ENDPOINT || "http://localhost:4566",
  region: process.env.AWS_REGION || "us-east-1",
  credentials: {
    accessKeyId: "test",
    secretAccessKey: "test"
  }
});
```

## Configuração no Kubernetes (kind)

Os pods no kind acessam LocalStack via:

```yaml
# k8s/backend-deployment.yaml
env:
  - name: AWS_ENDPOINT
    valueFrom:
      configMapKeyRef:
        name: backend-config
        key: AWS_ENDPOINT
    # Valor: http://host.docker.internal:4566 (Windows/Mac)
    # ou: http://192.168.x.x:4566 (IP do host)
```

## Comparação: Local vs AWS Real

| Componente | Local (Dev) | AWS (Prod) |
|------------|-------------|------------|
| **Banco de Dados** | LocalStack DynamoDB | AWS DynamoDB |
| **Kubernetes** | **kind** | AWS EKS Fargate |
| **Container Registry** | Local Docker | AWS ECR |
| **Secrets** | LocalStack Secrets Mgr | AWS Secrets Manager |
| **Logs** | Loki (Docker Compose) | CloudWatch Logs |
| **Métricas** | Prometheus (Docker) | Datadog + CloudWatch |

## Quando Usar LocalStack Pro?

Considere LocalStack Pro ($50/mês) se você precisa:
-  EKS emulado (sem kind)
-  RDS completo
-  Lambda avançado
-  ECS/Fargate
-  Suporte prioritário

**Para este projeto:** LocalStack Community + kind é suficiente!

## Troubleshooting

### "connection refused" ao acessar LocalStack do pod

**Problema:** Pod no kind não consegue acessar `localhost:4566`

**Solução 1 (Windows/Mac):**
```bash
# Use host.docker.internal
kubectl patch configmap backend-config -n case \
  --patch '{"data":{"AWS_ENDPOINT":"http://host.docker.internal:4566"}}'
```

**Solução 2 (Linux/All):**
```bash
# Use IP do host
IP=$(hostname -I | awk '{print $1}')
kubectl patch configmap backend-config -n case \
  --patch "{\"data\":{\"AWS_ENDPOINT\":\"http://$IP:4566\"}}"
```

### Verificar se backend está conectado

```bash
# Ver logs do backend
kubectl logs -n case deployment/backend | grep DynamoDB

# Esperado:
# [2025-10-24T10:30:00.000Z] INFO: DynamoDB client initialized
# [2025-10-24T10:30:01.000Z] INFO: Connected to DynamoDB at http://192.168.15.7:4566
```

## Próximos Passos

1.  LocalStack Community está rodando
2.  kind cluster está configurado
3.  Backend conecta ao DynamoDB local
4.  Frontend e Mobile funcionando

**Tudo pronto para desenvolvimento local!**

Para deploy em AWS real:
```bash
cd infra/terraform
terraform init
terraform apply
```

## Referências

- LocalStack Coverage: https://docs.localstack.cloud/references/coverage/
- LocalStack Pro: https://localstack.cloud/pricing/
- kind: https://kind.sigs.k8s.io/
- AWS SDK: https://docs.aws.amazon.com/sdk-for-javascript/
