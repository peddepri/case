# Diagnóstico: Dashboards Grafana sem Dados

## 🔍 Problema Identificado
Os dashboards do Grafana estão sem dados porque:

1. **Port-forwards não estão configurados permanentemente**
   - O Prometheus precisa acessar as métricas do backend via `host.docker.internal:3002`
   - Port-forward para backend: `kubectl port-forward -n case svc/backend 3002:3000`

2. **Falta de tráfego nos endpoints**
   - As métricas só aparecem quando há requisições HTTP
   - Métricas principais: `http_requests_total`, `http_request_duration_seconds_bucket`

## ✅ Soluções Aplicadas

### 1. Port-Forward para Métricas (Todos os Serviços)
```bash
# Script automatizado disponível - agora inclui frontend e mobile
./scripts/port-forward-metrics.sh
```

### 2. Verificação da Coleta
- **Prometheus**: http://localhost:9090/targets
- **Métricas Backend**: http://localhost:3002/metrics  
- **Frontend App**: http://localhost:3003/ (métricas via /metrics)
- **Mobile App**: http://localhost:3004/ (métricas via /metrics)
- **Grafana**: http://localhost:3100 (admin/admin)

### 3. Status dos Serviços
```bash
# Observabilidade rodando no Docker
✅ case-prometheus (porta 9090)
✅ case-grafana (porta 3100) 
✅ case-loki (porta 3101)
✅ case-tempo (porta 3102)
✅ case-promtail

# Aplicação rodando no Kubernetes
✅ backend (2 pods)
✅ frontend (2 pods) 
✅ mobile (1 pod)
```

## 🎯 Próximos Passos

### 1. Garantir Port-Forward Permanente (Todos os Serviços)
```bash
# Executar em background permanente
nohup ./scripts/port-forward-metrics.sh &
```

### 2. Gerar Tráfego para Dashboards
```bash
# Gerar requisições de teste - Backend
for i in {1..20}; do 
  curl -s http://localhost:3002/ > /dev/null
  curl -s http://localhost:3002/healthz > /dev/null  
  curl -s http://localhost:3002/api/orders > /dev/null
  sleep 0.2
done

# Gerar requisições de teste - Frontend/Mobile  
for i in {1..10}; do
  curl -s http://localhost:3003/ > /dev/null
  curl -s http://localhost:3004/ > /dev/null
  sleep 0.5
done
```

### 3. Verificar Dashboards no Grafana
- **Golden Signals**: http://localhost:3100/d/golden-signals
- **Business Metrics**: http://localhost:3100/d/business-metrics  
- **Logs/Traces**: http://localhost:3100/d/logs-metrics-traces

## 📊 Métricas Disponíveis

### Backend Node.js
```
# CPU/Memory
backend_process_cpu_user_seconds_total
backend_process_resident_memory_bytes
backend_nodejs_heap_size_used_bytes

# HTTP Requests
http_requests_total{method, route, status_code}
http_request_duration_seconds_bucket{method, route, status_code}
http_errors_total{method, route, status_code}

# Event Loop
backend_nodejs_eventloop_lag_seconds
```

### Infraestrutura
```
# Prometheus self-monitoring
prometheus_*

# Grafana metrics
grafana_http_*
```

## 🔧 Troubleshooting

### Se métricas não aparecem:
1. Verificar port-forward: `ps aux | grep port-forward`
2. Testar conectividade: `curl http://localhost:3002/metrics`
3. Verificar targets no Prometheus: http://localhost:9090/targets
4. Gerar tráfego nos endpoints

### Se dashboards continuam vazios:
1. Verificar range de tempo no Grafana (últimos 15 minutos)
2. Verificar se há dados nas queries: http://localhost:9090/graph
3. Recarregar configuração do Prometheus se necessário

## 📋 Resumo do Status

### ✅ **Infraestrutura de Observabilidade**
- Prometheus, Grafana, Loki, Tempo: **Funcionando**
- Dashboards configurados: Backend, Frontend, Mobile

### ⚠️ **Coleta de Métricas** 
- **Backend**: ✅ Métricas Prometheus funcionais (`/metrics`)
- **Frontend**: 🚧 Instrumentação adicionada (requer build)
- **Mobile**: 🚧 Instrumentação adicionada (requer build)
- **Port-forwards**: ⚠️ Requer execução manual contínua

### 📊 **Status dos Dashboards**
- **Golden Signals**: ⚠️ Aguardando dados (backend funcional) 
- **Frontend Dashboards**: 🚧 Aguardando nova instrumentação
- **Mobile Dashboards**: 🚧 Aguardando nova instrumentação
- **Logs/Traces**: ✅ Funcionando via Loki/Tempo

### 🔧 **Próximas Ações Necessárias**
1. **Build das aplicações** com nova instrumentação
2. **Port-forward estável** para coleta contínua  
3. **Geração de tráfego** para popular métricas
4. **Deploy das mudanças** no Kubernetes