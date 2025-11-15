# Observability Platform Module

Módulo Terraform completo para implantar uma plataforma de observabilidade enterprise baseada em OpenTelemetry, Victoria Metrics e Grafana.

## Recursos Criados

### Infraestrutura Core
- **OpenTelemetry Gateway**: Coletor centralizado com HA, auto-scaling, PII masking
- **Victoria Metrics Cluster**: Backend de métricas escalável (vmselect, vminsert, vmstorage)
- **Grafana**: Visualização com datasources pré-configurados
- **S3 Buckets**: Armazenamento de longo prazo (logs, métricas, traces) com lifecycle

### Segurança & Governança
- **IAM Roles (IRSA)**: Acesso seguro a recursos AWS
- **PII Masking**: 6 patterns automáticos (email, CPF, CNPJ, cartões, telefones, IPs)
- **Chargeback Tagging**: Atribuição de custos por equipe/centro de custo
- **Encryption**: AES-256 em todos os buckets S3

### Namespaces Kubernetes
- `observability`: OTel Gateway, collectors
- `monitoring`: Victoria Metrics, Grafana

## Uso Básico

```hcl
module "observability" {
  source = "./modules/observability-platform"

  cluster_name = "my-eks-cluster"
  region       = "us-east-1"

  # Features (tudo habilitado por padrão)
  enable_victoria_metrics  = true
  enable_otel_gateway      = true
  enable_grafana           = true
  enable_long_term_storage = true

  # Retenção
  retention_days_warm   = 90   # Dias em S3 Standard-IA
  retention_years_cold  = 10   # Anos antes de deletar
  victoria_metrics_retention_days = 30

  # Opcional: Integração com vendors externos
  dynatrace_endpoint   = "https://abc123.live.dynatrace.com/api/v2/otlp"
  dynatrace_token      = var.dynatrace_api_token  # Sensitive!
  
  newrelic_endpoint    = "https://otlp.nr-data.net:4317"
  newrelic_license_key = var.newrelic_license    # Sensitive!

  tags = {
    Environment = "production"
    Team        = "platform"
    CostCenter  = "engineering"
  }
}
```

## Outputs

```hcl
# Endpoint para aplicações enviarem telemetria
output "otel_endpoint" {
  value = module.observability.otel_gateway_endpoint
}

# URL para queries Prometheus
output "victoria_url" {
  value = module.observability.victoria_metrics_url
}

# Senha do Grafana (sensível)
output "grafana_password" {
  value     = module.observability.grafana_admin_password
  sensitive = true
}

# Instruções de onboarding
output "next_steps" {
  value = module.observability.onboarding_instructions
}
```

## Variáveis

| Nome | Descrição | Tipo | Padrão | Obrigatório |
|------|-----------|------|--------|:-----------:|
| `cluster_name` | Nome do cluster EKS | `string` | - |  |
| `region` | Região AWS | `string` | - |  |
| `enable_victoria_metrics` | Habilitar Victoria Metrics | `bool` | `true` |  |
| `enable_otel_gateway` | Habilitar OTel Gateway | `bool` | `true` |  |
| `enable_grafana` | Habilitar Grafana | `bool` | `true` |  |
| `enable_long_term_storage` | Habilitar S3 storage | `bool` | `true` |  |
| `retention_days_warm` | Dias em S3 Standard-IA | `number` | `90` |  |
| `retention_years_cold` | Anos antes de deletar | `number` | `10` |  |
| `victoria_metrics_retention_days` | Retenção Victoria Metrics | `number` | `30` |  |
| `dynatrace_endpoint` | Endpoint Dynatrace OTLP | `string` | `""` |  |
| `dynatrace_token` | Token API Dynatrace | `string` | `""` |  |
| `newrelic_endpoint` | Endpoint NewRelic OTLP | `string` | `""` |  |
| `newrelic_license_key` | License key NewRelic | `string` | `""` |  |
| `tags` | Tags para todos os recursos | `map(string)` | `{}` |  |

## Pré-requisitos

1. **Cluster EKS** rodando com Fargate ou nodes gerenciados
2. **OIDC Provider** configurado para IRSA
3. **Helm** instalado no cluster (via Terraform Helm provider)
4. **Providers Terraform**:
   - `hashicorp/aws ~> 5.0`
   - `hashicorp/kubernetes ~> 2.23`
   - `hashicorp/helm ~> 2.11`
   - `hashicorp/random` (latest)

## Deploy

```bash
# 1. Inicializar
cd domains/infra/terraform/modules/observability-platform
terraform init

# 2. Planejar
terraform plan \
  -var="cluster_name=my-eks" \
  -var="region=us-east-1"

# 3. Aplicar
terraform apply \
  -var="cluster_name=my-eks" \
  -var="region=us-east-1"

# 4. Obter password do Grafana
terraform output -raw grafana_admin_password
```

## Próximos Passos

Após o deploy:

1. **Onboard equipes**: `./scripts/onboard-team.sh --namespace my-team --cost-center CC123`
2. **Instrumentar apps**: Ver [docs/observability-migration-guide.md](../../../docs/observability-migration-guide.md)
3. **Acessar Grafana**: `kubectl port-forward -n monitoring svc/grafana 3000:80`
4. **Configurar chargeback**: Editar `config/chargeback-config.yaml`

## Arquitetura

```

   Applications   (Node.js, Python, Java)

          OTLP (gRPC/HTTP)
         

    OTel Gateway (3 replicas, HPA)          
   
   PII Mask  Sampling  Chargeback Tags  
   

                               
                               
   Victoria  S3    Dynatrace  NewRelic
   Metrics  (LTS)  (optional) (optional)
     
     
  Grafana
```

## Custos Estimados

| Componente | Custo Mensal (estimado) |
|------------|-------------------------|
| S3 Storage (1.5 PB) | $23,000 (com lifecycle) |
| Victoria Metrics (cluster) | $2,000 (r6i.xlarge × 3) |
| OTel Gateway | $500 (fargate) |
| Grafana | $200 (fargate) |
| CloudWatch | $500 |
| **Total** | **~$26,200** |

**Economia vs vendors**: $45k/mês (40% redução de $115k para $69k)

## Troubleshooting

### OTel Gateway não recebe telemetria
```bash
kubectl logs -n observability -l app=otel-gateway
kubectl get svc -n observability otel-gateway-opentelemetry-collector
```

### Victoria Metrics sem dados
```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=victoria-metrics
kubectl exec -n monitoring deploy/victoria-metrics-vmselect -- wget -O- http://localhost:8481/metrics
```

### Grafana não conecta ao Victoria Metrics
```bash
kubectl port-forward -n monitoring svc/victoria-metrics-vmselect 8481:8481
curl http://localhost:8481/select/0/prometheus/api/v1/query?query=up
```

## Suporte

- Documentação: [OBSERVABILITY_INDEX.md](../../../../OBSERVABILITY_INDEX.md)
- Arquitetura: [docs/observability-platform-architecture.md](../../../docs/observability-platform-architecture.md)
- Guia de Migração: [docs/observability-migration-guide.md](../../../docs/observability-migration-guide.md)
- Slack: `#plataforma-observabilidade`
