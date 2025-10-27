#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-}"
OUTPUT="${2:-sbom.spdx.json}"

if [ -z "$IMAGE" ]; then
    echo "Usage: $0 <image> [output-file]"
    exit 1
fi

echo "Generating SBOM for: $IMAGE"

# Generate SBOM with Syft
syft "$IMAGE" \
    -o spdx-json \
    --file "$OUTPUT"

if [ $? -eq 0 ]; then
    echo "✅ SBOM generated successfully: $OUTPUT"
    
    # Display summary
    echo ""
    echo "=== SBOM Summary ==="
    jq -r '.packages | length' "$OUTPUT" | xargs echo "Total packages:"
    
    # Count by type
    echo ""
    echo "Packages by type:"
    jq -r '.packages | group_by(.packageType) | .[] | "\(.[0].packageType): \(length)"' "$OUTPUT"
    
    exit 0
else
    echo "❌ SBOM generation failed"
    exit 1
fi
