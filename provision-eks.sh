#!/bin/bash

# Script para provisionar EKS com Fargate na AWS
# Execute este script aps configurar as credenciais AWS

set -e

echo "Iniciando provisionamento da infraestrutura EKS..."

# Verificar credenciais
echo "Verificando credenciais AWS..."
aws sts get-caller-identity

# Navegar para o diretrio do Terraform
cd infra/terraform

echo "Verificando configurao do Terraform..."
terraform --version

echo "Validando configurao..."
terraform validate

echo "Gerando plano de execuo..."
terraform plan -out=eks-deploy.tfplan

echo ""
echo "Plano gerado com sucesso!"
echo ""
echo "Para aplicar a infraestrutura, execute:"
echo " terraform apply eks-deploy.tfplan"
echo ""
echo "Recursos que sero criados:"
echo "  EKS Cluster com Fargate"
echo "  VPC com subnets pblicas e privadas"
echo "  ECR repositories"
echo "  DynamoDB table"
echo "  IAM roles e policies"
echo "  Datadog monitoring"
echo ""
echo "Custos estimados: ~$72-100/ms"
echo ""
echo "Para aplicar agora, execute:"
echo " terraform apply eks-deploy.tfplan"