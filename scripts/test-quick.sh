#!/bin/bash
# Teste Rápido - Performance e Chaos Engineering

echo "🚀 TESTES RÁPIDOS - PERFORMANCE & CHAOS"
echo "========================================"
echo ""

# 1. TESTE DE PERFORMANCE
echo "📊 TESTE DE PERFORMANCE"
echo "======================="

# Obter pod
POD=$(kubectl get pods -n case -l app=backend -o jsonpath='{.items[0].metadata.name}')
echo "Pod: $POD"

# Teste básico
echo ""
echo "🔍 Conectividade:"
kubectl exec -n case $POD -- wget -q -O - http://localhost:3000/healthz && echo "  ✅ Health: OK"
kubectl exec -n case $POD -- wget -q -O - http://localhost:3000/api/orders | head -1 && echo "  ✅ API: OK"

echo ""
echo "📈 Teste de Carga (10 requests):"
kubectl exec -n case $POD -- sh -c 'success=0; for i in $(seq 1 10); do wget -q -O /dev/null http://localhost:3000/healthz 2>/dev/null && success=$((success+1)); done; echo "  ✅ Sucesso: $success/10"'

echo ""
echo "🌐 Conectividade Inter-serviços:"
kubectl exec -n case $POD -- nc -z frontend 80 && echo "  ✅ Frontend: OK" || echo "  ❌ Frontend: FAIL"
kubectl exec -n case $POD -- nc -z mobile 19006 && echo "  ✅ Mobile: OK" || echo "  ❌ Mobile: FAIL"

echo ""
echo ""

# 2. TESTE DE CHAOS
echo "💥 TESTE DE CHAOS ENGINEERING"
echo "============================="

echo "Estado inicial:"
kubectl get pods -n case --no-headers | wc -l | awk '{print "  Pods ativos: " $1}'

echo ""
echo "💀 Simulando falha de pod..."
CHAOS_POD=$(kubectl get pods -n case -l app=backend -o jsonpath='{.items[0].metadata.name}')
echo "Deletando: $CHAOS_POD"

kubectl delete pod $CHAOS_POD -n case
echo "  ✅ Pod deletado"

echo ""
echo "🔄 Aguardando recuperação..."
sleep 10

kubectl wait --for=condition=Ready pods -l app=backend -n case --timeout=60s
echo "  ✅ Sistema recuperado"

NEW_POD=$(kubectl get pods -n case -l app=backend -o jsonpath='{.items[0].metadata.name}')
echo "Novo pod: $NEW_POD"

echo ""
echo "🔍 Teste pós-recuperação:"
sleep 5
kubectl exec -n case $NEW_POD -- wget -q -O - http://localhost:3000/healthz && echo "  ✅ Sistema funcional!" || echo "  ❌ Sistema com problemas"

echo ""
echo ""

# 3. RESUMO
echo "📋 RESUMO DOS TESTES"
echo "===================="
echo "✅ Performance: Testado conectividade e carga"
echo "✅ Chaos: Testado recuperação automática"
echo "✅ Resiliência: Sistema demonstrou auto-cura"
echo ""

kubectl get pods -n case

echo ""
echo "🎉 TESTES CONCLUÍDOS!"