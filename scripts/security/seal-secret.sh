#!/usr/bin/env bash

# Seal secrets using kubeseal for secure storage in Git
# Usage: ./seal-secret.sh <secret-name> <namespace> <key=value> [key=value...]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    cat <<EOF
Usage: $0 <secret-name> <namespace> <key=value> [key=value...]

Seal secrets using kubeseal for secure storage in Git.

Arguments:
  secret-name   Name of the secret to create
  namespace     Kubernetes namespace for the secret
  key=value     One or more key=value pairs for secret data

Examples:
  $0 db-creds prod host=db.example.com port=5432 password=secret123
  $0 api-key staging api_key=sk_live_xxx

Environment Variables:
  KUBESEAL_CONTROLLER_NAME      Name of the sealed secrets controller (default: sealed-secrets-controller)
  KUBESEAL_CONTROLLER_NAMESPACE Namespace of the controller (default: sealed-secrets)
  OUTPUT_DIR                    Directory to save sealed secret (default: ops/secrets)

Prerequisites:
  - kubectl configured and connected to cluster
  - kubeseal CLI installed (https://github.com/bitnami-labs/sealed-secrets)
EOF
    exit 1
}

check_prerequisites() {
    local missing=0

    if ! command -v kubectl &>/dev/null; then
        echo -e "${RED}✗${NC} kubectl is not installed"
        missing=1
    fi

    if ! command -v kubeseal &>/dev/null; then
        echo -e "${RED}✗${NC} kubeseal is not installed"
        echo "Install from: https://github.com/bitnami-labs/sealed-secrets/releases"
        missing=1
    fi

    if [ $missing -eq 1 ]; then
        exit 1
    fi

    echo -e "${GREEN}✓${NC} Prerequisites check passed"
}

create_sealed_secret() {
    local secret_name="$1"
    local namespace="$2"
    shift 2
    local secret_data=("$@")

    local controller_name="${KUBESEAL_CONTROLLER_NAME:-sealed-secrets-controller}"
    local controller_namespace="${KUBESEAL_CONTROLLER_NAMESPACE:-sealed-secrets}"
    local output_dir="${OUTPUT_DIR:-${PROJECT_ROOT}/ops/secrets}"

    # Create output directory if it doesn't exist
    mkdir -p "$output_dir"

    echo -e "${YELLOW}Creating sealed secret...${NC}"
    echo "  Name: $secret_name"
    echo "  Namespace: $namespace"
    echo "  Keys: ${#secret_data[@]}"

    # Build kubectl create secret command
    local create_cmd="kubectl create secret generic $secret_name --namespace=$namespace --dry-run=client -o yaml"

    for data in "${secret_data[@]}"; do
        if [[ ! $data =~ ^([^=]+)=(.+)$ ]]; then
            echo -e "${RED}✗${NC} Invalid key=value format: $data"
            exit 1
        fi
        local key="${BASH_REMATCH[1]}"
        local value="${BASH_REMATCH[2]}"
        create_cmd="$create_cmd --from-literal=$key=$value"
    done

    # Create and seal the secret
    local sealed_secret_file="$output_dir/${secret_name}-sealed.yaml"

    eval "$create_cmd" | kubeseal \
        --controller-name="$controller_name" \
        --controller-namespace="$controller_namespace" \
        --format yaml \
        >"$sealed_secret_file"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} Sealed secret created: $sealed_secret_file"
        echo ""
        echo "You can now safely commit this file to Git:"
        echo "  git add $sealed_secret_file"
        echo "  git commit -m \"Add sealed secret: $secret_name\""
        echo ""
        echo "To apply to cluster:"
        echo "  kubectl apply -f $sealed_secret_file"
    else
        echo -e "${RED}✗${NC} Failed to create sealed secret"
        exit 1
    fi
}

# Main
if [ $# -lt 3 ]; then
    usage
fi

SECRET_NAME="$1"
NAMESPACE="$2"
shift 2
SECRET_DATA=("$@")

check_prerequisites
create_sealed_secret "$SECRET_NAME" "$NAMESPACE" "${SECRET_DATA[@]}"
