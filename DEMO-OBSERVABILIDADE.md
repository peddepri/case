# DEMONSTRACAO - OBSERVABILIDADE PRONTA

## Status Atual: ✅ TUDO FUNCIONANDO

Todos os servicos de observabilidade estao UP e acessiveis:
- Prometheus ✅
- Grafana ✅
- Loki ✅
- Promtail ✅
- Tempo ✅

---

## ACESSO RAPIDO

### Grafana (Principal)
```
http://localhost:3100
usuario: admin
senha: admin
```

### Dashboards Disponiveis
1. **4 Golden Signals - Backend API**
   - Caminho: Dashboards → Browse → Case/
   - UID: golden-signals-backend
   
2. **Business Metrics - Orders**
   - Caminho: Dashboards → Browse → Case/
   - UID: business-orders

### Outros Acessos
- Prometheus: http://localhost:9090
- Prometheus Targets: http://localhost:9090/targets

---

## GERAR TRAFEGO PARA DEMO

### Terminal 1: Trafego Continuo
```bash
while true; do 
  curl -s http://localhost:3001/ > /dev/null
  echo -n "."
  sleep 1
done
```

### Terminal 2: Criar Orders
```bash
for i in {1..20}; do 
  curl -s -X POST http://localhost:3001/api/orders \
    -H "Content-Type: application/json" \
    -d '{"item":"Demo'$i'","price":'$((100 + i))'}'
  echo " Order $i"
  sleep 2
done
```

### Burst de Trafego (rapido)
```bash
for i in {1..100}; do curl -s http://localhost:3001/ > /dev/null; done
```

---

## ROTEIRO DA DEMO

### 1. Mostrar Grafana (2 min)
- Login no Grafana (admin/admin)
- Navegar: Dashboards → Browse → Case/
- Mostrar 2 dashboards disponiveis

### 2. Golden Signals Dashboard (5 min)
- Abrir "4 Golden Signals - Backend API"
- **Latencia:** Mostrar P50/P95/P99
- **Trafego:** Gerar requests, mostrar incrementando
- **Erros:** Mostrar error rate (deve estar baixo ~0%)
- **Saturacao:** CPU e Memory

### 3. Business Metrics Dashboard (3 min)
- Abrir "Business Metrics - Orders"
- Criar orders em outro terminal
- Mostrar counters incrementando
- **Orders Created Rate**
- **Orders Failed Rate** (simulacao ~10%)
- **Failure Rate Gauge**
- **Statistics**: Total 1h, Success Rate

### 4. Logs no Loki (3 min)
- Grafana → Explore
- Datasource: Loki
- Query: `{service="backend-localstack"}`
- Filtrar: `{service="backend-localstack"} | json | level="error"`
- Buscar: `{service="backend-localstack"} |= "Order created"`

### 5. Prometheus Direto (2 min)
- Abrir http://localhost:9090
- Status → Targets (mostrar alvos UP)
- Graph → Query: `histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))`
- Mostrar grafico de P99

---

## QUERIES UTEIS PARA COPY/PASTE

### Prometheus (Grafana Explore)
```promql
# Latencia P99
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))

# Trafego total
sum(rate(http_requests_total[5m]))

# Error rate
rate(http_errors_total[5m]) / rate(http_requests_total[5m])

# Orders criados
increase(orders_created_total[5m])

# Taxa de falha orders
rate(orders_failed_total[5m]) / (rate(orders_created_total[5m]) + rate(orders_failed_total[5m]))
```

### Loki (Grafana Explore)
```logql
# Todos os logs
{service="backend-localstack"}

# Apenas erros
{service="backend-localstack"} | json | level="error"

# Orders criados
{service="backend-localstack"} |= "Order created"

# Rate de erros
rate({service="backend-localstack"} | json | level="error" [5m])
```

---

## METRICAS ATUAIS

```bash
# Ver no terminal
curl -s http://localhost:3001/metrics | grep '^orders_'
```

Resultado esperado:
```
orders_created_total 53
orders_failed_total 2
```

---

## SE ALGO NAO FUNCIONAR

### Restart Stack
```bash
docker compose -f docker-compose.observability.yml restart
```

### Ver Logs
```bash
docker compose -f docker-compose.observability.yml logs -f grafana
docker compose -f docker-compose.observability.yml logs -f prometheus
docker compose -f docker-compose.observability.yml logs -f loki
docker compose -f docker-compose.observability.yml logs -f tempo
```

### Verificar Health
```bash
curl http://localhost:9090/-/healthy  # Prometheus
curl http://localhost:3100/api/health  # Grafana
curl http://localhost:3101/ready      # Loki
curl http://localhost:3102/ready      # Tempo
```

---

## PONTOS PRINCIPAIS PARA DESTACAR

1. **4 Golden Signals** implementados no backend:
   - Latencia (P50/P95/P99)
   - Trafego (req/s)
   - Erros (error rate)
   - Saturacao (CPU/Memory)

2. **Business Metrics** customizadas:
   - Orders Created
   - Orders Failed
   - Success Rate

3. **Stack completa** de observabilidade:
   - Prometheus (metricas)
   - Loki (logs)
   - Tempo (traces - pronto, aguardando implementacao)
   - Grafana (visualizacao unificada)

4. **Alertas configurados** (em alerts.yml):
   - High Latency P99
   - Traffic Dropped
   - High Error Rate
   - High CPU Usage
   - High Order Failure Rate
   - No Orders Created

5. **Auto-provisioning**:
   - Datasources automaticamente configurados
   - Dashboards automaticamente carregados
   - Pronto para uso apos `docker compose up`

---

## PROXIMOS PASSOS (mencionar se perguntarem)

1. Implementar OpenTelemetry traces no backend
2. Adicionar Alertmanager para notificacoes
3. Dashboard para metricas do LocalStack
4. Frontend metrics (Nginx)
5. Retencao de longo prazo (S3)
6. SLOs (Service Level Objectives)

---

## DOCUMENTACAO COMPLETA

- **OBSERVABILIDADE-RESUMO.md** - Resumo executivo completo
- **VERIFICACAO-OBSERVABILIDADE.md** - Guia detalhado de verificacao
- **observabilidade/README.md** - Documentacao tecnica da stack
