#!/bin/bash
# Quick check antes de iniciar gravação
# Uso: ./quick-pre-recording-check.sh

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${PURPLE}🎬 ======================================${NC}"
echo -e "${PURPLE}🎬   QUICK CHECK PRÉ-GRAVAÇÃO${NC}"
echo -e "${PURPLE}🎬 ======================================${NC}"
echo ""

# 1. URLs Principais - Verificação Rápida
echo -e "${BLUE}📊 1. DASHBOARDS PRINCIPAIS${NC}"
echo "   • Grafana Login: http://localhost:3100 (admin/admin)"
if curl -s http://localhost:3100/api/health | grep -q ok; then
    echo -e "     ✅ Grafana respondendo"
else
    echo -e "     ❌ Grafana não responde"
fi

echo "   • Golden Signals: http://localhost:3100/d/golden-signals"
echo "   • Frontend: http://localhost:3100/d/frontend-golden-signals"  
echo "   • Mobile: http://localhost:3100/d/mobile-golden-signals"
echo "   • Business: http://localhost:3100/d/business-metrics"
echo ""

# 2. Aplicações
echo -e "${BLUE}🚀 2. APLICAÇÕES${NC}"
for app in "Backend:3002" "Frontend:3003" "Mobile:3004"; do
    name=$(echo $app | cut -d: -f1)
    port=$(echo $app | cut -d: -f2)
    if curl -s http://localhost:$port/ > /dev/null 2>&1; then
        echo -e "   ✅ $name: http://localhost:$port"
    else
        echo -e "   ❌ $name: http://localhost:$port (não responde)"
    fi
done
echo ""

# 3. Métricas
echo -e "${BLUE}📈 3. MÉTRICAS${NC}"
if command -v jq >/dev/null 2>&1; then
    TARGETS_UP=$(curl -s http://localhost:9090/api/v1/targets 2>/dev/null | jq -r '.data.activeTargets[] | select(.health=="up") | .scrapePool' 2>/dev/null | wc -l)
    echo -e "   📊 Prometheus Targets UP: $TARGETS_UP"
    
    if [[ "$TARGETS_UP" -ge 3 ]]; then
        echo -e "   ✅ Métricas sendo coletadas"
    else
        echo -e "   ⚠️  Poucos targets ativos ($TARGETS_UP)"
    fi
else
    echo -e "   ⚠️  jq não encontrado - verificação limitada"
fi

# Testar endpoints de métricas
for endpoint in "3002:Backend" "3003:Frontend" "3004:Mobile"; do
    port=$(echo $endpoint | cut -d: -f1)
    name=$(echo $endpoint | cut -d: -f2)
    if curl -s http://localhost:$port/metrics | head -1 | grep -q "#"; then
        echo -e "   ✅ $name metrics: http://localhost:$port/metrics"
    else
        echo -e "   ⚠️  $name metrics: pode estar com problema"
    fi
done
echo ""

# 4. Port-forwards ativos
echo -e "${BLUE}🔗 4. PORT-FORWARDS${NC}"
PF_COUNT=$(ps aux 2>/dev/null | grep -c "port-forward" 2>/dev/null || echo "0")
if [[ "$PF_COUNT" -gt 0 ]]; then
    echo -e "   ✅ Port-forwards ativos: $PF_COUNT"
else
    echo -e "   ❌ Nenhum port-forward ativo"
    echo -e "   💡 Execute: ./scripts/port-forward-metrics.sh &"
fi
echo ""

# 5. Tráfego para demo
echo -e "${BLUE}🚦 5. COMANDOS PARA GRAVAÇÃO${NC}"
echo ""
echo -e "${YELLOW}📈 Para iniciar tráfego durante gravação:${NC}"
echo "   ./generate-demo-traffic.sh 20 &"
echo ""
echo -e "${YELLOW}🔍 URLs para mostrar na tela:${NC}"
echo "   • Grafana: http://localhost:3100"
echo "   • Prometheus: http://localhost:9090"
echo "   • Backend API: http://localhost:3002"
echo ""

# 6. Status final
echo -e "${PURPLE}🏁 ======================================${NC}"
echo ""

# Verificar se está pronto
READY=true

# Check essenciais
if ! curl -s http://localhost:3100/api/health > /dev/null; then
    READY=false
    echo -e "${RED}❌ Grafana não acessível${NC}"
fi

if ! curl -s http://localhost:9090/-/healthy > /dev/null; then
    READY=false
    echo -e "${RED}❌ Prometheus não acessível${NC}"
fi

if ! curl -s http://localhost:3002/healthz > /dev/null; then
    READY=false
    echo -e "${RED}❌ Backend não acessível${NC}"
fi

if [[ "$READY" == "true" ]]; then
    echo -e "${GREEN}🎉 AMBIENTE PRONTO PARA GRAVAÇÃO!${NC}"
    echo ""
    echo -e "${BLUE}🎬 Próximos passos:${NC}"
    echo "   1. Execute: ./generate-demo-traffic.sh 20 &"
    echo "   2. Abra Grafana: http://localhost:3100"
    echo "   3. Inicie gravação!"
    echo ""
    echo -e "${GREEN}⏰ Tempo estimado de gravação: 15-25 minutos${NC}"
else
    echo -e "${RED}⚠️  AMBIENTE NÃO ESTÁ PRONTO${NC}"
    echo ""
    echo -e "${BLUE}🔧 Para corrigir, execute:${NC}"
    echo "   ./setup-demo-environment.sh"
    echo ""
fi

echo -e "${PURPLE}🏁 ======================================${NC}"