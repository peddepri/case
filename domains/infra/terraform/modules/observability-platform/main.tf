# Observability Platform Module - Unified OpenTelemetry Stack

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

# Variables
variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "enable_victoria_metrics" {
  description = "Enable Victoria Metrics cluster"
  type        = bool
  default     = true
}

variable "enable_otel_gateway" {
  description = "Enable centralized OTel Gateway"
  type        = bool
  default     = true
}

variable "enable_long_term_storage" {
  description = "Enable S3 long-term storage for logs/metrics/traces"
  type        = bool
  default     = true
}

variable "enable_chargeback" {
  description = "Enable cost tracking and chargeback"
  type        = bool
  default     = true
}

variable "retention_days_hot" {
  description = "Hot storage retention days"
  type        = number
  default     = 7
}

variable "retention_days_warm" {
  description = "Warm storage retention days"
  type        = number
  default     = 90
}

variable "retention_years_cold" {
  description = "Cold storage retention years"
  type        = number
  default     = 10
}

variable "dynatrace_endpoint" {
  description = "Dynatrace tenant endpoint"
  type        = string
  default     = ""
  sensitive   = true
}

variable "dynatrace_token" {
  description = "Dynatrace API token"
  type        = string
  default     = ""
  sensitive   = true
}

variable "newrelic_endpoint" {
  description = "NewRelic OTLP endpoint"
  type        = string
  default     = ""
  sensitive   = true
}

variable "newrelic_license_key" {
  description = "NewRelic license key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}

# Locals
locals {
  namespace_observability = "observability"
  namespace_monitoring    = "monitoring"

  common_labels = {
    platform    = "observability"
    managed_by  = "terraform"
    environment = var.cluster_name
  }
}

# Namespaces
resource "kubernetes_namespace" "observability" {
  metadata {
    name = local.namespace_observability

    labels = merge(local.common_labels, {
      name = local.namespace_observability
    })

    annotations = {
      "prometheus.io/scrape" = "true"
    }
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = local.namespace_monitoring

    labels = merge(local.common_labels, {
      name = local.namespace_monitoring
    })
  }
}

# S3 Buckets for Long-Term Storage
resource "aws_s3_bucket" "logs_archive" {
  count  = var.enable_long_term_storage ? 1 : 0
  bucket = "${var.cluster_name}-logs-archive"

  tags = merge(var.tags, {
    Name    = "${var.cluster_name}-logs-archive"
    Purpose = "Long-term log retention for compliance"
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "logs_archive" {
  count  = var.enable_long_term_storage ? 1 : 0
  bucket = aws_s3_bucket.logs_archive[0].id

  rule {
    id     = "archive-lifecycle"
    status = "Enabled"

    filter {}

    transition {
      days          = var.retention_days_warm
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    transition {
      days          = 730
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = var.retention_years_cold * 365
    }
  }
}

resource "aws_s3_bucket" "metrics_archive" {
  count  = var.enable_long_term_storage ? 1 : 0
  bucket = "${var.cluster_name}-metrics-archive"

  tags = merge(var.tags, {
    Name    = "${var.cluster_name}-metrics-archive"
    Purpose = "Long-term metrics retention"
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "metrics_archive" {
  count  = var.enable_long_term_storage ? 1 : 0
  bucket = aws_s3_bucket.metrics_archive[0].id

  rule {
    id     = "archive-lifecycle"
    status = "Enabled"

    filter {}

    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    expiration {
      days = var.retention_years_cold * 365
    }
  }
}

resource "aws_s3_bucket" "traces_archive" {
  count  = var.enable_long_term_storage ? 1 : 0
  bucket = "${var.cluster_name}-traces-archive"

  tags = merge(var.tags, {
    Name    = "${var.cluster_name}-traces-archive"
    Purpose = "Long-term trace retention"
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "traces_archive" {
  count  = var.enable_long_term_storage ? 1 : 0
  bucket = aws_s3_bucket.traces_archive[0].id

  rule {
    id     = "archive-lifecycle"
    status = "Enabled"

    filter {}

    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    expiration {
      days = var.retention_years_cold * 365
    }
  }
}

# S3 Bucket Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "logs_archive" {
  count  = var.enable_long_term_storage ? 1 : 0
  bucket = aws_s3_bucket.logs_archive[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "metrics_archive" {
  count  = var.enable_long_term_storage ? 1 : 0
  bucket = aws_s3_bucket.metrics_archive[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "traces_archive" {
  count  = var.enable_long_term_storage ? 1 : 0
  bucket = aws_s3_bucket.traces_archive[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# IAM Role for OTel Collector (IRSA)
resource "aws_iam_role" "otel_collector" {
  name = "${var.cluster_name}-otel-collector"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}"
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:${local.namespace_observability}:otel-collector"
          "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "otel_collector_s3" {
  count = var.enable_long_term_storage ? 1 : 0
  name  = "s3-access"
  role  = aws_iam_role.otel_collector.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.logs_archive[0].arn,
          "${aws_s3_bucket.logs_archive[0].arn}/*",
          aws_s3_bucket.metrics_archive[0].arn,
          "${aws_s3_bucket.metrics_archive[0].arn}/*",
          aws_s3_bucket.traces_archive[0].arn,
          "${aws_s3_bucket.traces_archive[0].arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "otel_collector_cloudwatch" {
  name = "cloudwatch-access"
  role = aws_iam_role.otel_collector.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# Kubernetes Service Account
resource "kubernetes_service_account" "otel_collector" {
  metadata {
    name      = "otel-collector"
    namespace = kubernetes_namespace.observability.metadata[0].name

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.otel_collector.arn
    }

    labels = local.common_labels
  }
}

# Victoria Metrics Cluster
resource "helm_release" "victoria_metrics" {
  count = var.enable_victoria_metrics ? 1 : 0

  name       = "victoria-metrics"
  repository = "https://victoriametrics.github.io/helm-charts"
  chart      = "victoria-metrics-cluster"
  version    = "0.11.0"
  namespace  = local.namespace_monitoring

  values = [
    templatefile("${path.module}/templates/victoria-metrics-values.yaml", {
      retention_period = "${var.retention_days_hot}d"
      storage_size     = "100Gi"
      replicas         = 3
    })
  ]

  depends_on = [kubernetes_namespace.monitoring]
}

# OpenTelemetry Gateway
resource "helm_release" "otel_gateway" {
  count = var.enable_otel_gateway ? 1 : 0

  name       = "otel-gateway"
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-collector"
  version    = "0.74.0"
  namespace  = local.namespace_observability

  values = [
    templatefile("${path.module}/templates/otel-gateway-values.yaml", {
      service_account      = kubernetes_service_account.otel_collector.metadata[0].name
      dynatrace_endpoint   = var.dynatrace_endpoint
      dynatrace_token      = var.dynatrace_token
      newrelic_endpoint    = var.newrelic_endpoint
      newrelic_license_key = var.newrelic_license_key
      victoria_metrics_url = var.enable_victoria_metrics ? "http://victoria-metrics-vminsert.${local.namespace_monitoring}.svc:8480/insert" : ""
      s3_logs_bucket       = var.enable_long_term_storage ? aws_s3_bucket.logs_archive[0].id : ""
      s3_metrics_bucket    = var.enable_long_term_storage ? aws_s3_bucket.metrics_archive[0].id : ""
      s3_traces_bucket     = var.enable_long_term_storage ? aws_s3_bucket.traces_archive[0].id : ""
      region               = var.region
    })
  ]

  depends_on = [
    kubernetes_namespace.observability,
    kubernetes_service_account.otel_collector
  ]
}

# Grafana for Visualization
resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  version    = "7.0.0"
  namespace  = local.namespace_monitoring

  values = [
    templatefile("${path.module}/templates/grafana-values.yaml", {
      victoria_metrics_url = var.enable_victoria_metrics ? "http://victoria-metrics-vmselect.${local.namespace_monitoring}.svc:8481/select/0/prometheus" : ""
      admin_password       = random_password.grafana_admin.result
    })
  ]

  depends_on = [
    kubernetes_namespace.monitoring,
    helm_release.victoria_metrics
  ]
}

resource "random_password" "grafana_admin" {
  length  = 16
  special = true
}

# Chargeback ConfigMap
resource "kubernetes_config_map" "chargeback_config" {
  count = var.enable_chargeback ? 1 : 0

  metadata {
    name      = "chargeback-config"
    namespace = local.namespace_observability
    labels    = local.common_labels
  }

  data = {
    "chargeback.yaml" = file("${path.module}/config/chargeback-config.yaml")
  }
}

# Data sources
data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

# Outputs
output "victoria_metrics_url" {
  description = "Victoria Metrics query URL"
  value       = var.enable_victoria_metrics ? "http://victoria-metrics-vmselect.${local.namespace_monitoring}.svc:8481/select/0/prometheus" : ""
}

output "otel_gateway_endpoint" {
  description = "OTel Gateway OTLP endpoint"
  value       = var.enable_otel_gateway ? "otel-gateway-opentelemetry-collector.${local.namespace_observability}.svc:4317" : ""
}

output "grafana_admin_password" {
  description = "Grafana admin password"
  value       = random_password.grafana_admin.result
  sensitive   = true
}

output "s3_buckets" {
  description = "S3 buckets for long-term storage"
  value = var.enable_long_term_storage ? {
    logs    = aws_s3_bucket.logs_archive[0].id
    metrics = aws_s3_bucket.metrics_archive[0].id
    traces  = aws_s3_bucket.traces_archive[0].id
  } : {}
}

output "otel_collector_role_arn" {
  description = "IAM role ARN for OTel Collector"
  value       = aws_iam_role.otel_collector.arn
}
