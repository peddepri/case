# STACK DE OBSERVABILIDADE - RESUMO EXECUTIVO

## ✅ STATUS: TODOS OS SERVICOS FUNCIONANDO

Data: 2025-10-24
Ambiente: Docker Compose Local

---

## Servicos Disponiveis

| Servico | Status | URL | Funcao |
|---------|--------|-----|--------|
| **Prometheus** | ✅ UP | http://localhost:9090 | Coleta de metricas (scrape a cada 15s) |
| **Grafana** | ✅ UP | http://localhost:3100 | Visualizacao (admin/admin) |
| **Loki** | ✅ UP | http://localhost:3101 | Agregacao de logs |
| **Promtail** | ✅ UP | - | Coleta logs Docker → Loki |
| **Tempo** | ✅ UP | http://localhost:3102 | Traces distribuidos (OTLP) |

---

## Quick Start para Demonstracao

### 1. Acessar Grafana

```
URL: http://localhost:3100
Usuario: admin
Senha: admin
```

### 2. Visualizar Dashboards

**Caminho:** Dashboards → Browse → Case/

**Dashboards disponiveis:**
1. **4 Golden Signals - Backend API** (UID: golden-signals-backend)
2. **Business Metrics - Orders** (UID: business-orders)

### 3. Gerar Trafego (em outro terminal)

```bash
# Trafego basico (GET requests)
for i in {1..50}; do 
  curl -s http://localhost:3001/ > /dev/null
  echo -n "."
  sleep 0.2
done

# Criar orders (business metrics)
for i in {1..20}; do 
  curl -s -X POST http://localhost:3001/api/orders \
    -H "Content-Type: application/json" \
    -d '{"item":"Product'$i'","price":'$((10 + i))'}'
  echo -n "O"
  sleep 0.5
done
```

### 4. Ver Metricas Atualizando

Dashboards atualizam automaticamente a cada 10s.

---

## 4 Golden Signals Dashboard

### Paineis Disponiveis

#### 1. Latencia (Latency)
- **Metricas:** P50, P95, P99 de `http_request_duration_seconds`
- **Visualizacao:** Time series + Gauge (P99 atual)
- **Threshold:** P99 > 2s = alerta

#### 2. Trafego (Traffic)
- **Metricas:** `rate(http_requests_total[5m])` por metodo/rota/status
- **Visualizacao:** Time series + Gauge (total req/s)
- **Alerta:** rate < 0.1 req/s por 10 min

#### 3. Erros (Errors)
- **Metricas:** `http_errors_total / http_requests_total`
- **Visualizacao:** Time series + Gauge (% erro atual)
- **Threshold:** > 5% = critico

#### 4. Saturacao (Saturation)
- **CPU:** `backend_process_cpu_user_seconds_total`
- **Memory:** `backend_nodejs_heap_size_*_bytes`
- **Visualizacao:** Time series para CPU e Memory
- **Alerta:** CPU > 80% por 10 min

---

## Business Metrics Dashboard

### Paineis Disponiveis

#### Orders Created Rate
- **Metrica:** `rate(orders_created_total[5m])`
- **Visualizacao:** Time series + Gauge

#### Orders Failed Rate
- **Metrica:** `rate(orders_failed_total[5m])`
- **Visualizacao:** Time series (linha vermelha)

#### Order Failure Rate
- **Metrica:** `orders_failed / (orders_created + orders_failed)`
- **Visualizacao:** Gauge com thresholds (green < 5%, yellow < 10%, red >= 10%)

#### Statistics
- Total Orders (Last Hour)
- Failed Orders (Last Hour)
- Success Rate (Last Hour)
- Total Orders (Last 24h)

---

## Metricas Expostas

### Backend /metrics Endpoint

```bash
curl http://localhost:3001/metrics
```

**Golden Signals:**
- `http_request_duration_seconds` (Histogram): Latencia
- `http_requests_total` (Counter): Total requisicoes
- `http_errors_total` (Counter): Total erros
- `backend_process_cpu_*` (Gauge): CPU
- `backend_nodejs_heap_*` (Gauge): Memoria

**Business Metrics:**
- `orders_created_total` (Counter): Orders criados com sucesso
- `orders_failed_total` (Counter): Orders que falharam

**Valores Atuais:**
```
orders_created_total 53
orders_failed_total 2
```

---

## Logs (Loki)

### Acesso via Grafana Explore

1. Grafana → Explore
2. Selecionar datasource: **Loki**
3. Executar queries LogQL

### Queries de Exemplo

```logql
# Todos os logs do backend
{service="backend-localstack"}

# Apenas erros
{service="backend-localstack"} | json | level="error"

# Logs de orders criados
{service="backend-localstack"} |= "Order created"

# Rate de erros
rate({service="backend-localstack"} | json | level="error" [5m])
```

### Validacao

```bash
# Verificar labels disponiveis
curl -s 'http://localhost:3101/loki/api/v1/labels' | python -m json.tool

# Retorna:
{
    "status": "success",
    "data": [
        "container",
        "level",
        "service",
        "service_name",
        "stream"
    ]
}
```

---

## Traces (Tempo)

### Status

```bash
curl -s http://localhost:3102/ready
# Retorna: ready
```

### Acesso via Grafana

1. Grafana → Explore
2. Selecionar datasource: **Tempo**
3. Executar queries TraceQL

**Nota:** Backend ainda nao implementa OpenTelemetry traces. Servico pronto para receber traces via OTLP (porta 4317 gRPC, 4318 HTTP).

---

## Datasources Configurados

### Prometheus (Default)
- **URL:** http://prometheus:9090
- **Scrape Interval:** 15s
- **Targets:**
  - backend-localstack (Docker Compose)
  - backend-kubernetes (kind)
  - prometheus (self-monitoring)
  - grafana, loki, tempo

### Loki
- **URL:** http://loki:3100
- **Retencao:** 7 dias (168h)
- **Coleta:** Promtail via Docker socket

### Tempo
- **URL:** http://tempo:3100
- **Protocolos:** OTLP gRPC (4317), OTLP HTTP (4318)
- **Retencao:** 7 dias
- **Metrics Generator:** Envia metricas para Prometheus

---

## Alertas Configurados

### Golden Signals (Prometheus alerts.yml)

1. **HighLatencyP99**
   - Condicao: P99 > 2s por 5 min
   - Severidade: warning

2. **TrafficDropped**
   - Condicao: rate < 0.1 req/s por 10 min
   - Severidade: warning

3. **HighErrorRate**
   - Condicao: error rate > 5% por 5 min
   - Severidade: critical

4. **HighCPUUsage**
   - Condicao: CPU > 80% por 10 min
   - Severidade: warning

### Business Metrics (Prometheus alerts.yml)

1. **HighOrderFailureRate**
   - Condicao: failure rate > 10% por 5 min
   - Severidade: critical

2. **NoOrdersCreated**
   - Condicao: 0 orders por 15 min
   - Severidade: warning

---

## Verificacao dos Targets

### Prometheus Targets

```bash
curl -s http://localhost:9090/api/v1/targets | python -m json.tool | grep -E '"job"|"health"'
```

**Resultado esperado:**
- backend-localstack: health="up"
- backend-kubernetes: health="up"
- prometheus: health="up"
- grafana: health="up"
- loki: health="up"
- tempo: health="up" ou "down" (target tempo pode estar down, servico esta UP)

---

## Comandos Uteis

### Gerenciamento da Stack

```bash
# Subir stack
docker compose -f docker-compose.observability.yml up -d

# Ver status
docker compose -f docker-compose.observability.yml ps

# Ver logs
docker compose -f docker-compose.observability.yml logs -f

# Reiniciar servico especifico
docker compose -f docker-compose.observability.yml restart grafana

# Parar stack
docker compose -f docker-compose.observability.yml down

# Parar e limpar volumes (CUIDADO: apaga dados)
docker compose -f docker-compose.observability.yml down -v
```

### Verificacao de Health

```bash
# Prometheus
curl -s http://localhost:9090/-/healthy

# Grafana
curl -s http://localhost:3100/api/health | python -m json.tool

# Loki
curl -s http://localhost:3101/ready

# Tempo
curl -s http://localhost:3102/ready
```

### Consultas Diretas

```bash
# Ver metricas no backend
curl http://localhost:3001/metrics | grep '^orders_'

# Consultar Prometheus
curl -s 'http://localhost:9090/api/v1/query?query=orders_created_total' | python -m json.tool

# Ver labels no Loki
curl -s 'http://localhost:3101/loki/api/v1/labels' | python -m json.tool
```

---

## Problemas Resolvidos

### Tempo - Erro de Configuracao

**Problema:** Tempo em loop de restart com erro "field encoding not found"

**Causa:** Configuracao incompativel com Tempo 2.6.1

**Solucao:** Simplificacao da config em `observabilidade/tempo/tempo-config.yml`:
- Removido `storage.trace.block.index_downsample_bytes`
- Removido `storage.trace.block.encoding`
- Removido `storage.trace.wal.encoding`

**Resultado:** Tempo UP e ready em ~20s

### Business Metrics nao apareciam no Prometheus

**Problema:** Metricas `orders_created_total` e `orders_failed_total` nao expostas

**Causa:** Metricas enviadas apenas para DogStatsD

**Solucao:** Adicionar Counters Prometheus em `metrics.ts`:
```typescript
export const ordersCreatedTotal = new client.Counter({
  name: 'orders_created_total',
  help: 'Total orders created successfully'
});

export const ordersFailedTotal = new client.Counter({
  name: 'orders_failed_total',
  help: 'Total orders that failed'
});
```

**Resultado:** Metricas expostas em `/metrics` e coletadas pelo Prometheus

---

## Demonstracao - Roteiro Sugerido

### Parte 1: Overview (2 min)
1. Mostrar stack rodando: `docker compose -f docker-compose.observability.yml ps`
2. Explicar arquitetura: Backend → Prometheus/Loki/Tempo → Grafana
3. Mostrar endpoints de health

### Parte 2: Golden Signals (5 min)
1. Abrir dashboard "4 Golden Signals"
2. Gerar trafego em outro terminal
3. Mostrar metricas atualizando:
   - Latencia P99 subindo/descendo
   - Trafego incrementando
   - Error rate calculado
   - CPU/Memory Usage

### Parte 3: Business Metrics (3 min)
1. Abrir dashboard "Business Metrics - Orders"
2. Criar orders (mix de sucesso/falha)
3. Mostrar:
   - Orders Created incrementando
   - Orders Failed (simulacao 10%)
   - Failure Rate calculado
   - Statistics atualizando

### Parte 4: Logs (3 min)
1. Grafana → Explore → Loki
2. Query: `{service="backend-localstack"}`
3. Filtrar por level="error"
4. Buscar logs de "Order created"

### Parte 5: Prometheus Direto (2 min)
1. Abrir http://localhost:9090
2. Mostrar Targets (Status → Targets)
3. Executar query: `histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))`
4. Mostrar Graph

**Tempo Total:** ~15 min

---

## Proximos Passos

1. [ ] Implementar traces OpenTelemetry no backend
2. [ ] Adicionar Alertmanager para notificacoes (Slack, email)
3. [ ] Criar dashboard para LocalStack metrics
4. [ ] Adicionar frontend metrics (Nginx stub_status)
5. [ ] Configurar retencao de longo prazo (S3/MinIO)
6. [ ] Definir SLOs (Service Level Objectives)
7. [ ] Adicionar Recording Rules para queries pesadas
8. [ ] Integrar com PagerDuty/OpsGenie
