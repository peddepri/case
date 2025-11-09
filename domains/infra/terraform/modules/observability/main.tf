# Observability Module - Terraform Only (No Helm/Argo Drift)

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "enable_datadog" {
  description = "Enable Datadog monitoring"
  type        = bool
  default     = false
}

variable "datadog_api_key" {
  description = "Datadog API key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "datadog_site" {
  description = "Datadog site (datadoghq.com, datadoghq.eu, etc.)"
  type        = string
  default     = "datadoghq.com"
}

variable "enable_grafana_stack" {
  description = "Enable Grafana stack (Prometheus, Loki, Tempo)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Datadog Agent via Helm (Optional)
resource "helm_release" "datadog_agent" {
  count = var.enable_datadog ? 1 : 0

  name       = "datadog-agent"
  repository = "https://helm.datadoghq.com"
  chart      = "datadog"
  version    = "3.40.0"
  namespace  = "datadog"
  create_namespace = true

  values = [
    templatefile("${path.module}/templates/datadog-values.yaml", {
      datadog_api_key = var.datadog_api_key
      datadog_site    = var.datadog_site
      cluster_name    = var.cluster_name
    })
  ]

  depends_on = [kubernetes_namespace.datadog]
}

resource "kubernetes_namespace" "datadog" {
  count = var.enable_datadog ? 1 : 0

  metadata {
    name = "datadog"
    labels = {
      name = "datadog"
    }
  }
}

# Grafana Stack (Optional)
resource "helm_release" "grafana_stack" {
  count = var.enable_grafana_stack ? 1 : 0

  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "55.0.0"
  namespace  = "monitoring"
  create_namespace = true

  values = [
    file("${path.module}/templates/grafana-values.yaml")
  ]

  depends_on = [kubernetes_namespace.monitoring]
}

resource "kubernetes_namespace" "monitoring" {
  count = var.enable_grafana_stack ? 1 : 0
  
  metadata {
    name = "monitoring"
    labels = {
      name = "monitoring"
    }
  }
}

# Loki for Logs (Optional)
resource "helm_release" "loki" {
  count = var.enable_grafana_stack ? 1 : 0

  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = "5.42.0"
  namespace  = "monitoring"

  values = [
    file("${path.module}/templates/loki-values.yaml")
  ]

  depends_on = [helm_release.grafana_stack]
}

# Tempo for Traces (Optional)
resource "helm_release" "tempo" {
  count = var.enable_grafana_stack ? 1 : 0

  name       = "tempo"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "tempo"
  version    = "1.7.0"
  namespace  = "monitoring"

  values = [
    file("${path.module}/templates/tempo-values.yaml")
  ]

  depends_on = [helm_release.grafana_stack]
}