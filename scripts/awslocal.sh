#!/bin/bash
# Wrapper para AWS CLI via LocalStack

cd "$(dirname "$0")/.."

export AWS_ENDPOINT_URL=http://localstack:4566
export AWS_REGION=us-east-1
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test

docker compose -f docker-compose.localstack.yml exec -T localstack \
  awslocal "$@"
