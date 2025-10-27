#!/usr/bin/env bash
set -euo pipefail

ENV="${1:-dev}"

echo "Running smoke tests for $ENV environment..."

# Get the service URL
if [ "$ENV" = "dev" ]; then
    API_URL="http://localhost:8080"
else
    API_URL="https://api-$ENV.example.com"
fi

# Test health endpoint
echo "Testing health endpoint..."
HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/health")

if [ "$HEALTH_STATUS" != "200" ]; then
    echo "❌ Health check failed with status $HEALTH_STATUS"
    exit 1
fi

echo "✅ Health check passed"

# Test ready endpoint
echo "Testing ready endpoint..."
READY_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/ready")

if [ "$READY_STATUS" != "200" ]; then
    echo "❌ Ready check failed with status $READY_STATUS"
    exit 1
fi

echo "✅ Ready check passed"
echo "All smoke tests passed!"
