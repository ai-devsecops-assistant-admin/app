#!/usr/bin/env bash

# Disaster Recovery Backup Script
# Backs up critical platform governance data and configurations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/backups/platform-governance}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_NAME="backup-${TIMESTAMP}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

check_prerequisites() {
    local missing=0

    log "Checking prerequisites..."

    if ! command -v kubectl &>/dev/null; then
        error "kubectl is not installed"
        missing=1
    fi

    if ! command -v psql &>/dev/null; then
        warn "psql is not installed (database backup will be skipped)"
    fi

    if ! command -v restic &>/dev/null; then
        warn "restic is not installed (incremental backups not available)"
    fi

    if [ $missing -eq 1 ]; then
        exit 1
    fi

    success "Prerequisites check passed"
}

create_backup_dir() {
    local backup_path="${BACKUP_DIR}/${BACKUP_NAME}"

    log "Creating backup directory: $backup_path"
    mkdir -p "$backup_path"/{kubernetes,database,configs,secrets}

    echo "$backup_path"
}

backup_kubernetes_resources() {
    local backup_path="$1"
    local namespaces=("prod" "staging" "dev" "observability" "falco" "sealed-secrets" "flagger-system")

    log "Backing up Kubernetes resources..."

    for ns in "${namespaces[@]}"; do
        log "  Backing up namespace: $ns"

        # Check if namespace exists
        if ! kubectl get namespace "$ns" &>/dev/null; then
            warn "  Namespace $ns does not exist, skipping"
            continue
        fi

        # Backup namespace
        kubectl get namespace "$ns" -o yaml >"${backup_path}/kubernetes/namespace-${ns}.yaml"

        # Backup all resources in namespace
        kubectl get all,cm,secret,pvc,ing,networkpolicy -n "$ns" -o yaml \
            >"${backup_path}/kubernetes/resources-${ns}.yaml" 2>/dev/null || true

        # Backup specific CRDs
        kubectl get canaries,sealedsecrets,kustomizations,gitrepositories -n "$ns" -o yaml \
            >"${backup_path}/kubernetes/crds-${ns}.yaml" 2>/dev/null || true
    done

    # Backup cluster-wide resources
    log "  Backing up cluster-wide resources..."
    kubectl get clusterroles,clusterrolebindings,storageclasses,crds -o yaml \
        >"${backup_path}/kubernetes/cluster-resources.yaml" 2>/dev/null || true

    # Backup OPA/Gatekeeper policies
    kubectl get constrainttemplates,configs -n gatekeeper-system -o yaml \
        >"${backup_path}/kubernetes/gatekeeper-policies.yaml" 2>/dev/null || true

    # Backup Kyverno policies
    kubectl get clusterpolicies,policies -A -o yaml \
        >"${backup_path}/kubernetes/kyverno-policies.yaml" 2>/dev/null || true

    success "Kubernetes resources backed up"
}

backup_database() {
    local backup_path="$1"

    if ! command -v psql &>/dev/null; then
        warn "Skipping database backup (psql not available)"
        return
    fi

    log "Backing up database..."

    local db_host="${DATABASE_HOST:-localhost}"
    local db_port="${DATABASE_PORT:-5432}"
    local db_user="${DATABASE_USER:-postgres}"
    local db_name="${DATABASE_NAME:-platform_governance}"

    # Backup schema
    log "  Backing up database schema..."
    pg_dump -h "$db_host" -p "$db_port" -U "$db_user" \
        --schema-only --no-owner --no-acl \
        "$db_name" >"${backup_path}/database/schema.sql"

    # Backup data
    log "  Backing up database data..."
    pg_dump -h "$db_host" -p "$db_port" -U "$db_user" \
        --data-only --no-owner --no-acl \
        --column-inserts \
        "$db_name" >"${backup_path}/database/data.sql"

    # Backup full dump (compressed)
    log "  Creating compressed full backup..."
    pg_dump -h "$db_host" -p "$db_port" -U "$db_user" \
        --format=custom --compress=9 \
        "$db_name" >"${backup_path}/database/full-dump.pgdump"

    success "Database backed up"
}

backup_configurations() {
    local backup_path="$1"

    log "Backing up configuration files..."

    # Backup root configs
    cp -r "${PROJECT_ROOT}/.config" "${backup_path}/configs/" 2>/dev/null || true
    cp "${PROJECT_ROOT}/.root."*.yaml "${backup_path}/configs/" 2>/dev/null || true
    cp "${PROJECT_ROOT}/gate-lock-attest.yaml" "${backup_path}/configs/" 2>/dev/null || true

    # Backup policy files
    cp -r "${PROJECT_ROOT}/.config/policy" "${backup_path}/configs/" 2>/dev/null || true
    cp -r "${PROJECT_ROOT}/.config/kyverno" "${backup_path}/configs/" 2>/dev/null || true
    cp -r "${PROJECT_ROOT}/.config/conftest" "${backup_path}/configs/" 2>/dev/null || true

    # Backup observability configs
    cp -r "${PROJECT_ROOT}/observability" "${backup_path}/configs/" 2>/dev/null || true

    success "Configuration files backed up"
}

backup_secrets() {
    local backup_path="$1"

    log "Backing up secrets (encrypted)..."

    # Backup sealed secrets (safe to backup as they're encrypted)
    kubectl get sealedsecrets -A -o yaml \
        >"${backup_path}/secrets/sealed-secrets.yaml" 2>/dev/null || true

    # Backup sealed secrets controller key (CRITICAL - encrypt this!)
    kubectl get secret -n sealed-secrets \
        -l sealedsecrets.bitnami.com/sealed-secrets-key=active \
        -o yaml >"${backup_path}/secrets/sealed-secrets-keys.yaml" 2>/dev/null || true

    warn "CRITICAL: sealed-secrets-keys.yaml contains encryption keys!"
    warn "         Encrypt this file immediately after backup!"

    success "Secrets backed up"
}

create_manifest() {
    local backup_path="$1"

    log "Creating backup manifest..."

    cat >"${backup_path}/MANIFEST.txt" <<EOF
Platform Governance Backup
==========================

Backup Date: $(date)
Backup Name: ${BACKUP_NAME}
Kubernetes Version: $(kubectl version --short 2>/dev/null || echo "unknown")
Cluster: $(kubectl config current-context 2>/dev/null || echo "unknown")

Contents:
---------
- Kubernetes resources (all namespaces)
- Database schema and data
- Configuration files
- Sealed secrets and keys

Restoration:
-----------
To restore this backup, use: ${SCRIPT_DIR}/restore.sh ${BACKUP_NAME}

Notes:
------
- sealed-secrets-keys.yaml MUST be encrypted at rest
- Database backup requires PostgreSQL client
- Review restoration documentation before restoring

Checksum:
---------
EOF

    # Generate checksums
    find "$backup_path" -type f -not -name "MANIFEST.txt" -exec sha256sum {} \; \
        >>"${backup_path}/MANIFEST.txt"

    success "Backup manifest created"
}

compress_backup() {
    local backup_path="$1"

    log "Compressing backup..."

    cd "${BACKUP_DIR}"
    tar czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}"

    local size=$(du -h "${BACKUP_NAME}.tar.gz" | cut -f1)
    success "Backup compressed: ${BACKUP_NAME}.tar.gz (${size})"

    # Remove uncompressed backup
    rm -rf "${BACKUP_NAME}"
}

cleanup_old_backups() {
    log "Cleaning up old backups (retention: ${BACKUP_RETENTION_DAYS} days)..."

    find "${BACKUP_DIR}" -name "backup-*.tar.gz" -type f -mtime +${BACKUP_RETENTION_DAYS} -delete

    local count=$(find "${BACKUP_DIR}" -name "backup-*.tar.gz" -type f | wc -l)
    success "Cleanup complete (${count} backups remaining)"
}

# Main
main() {
    log "Starting Platform Governance backup..."
    log "Backup directory: ${BACKUP_DIR}"

    check_prerequisites

    local backup_path
    backup_path=$(create_backup_dir)

    backup_kubernetes_resources "$backup_path"
    backup_database "$backup_path"
    backup_configurations "$backup_path"
    backup_secrets "$backup_path"
    create_manifest "$backup_path"

    compress_backup "$backup_path"
    cleanup_old_backups

    success "Backup completed successfully!"
    log "Backup location: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
    log ""
    warn "IMPORTANT: Encrypt and store sealed-secrets-keys.yaml securely!"
}

main "$@"
