#!/usr/bin/env bash
set -euo pipefail

MANIFEST_FILE="${1:-}"

if [ -z "$MANIFEST_FILE" ]; then
    echo "Usage: $0 <manifest-file>"
    exit 1
fi

if [ ! -f "$MANIFEST_FILE" ]; then
    echo "Error: File not found: $MANIFEST_FILE"
    exit 1
fi

echo "Validating naming conventions in $MANIFEST_FILE..."

if conftest test "$MANIFEST_FILE" -p .config/conftest/policies/naming_policy.rego; then
    echo "✅ All naming conventions are valid!"
    exit 0
else
    echo "❌ Naming convention violations found!"
    exit 1
fi
