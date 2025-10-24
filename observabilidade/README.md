# Observabilidade - Grafana Stack

Stack completa de observabilidade com Prometheus, Grafana, Loki e Tempo.

## Arquitetura

```
┌─────────────┐
│   Backend   │ → Metricas (Prometheus) → http://backend:3000/metrics
│             │ → Logs (Pino JSON)      → Promtail → Loki
│             │ → Traces (OpenTelemetry)→ Tempo
└─────────────┘
       ↓
┌──────────────────────────────────────────────────────────┐
│  Stack de Observabilidade                                │
│                                                           │
│  Prometheus (9090)  →  Coleta metricas a cada 15s       │
│  Loki (3101)        →  Agrega logs via Promtail         │
│  Tempo (3102)       →  Traces distribuidos OTLP          │
│  Promtail           →  Coleta logs dos containers       │
│                                                           │
│  Grafana (3100)     →  Visualizacao unificada           │
│    ├─ Dashboards                                         │
│    │   ├─ 4 Golden Signals                              │
│    │   └─ Business Metrics (Orders)                     │
│    ├─ Datasources                                        │
│    │   ├─ Prometheus (metricas)                         │
│    │   ├─ Loki (logs)                                   │
│    │   └─ Tempo (traces)                                │
│    └─ Explore (queries ad-hoc)                          │
└──────────────────────────────────────────────────────────┘
```

## Quick Start

### 1. Subir a stack de observabilidade

```bash
docker compose -f docker-compose.observability.yml up -d
```

### 2. Verificar servicos

```bash
# Status
docker compose -f docker-compose.observability.yml ps

# Logs
docker compose -f docker-compose.observability.yml logs -f
```

### 3. Acessar interfaces

- **Grafana**: http://localhost:3100
  - User: `admin`
  - Password: `admin`
- **Prometheus**: http://localhost:9090
- **Loki**: http://localhost:3101
- **Tempo**: http://localhost:3102

## Dashboards

### 4 Golden Signals

Dashboard: **4 Golden Signals - Backend API** (UID: `golden-signals-backend`)

1. **Latencia**
   - P50, P95, P99 de `http_request_duration_seconds`
   - Gauge com P99 atual
   - Threshold: P99 > 2s = alerta

2. **Trafego**
   - Rate de `http_requests_total` por metodo/rota/status
   - Gauge com total de req/s
   - Alerta: rate < 0.1 req/s por 10 min

3. **Erros**
   - Error rate: `http_errors_total / http_requests_total`
   - Gauge com taxa atual
   - Threshold: > 5% = critico

4. **Saturacao**
   - CPU: `backend_process_cpu_user_seconds_total`
   - Memory: `backend_nodejs_heap_size_*_bytes`
   - Alerta: CPU > 80% por 10 min

### Business Metrics

Dashboard: **Business Metrics - Orders** (UID: `business-orders`)

- Orders Created Rate: `rate(orders_created_total[5m])`
- Orders Failed Rate: `rate(orders_failed_total[5m])`
- Order Failure Rate: `orders_failed / (orders_created + orders_failed)`
- Stats: Total orders (1h, 24h), Success rate

**Alertas de negocio:**
- High Order Failure Rate: > 10%
- No Orders Created: 0 pedidos por 15 min

## Queries Uteis

### Prometheus

```promql
# Latencia P99
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))

# Taxa de erro
rate(http_errors_total[5m]) / rate(http_requests_total[5m])

# Trafego total
sum(rate(http_requests_total[5m]))

# CPU usage
rate(backend_process_cpu_user_seconds_total[5m])

# Orders criados (ultimos 5 min)
rate(orders_created_total[5m])

# Taxa de falha em orders
rate(orders_failed_total[5m]) / (rate(orders_created_total[5m]) + rate(orders_failed_total[5m]))
```

### Loki (LogQL)

```logql
# Todos os logs do backend
{service="backend-localstack"}

# Logs de erro
{service="backend-localstack"} |= "error"

# Logs JSON parseados por level
{service="backend-localstack"} | json | level="error"

# Rate de logs de erro
rate({service="backend-localstack"} | json | level="error" [5m])

# Orders criados (via log)
{service="backend-localstack"} |= "Order created"
```

### Tempo (TraceQL)

```traceql
# Todas as traces
{}

# Traces lentas (> 1s)
{ duration > 1s }

# Traces com erro
{ status = error }

# Traces do servico backend
{ service.name = "backend" }
```

## Estrutura de Arquivos

```
observabilidade/
├── prometheus/
│   ├── prometheus.yml    # Config + scrape targets
│   └── alerts.yml        # Regras de alerta (Golden Signals + Business)
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/
│   │   │   └── datasources.yml    # Prometheus, Loki, Tempo
│   │   └── dashboards/
│   │       └── dashboards.yml     # Provisioning config
│   └── dashboards/
│       ├── golden-signals.json    # 4 Golden Signals
│       └── business-metrics.json  # Business Metrics
├── loki/
│   └── loki-config.yml   # Config de armazenamento e retencao (7 dias)
├── promtail/
│   └── promtail-config.yml   # Scraping de logs Docker
└── tempo/
    └── tempo-config.yml  # Config OTLP e storage local
```

## Metricas Expostas

O backend expoe metricas Prometheus em `/metrics`:

### Golden Signals
- `http_request_duration_seconds` (Histogram): Latencia por metodo/rota/status
- `http_requests_total` (Counter): Total de requisicoes
- `http_errors_total` (Counter): Total de erros (status >= 400)
- `backend_process_cpu_*` (Gauge): CPU user/system
- `backend_nodejs_heap_*` (Gauge): Memoria heap/external

### Business Metrics
- `orders_created_total` (Counter via DogStatsD): Pedidos criados com sucesso
- `orders_failed_total` (Counter via DogStatsD): Pedidos que falharam

## Alertas Configurados

### Golden Signals (alerts.yml)
1. `HighLatencyP99`: P99 > 2s por 5 min (warning)
2. `TrafficDropped`: rate < 0.1 req/s por 10 min (warning)
3. `HighErrorRate`: error rate > 5% por 5 min (critical)
4. `HighCPUUsage`: CPU > 80% por 10 min (warning)

### Business Metrics (alerts.yml)
1. `HighOrderFailureRate`: failure rate > 10% por 5 min (critical)
2. `NoOrdersCreated`: 0 pedidos por 15 min (warning)

## Troubleshooting

### Prometheus nao coleta metricas

```bash
# Verificar targets
curl http://localhost:9090/api/v1/targets

# Verificar se backend expoe metricas
curl http://localhost:3001/metrics  # Docker Compose
curl http://localhost:3002/metrics  # Kubernetes
```

### Loki nao recebe logs

```bash
# Verificar Promtail
docker logs case-promtail

# Verificar se Loki esta ready
curl http://localhost:3101/ready
```

### Grafana nao mostra dashboards

1. Verificar datasources: Grafana → Configuration → Data Sources
2. Verificar provisioning: `docker logs case-grafana`
3. Dashboards devem aparecer em: Dashboards → Browse → Case/

### Tempo nao recebe traces

```bash
# Verificar endpoint OTLP
curl http://localhost:4318/v1/traces

# Backend precisa exportar traces via OpenTelemetry
# (atualmente traces nao implementados no backend)
```

## Comandos Uteis

```bash
# Subir stack
docker compose -f docker-compose.observability.yml up -d

# Ver logs
docker compose -f docker-compose.observability.yml logs -f grafana
docker compose -f docker-compose.observability.yml logs -f prometheus

# Parar stack
docker compose -f docker-compose.observability.yml down

# Limpar volumes (cuidado: apaga dados)
docker compose -f docker-compose.observability.yml down -v

# Restart de um servico
docker compose -f docker-compose.observability.yml restart grafana

# Rebuild (apos mudancas em configs)
docker compose -f docker-compose.observability.yml up -d --force-recreate
```

## Integracao com Backend

O backend ja esta configurado para:
- Expor metricas Prometheus em `/metrics` (porta 3000)
- Enviar business metrics via DogStatsD (porta 8125)
- Logs em formato JSON (Pino) parseavel pelo Promtail

Para adicionar traces OpenTelemetry:
1. Instalar `@opentelemetry/sdk-node` e `@opentelemetry/auto-instrumentations-node`
2. Configurar OTLP exporter para `http://tempo:4318`
3. Inicializar antes do Express

## Proximos Passos

1. Implementar traces OpenTelemetry no backend
2. Adicionar Alertmanager para notificacoes (Slack, email)
3. Criar dashboards adicionais:
   - DynamoDB operations
   - LocalStack health
   - Frontend metrics (via Nginx stub_status)
4. Configurar retencao de longo prazo (S3/MinIO)
5. Adicionar Service Level Objectives (SLOs)
