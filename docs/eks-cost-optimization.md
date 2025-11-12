# EKS Fargate – Low-cost, consolidated setup (dev)

This repo is set up to run a single EKS cluster in a low-cost region (default: `us-east-1`) with:

- Fargate-only compute and three granular Fargate Profiles (backend, frontend, mobile) using label selectors
- One public ALB managed by AWS Load Balancer Controller with path-based routing
- Aggressive right-sizing at the minimal Fargate tier (0.25 vCPU / 0.5 GB)
- HPA with faster scale-down to reduce idle spend
- Optional ADOT Collector sending minimal metrics to CloudWatch Container Insights (no logs by default)

## What changed

- Terraform
  - Separate Fargate Profiles for `app=backend|frontend|mobile` to isolate policies/cost tracking
  - AWS Load Balancer Controller installed via Helm + IRSA (single shared ALB)
  - IRSA + ServiceAccount for ADOT Collector in namespace `observability`
- Kubernetes Manifests
  - Ingress switched to `alb` with `target-type: ip` (required for Fargate) and group to consolidate under one ALB
  - Deployments set requests/limits to 0.25 vCPU and 512Mi memory; replicas=1 (HPA scales up)
  - HPAs updated with more aggressive scale-down
  - ADOT collector deployment added (`domains/platform/manifests/adot-collector.yaml`)

## How to apply

1) Build/push images to ECR in the same region as the cluster

```bash
./push-to-ecr.ps1  # default region: us-east-1
```

2) Provision infra

```bash
./terraform-deploy.sh domains/infra/terraform/environments/dev
```

This will create VPC, EKS (Fargate), IRSA roles, AWS Load Balancer Controller, and ADOT IRSA/SA.

3) Sync app manifests through Argo CD as usual (or `kubectl apply -f domains/platform/manifests/` if testing locally).

## Optional: scale-to-zero after hours

For true off-hours savings (dev/stage), use KEDA’s Scheduled Scaler (requires installing KEDA operator) to set replicas=0 at night/weekends and restore in daytime.

Example ScaledObject (not applied by default):

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: frontend-schedule
  namespace: case
spec:
  scaleTargetRef:
    kind: Deployment
    name: frontend
  minReplicaCount: 0
  maxReplicaCount: 5
  triggers:
  - type: cron
    metadata:
      timezone: "America/New_York"
      start: "0 8 * * 1-5"   # scale up at 08:00 Mon–Fri
      end:   "0 20 * * 1-5"  # scale down at 20:00 Mon–Fri
      desiredReplicas: "1"
```

Install KEDA (optional):

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm upgrade --install keda kedacore/keda -n keda --create-namespace
```

## Datadog vs CloudWatch

- CloudWatch (ADOT): minimal metrics for Container Insights with low infra overhead. Keep log retention short if you enable logs.
- Datadog (optional): chart available in Terraform module. For Fargate, prefer kubelet-native log shipping to cut intermediaries.

## ALB consolidation

- One ALB handles `/api`, `/mobile`, and `/` paths. The first year ELB Free Tier (750 hrs + 15 LCUs) often covers a low-traffic dev setup.

## Next steps

- Put CloudFront in front of the frontend for egress/LCU savings.
- Consider Savings Plans for steady, long-lived prod traffic.
- For bursty async jobs, consider Fargate Spot or a small EC2 Spot NodeGroup for non-critical workloads.
