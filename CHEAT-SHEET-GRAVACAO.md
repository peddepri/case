# 🎬 CHEAT SHEET - GRAVAÇÃO AO VIVO

## 🚨 **ANTES DE LIGAR A CÂMERA**
```bash
# 1. Quick check final
./quick-pre-recording-check.sh

# 2. Se tudo OK, iniciar tráfego  
./generate-demo-traffic.sh 20 &

# 3. Verificar se Grafana carrega
open http://localhost:3100  # (admin/admin)
```

---

## 📋 **URLs ESSENCIAIS** (Cole na barra de endereço)

### **🎯 Dashboards (Grafana)**
```
http://localhost:3100                           # Login (admin/admin)
http://localhost:3100/d/golden-signals         # Golden Signals 
http://localhost:3100/d/frontend-golden-signals # Frontend Dashboard
http://localhost:3100/d/mobile-golden-signals  # Mobile Dashboard  
http://localhost:3100/d/business-metrics       # Business Metrics
```

### **🔍 Monitoramento**
```
http://localhost:9090                           # Prometheus
http://localhost:9090/targets                   # Targets Status
http://localhost:9090/graph                     # Query Interface
```

### **🚀 Aplicações**
```
http://localhost:3002                           # Backend API
http://localhost:3002/api/orders               # Orders Endpoint
http://localhost:3003                           # Frontend App
http://localhost:3004                           # Mobile App
```

---

## 🎤 **ROTEIRO DE NARRAÇÃO** (15-20 min)

### **1. Introdução (1-2 min)**
```
"Hoje vamos ver uma implementação completa de observabilidade 
com Prometheus, Grafana, Loki e Tempo. Temos 3 aplicações 
rodando em Kubernetes com monitoramento end-to-end."
```

### **2. Visão Geral das Apps (2-3 min)**
```
🚀 "Primeiro, nossas aplicações funcionando..."
 Backend: http://localhost:3002 
   "Nossa API Node.js com métricas completas"
 Frontend: http://localhost:3003
   "Interface React com Web Vitals"  
 Mobile: http://localhost:3004
   "App mobile com Expo"
```

### **3. Coleta de Métricas (3-4 min)**
```
📊 "Vamos ver como coletamos métricas..."
 Prometheus: http://localhost:9090/targets
   "6 targets sendo monitorados em tempo real"
 Query: up, http_requests_total
   "Métricas atualizando a cada 15 segundos"
```

### **4. Golden Signals (5-6 min)**  **FOCO PRINCIPAL**
```
📈 "O core do monitoramento: Golden Signals"
 http://localhost:3100/d/golden-signals

🔍 "Latency - Tempo de resposta"
   "P50, P95, P99 - vemos que 95% das requests são sub-200ms"

🔍 "Traffic - Volume de requisições" 
   "Requests por segundo, podemos ver o padrão de uso"

🔍 "Errors - Taxa de erro"
   "Percentage de erros, alertas quando > 5%"

🔍 "Saturation - Uso de recursos"
   "CPU, Memória, Event Loop - saúde da infraestrutura"
```

### **5. Dashboards Específicos (3-4 min)**
```
🎨 "Cada aplicação tem métricas específicas..."
 Frontend: http://localhost:3100/d/frontend-golden-signals
   "Web Vitals: FCP, LCP, CLS - performance do usuário"
 Mobile: http://localhost:3100/d/mobile-golden-signals  
   "Métricas mobile: load time, interactions, crashes"
```

### **6. Business Metrics (2-3 min)**
```
💼 "Conectando técnico com negócio..."
 http://localhost:3100/d/business-metrics
   "Orders criados, revenue, conversão - ROI da observabilidade"
```

### **7. Logs e Traces (2-3 min)**
```
🔍 "Para debugging profundo..."
 Grafana Explore  Loki (logs)
 Grafana Explore  Tempo (traces)  
   "Correlação entre métricas, logs e traces distribuídos"
```

---

## 📊 **QUERIES PROMETHEUS PARA MOSTRAR**

### **Básicas**
```
up                                    # Status dos serviços
http_requests_total                   # Total de requests
rate(http_requests_total[5m])         # Requests/segundo
```

### **Avançadas**  
```
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))  # P95 latency
rate(http_errors_total[5m]) / rate(http_requests_total[5m]) * 100        # Error rate %
process_cpu_user_seconds_total        # CPU usage
nodejs_heap_size_used_bytes          # Memory usage
```

---

## 🚨 **COMANDOS DE EMERGÊNCIA**

### **Se dashboards vazios:**
```bash
# Gerar tráfego instantâneo
for i in {1..50}; do curl -s http://localhost:3002/api/orders >/dev/null; done

# Restart port-forwards  
pkill -f port-forward && ./scripts/port-forward-metrics.sh &
```

### **Se app não responde:**
```bash
# Restart pods
kubectl rollout restart deployment/backend -n case
kubectl rollout restart deployment/frontend -n case
kubectl rollout restart deployment/mobile -n case
```

### **Verificação rápida:**
```bash
kubectl get pods -n case              # Pods status
docker ps | grep -E "(prometheus|grafana)"  # Observability
curl http://localhost:3100/api/health # Grafana health
```

---

## 🎯 **PONTOS-CHAVE PARA ENFATIZAR**

1. **📊 Dados em Tempo Real**: "Vejam que os dados atualizam a cada 15 segundos"
2. **🔄 Correlação**: "Podemos correlacionar métricas técnicas com negócio"  
3. **⚡ Alerting**: "Alertas automáticos quando SLIs violam SLOs"
4. **🔍 Troubleshooting**: "Do alert até root cause em minutos"
5. **📈 Escalabilidade**: "Solução que cresce com a aplicação"

---

## ⏰ **TIMING SUGERIDO**

- **0-2 min**: Intro + Overview
- **2-5 min**: Apps funcionando  
- **5-9 min**: Prometheus + Coleta
- **9-15 min**: **Golden Signals** (foco principal)
- **15-18 min**: Dashboards específicos
- **18-20 min**: Business + Wrap-up

**Total: 20 minutos + Q&A**

---

## 💡 **DICAS FINAIS**

-  **Sempre mostrar dados reais** (não mock/estático)
-  **Explicar o "porquê"** de cada métrica  
-  **Conectar com cenários reais** de produção
-  **Mostrar alerting em ação** (se possível)
-  **Enfatizar ROI** - tempo economizado em troubleshooting

🎬 **BOA GRAVAÇÃO!**