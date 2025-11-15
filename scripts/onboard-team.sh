#!/usr/bin/env bash
# OpenTelemetry Platform Onboarding Script
# Automates setup of observability stack for new teams

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_DIR="${SCRIPT_DIR}/../domains/platform"
MANIFEST_TEMPLATE="${PLATFORM_DIR}/manifests/otel-collector-template.yaml"

# Functions
log_info() {
    echo -e "${BLUE}ℹ ${NC}$1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

usage() {
    cat <<EOF
OpenTelemetry Platform Onboarding

Usage: $0 [OPTIONS]

Options:
    --team TEAM_NAME            Team name (required)
    --namespace NAMESPACE       Kubernetes namespace (required)
    --cost-center CC            Cost center code (required)
    --business-unit BU          Business unit (required)
    --environment ENV           Environment (dev|staging|production) (required)
    --vendor VENDOR             Observability vendor (internal|dynatrace|newrelic) (default: internal)
    --cluster CLUSTER           Target cluster context (default: current)
    --dry-run                   Preview changes without applying
    -h, --help                  Show this help message

Example:
    $0 --team payments \\
       --namespace payments \\
       --cost-center CC-1234 \\
       --business-unit finance \\
       --environment production \\
       --vendor internal

EOF
    exit 0
}

validate_requirements() {
    log_info "Validating requirements..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    
    # Check yq
    if ! command -v yq &> /dev/null; then
        log_warning "yq not found. Some features may be limited."
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Check your kubeconfig."
        exit 1
    fi
    
    log_success "Requirements validated"
}

create_namespace() {
    local namespace=$1
    local team=$2
    local cost_center=$3
    local business_unit=$4
    local environment=$5
    
    log_info "Creating namespace: ${namespace}"
    
    if kubectl get namespace "${namespace}" &> /dev/null; then
        log_warning "Namespace ${namespace} already exists"
        return 0
    fi
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would create namespace: ${namespace}"
        return 0
    fi
    
    kubectl create namespace "${namespace}"
    
    # Label namespace for observability
    kubectl label namespace "${namespace}" \
        team="${team}" \
        cost_center="${cost_center}" \
        business_unit="${business_unit}" \
        environment="${environment}" \
        observability="enabled" \
        --overwrite
    
    log_success "Namespace created and labeled"
}

deploy_otel_collector() {
    local namespace=$1
    local team=$2
    local cost_center=$3
    local business_unit=$4
    local environment=$5
    
    log_info "Deploying OpenTelemetry Collector..."
    
    if [[ ! -f "${MANIFEST_TEMPLATE}" ]]; then
        log_error "Template not found: ${MANIFEST_TEMPLATE}"
        exit 1
    fi
    
    # Create temporary manifest with substitutions
    local temp_manifest=$(mktemp)
    
    sed -e "s/NAMESPACE_PLACEHOLDER/${namespace}/g" \
        -e "s/TEAM_PLACEHOLDER/${team}/g" \
        -e "s/COST_CENTER_PLACEHOLDER/${cost_center}/g" \
        -e "s/BUSINESS_UNIT_PLACEHOLDER/${business_unit}/g" \
        -e "s/ENVIRONMENT_PLACEHOLDER/${environment}/g" \
        "${MANIFEST_TEMPLATE}" > "${temp_manifest}"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would apply manifest:"
        cat "${temp_manifest}"
        rm -f "${temp_manifest}"
        return 0
    fi
    
    kubectl apply -f "${temp_manifest}"
    rm -f "${temp_manifest}"
    
    # Wait for deployment
    log_info "Waiting for collector to be ready..."
    kubectl wait --for=condition=available \
        --timeout=300s \
        deployment/otel-collector \
        -n "${namespace}" || {
        log_error "Collector deployment failed"
        exit 1
    }
    
    log_success "OpenTelemetry Collector deployed"
}

create_grafana_datasource() {
    local namespace=$1
    local team=$2
    
    log_info "Creating Grafana datasource..."
    
    local datasource_config=$(cat <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasource-${team}
  namespace: monitoring
  labels:
    grafana_datasource: "1"
    team: ${team}
data:
  ${team}-datasource.yaml: |
    apiVersion: 1
    datasources:
      - name: ${team} - Victoria Metrics
        type: prometheus
        access: proxy
        url: http://victoria-metrics-vmselect.monitoring.svc:8481/select/0/prometheus
        isDefault: false
        editable: false
        jsonData:
          timeInterval: 30s
          httpMethod: POST
        orgId: 1
EOF
)
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would create datasource config"
        return 0
    fi
    
    echo "${datasource_config}" | kubectl apply -f -
    
    log_success "Grafana datasource created"
}

create_default_dashboards() {
    local namespace=$1
    local team=$2
    
    log_info "Creating default dashboards..."
    
    # Create basic dashboard ConfigMap
    local dashboard_config=$(cat <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboard-${team}
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
    team: ${team}
data:
  ${team}-overview.json: |
    {
      "dashboard": {
        "title": "${team} - Service Overview",
        "tags": ["${team}", "overview"],
        "timezone": "browser",
        "panels": [
          {
            "title": "Request Rate",
            "type": "graph",
            "datasource": "${team} - Victoria Metrics",
            "targets": [
              {
                "expr": "sum(rate(http_requests_total{namespace=\"${namespace}\"}[5m]))"
              }
            ]
          },
          {
            "title": "Error Rate",
            "type": "graph",
            "datasource": "${team} - Victoria Metrics",
            "targets": [
              {
                "expr": "sum(rate(http_requests_total{namespace=\"${namespace}\",status=~\"5..\"}[5m]))"
              }
            ]
          },
          {
            "title": "Response Time (P95)",
            "type": "graph",
            "datasource": "${team} - Victoria Metrics",
            "targets": [
              {
                "expr": "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{namespace=\"${namespace}\"}[5m])) by (le))"
              }
            ]
          }
        ]
      }
    }
EOF
)
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would create dashboard config"
        return 0
    fi
    
    echo "${dashboard_config}" | kubectl apply -f -
    
    log_success "Default dashboards created"
}

create_service_monitor() {
    local namespace=$1
    local team=$2
    
    log_info "Creating ServiceMonitor for metrics collection..."
    
    local service_monitor=$(cat <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: ${team}-services
  namespace: ${namespace}
  labels:
    team: ${team}
spec:
  selector:
    matchLabels:
      team: ${team}
  endpoints:
    - port: metrics
      interval: 30s
      path: /metrics
EOF
)
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would create ServiceMonitor"
        return 0
    fi
    
    echo "${service_monitor}" | kubectl apply -f -
    
    log_success "ServiceMonitor created"
}

generate_onboarding_docs() {
    local namespace=$1
    local team=$2
    local vendor=$3
    
    log_info "Generating onboarding documentation..."
    
    local docs_file="${SCRIPT_DIR}/../docs/teams/${team}-onboarding.md"
    mkdir -p "$(dirname "${docs_file}")"
    
    cat > "${docs_file}" <<EOF
# Observability Onboarding: ${team}

## Overview
- **Team:** ${team}
- **Namespace:** ${namespace}
- **Vendor:** ${vendor}
- **Date:** $(date +%Y-%m-%d)

## Instrumentation

### Backend (Node.js/Express)
\`\`\`javascript
const { NodeTracerProvider } = require('@opentelemetry/sdk-trace-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');

const provider = new NodeTracerProvider({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: 'your-service-name',
    [SemanticResourceAttributes.SERVICE_VERSION]: '1.0.0',
    'team.name': '${team}',
    'environment': 'production'
  })
});

const exporter = new OTLPTraceExporter({
  url: 'http://otel-collector.${namespace}.svc:4317'
});

provider.addSpanProcessor(new BatchSpanProcessor(exporter));
provider.register({
  instrumentations: [getNodeAutoInstrumentations()]
});
\`\`\`

### Metrics Endpoint
Expose metrics on \`/metrics\` endpoint:

\`\`\`javascript
const { MeterProvider } = require('@opentelemetry/sdk-metrics');
const { PrometheusExporter } = require('@opentelemetry/exporter-prometheus');

const prometheusPort = 9464;
const exporter = new PrometheusExporter({ port: prometheusPort });
const meterProvider = new MeterProvider();
meterProvider.addMetricReader(exporter);
\`\`\`

### Logs
Use structured JSON logging:

\`\`\`javascript
const winston = require('winston');
const logger = winston.createLogger({
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  defaultMeta: {
    service: 'your-service-name',
    team: '${team}'
  },
  transports: [new winston.transports.Console()]
});
\`\`\`

## Deployment Configuration

Add these annotations to your pods:

\`\`\`yaml
metadata:
  labels:
    team: ${team}
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "9464"
    prometheus.io/path: "/metrics"
\`\`\`

## Accessing Dashboards

- **Grafana:** https://grafana.example.com/d/${team}-overview
- **Victoria Metrics:** Query endpoint via Grafana datasource

## Cost Tracking

Your team's observability costs are tracked and allocated to:
- **Cost Center:** ${COST_CENTER}
- **Business Unit:** ${BUSINESS_UNIT}

View costs: https://grafana.example.com/d/chargeback-team?var-team=${team}

## Support

- **Slack:** #platform-observability
- **Email:** platform-team@company.com
- **Runbook:** https://wiki.company.com/observability

## Next Steps

1. ✅ Namespace created
2. ✅ OTel Collector deployed
3. ✅ Grafana datasource configured
4. ⏳ Instrument your applications
5. ⏳ Deploy instrumented services
6. ⏳ Verify metrics/traces in Grafana
7. ⏳ Set up alerts

EOF
    
    log_success "Documentation generated: ${docs_file}"
}

print_summary() {
    local namespace=$1
    local team=$2
    local vendor=$3
    
    cat <<EOF

${GREEN}═══════════════════════════════════════════════════════════════${NC}
${GREEN}              Onboarding Complete!                             ${NC}
${GREEN}═══════════════════════════════════════════════════════════════${NC}

Team:              ${team}
Namespace:         ${namespace}
Vendor:            ${vendor}
OTel Collector:    otel-collector.${namespace}.svc:4317 (gRPC)
                   otel-collector.${namespace}.svc:4318 (HTTP)

Next Steps:
  1. Instrument your applications (see docs/teams/${team}-onboarding.md)
  2. Deploy with proper labels and annotations
  3. Access Grafana: kubectl port-forward -n monitoring svc/grafana 3000:80
  4. View your dashboards and metrics

Need Help?
  Slack: #platform-observability
  Docs:  https://wiki.company.com/observability

${GREEN}═══════════════════════════════════════════════════════════════${NC}

EOF
}

# Main script
main() {
    # Parse arguments
    TEAM=""
    NAMESPACE=""
    COST_CENTER=""
    BUSINESS_UNIT=""
    ENVIRONMENT=""
    VENDOR="internal"
    CLUSTER=""
    DRY_RUN="false"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --team)
                TEAM="$2"
                shift 2
                ;;
            --namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            --cost-center)
                COST_CENTER="$2"
                shift 2
                ;;
            --business-unit)
                BUSINESS_UNIT="$2"
                shift 2
                ;;
            --environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            --vendor)
                VENDOR="$2"
                shift 2
                ;;
            --cluster)
                CLUSTER="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    # Validate required arguments
    if [[ -z "${TEAM}" ]] || [[ -z "${NAMESPACE}" ]] || [[ -z "${COST_CENTER}" ]] || \
       [[ -z "${BUSINESS_UNIT}" ]] || [[ -z "${ENVIRONMENT}" ]]; then
        log_error "Missing required arguments"
        usage
    fi
    
    # Switch cluster context if specified
    if [[ -n "${CLUSTER}" ]]; then
        log_info "Switching to cluster context: ${CLUSTER}"
        kubectl config use-context "${CLUSTER}"
    fi
    
    log_info "Starting onboarding for team: ${TEAM}"
    
    # Execute onboarding steps
    validate_requirements
    create_namespace "${NAMESPACE}" "${TEAM}" "${COST_CENTER}" "${BUSINESS_UNIT}" "${ENVIRONMENT}"
    deploy_otel_collector "${NAMESPACE}" "${TEAM}" "${COST_CENTER}" "${BUSINESS_UNIT}" "${ENVIRONMENT}"
    create_grafana_datasource "${NAMESPACE}" "${TEAM}"
    create_default_dashboards "${NAMESPACE}" "${TEAM}"
    create_service_monitor "${NAMESPACE}" "${TEAM}"
    generate_onboarding_docs "${NAMESPACE}" "${TEAM}" "${VENDOR}"
    
    if [[ "${DRY_RUN}" == "false" ]]; then
        print_summary "${NAMESPACE}" "${TEAM}" "${VENDOR}"
    else
        log_info "[DRY-RUN] Onboarding preview completed"
    fi
}

main "$@"
