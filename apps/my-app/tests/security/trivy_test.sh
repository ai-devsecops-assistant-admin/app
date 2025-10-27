#!/usr/bin/env bash
set -euo pipefail

echo "Running Trivy security scans..."

IMAGE_NAME="${1:-my-app-api:latest}"
SEVERITY="${2:-CRITICAL,HIGH}"

echo "Scanning image: $IMAGE_NAME"
trivy image \
  --severity "$SEVERITY" \
  --exit-code 1 \
  --no-progress \
  --format json \
  --output trivy-report.json \
  "$IMAGE_NAME"

echo "Trivy scan completed successfully"
