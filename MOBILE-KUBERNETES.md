# Mobile App - Deploy Kubernetes

## Status: FUNCIONANDO

Aplicação mobile (Expo Web) rodando no Kubernetes kind cluster.

---

## Acesso

### Kubernetes (kind)
- **URL**: http://localhost:19007
- **Service**: `mobile.case.svc.cluster.local:19006`
- **Backend URL**: Configurado para `http://backend:3000`

---

## Arquitetura

```
┌─────────────────────────────────────┐
│ Mobile App (Expo Web)               │
│                                     │
│ - Framework: React Native Web      │
│ - Build: Expo export:web (static)  │
│ - Server: http-server               │
│ - Port: 19006                       │
│                                     │
│ Observability:                      │
│ - Console logging (pino-compatible) │
│ - Request tracking                  │
│ - Error handling                    │
└─────────────────────────────────────┘
           ↓ HTTP
┌─────────────────────────────────────┐
│ Backend API                         │
│ http://backend:3000/api/orders      │
└─────────────────────────────────────┘
```

---

## Funcionalidades

### Mobile Orders App

1. **Listar Orders**
   - Fetch de `/api/orders`
   - Display em FlatList
   - Total count

2. **Criar Order**
   - POST `/api/orders`
   - Item: "mobile"
   - Price: aleatório (0-100)
   - Auto-refresh após criação

3. **Observabilidade**
   - Logging de requisições
   - Tracking de latência
   - Error handling com display

---

## Deploy no Kubernetes

### Manifesto

Arquivo: `k8s/mobile-deployment.yaml`

**Deployment:**
- Replicas: 1
- Image: `case-mobile:latest` (imagePullPolicy: Never)
- Resources:
  - Requests: 256Mi RAM, 100m CPU
  - Limits: 512Mi RAM, 500m CPU
- Health Checks:
  - Liveness: 90s initial delay, 30s period
  - Readiness: 60s initial delay, 15s period

**Service:**
- Type: ClusterIP
- Port: 19006

**Ingress:**
- Path: `/mobile(/|$)(.*)`
- Backend: `mobile:19006`

### Dockerfile

Arquivo: `app/mobile/Dockerfile`

**Build Strategy:**
1. Base: `node:20-bullseye`
2. Install: expo-cli@6.3.10, expo@^51.0.0
3. Install dependencies: `npm ci --legacy-peer-deps`
4. Build static web: `npx expo export:web`
5. Serve: `http-server web-build -p 19006 --cors`

**Environment Variables:**
- `EXPO_PUBLIC_BACKEND_URL`: Backend URL
- `EXPO_NO_TELEMETRY=1`: Disable telemetry
- `NODE_ENV=production`

---

## Build e Deploy

### 1. Build Imagem Docker

```bash
cd app/mobile
docker build -t case-mobile:latest .
```

**Tempo estimado:** ~3-5 minutos

### 2. Carregar no kind

```bash
kind load docker-image case-mobile:latest --name case-local
```

### 3. Deploy no Kubernetes

```bash
kubectl apply -f k8s/mobile-deployment.yaml
```

### 4. Verificar Status

```bash
kubectl get pods -n case | grep mobile
kubectl logs -n case deployment/mobile
```

### 5. Port-Forward (para acesso local)

```bash
kubectl port-forward -n case svc/mobile 19007:19006
```

Acessar: http://localhost:19007

---

## Observabilidade

### Logging

Console logs estruturados:

```typescript
logger.info('Fetching orders from backend', { url: BACKEND_URL });
logger.error('Failed to fetch orders', error);
```

### Métricas Rastreadas

- **Request Duration**: Tempo de resposta do backend
- **Error Count**: Requisições falhadas
- **Orders Count**: Total de orders exibidos

### Health Checks

```bash
# Liveness probe
curl http://localhost:19007/

# Dentro do pod
kubectl exec -n case deployment/mobile -- curl http://localhost:19006/
```

---

## Troubleshooting

### Pod em CrashLoopBackOff

**Problema comum:** Expo tentando usar Metro bundler

**Solução:** Usar build estático com `expo export:web`

```dockerfile
RUN npx expo export:web && npm install -g http-server
CMD ["http-server", "web-build", "-p", "19006", "--cors"]
```

### Porta em uso

Se porta 19006 estiver em uso localmente, usar outra porta no port-forward:

```bash
kubectl port-forward -n case svc/mobile 19007:19006
```

### Backend não acessível

Verificar se `EXPO_PUBLIC_BACKEND_URL` está correto:

```bash
kubectl describe pod -n case <mobile-pod> | grep EXPO_PUBLIC_BACKEND_URL
```

Deve ser: `http://backend:3000` (DNS interno Kubernetes)

### Rebuild necessário

Se App.tsx ou package.json mudaram:

```bash
# Rebuild
cd app/mobile
docker build -t case-mobile:latest .

# Reload no kind
kind load docker-image case-mobile:latest --name case-local

# Restart deployment
kubectl rollout restart deployment/mobile -n case
```

---

## Melhorias Implementadas

### 1. Observabilidade

- Logger estruturado (console)
- Request/response tracking
- Error handling com display
- Latência medida

### 2. UX

- Loading state
- Error display
- Total orders count
- Disabled buttons durante loading
- Empty state message

### 3. Build

- Static export (Expo web)
- Health checks lenientes (90s/60s)
- CORS habilitado
- Produção ready

---

## Próximos Passos

### Observabilidade Avançada

1. [ ] Exportar métricas para Prometheus
   - Web vitals (FCP, LCP, FID)
   - API call success rate
   - Error rate

2. [ ] Integrar com Grafana
   - Dashboard mobile-specific
   - User journey tracking

3. [ ] Logs para Loki
   - Structured logging via API
   - Log aggregation

### Features

1. [ ] Refresh automático
2. [ ] Pull-to-refresh
3. [ ] Paginação de orders
4. [ ] Filtros (por preço, data)
5. [ ] Dark mode

### Performance

1. [ ] Service Worker para cache
2. [ ] Lazy loading
3. [ ] Code splitting
4. [ ] Image optimization

---

## Comandos Úteis

```bash
# Status
kubectl get all -n case -l app=mobile

# Logs (tail)
kubectl logs -n case deployment/mobile -f

# Shell no pod
kubectl exec -it -n case deployment/mobile -- bash

# Describe
kubectl describe pod -n case -l app=mobile

# Delete e recreate
kubectl delete deployment mobile -n case
kubectl apply -f k8s/mobile-deployment.yaml

# Scale
kubectl scale deployment mobile -n case --replicas=2

# Port-forward
kubectl port-forward -n case svc/mobile 19007:19006
```

---

## Arquivos Modificados

1. **app/mobile/Dockerfile**
   - Adicionado curl para healthcheck
   - Expo export:web para build estático
   - http-server para servir
   - Health check configurado

2. **app/mobile/package.json**
   - Adicionado `@expo/webpack-config`
   - Adicionado `pino` e `pino-pretty`
   - Script `web` adicionado

3. **app/mobile/App.tsx**
   - Logger estruturado
   - Loading state
   - Error handling
   - Latência tracking
   - UX melhorada

4. **k8s/mobile-deployment.yaml**
   - Health checks ajustados (90s/60s)
   - Resources definidos
   - Datadog tags
   - Service criado

5. **k8s/ingress.yaml** (já existia)
   - Rota `/mobile` para mobile service

---

## Demo

### Testando Mobile App

1. **Abrir mobile**: http://localhost:19007

2. **Testar Refresh**:
   - Clicar em "Refresh"
   - Verificar console logs (F12)
   - Ver latência e count

3. **Criar Order**:
   - Clicar em "Create Order"
   - Ver log de criação
   - Lista atualiza automaticamente

4. **Verificar Observabilidade**:
   - Logs no console do browser
   - Logs no pod: `kubectl logs -n case deployment/mobile -f`

---

## Integração com Stack de Observabilidade

O mobile está pronto para integração com:

- Prometheus (métricas de infra via http-server)
- Loki (logs via stdout, Promtail pode coletar)
- Tempo (traces não implementados no frontend)
- Grafana (dashboard mobile-specific a criar)

Para integração completa, próximos passos:
1. Instrumentar com OpenTelemetry Web
2. Exportar custom metrics para Prometheus
3. Criar dashboard Grafana para mobile
