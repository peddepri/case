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
GIT_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo local)"
DATE_TAG="$(date +%Y%m%d%H%M%S)"

# Select which apps to build (space‑separated). Override: APPS="backend frontend" ./build-and-push-images.sh
APPS_LIST=${APPS:-"backend frontend mobile"}

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
    local base_tag=${3:-latest}
    local extra_tags=()

    # Always tag latest + commit SHA; optionally date tag if USE_DATE_TAG=1
    extra_tags+=("${base_tag}" "${GIT_SHA}")
    if [[ "${USE_DATE_TAG:-1}" == "1" ]]; then
        extra_tags+=("${DATE_TAG}")
    fi

    print_status "Building ${app_name} (tags: ${extra_tags[*]})"
    cd "${docker_context}"

    # Build once with a temporary local name
    local local_image="case-${app_name}-build:${GIT_SHA}"
    docker build -t "${local_image}" .

    # Calculate local digest
    local local_digest
    local_digest=$(docker inspect --format='{{index .RepoDigests 0}}' "${local_image}" || true)

    # Decide push per tag (skip if same digest already in registry)
    for tag in "${extra_tags[@]}"; do
        local remote_ref="${ECR_REGISTRY}/case-${app_name}:${tag}"
        # Try to get remote digest
        local remote_digest
        remote_digest=$(aws ecr describe-images --repository-name "case-${app_name}" --image-ids imageTag="${tag}" --region "${AWS_REGION}" --query 'imageDetails[0].imageDigest' --output text 2>/dev/null || echo "NONE")
        if [[ "${remote_digest}" != "NONE" && -n "${local_digest}" && "${remote_digest}" == $(echo "${local_digest}" | sed 's/.*@//') ]]; then
            print_status "Skip push (unchanged digest) ${remote_ref}"
        else
            docker tag "${local_image}" "${remote_ref}"
            print_status "Pushing ${remote_ref}"
            docker push "${remote_ref}"
        fi
    done

    # Show summary
    print_status "Image summary for ${app_name}:"
    for tag in "${extra_tags[@]}"; do
        echo "  ${ECR_REGISTRY}/case-${app_name}:${tag}"
    done
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

        for app in ${APPS_LIST}; do
                case "$app" in
                    backend)  build_and_push "backend"  "domains/apps/app/backend"  "latest";;
                    frontend) build_and_push "frontend" "domains/apps/app/frontend" "latest";;
                    mobile)   build_and_push "mobile"   "domains/apps/app/mobile"   "latest";;
                    *) print_warning "Unknown app '$app' – skipping";;
                esac
        done

    print_status "All images built and pushed successfully!"
    echo ""
    print_status "Image URIs:"
    [[ "$APPS_LIST" == *backend* ]]  && echo "  Backend:  ${ECR_REGISTRY}/case-backend:latest / ${ECR_REGISTRY}/case-backend:${GIT_SHA}" || true
    [[ "$APPS_LIST" == *frontend* ]] && echo "  Frontend: ${ECR_REGISTRY}/case-frontend:latest / ${ECR_REGISTRY}/case-frontend:${GIT_SHA}" || true
    [[ "$APPS_LIST" == *mobile* ]]   && echo "  Mobile:   ${ECR_REGISTRY}/case-mobile:latest / ${ECR_REGISTRY}/case-mobile:${GIT_SHA}" || true
}

# Run main function
main "$@"