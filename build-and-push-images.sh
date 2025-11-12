#!/bin/bash

# Build and Push Images to ECR
set -euo pipefail

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

# Configuration (defaults)
AWS_REGION_DEFAULT="us-east-1"
AWS_ACCOUNT_ID="918859180133"

# If a local env file with credentials exists, source it (do not commit real secrets)
AWS_ENV_FILE="scripts/aws-config.env"
if [ -f "$AWS_ENV_FILE" ]; then
    print_status "Carregando variáveis de credenciais de $AWS_ENV_FILE"
    # shellcheck disable=SC2046,SC2163
    export $(grep -v '^#' "$AWS_ENV_FILE" | xargs -d '\n') || true
fi

# Normalize region and set effective values
AWS_REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-$AWS_REGION_DEFAULT}}"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
# Allow overriding AWS command path (e.g., export AWS_CMD="/c/Program Files/Amazon/AWSCLIV2/aws.exe")
AWS_CMD=${AWS_CMD:-aws}

# Resolve AWS CLI path if not found in PATH
if ! command -v "$AWS_CMD" >/dev/null 2>&1; then
    if [ -x "/c/Program Files/Amazon/AWSCLIV2/aws.exe" ]; then
        AWS_CMD="/c/Program Files/Amazon/AWSCLIV2/aws.exe"
    elif [ -x "/c/Program Files/Amazon/AWSCLI/aws.exe" ]; then
        AWS_CMD="/c/Program Files/Amazon/AWSCLI/aws.exe"
    fi
fi
print_status "Using AWS CLI: ${AWS_CMD} (region: ${AWS_REGION}, profile: ${AWS_PROFILE:-unset})"

# Function to login to ECR
ecr_login() {
    print_status "Logging in to ECR (region: ${AWS_REGION}, registry: ${ECR_REGISTRY})..."
    local login_pw
    if ! login_pw=$(${AWS_CMD} ecr get-login-password --region "${AWS_REGION}"); then
        print_error "Failed to obtain ECR login password (check AWS credentials & region)."
        exit 1
    fi
    if ! echo "${login_pw}" | docker login --username AWS --password-stdin "${ECR_REGISTRY}"; then
        print_error "Docker login to ECR failed. Ensure Docker is running and you have permissions (ecr:GetAuthorizationToken)."
        exit 1
    fi
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
ensure_repos() {
    for repo in case-backend case-frontend case-mobile; do
        if ! ${AWS_CMD} ecr describe-repositories --repository-names "${repo}" --region "${AWS_REGION}" >/dev/null 2>&1; then
            print_warning "ECR repository '${repo}' not found. Creating..."
            ${AWS_CMD} ecr create-repository --repository-name "${repo}" --region "${AWS_REGION}" >/dev/null
            print_status "Repository '${repo}' created."
        fi
    done
}

main() {
    print_status "Starting build and push process..."

    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker Desktop and try again."
        exit 1
    fi

    # Show AWS identity for transparency
    if ${AWS_CMD} sts get-caller-identity >/dev/null 2>&1; then
        print_status "AWS credentials OK: $(${AWS_CMD} sts get-caller-identity --query 'Arn' --output text)"
    else
        print_error "AWS CLI credentials not working. Run 'aws configure' or set AWS_PROFILE / env vars."
        exit 1
    fi

    ensure_repos
    ecr_login

    build_and_push "backend" "domains/apps/app/backend" "latest"
    build_and_push "frontend" "domains/apps/app/frontend" "latest"
    build_and_push "mobile" "domains/apps/app/mobile" "latest"

    print_status "All images built and pushed successfully!"
    echo ""
    print_status "Image URIs:"
    echo "  Backend:  ${ECR_REGISTRY}/case-backend:latest"
    echo "  Frontend: ${ECR_REGISTRY}/case-frontend:latest"
    echo "  Mobile:   ${ECR_REGISTRY}/case-mobile:latest"
}

# Run main function
main "$@"