#!/bin/bash
echo " Iniciando port-forwards para acesso local..."
echo ""

# Função para matar port-forwards anteriores
cleanup() {
    echo " Parando port-forwards anteriores..."
    pkill -f "kubectl.*port-forward.*case" 2>/dev/null || true
    sleep 2
}

# Cleanup inicial
cleanup

# Trap para cleanup no exit
trap cleanup EXIT

echo " Configurando acessos:"
echo "   • Backend:  http://localhost:8081"
echo "   • Frontend: http://localhost:8082"  
echo "   • Mobile:   http://localhost:8083"
echo ""

# Port-forwards em background
kubectl port-forward -n case svc/backend 8081:3000 > /dev/null 2>&1 &
kubectl port-forward -n case svc/frontend 8082:80 > /dev/null 2>&1 &
kubectl port-forward -n case svc/mobile 8083:19006 > /dev/null 2>&1 &

echo " Port-forwards configurados!"
echo ""
echo " Acesse as aplicações em:"
echo "   • Backend:  http://localhost:8081"
echo "   • Frontend: http://localhost:8082"
echo "   • Mobile:   http://localhost:8083"
echo "   • API:      http://localhost:8081/api/orders"
echo ""
echo "  Pressione Ctrl+C para parar todos os port-forwards"

# Aguardar sinal para parar
wait
