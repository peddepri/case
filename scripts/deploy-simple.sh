#!/bin/bash
# Simple deployment script for CI/CD pipeline
set -euo pipefail

echo "Starting simple deployment..."

# Create namespace first
echo "Creating namespace..."
kubectl apply -f k8s/namespace.yaml

# Create config and secrets
echo "Creating configs and secrets..."
kubectl create configmap env-config -n case \
  --from-literal=DDB_TABLE=orders \
  --from-literal=AWS_REGION=us-east-1 \
  --from-literal=DD_SITE=us1.datadoghq.com \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic datadog -n case \
  --from-literal=api-key=dummy-key \
  --dry-run=client -o yaml | kubectl apply -f -

# Apply core resources (backend and mobile only for speed)
echo "Applying deployments..."
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/backend-serviceaccount.yaml
kubectl apply -f k8s/mobile-deployment.yaml

# Wait for deployments to be ready
echo "Waiting for deployments..."
kubectl rollout status deployment/backend -n case --timeout=180s
kubectl rollout status deployment/mobile -n case --timeout=180s

echo "Simple deployment completed successfully!"

# Show final status
echo "Final status:"
kubectl get pods -n case
kubectl get services -n case