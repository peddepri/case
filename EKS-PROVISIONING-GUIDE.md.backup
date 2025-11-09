# Provisionamento da Infraestrutura EKS com Fargate

## Status Atual

**AWS CLI:** Configurado  
**Credentials:** Válidas (Account: 918859180133, User: ppedde)  
**Terraform:** Inicializado  
**Região:** us-east-2  

## Infraestrutura que será criada

### Recursos Principais:
- **EKS Cluster** (`case-cluster`) com Kubernetes 1.30
- **Fargate Profiles** para namespaces `case` e `kube-system`
- **VPC** com subnets públicas e privadas (10.0.0.0/16)
- **ECR Repositories** para backend e frontend
- **DynamoDB** table `orders` (pay-per-request)
- **IAM Roles** para IRSA (Service Account permissions)
- **Datadog** monitoring via Helm

### Detalhes da Arquitetura:
```
┌─────────────────────────────────────────┐
│               AWS Account               │
│            918859180133                 │
├─────────────────────────────────────────┤
│  Region: us-east-2                     │
│                                         │
│  ┌─────────────────────────────────────┐│
│  │ VPC: case (10.0.0.0/16)            ││
│  │                                     ││
│  │ Public Subnets:                     ││
│  │ • 10.0.101.0/24 (us-east-2a)       ││
│  │ • 10.0.102.0/24 (us-east-2b)       ││
│  │                                     ││
│  │ Private Subnets:                    ││
│  │ • 10.0.1.0/24 (us-east-2a)         ││
│  │ • 10.0.2.0/24 (us-east-2b)         ││
│  │                                     ││
│  │ ┌─────────────────────────────────┐ ││
│  │ │ EKS Cluster: case-cluster       │ ││
│  │ │                                 │ ││
│  │ │ Fargate Profiles:               │ ││
│  │ │ • case (namespace: case)        │ ││
│  │ │ • kube-system (CoreDNS)         │ ││
│  │ └─────────────────────────────────┘ ││
│  └─────────────────────────────────────┘│
│                                         │
│  ECR Repositories:                      │
│  • backend                             │
│  • frontend                            │
│                                         │
│  DynamoDB:                             │
│  • orders table                        │
└─────────────────────────────────────────┘
```

## Custos Estimados

| Recurso | Custo Mensal (USD) |
|---------|-------------------|
| EKS Cluster | $72.00 |
| Fargate vCPU/Memory | $15-30 |
| NAT Gateway | $32.40 |
| DynamoDB | $0-5 (pay-per-request) |
| **Total** | **~$120-140/mês** |

## Como Provisionar

### 1. Executar o script de preparação:
```bash
chmod +x provision-eks.sh
./provision-eks.sh
```

### 2. Revisar o plano e aplicar:
```bash
cd infra/terraform
terraform apply eks-deploy.tfplan
```

### 3. Configurar kubectl:
```bash
aws eks update-kubeconfig --name case-cluster --region us-east-2
```

### 4. Verificar cluster:
```bash
kubectl get nodes
kubectl get namespaces
```

## Considerações Importantes

1. **Custos:** Os recursos criarão custos na AWS (~$120-140/mês)
2. **Tempo:** Provisionamento leva ~15-20 minutos
3. **Datadog:** Requer chave API válida (atualmente usando dummy key)
4. **Fargate:** Pods executam serverless (sem EC2 nodes)
5. **Networking:** VPC com NAT Gateway para conectividade

## Comandos Úteis

```bash
# Verificar status do cluster
aws eks describe-cluster --name case-cluster --region us-east-2

# Listar Fargate profiles
aws eks describe-fargate-profile --cluster-name case-cluster --fargate-profile-name case --region us-east-2

# Ver logs do Terraform
terraform show

# Destruir infraestrutura (se necessário)
terraform destroy
```

## Próximos Passos Após Provisionamento

1. Configurar kubectl
2. Deploy das aplicações via CI/CD pipeline
3. Configurar Datadog com chave real
4. Configurar DNS/Ingress se necessário
5. Configurar backup policies