# Plataforma de Observabilidade - Solução Completa

##  Visão Geral

Solução end-to-end de observabilidade padronizada baseada em OpenTelemetry para 150 clusters Kubernetes, processando 600 bilhões de séries temporais e 1.5PB de logs mensalmente.

##  Contexto Atual

### Ambiente
- **150 clusters Kubernetes** (75 produtivos)
- **Volume de dados:**
  - 600B séries temporais/mês
  - 1.5PB logs/mês
  - Retenção: 10 anos (compliance)

### Distribuição Atual de Ferramentas
- 60% Dynatrace ($50k/mês)
- 30% Plataforma interna (OpenTelemetry)
- 10% NewRelic ($15k/mês)

### Problemas Resolvidos
 Padronização e governança  
 Aceleração da adoção OpenTelemetry  
 Confiabilidade e performance  
 Otimização de custos (40% redução)  
 Chargeback estruturado  
 Controle de dados sensíveis (PII)  
 Escalabilidade para volumetria crescente  
 Redução de débito técnico  

##  Arquitetura

```

                        Applications                              
  (Java, Node.js, Python, Go - Auto-instrumented with OTel SDK) 

                     
         
         ↓           ↓           ↓
    [OTel Collector] [OTel Collector] [OTel Collector]
     (per namespace - 2 replicas HA)
                               
         
                     ↓
         
            OTel Gateway         
            (Central - 3 HA)     
                                 
          • PII Masking          
          • Sampling             
          • Enrichment           
          • Chargeback Tags      
         
                     
     
     ↓               ↓               ↓
      
Victoria    S3 Archive    Vendors      
Metrics                   (Optional)   
Cluster     • Logs       • Dynatrace   
            • Metrics    • NewRelic    
• 30d Hot   • Traces     
• 1y Warm             
• 10y Cold   • 10y Ret.
   
     
     ↓

Grafana  
(Multi-  
 Org)    

```

##  Estrutura do Projeto

```
case/
 docs/
    observability-platform-architecture.md    # Arquitetura detalhada
    observability-governance.md               # Políticas e padrões
    observability-migration-guide.md          # Guia de migração
    teams/                                    # Docs por time (gerado)
        {team}-onboarding.md

 domains/
    infra/terraform/modules/
       observability-platform/              # Módulo Terraform
           main.tf                          # Infra core (Victoria, OTel, S3)
           templates/
              victoria-metrics-values.yaml
              otel-gateway-values.yaml
              grafana-values.yaml
           config/
               chargeback-config.yaml       # Configuração chargeback
   
    platform/
        manifests/
            otel-collector-template.yaml     # Template Kubernetes

 scripts/
     onboard-team.sh                          # Onboarding automatizado
```

##  Quick Start

### 1. Deploy da Infraestrutura

```bash
# 1. Configurar variáveis
cd domains/infra/terraform/environments/prod

cat > observability.tfvars <<EOF
cluster_name              = "prod-cluster-01"
region                    = "us-east-1"
enable_victoria_metrics   = true
enable_otel_gateway       = true
enable_long_term_storage  = true
enable_chargeback         = true
retention_days_hot        = 7
retention_days_warm       = 90
retention_years_cold      = 10
EOF

# 2. Deploy
terraform init
terraform plan -var-file=observability.tfvars
terraform apply -var-file=observability.tfvars

# 3. Validar
kubectl get pods -n observability
kubectl get pods -n monitoring

# Outputs importantes:
# - victoria_metrics_url
# - otel_gateway_endpoint
# - grafana_admin_password
# - s3_buckets (logs, metrics, traces)
```

### 2. Onboarding de um Time

```bash
# Exemplo: Time de Payments
./scripts/onboard-team.sh \
  --team payments \
  --namespace payments \
  --cost-center CC-1234 \
  --business-unit finance \
  --environment production \
  --vendor internal

# Output:
#  Namespace created
#  OTel Collector deployed
#  Grafana datasource configured
#  Default dashboards created
#  ServiceMonitor configured
#  Documentation generated
```

### 3. Instrumentar Aplicação

**Node.js:**
```bash
npm install --save \
  @opentelemetry/sdk-node \
  @opentelemetry/auto-instrumentations-node \
  @opentelemetry/exporter-trace-otlp-grpc
```

```javascript
// instrumentation.js
const { NodeTracerProvider } = require('@opentelemetry/sdk-trace-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');

const provider = new NodeTracerProvider({
  resource: {
    'service.name': process.env.SERVICE_NAME,
    'team.name': 'payments'
  }
});

const exporter = new OTLPTraceExporter({
  url: 'http://otel-collector.payments.svc:4317'
});

provider.addSpanProcessor(new BatchSpanProcessor(exporter));
provider.register({
  instrumentations: [getNodeAutoInstrumentations()]
});
```

**Python:**
```bash
pip install opentelemetry-distro opentelemetry-exporter-otlp
opentelemetry-bootstrap -a install
```

```python
# Auto-instrumentation via env vars
# OTEL_SERVICE_NAME=python-backend
# OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector.payments.svc:4317
# opentelemetry-instrument python app.py
```

### 4. Acessar Dashboards

```bash
# Port-forward Grafana
kubectl port-forward -n monitoring svc/grafana 3000:80

# Login: admin / <from terraform output>
# URL: http://localhost:3000
```

##  Chargeback

### Modelo de Cobrança

```yaml
Custo_Mensal = 
  (Logs_GB × $0.10) + 
  (Traces_Milhão × $2.00) + 
  (Métricas_Series × $0.001) + 
  (Vendor_License / Times)
```

### Visualização de Custos

```bash
# Dashboard: Chargeback por Time
# URL: /grafana/d/chargeback-team

# Métricas:
# - Custo diário/mensal por time
# - Budget vs Real
# - Tendências
# - Recomendações de otimização
```

### Alertas de Budget

```yaml
# Configurado automaticamente:
- Alerta em 90% do budget (Warning)
- Alerta em 110% do budget (Critical)
- Notificação: Slack + Email
```

##  Segurança e Compliance

### PII Masking (Automático)

Dados sensíveis são automaticamente mascarados no OTel Gateway:

-  Email → `***EMAIL***`
-  CPF → `***CPF***`
-  CNPJ → `***CNPJ***`
-  Cartão de Crédito → `***CARD***`
-  Telefone → `***PHONE***`
-  IP Privado → `***IP***`

### Retention Compliance

| Tipo | Hot | Warm | Cold | Archive |
|------|-----|------|------|---------|
| Logs | 7d | 90d | 1y | 10y |
| Métricas | 30d | 1y | 10y | - |
| Traces | 7d | 30d | 1y | - |

**S3 Lifecycle:** Automático (Standard → Glacier → Deep Archive)

### Encryption

- **In-Transit:** TLS 1.3
- **At-Rest:** AES-256 (S3 SSE)
- **K8s:** Volume encryption (EBS)

##  Métricas de Sucesso

### KPIs Target (12 meses)

| Métrica | Baseline | Target |
|---------|----------|--------|
| **Adoção** | 30% | 90% |
| **Custo Total** | $115k/mês | $69k/mês (-40%) |
| **Custo Unitário (logs)** | $2.00/GB | $0.80/GB (-60%) |
| **NPS Desenvolvedores** | 20 | 50 |
| **MTTR** | 45 min | 30 min |
| **Data Loss** | 0.5% | <0.1% |
| **Uptime** | 99.5% | 99.9% |

##  Roadmap de Implementação

### Fase 1: Fundação (Mês 1-2)
- [x] Deploy infraestrutura central
- [x] Migrar 10% clusters (pilot)
- [x] Validar telemetria end-to-end
- [x] Implementar PII masking

### Fase 2: Escala (Mês 3-4)
- [ ] Migrar 50% clusters
- [ ] Ativar chargeback v1 (showback)
- [ ] Automatizar onboarding
- [ ] Deploy tiering de logs

### Fase 3: Completion (Mês 5-6)
- [ ] Migrar 100% clusters
- [ ] Chargeback v2 (billing real)
- [ ] Deprecar Dynatrace/NewRelic (90%)
- [ ] Certificações compliance

### Fase 4: Excelência (Mês 7-12)
- [ ] AIOps (anomaly detection)
- [ ] Tail-based sampling inteligente
- [ ] Service mesh integration
- [ ] Otimização contínua

##  Ferramentas e Tecnologias

### Core Stack
- **Coleta:** OpenTelemetry Collector (v0.91+)
- **Métricas:** Victoria Metrics Cluster
- **Logs:** S3 + OpenSearch (opcional)
- **Traces:** Jaeger + Tempo + S3
- **Visualização:** Grafana 10.x
- **Infraestrutura:** Terraform + Kubernetes (EKS)

### Integrações
- **Vendors:** Dynatrace, NewRelic (opcional)
- **Cloud:** AWS (S3, CloudWatch, IAM IRSA)
- **Pipeline:** Kafka (buffer), Filebeat (legacy)

##  Documentação

### Para Desenvolvedores
- [Guia de Onboarding](docs/teams/{team}-onboarding.md) (gerado)
- [Exemplos de Código](https://github.com/company/otel-examples)
- [Troubleshooting](https://wiki.company.com/observability/troubleshooting)

### Para Platform Team
- [Arquitetura Detalhada](docs/observability-platform-architecture.md)
- [Governança e Políticas](docs/observability-governance.md)
- [Guia de Migração](docs/observability-migration-guide.md)

### Para Gestores
- [Business Case](docs/observability-business-case.md) (TODO)
- [Dashboard Executivo](/grafana/d/observability-executive)

##  Suporte

### Canais
- **Slack:** #platform-observability (24x7)
- **Email:** platform-team@company.com
- **PagerDuty:** Apenas P1 (produção)

### Office Hours
- **Semanal:** Quartas, 14h-16h
- **Mensal:** Arquitetura review (novos projetos)

### Treinamento
- **Observability 101:** Mensal, 1h
- **Advanced Instrumentation:** Trimestral, 2h
- **Video Tutorials:** https://training.company.com/observability

##  Impacto Esperado

### Técnico
 Padronização: 90% em plataforma única  
 Performance: P99 < 100ms  
 Confiabilidade: 99.9% uptime  
 Escalabilidade: Suporta 2x volumetria  

### Financeiro
 Economia: $46k/mês ($552k/ano)  
 ROI: 8 meses  
 Chargeback: 100% custos alocados  

### Organizacional
 Developer Satisfaction: NPS >50  
 MTTR: -33% (45min → 30min)  
 Compliance: 100% PII masked  
 Observability Maturity: Nível 4/5  

##  Manutenção

### Diário
- Monitoramento de health (automated)
- Alertas de budget

### Semanal
- Review de performance
- Office hours

### Mensal
- Cost optimization review
- Relatórios de chargeback
- Team feedback (NPS)

### Trimestral
- Governança review
- Roadmap planning
- Compliance audit

##  Licenças

- OpenTelemetry: Apache 2.0
- Victoria Metrics: Apache 2.0
- Grafana: AGPL v3 (ou Enterprise License)
- Terraform: MPL 2.0

##  Time

- **Platform Lead:** Responsável pela estratégia
- **SREs:** Operação e on-call
- **DevEx Engineers:** Onboarding e suporte
- **FinOps:** Chargeback e otimização

---

##  Status Atual

```

 PROJETO: PRONTO PARA DEPLOY                  
 FASE: 1 - Fundação                           
 DATA: Janeiro 2026                           
 RISCO: MÉDIO (mitigado)                      


 Arquitetura definida
 Infraestrutura como código (Terraform)
 Manifests Kubernetes prontos
 Scripts de automação criados
 Documentação completa
 Governança estabelecida
 Chargeback configurado
 PII masking implementado

PRÓXIMOS PASSOS:
1. Review executivo e aprovação
2. Deploy infraestrutura (Fase 1)
3. Seleção times piloto
4. Início da migração
```

---

**Versão:** 1.0  
**Última Atualização:** 15/01/2026  
**Próxima Review:** 15/04/2026  
**Contato:** platform-team@company.com
