# OpenTelemetry & Observabilidade Completa - Documentação

## Visão Geral

Este documento descreve a implementação completa de observabilidade para frontend e mobile usando OpenTelemetry, Web Vitals e dashboards do Grafana.

## Arquitetura de Tracing

```
Frontend (Browser) → OTLP HTTP → Tempo (4318)
                  ↓ (traceparent header)
Backend (Node.js) → OTLP HTTP → Tempo (4318)
                  ↓
              Grafana (Trace Queries)
```

## Componentes Implementados

### 1. Frontend OpenTelemetry

**Arquivo:** `app/frontend/src/tracing.ts`

- **SDK:** `@opentelemetry/sdk-trace-web`
- **Auto-instrumentations:**
  - Document Load: Captura timings de navegação e carregamento
  - User Interaction: Captura cliques, submits, keypresses
  - Fetch API: Captura e propaga contexto de trace para o backend
  - XMLHttpRequest: Captura XHR calls

- **W3C Trace Context Propagation:**
  - Frontend injeta automaticamente header `traceparent` em todas as chamadas fetch/XHR
  - Backend continua o trace usando o mesmo trace ID
  - Permite correlação end-to-end: Browser → Backend → DynamoDB

**Configuração:**
```typescript
new FetchInstrumentation({
  propagateTraceHeaderCorsUrls: [
    /localhost:3000/,
    /localhost:3002/,
    new RegExp(import.meta.env.VITE_BACKEND_URL || ''),
  ],
  clearTimingResources: true,
})
```

### 2. Web Vitals

**Arquivo:** `app/frontend/src/webVitals.ts`

- **Biblioteca:** `web-vitals` v4.2.3
- **Métricas Coletadas:**
  - **FCP (First Contentful Paint):** Tempo até primeiro conteúdo visível
  - **LCP (Largest Contentful Paint):** Tempo até maior elemento visível
  - **FID (First Input Delay):** Latência da primeira interação do usuário
  - **CLS (Cumulative Layout Shift):** Estabilidade visual da página
  - **TTFB (Time to First Byte):** Tempo até receber primeiro byte

- **Exportação:**
  - Enviadas via `navigator.sendBeacon()` para `/api/metrics/web-vitals`
  - Backend converte para métricas Prometheus
  - Prometheus expõe como `frontend_web_vitals_fcp`, `frontend_web_vitals_lcp`, etc.

### 3. Backend OpenTelemetry

**Arquivo:** `app/backend/src/tracing.ts`

- **SDK:** `@opentelemetry/sdk-node`
- **Auto-instrumentations:**
  - HTTP: Captura requests/responses
  - Express: Captura rotas e middlewares
  - AWS SDK: Captura chamadas DynamoDB

- **Configuração:**
```typescript
instrumentations: [
  getNodeAutoInstrumentations({
    '@opentelemetry/instrumentation-http': {
      enabled: true,
      ignoreIncomingRequestHook: (req) => {
        const url = req.url || '';
        return url.includes('/healthz') || url.includes('/metrics');
      },
    },
    '@opentelemetry/instrumentation-express': { enabled: true },
    '@opentelemetry/instrumentation-aws-sdk': { enabled: true },
  }),
]
```

### 4. Backend Metrics Endpoint

**Arquivo:** `app/backend/src/routes/metrics.ts`

**Endpoints:**
- `POST /api/metrics/web-vitals` - Recebe Web Vitals do frontend
- `POST /api/metrics/frontend` - Recebe métricas de requests do frontend
- `POST /api/metrics/mobile` - Recebe métricas de requests do mobile

**Métricas Prometheus:**
```
frontend_web_vitals_fcp         # First Contentful Paint
frontend_web_vitals_lcp         # Largest Contentful Paint
frontend_web_vitals_fid         # First Input Delay
frontend_web_vitals_cls         # Cumulative Layout Shift
frontend_web_vitals_ttfb        # Time to First Byte
frontend_web_vitals_total       # Total Web Vitals reports

frontend_requests_total{route}  # Total frontend requests
frontend_errors_total{route}    # Total frontend errors

mobile_requests_total{route}    # Total mobile requests
mobile_errors_total{route}      # Total mobile errors
```

## Dashboards Grafana

### 1. Frontend - 4 Golden Signals & Web Vitals

**Arquivo:** `observabilidade/grafana/dashboards/frontend-golden-signals.json`

**Painéis:**
1. **Latency:** P50/P95/P99 de requests (timeseries + gauge)
2. **Web Vitals:** FCP, LCP, FID (timeseries + gauge CLS)
3. **Traffic:** Request rate por rota (timeseries + gauge total)
4. **Errors:** Error rate (timeseries + gauge %)

**Métricas Utilizadas:**
- `histogram_quantile(0.50, sum(rate(frontend_request_duration_bucket[5m])) by (le, route))`
- `frontend_web_vitals_fcp`, `frontend_web_vitals_lcp`, `frontend_web_vitals_fid`
- `sum(rate(frontend_requests_total[5m])) by (route)`
- `sum(rate(frontend_errors_total[5m])) / sum(rate(frontend_requests_total[5m]))`

### 2. Mobile Backend - 4 Golden Signals

**Arquivo:** `observabilidade/grafana/dashboards/mobile-golden-signals.json`

**Painéis:**
1. **Latency:** P50/P95/P99 de requests mobile (timeseries + gauge)
2. **Traffic:** Request rate por rota (timeseries + gauge total)
3. **Errors:** Error rate (timeseries + gauge %)
4. **Saturation:** CPU & Memory, Event Loop Lag & Active Handles

**Métricas Utilizadas:**
- `histogram_quantile(0.99, sum(rate(mobile_request_duration_bucket[5m])) by (le))`
- `sum(rate(mobile_requests_total[5m])) by (route)`
- `sum(rate(mobile_errors_total[5m])) / sum(rate(mobile_requests_total[5m]))`
- `nodejs_eventloop_lag_seconds`, `nodejs_active_handles_total`

### 3. Frontend - Business Metrics

**Arquivo:** `observabilidade/grafana/dashboards/frontend-business.json`

**Painéis:**
1. **Orders API Traffic:** Taxa de requests para `/api/orders`
2. **Total Orders API Calls:** Total acumulado
3. **Orders API Error Rate:** Taxa de erros
4. **Orders Error Rate %:** Percentual de erros (gauge com thresholds)
5. **Web Vitals Reports:** Número de reports por métrica (FCP, LCP, FID)
6. **Web Vitals by Rating:** Distribuição por rating (good, needs-improvement, poor)

### 4. Mobile - Business Metrics

**Arquivo:** `observabilidade/grafana/dashboards/mobile-business.json`

**Painéis:**
1. **Orders API Traffic:** Taxa de requests mobile para `/api/orders`
2. **Total Orders API Calls:** Total acumulado mobile
3. **Orders API Error Rate:** Taxa de erros mobile
4. **Orders Error Rate %:** Percentual de erros
5. **Orders API P95 Latency:** Latência P95 específica para orders
6. **Success vs Errors (1h):** Comparação de sucessos vs erros (stacked)

## Deployment

### Variáveis de Ambiente

**Backend (k8s/backend-deployment.yaml):**
```yaml
- name: OTEL_TRACE_ENABLED
  value: "true"
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: "http://tempo:4318/v1/traces"
- name: SERVICE_NAME
  value: "case-backend"
- name: SERVICE_VERSION
  value: "0.1.0"
```

**Frontend (k8s/frontend-deployment.yaml):**
```yaml
- name: VITE_BACKEND_URL
  value: "http://backend.case.svc.cluster.local:3000"
- name: VITE_OTLP_ENDPOINT
  value: "http://tempo:4318/v1/traces"
```

### Instalação de Dependências

**Frontend:**
```bash
cd app/frontend
npm install
```

**Backend:**
```bash
cd app/backend
npm install
```

### Build e Deploy

```bash
# Build images
docker build -t case-frontend:latest app/frontend
docker build -t case-backend:latest app/backend

# Load to kind
kind load docker-image case-frontend:latest --name case-local
kind load docker-image case-backend:latest --name case-local

# Apply manifests
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/frontend-deployment.yaml

# Restart to apply changes
kubectl rollout restart deployment/backend -n case
kubectl rollout restart deployment/frontend -n case
```

## Verificação

### 1. Verificar Traces no Tempo

```bash
# Enviar trace de teste
curl -X POST http://localhost:3002/api/orders \
  -H "Content-Type: application/json" \
  -d '{"item":"test","price":10}'

# Verificar Tempo ready
curl http://localhost:3102/ready
# Output: ready

# Query traces via Grafana → Explore → Tempo
# Filtrar por: service.name="case-backend" ou "case-frontend"
```

### 2. Verificar Web Vitals

```bash
# Acessar frontend
open http://localhost:5173

# Navegar pela página para gerar Web Vitals
# Verificar métricas no backend
curl http://localhost:3002/metrics | grep frontend_web_vitals

# Output esperado:
# frontend_web_vitals_fcp 1234.5
# frontend_web_vitals_lcp 2345.6
# frontend_web_vitals_fid 15.2
# frontend_web_vitals_cls 0.02
```

### 3. Verificar Dashboards

```bash
# Acessar Grafana
open http://localhost:3100

# Navegar para Dashboards:
# - Frontend - 4 Golden Signals & Web Vitals
# - Mobile Backend - 4 Golden Signals
# - Frontend - Business Metrics
# - Mobile - Business Metrics
```

### 4. Verificar Trace Context Propagation

```bash
# Fazer request do frontend (que deve propagar traceparent)
# Verificar logs do backend para confirmar trace ID recebido
kubectl logs -n case deployment/backend | grep trace

# Verificar no Grafana Explore:
# 1. Ir para Tempo datasource
# 2. Query por trace ID
# 3. Ver spans de frontend e backend no mesmo trace
```

## Troubleshooting

### Traces não aparecem no Tempo

1. Verificar se Tempo está recebendo traces:
```bash
kubectl logs -n observability tempo | grep "received spans"
```

2. Verificar endpoint OTLP:
```bash
curl http://localhost:4318/v1/traces -X POST \
  -H "Content-Type: application/json" \
  -d '{"resourceSpans":[]}'
```

3. Verificar configuração do exporter no código:
- Frontend: `app/frontend/src/tracing.ts`
- Backend: `app/backend/src/tracing.ts`

### Web Vitals não aparecem no Prometheus

1. Verificar se frontend está enviando métricas:
```bash
# Abrir DevTools → Network → Filter "web-vitals"
# Deve mostrar POSTs para /api/metrics/web-vitals
```

2. Verificar se backend está recebendo:
```bash
kubectl logs -n case deployment/backend | grep "Web Vital metric received"
```

3. Verificar métricas no Prometheus:
```bash
curl http://localhost:9090/api/v1/query?query=frontend_web_vitals_fcp
```

### Dashboards vazios

1. Verificar se Prometheus está coletando métricas:
```bash
curl http://localhost:9090/api/v1/targets
```

2. Verificar se queries estão corretas no dashboard:
- Abrir dashboard → Panel → Edit
- Verificar query PromQL
- Testar no Prometheus diretamente

3. Verificar time range do dashboard (deve ter dados no período selecionado)

## Melhores Práticas

### 1. Rate Limiting no Frontend

Para evitar sobrecarga do backend com Web Vitals:
```typescript
// Implementar debounce/throttle
const sendMetric = debounce((metric: Metric) => {
  navigator.sendBeacon(`${backendUrl}/api/metrics/web-vitals`, JSON.stringify(metric));
}, 1000);
```

### 2. Sampling de Traces

Para produção com alto tráfego, configurar sampling:
```typescript
// Frontend
const provider = new WebTracerProvider({
  resource,
  sampler: new TraceIdRatioBasedSampler(0.1), // 10% sampling
});

// Backend
const sdk = new NodeSDK({
  resource,
  sampler: new TraceIdRatioBasedSampler(0.1),
});
```

### 3. Correlação de Logs e Traces

Adicionar trace ID aos logs:
```typescript
import { trace } from '@opentelemetry/api';

const span = trace.getActiveSpan();
logger.info({
  traceId: span?.spanContext().traceId,
  spanId: span?.spanContext().spanId,
}, 'Processing order');
```

## Recursos Adicionais

- [OpenTelemetry JS Docs](https://opentelemetry.io/docs/instrumentation/js/)
- [Web Vitals](https://web.dev/vitals/)
- [Tempo OTLP](https://grafana.com/docs/tempo/latest/configuration/otlp/)
- [W3C Trace Context](https://www.w3.org/TR/trace-context/)

## Próximos Passos

1. **Alerting:** Configurar alertas para:
   - Web Vitals degradados (FCP > 3s, LCP > 4s, FID > 300ms, CLS > 0.25)
   - Trace duration anomalias (P99 > threshold)
   - Erro de correlação de traces (órfãos)

2. **RUM (Real User Monitoring):** Adicionar:
   - Session replay
   - User journey tracking
   - Error boundary tracking com trace context

3. **Advanced Queries:** Criar dashboards de:
   - Trace duration breakdown (por serviço, operação)
   - Dependency graph (service map)
   - Error rate por user agent/geo

4. **Performance:** Otimizar:
   - Batch span processor config
   - OTLP compression
   - Sampling strategies por rota
