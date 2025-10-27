#!/usr/bin/env bash
set -euo pipefail

ENV="${1:-}"

if [ -z "$ENV" ]; then
    echo "Usage: $0 <environment>"
    echo "Valid environments: dev, staging, prod"
    exit 1
fi

if [[ ! "$ENV" =~ ^(dev|staging|prod)$ ]]; then
    echo "Error: Invalid environment '$ENV'"
    echo "Valid environments: dev, staging, prod"
    exit 1
fi

echo "Deploying to $ENV environment..."

# Check deployment freeze
if ! ./scripts/gate/check-freeze.sh; then
    echo "Deployment blocked by freeze window"
    exit 1
fi

# Deploy with Helm
helm upgrade --install \
    --namespace "$ENV" \
    --create-namespace \
    --values "deploy/helm/my-app-api/values-$ENV.yaml" \
    --wait \
    --timeout 10m \
    "$ENV-my-app-api-v1.0.0" \
    deploy/helm/my-app-api/

echo "Deployment to $ENV completed successfully!"

# Verify deployment
kubectl rollout status deployment/"$ENV-my-app-api-deploy-v1.0.0" -n "$ENV"

# Run smoke tests
echo "Running smoke tests..."
./scripts/test/smoke-test.sh "$ENV"

echo "Deployment and verification complete!"
