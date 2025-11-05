# Scripts LocalStack Pro + EKS + Observabilidade

Este documento descreve os novos scripts criados para subir o ambiente completo do projeto com LocalStack Pro, EKS simulado (kind), aplicações (mobile, backend, frontend) e stack de observabilidade.

## 📋 Scripts Disponíveis

### 1. `start-localstack-pro-full.sh` - Ambiente Completo

**Descrição:** Script completo que sobe todo o ambiente: LocalStack Pro + EKS (kind) + Apps + Observabilidade

**O que faz:**
- [OK] Inicia LocalStack Pro com EKS, DynamoDB, ECR, IAM, S3, Secrets Manager
- [OK] Provisiona recursos AWS automaticamente
- [OK] Sobe stack de observabilidade (Prometheus, Grafana, Loki, Tempo)
- [OK] Inicia aplicações no LocalStack (backend, frontend, datadog-agent)
- [OK] Cria cluster Kubernetes local (kind)
- [OK] Faz build e deploy das aplicações no Kubernetes
- [OK] Configura Ingress Controller (Nginx)
- [OK] Executa testes de conectividade

**Uso:**
```bash
bash scripts/start-localstack-pro-full.sh
```

**Tempo estimado:** 3-5 minutos

**Endpoints criados:**
- LocalStack: http://localhost:4566
- Backend LocalStack: http://localhost:3001
- Frontend LocalStack: http://localhost:5174
- Grafana: http://localhost:3100 (admin/admin)
- Prometheus: http://localhost:9090
- Kubernetes Ingress: http://localhost:8080

### 2. `start-localstack-pro-simple.sh` - Ambiente Simplificado

**Descrição:** Versão rápida sem Kubernetes, ideal para desenvolvimento local

**O que faz:**
- [OK] Inicia LocalStack Pro
- [OK] Provisiona recursos AWS
- [OK] Sobe observabilidade
- [OK] Inicia aplicações LocalStack
- [WARNING] Não inclui Kubernetes (mais rápido)

**Uso:**
```bash
bash scripts/start-localstack-pro-simple.sh
```

**Tempo estimado:** 1-2 minutos

### 3. `stop-all.sh` - Parar Todos os Serviços

**Descrição:** Para todos os serviços e opcionalmente remove dados persistentes

**O que faz:**
- 🛑 Para LocalStack e aplicações
- 🛑 Para stack de observabilidade
- 🛑 Deleta cluster kind (se existir)
- 🗑 Opção para remover dados persistentes
- 🧹 Limpeza de containers e volumes órfãos

**Uso:**
```bash
bash scripts/stop-all.sh
```

### 4. `validate-environment.sh` - Validação Completa

**Descrição:** Executa bateria completa de testes para validar o ambiente

**O que testa:**
- 🔍 LocalStack (Gateway, DynamoDB, ECR, IAM)
- 🔍 Aplicações (Backend, Frontend, API)
- 🔍 Observabilidade (Prometheus, Grafana, Loki, Tempo)
- 🔍 Kubernetes (se disponível)
- 🔍 Testes funcionais (criar orders, verificar DynamoDB)
- 🔍 Métricas Prometheus
- 🔍 Performance básica
- 🔍 Teste de carga (10 requests)

**Uso:**
```bash
bash scripts/validate-environment.sh
```

**Saída:** Relatório detalhado com status de cada componente

### 5. `load-test.sh` - Teste de Carga

**Descrição:** Gera tráfego para validar observabilidade e performance

**O que faz:**
- 🚀 Executa requests concorrentes por tempo determinado
- 📊 Mix de operações (GET, POST, health checks, erros simulados)
- 📈 Mostra métricas em tempo real
- 📊 Relatório final com estatísticas

**Uso:**
```bash
# Teste padrão (60s, 5 workers)
bash scripts/load-test.sh

# Teste customizado (120s, 10 workers)
bash scripts/load-test.sh 120 10
```

## 🚀 Fluxo de Uso Recomendado

### Para Desenvolvimento Local (Rápido)

```bash
# 1. Iniciar ambiente simplificado
bash scripts/start-localstack-pro-simple.sh

# 2. Validar funcionamento
bash scripts/validate-environment.sh

# 3. Gerar tráfego para métricas
bash scripts/load-test.sh

# 4. Acessar Grafana
# http://localhost:3100 (admin/admin)

# 5. Parar quando terminar
bash scripts/stop-all.sh
```

### Para Demonstração Completa (com Kubernetes)

```bash
# 1. Iniciar ambiente completo
bash scripts/start-localstack-pro-full.sh

# 2. Validar tudo
bash scripts/validate-environment.sh

# 3. Teste de carga mais intenso
bash scripts/load-test.sh 300 10

# 4. Demonstrar dashboards Grafana
# - Golden Signals: http://localhost:3100/d/golden-signals-backend
# - Business Metrics: http://localhost:3100/d/business-orders

# 5. Mostrar Kubernetes
kubectl get pods -n case
kubectl logs -n case -l app=backend -f

# 6. Parar tudo
bash scripts/stop-all.sh
```

## 📊 Endpoints e Dashboards

### Aplicações
| Serviço | URL | Descrição |
|---------|-----|-----------|
| Backend LocalStack | http://localhost:3001 | API REST |
| Frontend LocalStack | http://localhost:5174 | Interface web |
| Mobile (opcional) | http://localhost:19006 | App mobile web |
| Kubernetes Ingress | http://localhost:8080 | Apps via K8s |

### Observabilidade
| Serviço | URL | Credenciais |
|---------|-----|-------------|
| Grafana | http://localhost:3100 | admin/admin |
| Prometheus | http://localhost:9090 | - |
| Loki | http://localhost:3101 | - |
| Tempo | http://localhost:3102 | - |

### AWS Local
| Serviço | URL | Descrição |
|---------|-----|-----------|
| LocalStack Gateway | http://localhost:4566 | Todos os serviços AWS |
| Health Check | http://localhost:4566/_localstack/health | Status |

### Dashboards Grafana
| Dashboard | URL | Descrição |
|-----------|-----|-----------|
| Golden Signals | http://localhost:3100/d/golden-signals-backend | Latência, Tráfego, Erros, Saturação |
| Business Metrics | http://localhost:3100/d/business-orders | Métricas de negócio (orders) |

## 🔧 Comandos Úteis

### LocalStack
```bash
# Listar tabelas DynamoDB
bash scripts/awslocal.sh dynamodb list-tables

# Ver orders na tabela
bash scripts/awslocal.sh dynamodb scan --table-name orders

# Listar repositórios ECR
bash scripts/awslocal.sh ecr describe-repositories

# Ver roles IAM
bash scripts/awslocal.sh iam list-roles
```

### Kubernetes
```bash
# Status dos pods
kubectl get pods -n case

# Logs do backend
kubectl logs -n case -l app=backend -f

# Port-forward direto
kubectl port-forward -n case svc/backend 3002:3000

# Descrever ingress
kubectl describe ingress case-ingress -n case
```

### API Testing
```bash
# Health check
curl http://localhost:3001/healthz

# Listar orders
curl http://localhost:3001/api/orders

# Criar order
curl -X POST http://localhost:3001/api/orders \
  -H "Content-Type: application/json" \
  -d '{"item":"test","price":100}'

# Ver métricas Prometheus
curl http://localhost:3001/metrics
```

### Docker
```bash
# Status dos containers
docker compose -f docker-compose.localstack.yml ps
docker compose -f docker-compose.observability.yml ps

# Logs específicos
docker compose -f docker-compose.localstack.yml logs -f backend-localstack
docker compose -f docker-compose.observability.yml logs -f grafana

# Recursos utilizados
docker stats
```

## 🐛 Troubleshooting

### LocalStack não inicia
```bash
# Verificar logs
docker compose -f docker-compose.localstack.yml logs localstack

# Verificar token
grep LOCALSTACK_AUTH_TOKEN .env.localstack

# Limpar dados e reiniciar
bash scripts/stop-all.sh
# Responder 's' para remover dados
bash scripts/start-localstack-pro-simple.sh
```

### Backend não conecta no DynamoDB
```bash
# Verificar endpoint
docker compose -f docker-compose.localstack.yml exec backend-localstack env | grep DYNAMODB

# Testar conectividade
docker compose -f docker-compose.localstack.yml exec backend-localstack \
  curl http://localstack:4566/_localstack/health
```

### Kubernetes pods não iniciam
```bash
# Ver eventos
kubectl get events -n case --sort-by='.lastTimestamp'

# Descrever pod com problema
kubectl describe pod -n case <pod-name>

# Verificar imagens carregadas
docker exec -it case-local-control-plane crictl images
```

### Grafana não mostra dados
```bash
# Verificar datasources
curl -s http://localhost:3100/api/datasources | python -m json.tool

# Testar Prometheus
curl http://localhost:9090/api/v1/targets

# Verificar métricas do backend
curl http://localhost:3001/metrics | grep orders_
```

## 📈 Métricas Importantes

### Golden Signals
- **Latência:** `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))`
- **Tráfego:** `rate(http_requests_total[5m])`
- **Erros:** `rate(http_errors_total[5m]) / rate(http_requests_total[5m])`
- **Saturação:** `backend_process_cpu_user_seconds_total`, `backend_nodejs_heap_size_used_bytes`

### Business Metrics
- **Orders Created:** `rate(orders_created_total[5m])`
- **Orders Failed:** `rate(orders_failed_total[5m])`
- **Failure Rate:** `orders_failed_total / (orders_created_total + orders_failed_total)`

## 🎯 Cenários de Demonstração

### 1. Desenvolvimento Local (5 min)
1. `bash scripts/start-localstack-pro-simple.sh`
2. Mostrar aplicações funcionando
3. Criar algumas orders via API
4. Mostrar dados no DynamoDB
5. Abrir Grafana e mostrar métricas

### 2. Observabilidade Completa (10 min)
1. `bash scripts/start-localstack-pro-full.sh`
2. `bash scripts/validate-environment.sh`
3. `bash scripts/load-test.sh 120 5`
4. Mostrar dashboards Grafana em tempo real
5. Explicar 4 Golden Signals
6. Mostrar business metrics

### 3. Kubernetes + AWS Local (15 min)
1. Ambiente completo rodando
2. Mostrar pods no Kubernetes
3. Demonstrar Ingress funcionando
4. Port-forward para debug
5. Mostrar recursos AWS no LocalStack
6. Simular deploy Blue/Green
7. Teste de caos (matar pods)

## 🔄 Próximos Passos

Após validar o ambiente local:

1. **Deploy em AWS Real:**
   ```bash
   bash scripts/up.sh eks
   ```

2. **CI/CD Pipeline:**
   - Configurar GitHub Actions
   - Build e push para ECR real
   - Deploy Blue/Green no EKS

3. **Observabilidade Produção:**
   - Configurar Datadog real
   - Alertas e monitores
   - Dashboards customizados

4. **Segurança:**
   - IRSA (IAM Roles for Service Accounts)
   - Network Policies
   - Pod Security Standards

---

**Criado por:** Kiro  Assistant  
**Data:** 2025-10-25  
**Versão:** 1.0