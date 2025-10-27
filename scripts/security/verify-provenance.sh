#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-}"

if [ -z "$IMAGE" ]; then
    echo "Usage: $0 <image>"
    exit 1
fi

echo "Verifying SLSA provenance for: $IMAGE"

# Verify provenance attestation
cosign verify-attestation \
    --type slsaprovenance \
    --certificate-identity-regexp="^https://github.com/.*" \
    --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
    "$IMAGE"

if [ $? -eq 0 ]; then
    echo "✅ SLSA provenance verified"
    
    # Display provenance details
    echo ""
    echo "=== Provenance Details ==="
    cosign verify-attestation \
        --type slsaprovenance \
        "$IMAGE" 2>/dev/null | jq -r '.payload' | base64 -d | jq .
    
    exit 0
else
    echo "❌ SLSA provenance verification failed"
    exit 1
fi
