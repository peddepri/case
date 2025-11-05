#!/bin/bash
# Cleanup do ambiente LocalStack EKS

cd "$(dirname "$0")/.."

echo "🧹 Limpando ambiente LocalStack EKS..."
echo ""

CLUSTER_NAME="case-eks-local"

# Deletar recursos Kubernetes
if [ -f "localstack-kubeconfig/config" ]; then
    export KUBECONFIG=$(pwd)/localstack-kubeconfig/config
    
    echo "1. Deletando recursos Kubernetes..."
    kubectl delete namespace case --ignore-not-found=true --timeout=30s
    
    # Deletar cluster EKS
    echo "2. Deletando cluster EKS..."
    bash scripts/awslocal.sh eks delete-cluster --name "$CLUSTER_NAME" 2>/dev/null || true
    
    # Limpar kubeconfig
    echo "3. Removendo kubeconfig..."
    rm -rf localstack-kubeconfig/
fi

# Parar LocalStack
echo "4. Parando LocalStack..."
docker compose -f docker-compose.localstack.yml down -v

# Limpar dados persistidos (opcional)
read -p "Deseja limpar dados persistidos do LocalStack? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "5. Limpando dados persistidos..."
    rm -rf localstack-data/*
fi

echo ""
echo " Ambiente limpo!"
echo ""
echo "Para reiniciar: bash scripts/localstack-eks-trial.sh"
