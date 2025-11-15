# Arquitetura da Plataforma de Observabilidade

## Visão Geral

Plataforma de observabilidade padronizada e escalável para 150 clusters Kubernetes (75 produtivos), processando 600 bilhões de séries temporais e 1.5PB de logs mensalmente.

## Contexto Atual

### Cenário
- **150 clusters K8s** (50% produtivo)
- **Distribuição de ferramentas:**
  - 60% Dynatrace
  - 30% Plataforma interna (OpenTelemetry)
  - 10% NewRelic
- **Volume:**
  - 600B séries temporais/mês
  - 1.5PB logs/mês
- **Retenção:** 10 anos (compliance regulatório)

### Problemas Identificados
1. Falta de padronização e governança
2. Baixa adoção/maturidade OpenTelemetry
3. Confiabilidade e performance insuficientes
4. Baixa percepção de valor
5. Custos elevados de armazenamento
6. Ausência de chargeback estruturado
7. Controle inadequado de dados sensíveis
8. Dificuldade em escalar com volumetria crescente
9. Débito técnico acumulado

## Arquitetura Target

### Princípios
1. **OpenTelemetry First**: Instrumentação padronizada
2. **Multi-Vendor**: Suporte Dynatrace, NewRelic, plataforma interna
3. **Cost-Aware**: Chargeback, sampling inteligente, tiering
4. **Compliance**: PII masking, retenção regulatória
5. **Self-Service**: Onboarding automatizado, templates

### Componentes Principais

#### 1. Camada de Coleta (OTel Gateway)
```
Applications → OTel SDK/Agent → OTel Collector (Sidecar/DaemonSet) 
                                      ↓
                              OTel Gateway Cluster
                                      ↓
                    
                    ↓                 ↓                 ↓
              Dynatrace          NewRelic       Plataforma Interna
```

**Benefícios:**
- Desacoplamento vendor
- Transformação centralizada
- Sampling inteligente
- Enrichment unificado

#### 2. Stack Logs (Padronizada)

**Pipeline Unificado:**
```
Filebeat/OTel → Kafka (buffer) → OTel Collector (processor) 
                                          ↓
                        
                        ↓                 ↓                 ↓
                 Hot Storage        Warm Storage      Cold Storage
              (OpenSearch 7d)    (S3 Glacier 90d)   (S3 Deep 10y)
                        ↓                 ↓                 ↓
                    Vendors          Archive           Compliance
```

**Características:**
- Kafka como buffer resiliente (3d retention)
- Processamento: PII masking, sampling, enrichment
- Tiering automático por idade/importância
- Backup regulatório em S3 Deep Archive

#### 3. Stack Métricas (Padronizada)

**Arquitetura:**
```
OTel Collector → Victoria Metrics (cluster) → Grafana
                       ↓
            Victoria Metrics (LTS)
                       ↓
              S3 (retenção longa)
```

**Características:**
- Victoria Metrics cluster (alta disponibilidade)
- Retenção inteligente: hot (30d), warm (1y), cold (10y)
- Downsampling automático
- Remote write para vendors

#### 4. Stack Traces (Padronizada)

**Arquitetura:**
```
OTel SDK → OTel Collector → OTel Gateway
                                  ↓
                    
                    ↓             ↓             ↓
              Jaeger (7d)   Tempo (30d)   S3 (1y)
```

**Características:**
- Tail-based sampling (1-10%)
- Correlação automática com logs/métricas
- Retention policy por criticidade

## Governança e Padronização

### Decision Framework

**Matriz de Decisão para Novos Projetos:**

| Critério | Plataforma Interna | Dynatrace | NewRelic |
|----------|-------------------|-----------|----------|
| Custo/mês | < $5k | $5k-50k | $10k-30k |
| Criticidade | Baixa-Média | Alta | Média-Alta |
| Compliance | Standard | High | High |
| Customização | Alta | Baixa | Média |
| Suporte | Team | 24x7 | 24x7 |

**Regra Geral:**
- **Default**: Plataforma Interna (OpenTelemetry)
- **Exceções**: Aprovação via comitê (criticidade, SLA)

### Standards OpenTelemetry

#### Instrumentação Obrigatória
1. **Traces:** 100% dos requests HTTP/gRPC
2. **Métricas:** RED (Rate, Errors, Duration) + USE (Utilization, Saturation, Errors)
3. **Logs:** Structured JSON + trace correlation
4. **Semantic Conventions:** Seguir OTEL spec v1.x

#### Exemplo Configuração
```yaml
# otel-config-template.yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 10s
    send_batch_size: 1024
  
  memory_limiter:
    check_interval: 1s
    limit_mib: 512
  
  resourcedetection:
    detectors: [env, system, docker, kubernetes]
  
  k8sattributes:
    auth_type: "serviceAccount"
    passthrough: false
    extract:
      metadata:
        - k8s.namespace.name
        - k8s.deployment.name
        - k8s.pod.name
        - k8s.node.name
  
  # PII Masking
  transform:
    log_statements:
      - context: log
        statements:
          - replace_pattern(body, "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b", "***EMAIL***")
          - replace_pattern(body, "\\b\\d{3}-\\d{2}-\\d{4}\\b", "***SSN***")
  
  # Sampling
  probabilistic_sampler:
    sampling_percentage: 10

exporters:
  otlp/internal:
    endpoint: otel-gateway.observability.svc:4317
  
  otlp/dynatrace:
    endpoint: ${DYNATRACE_ENDPOINT}
    headers:
      Authorization: "Api-Token ${DYNATRACE_TOKEN}"
  
  prometheusremotewrite:
    endpoint: http://victoria-metrics:8428/api/v1/write

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, resourcedetection, k8sattributes, probabilistic_sampler, batch]
      exporters: [otlp/internal]
    
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, resourcedetection, k8sattributes, batch]
      exporters: [prometheusremotewrite]
    
    logs:
      receivers: [otlp]
      processors: [memory_limiter, resourcedetection, k8sattributes, transform, batch]
      exporters: [otlp/internal]
```

## Estratégia de Custos e Chargeback

### Cost Optimization

#### 1. Sampling Inteligente
- **Traces:** Tail-based (erros 100%, success 1-10%)
- **Logs:** Por nível (ERROR 100%, INFO 10%, DEBUG 1%)
- **Métricas:** Downsampling após 30 dias

#### 2. Tiering de Armazenamento
| Tipo | Hot | Warm | Cold | Archive |
|------|-----|------|------|---------|
| **Logs** | 7d OpenSearch | 90d S3 Standard | 1y S3 Glacier | 10y S3 Deep |
| **Métricas** | 30d Victoria | 1y Victoria LTS | 10y S3 Parquet | - |
| **Traces** | 7d Jaeger | 30d Tempo | 1y S3 | - |

**Economia Estimada:** 60-70% vs hot storage only

#### 3. Vendor Cost Management
- **Dynatrace:** DEM units monitoring + DDU alerting
- **NewRelic:** Ingest pipeline pre-filtering
- **Plataforma Interna:** Reserved capacity (Victoria Metrics, OpenSearch)

### Sistema de Chargeback

#### Modelo de Cobrança

**Fórmula:**
```
Custo_Mensal = (Logs_GB × $0.10) + (Traces_M × $2.00) + (Metrics_Series × $0.001) + (Vendor_License / Teams)
```

**Implementação:**
```yaml
# chargeback-config.yaml
teams:
  - name: team-payments
    namespace: payments
    cost_center: CC-1234
    tags:
      business_unit: finance
      criticality: high
    
  - name: team-logistics
    namespace: logistics
    cost_center: CC-5678
    tags:
      business_unit: operations
      criticality: medium

pricing:
  logs:
    ingress_per_gb: 0.10
    storage_hot_per_gb_month: 0.15
    storage_warm_per_gb_month: 0.03
    storage_cold_per_gb_month: 0.01
  
  metrics:
    per_timeseries_month: 0.001
    per_query: 0.0001
  
  traces:
    per_million_spans: 2.00
    per_gb_storage: 0.20

vendors:
  dynatrace:
    fixed_cost_month: 50000
    allocation_method: proportional  # ou fixed_per_team
  
  newrelic:
    fixed_cost_month: 15000
    allocation_method: proportional
```

#### Dashboard de Custos
- **Visibilidade:** Custo por time/namespace/cluster
- **Alertas:** Budget excedido (>90%)
- **Otimização:** Recomendações automáticas

## Controle de Dados Sensíveis

### PII Detection & Masking

**Padrões Detectados:**
- Email, CPF, CNPJ, Telefone
- Cartão de crédito, Senhas
- IP interno, Tokens

**Implementação:**
```yaml
# otel-pii-processor.yaml
processors:
  transform/pii:
    log_statements:
      - context: log
        statements:
          # Email
          - replace_pattern(body, "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b", "***EMAIL***")
          
          # CPF
          - replace_pattern(body, "\\b\\d{3}\\.\\d{3}\\.\\d{3}-\\d{2}\\b", "***CPF***")
          
          # CNPJ
          - replace_pattern(body, "\\b\\d{2}\\.\\d{3}\\.\\d{3}/\\d{4}-\\d{2}\\b", "***CNPJ***")
          
          # Credit Card
          - replace_pattern(body, "\\b\\d{4}[\\s-]?\\d{4}[\\s-]?\\d{4}[\\s-]?\\d{4}\\b", "***CARD***")
          
          # IP Privado
          - replace_pattern(body, "\\b10\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\b", "***IP***")
          - replace_pattern(body, "\\b172\\.(1[6-9]|2[0-9]|3[0-1])\\.\\d{1,3}\\.\\d{1,3}\\b", "***IP***")
          - replace_pattern(body, "\\b192\\.168\\.\\d{1,3}\\.\\d{1,3}\\b", "***IP***")
    
    trace_statements:
      - context: span
        statements:
          - set(attributes["http.request.header.authorization"], "***REDACTED***") where attributes["http.request.header.authorization"] != nil
          - set(attributes["http.request.header.cookie"], "***REDACTED***") where attributes["http.request.header.cookie"] != nil
```

### Compliance & Auditoria

**Features:**
1. **Audit Log:** Todas as queries em dados sensíveis
2. **RBAC:** Acesso baseado em roles/teams
3. **Encryption:** At-rest (S3 KMS) + in-transit (TLS)
4. **Retention Policy:** Automático por tipo de dado

## Práticas de Engenharia

### 1. Automação de Onboarding

**Self-Service Portal:**
```bash
# CLI Tool
otel-platform init \
  --team payments \
  --namespace payments \
  --vendor internal \
  --instrumentation auto

# Output:
 Namespace created
 OTel Collector deployed
 ServiceAccount configured
 Grafana datasource added
 Default dashboards imported
 Chargeback enabled
```

### 2. GitOps para Configuração

**Estrutura:**
```
observability-config/
 teams/
    payments/
       otel-config.yaml
       sampling-rules.yaml
       dashboards/
       alerts/
    logistics/
 global/
    collectors/
    gateways/
    backends/
 policies/
     pii-masking.yaml
     retention.yaml
     chargeback.yaml
```

### 3. Testes Automatizados

**Pipeline:**
```yaml
# .github/workflows/observability-test.yaml
name: Test Observability Stack

on: [pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Validate OTel Config
        run: |
          otelcol validate --config=otel-config.yaml
      
      - name: Test PII Masking
        run: |
          echo '{"email":"test@example.com","cpf":"123.456.789-00"}' | \
          otelcol --config=otel-config.yaml | \
          grep -q "***EMAIL***" && grep -q "***CPF***"
      
      - name: Load Test
        run: |
          k6 run load-test.js --vus 100 --duration 30s
      
      - name: Cost Estimation
        run: |
          ./scripts/estimate-cost.sh --config otel-config.yaml
```

### 4. Observabilidade da Observabilidade

**Meta-Monitoring:**
- **SLIs:** Latência coleta, perda de dados, disponibilidade
- **Dashboards:** Health dos coletores, gateways, backends
- **Alertas:** Pipeline degradado, custo anômalo

## Roadmap de Implementação

### Fase 1: Fundação (Mês 1-2)
- [ ] Deploy OTel Gateway centralizado
- [ ] Migrar 10% clusters para plataforma padronizada
- [ ] Implementar PII masking básico
- [ ] Setup Victoria Metrics cluster

### Fase 2: Escala (Mês 3-4)
- [ ] Migrar 50% clusters
- [ ] Implementar chargeback v1
- [ ] Deploy tiering de logs (hot/warm/cold)
- [ ] Automatizar onboarding

### Fase 3: Otimização (Mês 5-6)
- [ ] Tail-based sampling inteligente
- [ ] Chargeback v2 (showback → chargeback)
- [ ] 100% clusters migrados
- [ ] Deprecar stacks legadas

### Fase 4: Excelência (Mês 7+)
- [ ] AIOps: Anomaly detection, root cause analysis
- [ ] FinOps: Otimização contínua de custos
- [ ] Compliance: Certificações (SOC2, ISO27001)
- [ ] Developer Experience: IDE plugins, auto-instrumentation

## Métricas de Sucesso

### KPIs
1. **Adoção:** 90% clusters em plataforma padronizada (6 meses)
2. **Custo:** Redução 40% custo unitário (12 meses)
3. **Performance:** P99 < 100ms latência coleta
4. **Confiabilidade:** 99.9% disponibilidade pipeline
5. **Compliance:** 100% dados sensíveis masked
6. **Developer Satisfaction:** NPS > 50

### Dashboards
- **Executive:** Custo total, adoção, incidentes
- **Platform Team:** Health, performance, capacity
- **Development Teams:** Custo por team, uso, onboarding

## Referências

- [OpenTelemetry Best Practices](https://opentelemetry.io/docs/concepts/data-collection/)
- [Victoria Metrics Architecture](https://docs.victoriametrics.com/Cluster-VictoriaMetrics.html)
- [FinOps Framework](https://www.finops.org/)
- [OWASP Data Classification](https://owasp.org/www-community/Data_Classification)
