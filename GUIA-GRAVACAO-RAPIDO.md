# 🎬 GUIA RÁPIDO PARA GRAVAÇÃO

## 📋 **Pré-Gravação (Execute uma vez)**

### 1. Limpeza e Setup Completo
```bash
# Limpar ambiente anterior (se necessário)
./cleanup-and-restart.sh

# Subir ambiente completo para demo
./setup-demo-environment.sh
```

### 2. Validar se está Tudo OK  
```bash
# Verificar se ambiente está pronto
./validate-demo-environment.sh
```

### 3. Verificação Rápida Final
```bash
# Verificar se tudo está acessível
./quick-pre-recording-check.sh
```

---

## 🎥 **Durante a Gravação**

### URLs Principais:
- **Grafana**: http://localhost:3100 (admin/admin)
- **Prometheus**: http://localhost:9090
- **Backend API**: http://localhost:3002
- **Frontend**: http://localhost:3003  
- **Mobile**: http://localhost:3004

### Dashboards para Demo:
- **Golden Signals**: http://localhost:3100/d/golden-signals
- **Business Metrics**: http://localhost:3100/d/business-metrics
- **Frontend**: http://localhost:3100/d/frontend-golden-signals
- **Mobile**: http://localhost:3100/d/mobile-golden-signals

### Gerar Tráfego Contínuo:
```bash
# Iniciar tráfego de 20 minutos (para gravação de 15-25min)
./generate-demo-traffic.sh 20 &
```

---

## 🎯 **Roteiro Sugerido de Gravação**

### 1. **Introdução (2min)**
- Mostrar arquitetura local rodando
- Explicar stack: Kind + Observabilidade

### 2. **Métricas Backend (5min)**  
- Abrir Grafana: http://localhost:3100
- Dashboard Golden Signals
- Mostrar métricas em tempo real
- Explicar RED metrics

### 3. **Métricas Frontend (3min)**
- Dashboard Frontend Golden Signals  
- Métricas específicas de web (Core Web Vitals)

### 4. **Métricas Mobile (3min)**
- Dashboard Mobile Golden Signals
- Métricas de app mobile

### 5. **Business Metrics (5min)**
- Dashboard Business Metrics
- KPIs de negócio
- Correlação com métricas técnicas

### 6. **Observabilidade Completa (5min)**
- Logs no Loki
- Traces no Tempo  
- Correlação entre métricas, logs e traces

### 7. **Conclusão (2min)**
- Benefícios da observabilidade
- Próximos passos

---

## 🚨 **Troubleshooting Durante Gravação**

### Se algum serviço não responder:
```bash
# Verificar pods
kubectl get pods -n case

# Restart port-forwards
bash scripts/port-forward-metrics.sh &
```

### Se métricas pararam:
```bash
# Gerar mais tráfego
./generate-demo-traffic.sh 5 &
```

### Se Grafana não carregar dashboards:
- Aguarde 30s para métricas chegarem
- Ajuste time range para "Last 5 minutes"
- Refresh manual (Ctrl+R)

---

## 🧹 **Pós-Gravação**
```bash
# Limpar ambiente
./cleanup-and-restart.sh
```

---

## ⚡ **Scripts Disponíveis**

| Script | Função |
|--------|---------|
| `setup-demo-environment.sh` | Setup completo do ambiente |
| `validate-demo-environment.sh` | Validar se está tudo OK |  
| `quick-pre-recording-check.sh` | Check rápido pré-gravação |
| `generate-demo-traffic.sh` | Gerar tráfego contínuo |
| `cleanup-and-restart.sh` | Limpeza completa |

---

## 📊 **Métricas Disponíveis**

### Backend:
- Request rate, error rate, duration
- Memory, CPU usage
- Custom business metrics

### Frontend:  
- Page load times, Core Web Vitals
- User interactions
- Error tracking

### Mobile:
- App performance metrics
- User sessions
- Crash tracking

**🎬 AMBIENTE PRONTO PARA GRAVAÇÃO PROFISSIONAL! 🚀**