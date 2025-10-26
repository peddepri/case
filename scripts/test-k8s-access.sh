#!/bin/bash

echo " Testando acesso às aplicações no Kubernetes..."
echo ""

# Verificar se o cluster está rodando
if ! kind get clusters 2>/dev/null | grep -q "case-local"; then
    echo " Cluster KIND não encontrado"
    exit 1
fi

echo " Cluster KIND 'case-local' encontrado"

# Verificar pods
echo ""
echo " Status dos pods:"
kubectl get pods -n case

echo ""
echo " Para acessar as aplicações, você pode:"
echo ""
echo "1️  Via Docker Compose (mais simples):"
echo "   • Backend:  http://localhost:3001"
echo "   • Frontend: http://localhost:5174"
echo "   • Mobile:   http://localhost:19007"
echo ""
echo "2️  Via Kubernetes (usando port-forward):"
echo "   Execute os comandos abaixo em terminais separados:"
echo ""
echo "   # Backend"
echo "   kubectl port-forward -n case svc/backend 8081:3000"
echo "   # Depois acesse: http://localhost:8081"
echo ""
echo "   # Frontend"  
echo "   kubectl port-forward -n case svc/frontend 8082:80"
echo "   # Depois acesse: http://localhost:8082"
echo ""
echo "   # Mobile"
echo "   kubectl port-forward -n case svc/mobile 8083:19006"
echo "   # Depois acesse: http://localhost:8083"
echo ""
echo " Para sua apresentação, recomendo usar o Docker Compose (opção 1)"