# RESUMO - APLICAÇÕES NO KUBERNETES

## STATUS: TODOS OS SERVIÇOS RODANDO

Data: 2025-10-24
Cluster: kind (case-local)
Namespace: case

---

## Serviços Deployados

| Serviço | Pods | Status | Port | Acesso Local |
|---------|------|--------|------|--------------|
| **Backend** | 1/1 | Running | 3000 | http://localhost:3002 |
| **Frontend** | 1/1 | Running | 80 | http://localhost:5173 |
| **Mobile** | 1/1 | Running | 19006 | http://localhost:19007 |

---

## Arquitetura Completa

```
┌───────────────────────────────────────────────────────────┐
│ Kubernetes Cluster (kind - case-local)                   │
│                                                           │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Namespace: case                                     │ │
│ │                                                     │ │
│ │  ┌─────────────┐    ┌──────────────┐    ┌────────┐│ │
│ │  │   Backend   │    │   Frontend   │    │ Mobile ││ │
│ │  │             │    │              │    │        ││ │
│ │  │ Node.js +   │←───│ React +      │    │ Expo   ││ │
│ │  │ Express     │    │ Vite +       │    │ Web    ││ │
│ │  │ Port: 3000  │    │ Nginx        │    │ 19006  ││ │
│ │  │             │    │ Port: 80     │    │        ││ │
│ │  │ Metricas    │    │              │    │        ││ │
│ │  │ /metrics    │    │              │    │        ││ │
│ │  └─────────────┘    └──────────────┘    └────────┘│ │
│ │         │                   │                 │    │ │
│ │         ↓                   ↓                 ↓    │ │
│ │  ┌──────────────────────────────────────────────┐ │ │
│ │  │ Services (ClusterIP)                         │ │ │
│ │  │ - backend:3000                               │ │ │
│ │  │ - frontend:80                                │ │ │
│ │  │ - mobile:19006                               │ │ │
│ │  └──────────────────────────────────────────────┘ │ │
│ │         │                                          │ │
│ │         ↓                                          │ │
│ │  ┌──────────────────────────────────────────────┐ │ │
│ │  │ Ingress (nginx)                              │ │ │
│ │  │ - /api/*      → backend:3000                 │ │ │
│ │  │ - /mobile/*   → mobile:19006                 │ │ │
│ │  │ - /*          → frontend:80                  │ │ │
│ │  └──────────────────────────────────────────────┘ │ │
│ └─────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────┘
           ↓ Port-Forwards
┌───────────────────────────────────────────────────────────┐
│ Acesso Local                                              │
│ - Backend:  http://localhost:3002                         │
│ - Frontend: http://localhost:5173                         │
│ - Mobile:   http://localhost:19007                        │
└───────────────────────────────────────────────────────────┘
           ↓ External Backend
┌───────────────────────────────────────────────────────────┐
│ LocalStack (AWS Mock)                                     │
│ - DynamoDB: orders table                                  │
│ - S3, IAM, Secrets Manager                                │
│ - Endpoint: http://192.168.15.7:4566                      │
└───────────────────────────────────────────────────────────┘
```

---

## Observabilidade Integrada

### Stack Grafana (Docker Compose)

Rodando em paralelo ao Kubernetes:

| Serviço | Status | URL | Função |
|---------|--------|-----|--------|
| **Prometheus** | UP | http://localhost:9090 | Coleta métricas |
| **Grafana** | UP | http://localhost:3100 | Visualização |
| **Loki** | UP | http://localhost:3101 | Logs |
| **Promtail** | UP | - | Coleta logs |
| **Tempo** | UP | http://localhost:3102 | Traces |

### Métricas Coletadas

**Backend** (expostas em `/metrics`):
- Golden Signals:
  - `http_request_duration_seconds` (P50/P95/P99)
  - `http_requests_total` (req/s)
  - `http_errors_total` (error rate)
  - `backend_process_cpu_*`, `backend_nodejs_heap_*` (saturation)
- Business Metrics:
  - `orders_created_total` (53 criados)
  - `orders_failed_total` (2 falhados)

**Prometheus Targets**:
- backend-localstack (Docker Compose) - UP
- backend-kubernetes (kind via port-forward) - UP
- prometheus, grafana, loki, tempo - UP

---

## Demonstração Completa

### 1. Backend + Observabilidade (5 min)

```bash
# Ver dashboards Grafana
open http://localhost:3100  # admin/admin

# Dashboards:
# - 4 Golden Signals - Backend API
# - Business Metrics - Orders

# Gerar tráfego
for i in {1..50}; do curl -s http://localhost:3002/ > /dev/null; done

# Criar orders
for i in {1..10}; do 
  curl -s -X POST http://localhost:3002/api/orders \
    -H "Content-Type: application/json" \
    -d '{"item":"Demo'$i'","price":'$i'}'
done

# Ver métricas atualizando em tempo real
```

### 2. Frontend (2 min)

```bash
# Abrir frontend
open http://localhost:5173

# Funcionalidades:
# - Lista de orders (fetch de /api/orders)
# - Comunicação com backend via proxy
```

### 3. Mobile App (3 min)

```bash
# Abrir mobile web
open http://localhost:19007

# Funcionalidades:
# - Mobile Orders interface
# - Refresh orders
# - Create order (item: "mobile", price: random)
# - Loading states
# - Error handling
# - Console logging (F12)

# Ver logs do pod
kubectl logs -n case deployment/mobile -f
```

### 4. Logs no Loki (2 min)

```bash
# Grafana → Explore → Loki

# Queries:
{service="backend-localstack"}
{service="backend-localstack"} | json | level="error"
{service="backend-localstack"} |= "Order created"
```

### 5. Prometheus Direto (2 min)

```bash
# Abrir Prometheus
open http://localhost:9090

# Status → Targets (verificar UP)
# Graph → Queries:
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))
rate(orders_created_total[5m])
```

**Tempo Total Demo:** ~15 min

---

## Comandos Úteis

### Kubernetes

```bash
# Ver todos os recursos
kubectl get all -n case

# Logs
kubectl logs -n case deployment/backend -f
kubectl logs -n case deployment/frontend -f
kubectl logs -n case deployment/mobile -f

# Shell nos pods
kubectl exec -it -n case deployment/backend -- bash
kubectl exec -it -n case deployment/mobile -- sh

# Port-forwards
kubectl port-forward -n case svc/backend 3002:3000
kubectl port-forward -n case svc/frontend 5173:80
kubectl port-forward -n case svc/mobile 19007:19006

# Restart deployments
kubectl rollout restart deployment/backend -n case
kubectl rollout restart deployment/frontend -n case
kubectl rollout restart deployment/mobile -n case

# Describe
kubectl describe pod -n case -l app=backend
kubectl describe svc -n case backend

# Status
kubectl get pods -n case -w
```

### Observabilidade

```bash
# Stack completa
docker compose -f docker-compose.observability.yml ps

# Logs
docker compose -f docker-compose.observability.yml logs -f grafana
docker compose -f docker-compose.observability.yml logs -f prometheus

# Restart
docker compose -f docker-compose.observability.yml restart

# Health checks
curl http://localhost:9090/-/healthy  # Prometheus
curl http://localhost:3100/api/health  # Grafana
curl http://localhost:3101/ready      # Loki
curl http://localhost:3102/ready      # Tempo
```

### Build e Deploy

```bash
# Backend
cd app/backend
docker build -t case-backend:latest .
kind load docker-image case-backend:latest --name case-local
kubectl rollout restart deployment/backend -n case

# Frontend
cd app/frontend
docker build -t case-frontend:latest .
kind load docker-image case-frontend:latest --name case-local
kubectl rollout restart deployment/frontend -n case

# Mobile
cd app/mobile
docker build -t case-mobile:latest .
kind load docker-image case-mobile:latest --name case-local
kubectl rollout restart deployment/mobile -n case
```

---

## Checklist de Validação

### Kubernetes

- [x] Backend pod rodando (1/1 Ready)
- [x] Frontend pod rodando (1/1 Ready)
- [x] Mobile pod rodando (1/1 Ready)
- [x] Services criados (ClusterIP)
- [x] Port-forwards ativos
- [x] Backend acessível: http://localhost:3002
- [x] Frontend acessível: http://localhost:5173
- [x] Mobile acessível: http://localhost:19007

### Backend

- [x] API root: GET / retorna info
- [x] Orders list: GET /api/orders
- [x] Create order: POST /api/orders
- [x] Metrics: GET /metrics (Prometheus format)
- [x] Conectado ao LocalStack (DynamoDB)

### Observabilidade

- [x] Prometheus coletando métricas
- [x] Grafana acessível (admin/admin)
- [x] Dashboard Golden Signals funcionando
- [x] Dashboard Business Metrics funcionando
- [x] Loki coletando logs
- [x] Promtail enviando logs
- [x] Tempo pronto (ready)
- [x] Datasources configurados no Grafana

### Mobile

- [x] Expo Web build estático
- [x] http-server servindo em 19006
- [x] Health checks passando
- [x] Comunicação com backend funcionando
- [x] UI responsiva
- [x] Loading states
- [x] Error handling
- [x] Console logging

---

## Problemas Resolvidos

### 1. Backend Connectivity

**Problema:** Pods não acessavam LocalStack via `host.docker.internal`

**Solução:** Configurar IP direto do host (192.168.15.7:4566) no ConfigMap

### 2. Backend Root Route

**Problema:** `Cannot GET /` ao acessar raiz

**Solução:** Adicionado route GET / retornando info da API

### 3. Observabilidade - Business Metrics

**Problema:** `orders_created_total` não aparecia no Prometheus

**Solução:** Adicionado Counters Prometheus além do DogStatsD

### 4. Loki e Tempo Inacessíveis

**Problema:** Tempo em CrashLoopBackOff, config incompatível

**Solução:** Simplificada config do Tempo (remover campos deprecated)

**Resultado:** Ambos UP e `ready`

### 5. Mobile CrashLoopBackOff

**Problema:** Expo tentando usar Metro bundler interativo

**Solução:** Usar `expo export:web` para build estático + `http-server`

**Resultado:** Mobile Running com health checks OK

---

## Arquivos Documentação

Criados durante o processo:

1. **OBSERVABILIDADE-RESUMO.md** - Stack Grafana completa
2. **DEMO-OBSERVABILIDADE.md** - Roteiro para demonstração
3. **VERIFICACAO-OBSERVABILIDADE.md** - Guia de verificação
4. **MOBILE-KUBERNETES.md** - Deploy e troubleshooting mobile
5. **KUBERNETES-RESUMO.md** (este arquivo) - Overview completo

---

## Próximos Passos

### Observabilidade

1. [ ] Implementar OpenTelemetry traces no backend
2. [ ] Dashboard Grafana específico para mobile
3. [ ] Alertmanager para notificações
4. [ ] Frontend metrics (Nginx)
5. [ ] SLOs (Service Level Objectives)

### Infraestrutura

1. [ ] Ingress Controller instalado
2. [ ] HPA (Horizontal Pod Autoscaler)
3. [ ] PersistentVolumes para dados
4. [ ] Network Policies
5. [ ] Resource Quotas

### CI/CD

1. [ ] GitHub Actions para build/push
2. [ ] Automated testing
3. [ ] Blue/Green deployment automation
4. [ ] Rollback automation

### Features

1. [ ] Auth/AuthZ
2. [ ] Rate limiting
3. [ ] Caching (Redis)
4. [ ] Message queue (RabbitMQ/SQS)
5. [ ] WebSockets para real-time

---

## Conclusão

**Stack completa funcionando:**
- 3 aplicações no Kubernetes (backend, frontend, mobile)
- Stack de observabilidade completa (Prometheus, Grafana, Loki, Tempo)
- Métricas Golden Signals + Business Metrics
- Logs agregados
- Health checks configurados
- Documentação completa

**Pronto para demonstração e evolução!**
