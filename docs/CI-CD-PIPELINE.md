# CI/CD Pipeline Guide

## Overview

Este projeto implementa uma pipeline CI/CD moderna e simplificada que suporta tanto desenvolvimento local com Kind quanto deployment em produção no AWS EKS.

## Estrutura da Pipeline

### 1. Pipeline Principal (`cicd-simple.yml`)
- **Trigger**: Push/PR para branch `main`
- **Ambiente**: Kind cluster local com Docker Desktop
- **Funcionalidades**:
  - Testes unitários (backend Python, frontend Node.js)
  - Build e push para registry local
  - Deploy no Kind cluster
  - Testes básicos de saúde
  - Testes opcionais de performance e chaos

### 2. Pipeline de Produção (`production-deploy.yml`)
- **Trigger**: Sucesso da pipeline principal ou manual
- **Ambiente**: AWS EKS
- **Funcionalidades**:
  - Blue-Green deployment
  - ECR para imagens de containers
  - Configuração completa de monitoramento

## Problemas Resolvidos

### ❌ Problemas Identificados:
1. **ServiceMonitor API version incorreta**: `v1` → `monitoring.coreos.com/v1`
2. **metrics-server-patch.yaml incompleto**: Faltavam `selector` e `labels`
3. **Dependência desnecessária do ECR**: Localstack community não suporta ECR
4. **Complexidade excessiva**: Pipeline muito complexa para desenvolvimento local

### ✅ Soluções Implementadas:

#### 1. **Registry Local para Kind**
```bash
# Registry local na porta 5001
docker run -d --restart=always -p 5001:5000 --name registry registry:2
docker network connect kind registry
```

#### 2. **Configuração Simplificada**
```yaml
# Configs mínimas para teste local
kubectl create configmap env-config -n case \
  --from-literal=DDB_TABLE=orders \
  --from-literal=AWS_REGION=us-east-1
```

#### 3. **Deployment Condicional**
- **Local**: Kind + registry local
- **Produção**: EKS + ECR (apenas quando configurado)

## Configuração do Repositório

### Variáveis Necessárias (Repository Variables)
Para produção AWS, configure as seguintes variáveis no GitHub:

```bash
# Obrigatórias para AWS deployment
EKS_CLUSTER_NAME=my-eks-cluster
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=123456789012

# Opcionais
ENABLE_PERFORMANCE_TESTS=true
ENABLE_CHAOS_TESTS=true
ENABLE_MONITORING=true
DEPLOY_TO_AWS=true  # Para habilitar deploy automático
```

### Secrets Necessários
```bash
# AWS
AWS_ROLE_TO_ASSUME=arn:aws:iam::123456789012:role/GitHubActionsRole
BACKEND_IRSA_ROLE_ARN=arn:aws:iam::123456789012:role/BackendRole

# Datadog
DD_API_KEY=your-datadog-api-key
```

## Como Usar

### 1. **Desenvolvimento Local (Automático)**
```bash
# Qualquer push para main triggera:
git push origin main

# A pipeline automaticamente:
# 1. Executa testes
# 2. Cria Kind cluster
# 3. Build + deploy local
# 4. Testes de saúde
```

### 2. **Deploy Manual para Produção**
```bash
# Via GitHub Actions UI:
# 1. Vá para Actions → Production Deploy
# 2. Clique "Run workflow"
# 3. Selecione ambiente (staging/production)
```

### 3. **Deploy Automático para Produção**
- Configure `DEPLOY_TO_AWS=true` nas variáveis do repositório
- Deploy automático após sucesso da pipeline principal

## Testes Implementados

### 🧪 **Testes Funcionais**
- ✅ Testes unitários de backend (pytest)
- ✅ Build do frontend (npm run build)
- ✅ Health checks via curl

### ⚡ **Testes de Performance (Opcional)**
```bash
# Ativado com ENABLE_PERFORMANCE_TESTS=true
for i in {1..5}; do
  curl -s http://localhost:8080/health
done
```

### 🌪️ **Chaos Engineering (Opcional)**
```bash
# Ativado com ENABLE_CHAOS_TESTS=true
# Simula falha de pod e testa recuperação
kubectl delete pod $POD_NAME -n case
kubectl wait --for=condition=ready pod -l app=backend
```

## Monitoramento e Observabilidade

### Local (Kind)
- Logs básicos via `kubectl logs`
- Health checks simples

### Produção (EKS)
- ServiceMonitors do Prometheus
- Datadog APM (se configurado)
- Métricas de aplicação

## Boas Práticas Implementadas

1. **🔄 Blue-Green Deployment**: Zero downtime em produção
2. **🧪 Testes Graduais**: Local → Staging → Production
3. **🛡️ Validação de Configuração**: Falha rápida se configs ausentes
4. **🏗️ Infraestrutura como Código**: Manifests K8s versionados
5. **📊 Observabilidade**: Logs, métricas e health checks
6. **🔒 Segurança**: IRSA roles, secrets gerenciados
7. **🚀 Simplicidade**: Pipeline minimalista mas completa

## Troubleshooting

### Problema: Registry local não funciona
```bash
# Verifique se o registry está rodando
docker ps | grep registry

# Reconecte à rede do Kind
docker network connect kind registry
```

### Problema: Kind cluster não inicia
```bash
# Limpe clusters antigos
kind delete cluster --name case-cluster

# Verifique a configuração
cat kind-config.yaml
```

### Problema: Deploy AWS falha
```bash
# Verifique configurações
echo $EKS_CLUSTER_NAME
aws sts get-caller-identity
kubectl config current-context
```

## Próximos Passos

1. **Integração com ArgoCD**: Deploy GitOps
2. **Testes de Integração**: Testcontainers
3. **Segurança**: Scanning de vulnerabilidades
4. **Performance**: Testes de carga com k6
5. **Chaos**: Litmus Chaos mais avançado

---

Esta abordagem mantém a simplicidade para desenvolvimento local enquanto oferece recursos enterprise para produção. A pipeline é escalável e pode ser estendida conforme necessário.