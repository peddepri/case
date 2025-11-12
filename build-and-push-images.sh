#!/bin/bash

# Build and Push Images to ECR
set -e

# Configuration
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="918859180133"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to login to ECR
ecr_login() {
    print_status "Logging in to ECR..."
    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
}

# Function to build and push image
build_and_push() {
    local app_name=$1
    local docker_context=$2
    local image_tag=${3:-latest}
    
    print_status "Building and pushing ${app_name}..."
    
    # Build image
    print_status "Building ${app_name} image..."
    cd ${docker_context}
    docker build -t ${app_name}:${image_tag} .
    
    # Tag for ECR
    docker tag ${app_name}:${image_tag} ${ECR_REGISTRY}/case-${app_name}:${image_tag}
    
    # Push to ECR
    print_status "Pushing ${app_name} to ECR..."
    docker push ${ECR_REGISTRY}/case-${app_name}:${image_tag}
    
    print_status "${app_name} image pushed successfully!"
    echo "Image URI: ${ECR_REGISTRY}/case-${app_name}:${image_tag}"
    
    cd - > /dev/null
}

# Main execution
main() {
    print_status "Starting build and push process..."
    
    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
    
    # Check if AWS CLI is configured
    if ! aws sts get-caller-identity > /dev/null 2>&1; then
        print_error "AWS CLI is not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    # Login to ECR
    ecr_login
    
    # Build and push each application
    build_and_push "backend" "domains/apps/app/backend" "latest"
    build_and_push "frontend" "domains/apps/app/frontend" "latest"
    build_and_push "mobile" "domains/apps/app/mobile" "latest"
    
    print_status "All images built and pushed successfully!"
    
    # Display image URIs
    echo ""
    print_status "Image URIs:"
    echo "  Backend:  ${ECR_REGISTRY}/case-backend:latest"
    echo "  Frontend: ${ECR_REGISTRY}/case-frontend:latest"
    echo "  Mobile:   ${ECR_REGISTRY}/case-mobile:latest"
}

# Run main function
main "$@"