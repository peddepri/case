# Configuração Rápida do Datadog

## 1. Obter API Key do Datadog

1. Acesse: https://app.us5.datadoghq.com/organization-settings/api-keys
2. Se não tiver conta, crie trial gratuito em: https://www.datadoghq.com/
3. Clique em **"New Key"** ou copie uma existente
4. Copie o valor da API Key (ex: `a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6`)

## 2. Configurar no ambiente local

Edite o arquivo `.env` na raiz do projeto:

```bash
# Cole sua API key aqui
DD_API_KEY=a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6
DD_SITE=us5.datadoghq.com
```

## 3. Reiniciar o stack Docker

```bash
# Parar containers
docker compose down

# Subir novamente com a API key
docker compose up -d

# Verificar logs do Datadog Agent
docker compose logs datadog-agent | grep "Datadog Agent is running"
```

## 4. Verificar conexão

Aguarde 1-2 minutos e acesse:
- https://app.us5.datadoghq.com/infrastructure/map
- https://app.us5.datadoghq.com/apm/services

Você deve ver:
-  Host/containers aparecerem em **Infrastructure**
-  Service `backend` em **APM > Services**
-  Métricas e traces sendo coletados

## 5. Testar envio de traces

```bash
# Fazer algumas requisições ao backend
curl http://localhost:3000/healthz
curl http://localhost:3000/api/orders
curl -X POST http://localhost:3000/api/orders \
  -H "Content-Type: application/json" \
  -d '{"item":"test","price":100}'
```

Aguarde 30-60 segundos e veja as traces em:
https://app.us5.datadoghq.com/apm/traces

## Troubleshooting

### Agent não conecta

```bash
# Ver logs detalhados
docker compose logs datadog-agent --tail=50

# Procurar por erros
docker compose logs datadog-agent | grep -i error
```

Erros comuns:
- `API key is invalid`  Verifique se copiou a key completa
- `connection refused`  Verifique firewall/proxy

### Sem dados no Datadog

1. Confirme que DD_API_KEY está no `.env` (sem aspas)
2. Verifique o DD_SITE correto (us5.datadoghq.com)
3. Aguarde 2-3 minutos após reiniciar containers
4. Teste fazer requisições ao backend

## Configuração Kubernetes (EKS)

Para o ambiente EKS, a API key será configurada via:
1. Terraform: `dd_api_key` em `terraform.tfvars`
2. Kubernetes Secret: criado automaticamente pelo Helm
3. DatadogAgent CRD: referencia o secret

Exemplo de manifest K8s (já aplicado via Terraform/Helm):

```yaml
apiVersion: datadoghq.com/v2alpha1
kind: DatadogAgent
metadata:
  name: datadog
  namespace: datadog
spec:
  global:
    site: us5.datadoghq.com
    credentials:
      apiSecret:
        secretName: datadog-secret
        keyName: api-key
    tags:
      - env:staging
  features:
    apm:
      enabled: true
    logCollection:
      enabled: true
```

## Próximos passos

Depois de conectar localmente:
1.  Validar métricas/traces no Datadog
2.  Provisionar EKS com Terraform (Seção 2 do guia)
3.  Configurar GitHub Secrets com DD_API_KEY
4.  Deploy no EKS com observabilidade completa
