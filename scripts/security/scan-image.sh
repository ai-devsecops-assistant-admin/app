#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-}"

if [ -z "$IMAGE" ]; then
    echo "Usage: $0 <image>"
    exit 1
fi

echo "Scanning image: $IMAGE"

# Run Trivy scan
echo "Running Trivy vulnerability scan..."
if trivy image \
    --severity CRITICAL,HIGH \
    --exit-code 1 \
    --format table \
    "$IMAGE"
then
    echo "✅ No critical or high vulnerabilities found"
else
    echo "❌ Vulnerabilities detected!"
    exit 1
fi

# Verify signature
echo "Verifying image signature..."
if command -v cosign &> /dev/null; then
    cosign verify \
        --certificate-identity-regexp="^https://github.com/.*" \
        --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
        "$IMAGE" || echo "⚠️  Signature verification failed or not signed"
fi

echo "Image scan complete!"
