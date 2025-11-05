# 📋 Guia Completo: Ambiente Local com Observabilidade

## 🎯 Objetivo
Este guia mostra como subir completamente o ambiente local com **todas as aplicações** e **observabilidade completa** funcionando para gravação de demo.

---

## 🔧 Pré-requisitos

### Ferramentas Necessárias
- Docker & Docker Compose
- Kind (Kubernetes in Docker)
- kubectl
- Node.js/npm (para builds)
- curl/jq (para testes)

### Verificar Instalação
```bash
# Verificar se todas as ferramentas estão disponíveis
docker --version
kind --version
kubectl version --client
node --version
npm --version
```

---

## 🚀 Passo a Passo Completo

### **1. Preparar o Ambiente Base**

```bash
# 1.1 - Navegar para o diretório do projeto
cd /path/to/case

# 1.2 - Limpar ambiente anterior (se houver)
kind delete cluster --name case-local 2>/dev/null || true
docker compose -f docker-compose.observability.yml down 2>/dev/null || true

# 1.3 - Criar cluster Kubernetes local
kind create cluster --name case-local --config kind-config.yaml

# 1.4 - Verificar cluster
kubectl cluster-info --context kind-case-local
kubectl get nodes
```

### **2. Subir Stack de Observabilidade**

```bash
# 2.1 - Iniciar Prometheus, Grafana, Loki, Tempo
docker compose -f docker-compose.observability.yml up -d

# 2.2 - Aguardar serviços ficarem prontos (30-60 segundos)
echo "⏳ Aguardando serviços de observabilidade..."
sleep 45

# 2.3 - Verificar status
docker ps | grep -E "(prometheus|grafana|loki|tempo)"

# 2.4 - Testar acessos
curl -s http://localhost:9090/-/healthy && echo "✅ Prometheus OK"
curl -s http://localhost:3100/api/health && echo "✅ Grafana OK" 
curl -s http://localhost:3101/ready && echo "✅ Loki OK"
curl -s http://localhost:3102/ready && echo "✅ Tempo OK"
```

### **3. Deploy das Aplicações no Kubernetes**

```bash
# 3.1 - Criar namespace
kubectl create namespace case --dry-run=client -o yaml | kubectl apply -f -

# 3.2 - Build das imagens locais (com instrumentação atualizada)
echo "🔨 Building backend..."
cd app/backend
docker build -t localhost:5001/case-backend:latest .
cd ../..

echo "🔨 Building frontend..."
cd app/frontend  
npm run build
docker build -t localhost:5001/case-frontend:latest .
cd ../..

echo "🔨 Building mobile..."
cd app/mobile
docker build -t localhost:5001/case-mobile:latest .
cd ../..

# 3.3 - Configurar registry local (se necessário)
docker run -d --restart=always -p 5001:5000 --name registry registry:2 2>/dev/null || true
sleep 5

# 3.4 - Push das imagens
docker push localhost:5001/case-backend:latest
docker push localhost:5001/case-frontend:latest  
docker push localhost:5001/case-mobile:latest

# 3.5 - Deploy no Kubernetes
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/env-config.yaml
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/backend-serviceaccount.yaml
kubectl apply -f k8s/frontend-deployment.yaml
kubectl apply -f k8s/mobile-deployment.yaml

# 3.6 - Aguardar pods ficarem prontos
echo "⏳ Aguardando pods ficarem Ready..."
kubectl wait --for=condition=Ready pods --all -n case --timeout=300s

# 3.7 - Verificar status
kubectl get pods -n case
kubectl get svc -n case
```

### **4. Configurar Coleta de Métricas**

```bash
# 4.1 - Executar port-forwards para métricas
echo "🔗 Configurando port-forwards para coleta de métricas..."
./scripts/port-forward-metrics.sh &
PORT_FORWARD_PID=$!

# 4.2 - Aguardar port-forwards estarem ativos
sleep 10

# 4.3 - Verificar conectividade
echo "🧪 Testando conectividade..."
curl -s http://localhost:3002/metrics | head -3 && echo "✅ Backend metrics OK"
curl -s -I http://localhost:3003/ | head -1 && echo "✅ Frontend OK"
curl -s -I http://localhost:3004/ | head -1 && echo "✅ Mobile OK"

# 4.4 - Verificar targets no Prometheus
echo "🎯 Verificando targets no Prometheus..."
curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.scrapePool | test("kubernetes")) | "\(.scrapePool): \(.health)"'
```

### **5. Gerar Dados para Dashboards**

```bash
# 5.1 - Gerar tráfego inicial
echo "📈 Gerando tráfego para popular métricas..."

# Backend - APIs
for i in {1..30}; do
    curl -s http://localhost:3002/ > /dev/null
    curl -s http://localhost:3002/healthz > /dev/null
    curl -s http://localhost:3002/api/orders > /dev/null
    echo -n "."
    sleep 0.2
done

# Frontend - Páginas  
for i in {1..15}; do
    curl -s http://localhost:3003/ > /dev/null
    echo -n "F"
    sleep 0.3
done

# Mobile - App
for i in {1..10}; do
    curl -s http://localhost:3004/ > /dev/null  
    echo -n "M"
    sleep 0.5
done

echo -e "\n✅ Tráfego inicial gerado!"

# 5.2 - Aguardar coleta de métricas
echo "⏳ Aguardando coleta de métricas (60s)..."
sleep 60

# 5.3 - Verificar se métricas estão sendo coletadas
echo "📊 Verificando métricas coletadas..."
METRICS_COUNT=$(curl -s 'http://localhost:9090/api/v1/query?query=up' | jq '.data.result | length')
echo "📈 Métricas 'up' encontradas: $METRICS_COUNT"

HTTP_METRICS=$(curl -s 'http://localhost:9090/api/v1/query?query=http_requests_total' | jq '.data.result | length')
echo "🌐 Métricas HTTP encontradas: $HTTP_METRICS"
```

### **6. Executar Testes de Carga (Opcional)**

```bash
# 6.1 - Executar teste de performance para gerar mais dados
echo "🚀 Executando teste de carga..."
bash scripts/load-test.sh

# 6.2 - Ou usar Locust (se disponível)
kubectl get pods -n case | grep locust && {
    echo "🐝 Locust disponível - executando carga via Locust..."
    kubectl port-forward -n case svc/locust-master 8089:8089 &
    LOCUST_PF=$!
    sleep 5
    echo "📊 Locust UI: http://localhost:8089"
}
```

---

## 🎯 URLs para Demo/Gravação

### **📊 Dashboards Principais**
- **Grafana**: http://localhost:3100 (admin/admin)
  - Golden Signals: http://localhost:3100/d/golden-signals
  - Business Metrics: http://localhost:3100/d/business-metrics
  - Frontend Dashboard: http://localhost:3100/d/frontend-golden-signals
  - Mobile Dashboard: http://localhost:3100/d/mobile-golden-signals

### **🔍 Monitoramento**  
- **Prometheus**: http://localhost:9090
  - Targets: http://localhost:9090/targets
  - Metrics: http://localhost:9090/graph
- **Loki**: http://localhost:3101
- **Tempo**: http://localhost:3102

### **🚀 Aplicações**
- **Backend API**: http://localhost:3002 
  - Health: http://localhost:3002/healthz
  - Metrics: http://localhost:3002/metrics
  - Orders: http://localhost:3002/api/orders
- **Frontend**: http://localhost:3003
- **Mobile**: http://localhost:3004

### **🐝 Performance (se ativo)**
- **Locust**: http://localhost:8089

---

## ✅ Checklist de Verificação

Antes de iniciar a gravação, verificar:

### **Infraestrutura**
- [ ] Kind cluster rodando: `kubectl get nodes`
- [ ] Pods rodando: `kubectl get pods -n case`
- [ ] Observabilidade ativa: `docker ps | grep -E "(prometheus|grafana)"`

### **Conectividade**
- [ ] Backend respondendo: `curl http://localhost:3002/healthz`
- [ ] Frontend acessível: `curl -I http://localhost:3003/`  
- [ ] Mobile acessível: `curl -I http://localhost:3004/`
- [ ] Grafana login: http://localhost:3100 (admin/admin)

### **Métricas**
- [ ] Targets UP: http://localhost:9090/targets
- [ ] Dados nos dashboards: http://localhost:3100/d/golden-signals
- [ ] Logs visíveis: Grafana → Explore → Loki
- [ ] Traces visíveis: Grafana → Explore → Tempo

### **Performance** 
- [ ] Load test funcionando: `bash scripts/load-test.sh`
- [ ] Métricas sendo atualizadas em tempo real

---

## 🛠 Comandos Úteis Durante Demo

### **Gerar Tráfego Contínuo**
```bash
# Loop contínuo para manter métricas ativas durante demo
while true; do
    curl -s http://localhost:3002/api/orders > /dev/null
    curl -s http://localhost:3003/ > /dev/null
    sleep 2
done &
```

### **Restart Rápido de Serviços**
```bash
# Se precisar reiniciar algo rapidamente
kubectl rollout restart deployment/backend -n case
kubectl rollout restart deployment/frontend -n case  
kubectl rollout restart deployment/mobile -n case
```

### **Limpeza Pós-Demo**
```bash
# Parar tudo após demo
kill $PORT_FORWARD_PID 2>/dev/null || true
pkill -f "port-forward" 2>/dev/null || true
docker compose -f docker-compose.observability.yml down
kind delete cluster --name case-local
```

---

## 📝 Script de Execução Completa

Para executar tudo de uma vez:

```bash
# Salvar como: setup-demo-environment.sh
chmod +x setup-demo-environment.sh
./setup-demo-environment.sh
```

🎬 **Ambiente pronto para gravação em ~5-10 minutos!**