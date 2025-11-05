# 🎬 Guia Completo: Pré-Gravação e Gravação

## 📋 **PRÉ-GRAVAÇÃO (5-8 minutos)**

### **🚀 1. Setup Automático Completo**
```bash
# Executar script completo de setup
./setup-demo-environment.sh
```
**O que acontece:**
-  Cria cluster Kind
-  Sobe Prometheus, Grafana, Loki, Tempo
-  Build e deploy de Backend, Frontend, Mobile
-  Configura port-forwards para métricas
-  Gera tráfego inicial

### **🔍 2. Verificação Completa do Ambiente**
```bash
# Verificar se tudo está funcionando
./check-demo-status.sh
```
**Checklist esperado:**
```
📋 1. Kubernetes Cluster
   Kind cluster 'case-local' existe
   Nodes do cluster prontos
   Namespace 'case' existe

📋 2. Aplicações (Pods)
  📊 Pods Running: 5/5
   Backend pods rodando
   Frontend pods rodando
   Mobile pods rodando

📋 3. Stack de Observabilidade
   Prometheus container ativo
   Grafana container ativo
   Loki container ativo
   Tempo container ativo

📋 4. Conectividade via Port-Forward
   Backend acessível (3002)
   Frontend acessível (3003)
   Mobile acessível (3004)

📋 5. Interfaces Web
   Prometheus UI (9090)
   Grafana UI (3100)
   Loki API (3101)
   Tempo API (3102)

📋 6. Coleta de Métricas
  🎯 Targets Prometheus: 6/6 UP
  📈 Métricas HTTP coletadas: 10+
  📊 Métricas 'up' ativas: 6
```

### **🧪 3. Teste Final de Métricas**
```bash
# Verificar se todas as métricas estão sendo coletadas
./test-metrics-collection.sh
```
**Resultado esperado:**
```
🧪 TESTE DE COLETA DE MÉTRICAS

1. Testando endpoints de métricas...
 Backend metrics (/metrics) - OK
   📊 Métricas encontradas: 25
 Frontend metrics (/metrics) - OK
   📊 Métricas encontradas: 8
 Mobile metrics (/metrics) - OK
   📊 Métricas encontradas: 6

2. Verificando coleta no Prometheus...
   🎯 Targets UP: 6/6
   📈 HTTP requests (backend): 15
   🎨 Frontend requests: 5
   📱 Mobile requests: 3

🎉 TODOS OS SERVIÇOS EXPONDO MÉTRICAS (3/3)
    Backend: Métricas Prometheus nativas
    Frontend: Métricas simuladas via Nginx
    Mobile: Métricas simuladas via Express

🎬 DASHBOARDS TERÃO DADOS! Pode iniciar gravação.
```

---

## 🎥 **DURANTE A GRAVAÇÃO**

### **📈 1. Iniciar Tráfego Contínuo**
```bash
# Gerar tráfego realista durante toda a gravação (15-20 min)
./generate-demo-traffic.sh 20 &
```
**O que acontece em background:**
- 🔄 Requests contínuos no Backend (API calls, health checks)
- 🔄 Navegação simulada no Frontend
- 🔄 Interações simuladas no Mobile
- 📊 Métricas atualizando em tempo real

### **🖥 2. URLs Principais para Demo**

#### **📊 Dashboards Principais (Grafana)**
- **Login Grafana**: http://localhost:3100 
  - User: `admin` / Password: `admin`
- **Golden Signals**: http://localhost:3100/d/golden-signals
- **Frontend Dashboard**: http://localhost:3100/d/frontend-golden-signals
- **Mobile Dashboard**: http://localhost:3100/d/mobile-golden-signals
- **Business Metrics**: http://localhost:3100/d/business-metrics
- **Logs & Traces**: http://localhost:3100/d/logs-metrics-traces

#### **🔍 Monitoramento e Métricas**
- **Prometheus**: http://localhost:9090
- **Targets Status**: http://localhost:9090/targets
- **Query Interface**: http://localhost:9090/graph
- **Alertmanager**: http://localhost:9093 (se configurado)

#### **🚀 Aplicações Funcionais**
- **Backend API**: http://localhost:3002
  - Health: http://localhost:3002/healthz
  - Metrics: http://localhost:3002/metrics
  - Orders API: http://localhost:3002/api/orders
- **Frontend App**: http://localhost:3003
  - Metrics: http://localhost:3003/metrics
- **Mobile App**: http://localhost:3004
  - Metrics: http://localhost:3004/metrics

### **🎯 3. Roteiro de Demonstração**

#### **3.1 Overview da Arquitetura (2-3 min)**
```
🏗 "Vamos ver nossa arquitetura completa de observabilidade..."
 Mostrar diagrama/slides da arquitetura
 Explicar: Apps  Prometheus  Grafana  Dashboards
```

#### **3.2 Aplicações Funcionando (2-3 min)**
```
🚀 "Primeiro, vamos ver nossas aplicações rodando..."
 Backend: http://localhost:3002 (mostrar JSON da API)
 Frontend: http://localhost:3003 (mostrar React app)
 Mobile: http://localhost:3004 (mostrar Expo web app)
```

#### **3.3 Coleta de Métricas (3-4 min)**
```
📊 "Agora vamos ver como coletamos métricas..."
 Prometheus: http://localhost:9090/targets (mostrar targets UP)
 Queries: up, http_requests_total, process_cpu_user_seconds_total
 Mostrar métricas sendo atualizadas em tempo real
```

#### **3.4 Dashboards Principal - Golden Signals (4-5 min)**
```
📈 "O coração do nosso monitoramento são os Golden Signals..."
 Grafana: http://localhost:3100/d/golden-signals
 Mostrar:
  - Latency (percentis P50, P95, P99)
  - Traffic (requests/segundo)
  - Errors (taxa de erro)
  - Saturation (CPU, memória)
 Destacar dados sendo atualizados em tempo real
```

#### **3.5 Dashboards Específicos (3-4 min)**
```
🎨 "Cada aplicação tem seu dashboard específico..."
 Frontend: http://localhost:3100/d/frontend-golden-signals
  - Web Vitals (FCP, LCP, CLS)
  - User interactions
  - Page load times
 Mobile: http://localhost:3100/d/mobile-golden-signals
  - App performance
  - User engagement
  - Error tracking
```

#### **3.6 Business Metrics (2-3 min)**
```
💼 "Além da parte técnica, monitoramos métricas de negócio..."
 Business: http://localhost:3100/d/business-metrics
 Orders created, revenue, user activity
 Correlação entre métricas técnicas e de negócio
```

#### **3.7 Logs e Traces (2-3 min)**
```
🔍 "Para troubleshooting, temos logs e traces distribuídos..."
 Logs: Grafana Explore  Loki
 Traces: Grafana Explore  Tempo
 Mostrar correlação entre métricas, logs e traces
```

---

## 📊 **COMANDOS ÚTEIS DURANTE GRAVAÇÃO**

### **🔄 Gerar Mais Tráfego Instantâneo**
```bash
# Se precisar de mais atividade nos dashboards
for i in {1..50}; do curl -s http://localhost:3002/api/orders >/dev/null; done
```

### **⚡ Simular Problemas (Opcional)**
```bash
# Simular alta latência
for i in {1..20}; do curl -s http://localhost:3002/nonexistent >/dev/null; done

# Simular pico de tráfego
seq 1 100 | xargs -P 10 -I {} curl -s http://localhost:3002/healthz >/dev/null
```

### **📈 Mostrar Queries Específicas no Prometheus**
```
# Queries interessantes para mostrar:
up                                          # Status dos serviços
rate(http_requests_total[5m])              # Requests por segundo
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))  # P95 latency
process_cpu_user_seconds_total             # CPU usage
nodejs_heap_size_used_bytes               # Memory usage
```

---

## 🚨 **TROUBLESHOOTING RÁPIDO**

### **Se dashboards estão vazios:**
```bash
# 1. Verificar port-forwards
ps aux | grep port-forward

# 2. Recriar se necessário
pkill -f port-forward
./scripts/port-forward-metrics.sh &

# 3. Gerar tráfego
./generate-demo-traffic.sh 5 &
```

### **Se algum serviço não responde:**
```bash
# Verificar pods
kubectl get pods -n case

# Restart se necessário
kubectl rollout restart deployment/backend -n case
kubectl rollout restart deployment/frontend -n case
kubectl rollout restart deployment/mobile -n case
```

---

##  **CHECKLIST FINAL PRÉ-GRAVAÇÃO**

- [ ] `./setup-demo-environment.sh` executado com sucesso
- [ ] `./check-demo-status.sh` mostra todos 
- [ ] `./test-metrics-collection.sh` confirma métricas funcionando
- [ ] Grafana login funcionando (admin/admin)
- [ ] Todos os dashboards carregando com dados
- [ ] Tráfego contínuo iniciado: `./generate-demo-traffic.sh 20 &`
- [ ] URLs principais testadas e funcionando

## 🎬 **RESULTADO ESPERADO**

** Ambiente 100% funcional com:**
- **3 aplicações** rodando e acessíveis
- **4 serviços** de observabilidade ativos  
- **6+ dashboards** com dados reais
- **Métricas** atualizando em tempo real
- **Tráfego realista** simulado
- **Demo profissional** pronta para gravação!

🎯 **Duração estimada da gravação**: 15-25 minutos com demonstração completa