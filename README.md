# Case: Plataforma AWS EKS Fargate (Estrutura Organizada)

Projeto simplificado para execução de backend, frontend e mobile em um único cluster EKS Fargate, com Helm consolidado, ALB único, detecção de drift e observabilidade mínima opcional.

## Componentes Atuais
- Infraestrutura: Terraform (VPC, EKS Fargate, perfis Fargate por tipo, IRSA, ALB Controller)
- Deploy: Argo CD + Helm chart único (`domains/platform/helm`)
- Aplicações: Backend / Frontend / Mobile (`domains/apps/app/`)
- Observabilidade: ADOT Collector opcional (CloudWatch Container Insights) – Datadog/Grafana podem ser adicionados depois
- Ingress: ALB único com roteamento por caminho
- Persistência: DynamoDB (tabela `orders` PAY_PER_REQUEST)
- CI/CD: GitHub Actions (build/push, workflow refresh-only para detectar drift)

## Pré-requisitos
- Docker
- Conta AWS (VPC, EKS, ECR, IAM OIDC, DynamoDB)
- Terraform >= 1.8

## Início rápido
Build e push das imagens (ECR na mesma região do cluster):
```bash
./build-and-push-images.sh
```
Provisionar infra (exemplo dev):
```bash
./terraform-deploy.sh domains/infra/terraform/environments/dev
```
Aplicar via Argo CD (root app sincroniza) ou manual para testar:
```bash
helm template case-platform domains/platform/helm -f domains/platform/helm/values-dev.yaml | kubectl apply -n case -f -
```

## Estrutura
- `domains/infra/terraform/` – módulos e ambientes
- `domains/platform/helm/` – chart (deployments, services, ingress, HPA, ADOT)
- `domains/platform/argo/` – definições Argo (root + apps limpas)
- `domains/apps/app/` – código das aplicações
- `.github/workflows/` – pipelines (inclui terraform-refresh-only)
- `docs/` – documentação técnica

## Fluxo
1. Terraform provisiona cluster e perfis Fargate.
2. Argo CD aplica Helm chart por ambiente.
3. GitHub Actions detecta drift (`terraform plan -refresh-only`).
4. Ajustes de custo: um ALB, perfis Fargate separados, requests mínimos.

## Custos
- Cluster único (reduz taxa por cluster EKS)
- ALB consolidado (economia de LCU/hora)
- Perfis Fargate por tipo (monitoramento separado e rightsizing)
- Requests alinhadas ao tier mínimo (0.25 vCPU / 0.5 GB)

## Limitações
- Fargate não suporta DaemonSets (coleta via sidecar ou agentless)
- Ajuste de memória/CPU exige observação para não saltar de tier

## Evoluções Futuras (Sugestões)
- KEDA para scale-to-zero
- Grafana/Prometheus ou Datadog completos
- Service Mesh (App Mesh/Istio)
- Policies (OPA/Kyverno) e supply chain (Cosign, Trivy)

## Docker Local
Usado apenas para desenvolvimento e testes rápidos; produção utiliza EKS Fargate.

## Testes
- Backend: Jest
- Frontend: Vitest
- Mobile: testes básicos (opcional)

## Provisionar Infra (Exemplo)
```bash
./terraform-deploy.sh domains/infra/terraform/environments/dev
```

Variáveis importantes (veja `infra/terraform/variables.tf`):
- `region`, `project_name`, `eks_cluster_name`
- `dd_api_key`, `dd_site` (para Datadog Cluster Agent e APM agentless)
- `dynamodb_table_name` (padrão `orders`)

Recursos criados:
- VPC (2 AZs, subnets públicas/privadas, 1 NAT)
- EKS (Fargate profiles para namespace `case` e CoreDNS)
- OIDC provider (IRSA)
- ECR repos: `backend`, `frontend`
- Tabela DynamoDB `orders` (PAY_PER_REQUEST)
- IAM Role para ServiceAccount `backend-sa` com acesso mínimo (IRSA)
- Datadog Cluster Agent via Helm (sem node agents no Fargate)

## Deploy
Argo CD sincroniza chart Helm; GitHub Actions entrega imagens ao ECR.

## Observabilidade
ADOT opcional via Helm; exporta métricas para CloudWatch. Outros backends podem ser adicionados.

Dashboards inclusos:
- `observabilidade/datadog/dashboards/golden_signals_backend.json`
- `observabilidade/datadog/dashboards/business_metrics.json`

Criação via API (scripts prontos):

```bash
DD_API_KEY=<key> DD_APP_KEY=<appkey> DD_SITE=datadoghq.com ./scripts/datadog-apply-dashboards.sh
DD_API_KEY=<key> DD_APP_KEY=<appkey> DD_SITE=datadoghq.com ./scripts/datadog-apply-monitors.sh
```

## Testes de Carga e Caos (Removidos)
Manifests e scripts legados de carga/caos foram removidos; reintroduzir apenas se necessário.

## AppDynamics
Integração opcional via variáveis de ambiente (não habilitada por padrão).

## Ferramentas
Scripts auxiliares podem ser adaptados para execução dentro de contêiner; mantenha minimalistas.

## Checklist
- [ ] Terraform apply ok
- [ ] Imagens publicadas no ECR
- [ ] Argo CD sincroniza Helm chart
- [ ] Ingress ALB ativo
- [ ] Métricas básicas no CloudWatch (se ADOT habilitado)

## Segurança e FinOps
- IRSA para acesso mínimo DynamoDB
- Subnets privadas + NAT único
- ECR scan-on-push
- Rightsizing + HPA para evitar desperdício

## Datadog (Opcional)
Adicionar via Helm ou Terraform módulo futuro; não habilitado por padrão.

## Troubleshooting
- Verificar IAM Role OIDC
- Confirmar perfis Fargate criados
- Checar ALB Controller pods saudáveis

## Manutenção
Conteúdo legado removido para refletir estado atual. Expandir conforme evolução.
- Backups/exports: enable PITR or scheduled exports if needed

FinOps
- Fargate removes node management and reduces idle costs; use right-sized requests/limits
- HPA manifests provided (CPU 70%) – scale to zero out-of-hours by automation if permissible
- Terraform tags (`local.tags`) applied across resources for cost allocation
- NAT gateway is a fixed cost – consider VPC endpoints for Datadog intake to reduce egress (advanced)

## Como usar o teste do Datadog

1. **Inscreva-se** para um teste gratuito em [datadoghq.com](https://www.datadoghq.com) e copie sua chave de API.  
2. **Defina o segredo do repositório** `DD_API_KEY`.  
3. **Defina a variável do repositório** `DD_SITE` (por exemplo, `datadoghq.com` ou `datadoghq.eu`).  
4. **Mescle com o repositório principal** para acionar o **CI/CD** e visualizar:
   - Rastreamentos de **APM**
   - **Telemetria** do cluster
   - **Painéis** do Datadog

---

### Solução de problemas

- Certifique-se de que o **Docker** tenha recursos suficientes (CPU/RAM).  
- Se os dados do **Datadog** não forem exibidos:
  - Confirme as variáveis `DD_API_KEY` e `DD_SITE`.  
  - Verifique os **logs do Agente Datadog**.  
- Verifique os **eventos do Kubernetes** e **logs dos pods** para identificar problemas de permissões ou falhas no pull de imagens.
