#!/usr/bin/env bash

# Disaster Recovery Restore Script
# Restores platform governance from backup

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/backups/platform-governance}"

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

usage() {
    cat <<EOF
Usage: $0 <backup-name>

Restore platform governance from backup.

Arguments:
  backup-name   Name of the backup to restore (e.g., backup-20251027-120000)

Options:
  --kubernetes-only    Restore only Kubernetes resources
  --database-only      Restore only database
  --dry-run           Show what would be restored without making changes

Examples:
  $0 backup-20251027-120000
  $0 backup-20251027-120000 --kubernetes-only
  $0 backup-20251027-120000 --dry-run

EOF
    exit 1
}

check_prerequisites() {
    local missing=0

    log "Checking prerequisites..."

    if ! command -v kubectl &>/dev/null; then
        error "kubectl is not installed"
        missing=1
    fi

    if ! command -v psql &>/dev/null && [ "${DATABASE_ONLY}" != "true" ]; then
        warn "psql is not installed (database restore will be skipped)"
    fi

    if [ $missing -eq 1 ]; then
        exit 1
    fi

    success "Prerequisites check passed"
}

confirm_restore() {
    local backup_name="$1"

    warn "========================================="
    warn "DISASTER RECOVERY RESTORE"
    warn "========================================="
    warn "Backup: ${backup_name}"
    warn "Target cluster: $(kubectl config current-context)"
    warn ""
    warn "This operation will:"
    warn "  - Restore Kubernetes resources"
    warn "  - Restore database (if selected)"
    warn "  - Potentially overwrite existing data"
    warn ""
    warn "THIS OPERATION CANNOT BE UNDONE!"
    warn "========================================="
    echo ""

    read -p "Are you sure you want to proceed? (type 'yes' to continue): " confirmation

    if [ "$confirmation" != "yes" ]; then
        error "Restore cancelled by user"
        exit 1
    fi

    success "Restore confirmed, proceeding..."
}

extract_backup() {
    local backup_name="$1"
    local backup_file="${BACKUP_DIR}/${backup_name}.tar.gz"
    local extract_dir="${BACKUP_DIR}/restore-${backup_name}"

    if [ ! -f "$backup_file" ]; then
        error "Backup file not found: $backup_file"
        exit 1
    fi

    log "Extracting backup..."
    mkdir -p "$extract_dir"
    tar xzf "$backup_file" -C "$extract_dir" --strip-components=1

    echo "$extract_dir"
}

verify_backup() {
    local backup_path="$1"

    log "Verifying backup integrity..."

    if [ ! -f "${backup_path}/MANIFEST.txt" ]; then
        error "Backup manifest not found!"
        exit 1
    fi

    # Display manifest
    cat "${backup_path}/MANIFEST.txt" | head -20

    # Verify checksums
    local checksum_errors=0
    while IFS= read -r line; do
        if [[ $line =~ ^([a-f0-9]+)\ \ (.+)$ ]]; then
            local expected_sum="${BASH_REMATCH[1]}"
            local file="${BASH_REMATCH[2]}"

            if [ -f "$file" ]; then
                local actual_sum=$(sha256sum "$file" | cut -d' ' -f1)
                if [ "$expected_sum" != "$actual_sum" ]; then
                    error "Checksum mismatch: $file"
                    checksum_errors=$((checksum_errors + 1))
                fi
            fi
        fi
    done < "${backup_path}/MANIFEST.txt"

    if [ $checksum_errors -gt 0 ]; then
        error "Backup verification failed ($checksum_errors errors)"
        exit 1
    fi

    success "Backup verified successfully"
}

restore_kubernetes_resources() {
    local backup_path="$1"

    log "Restoring Kubernetes resources..."

    # Restore namespaces first
    log "  Restoring namespaces..."
    for ns_file in "${backup_path}"/kubernetes/namespace-*.yaml; do
        if [ -f "$ns_file" ]; then
            kubectl apply -f "$ns_file" || warn "Failed to restore $(basename $ns_file)"
        fi
    done

    # Restore CRDs
    log "  Restoring CRDs..."
    if [ -f "${backup_path}/kubernetes/cluster-resources.yaml" ]; then
        kubectl apply -f "${backup_path}/kubernetes/cluster-resources.yaml" || warn "Some CRDs may have failed"
    fi

    # Wait for CRDs to be established
    sleep 5

    # Restore sealed secrets keys FIRST (critical for secret decryption)
    log "  Restoring Sealed Secrets keys..."
    if [ -f "${backup_path}/secrets/sealed-secrets-keys.yaml" ]; then
        kubectl apply -f "${backup_path}/secrets/sealed-secrets-keys.yaml"
        # Restart sealed secrets controller to pick up new keys
        kubectl rollout restart deployment/sealed-secrets-controller -n sealed-secrets 2>/dev/null || true
        sleep 10
    fi

    # Restore policies
    log "  Restoring policies..."
    [ -f "${backup_path}/kubernetes/gatekeeper-policies.yaml" ] && \
        kubectl apply -f "${backup_path}/kubernetes/gatekeeper-policies.yaml" || true
    [ -f "${backup_path}/kubernetes/kyverno-policies.yaml" ] && \
        kubectl apply -f "${backup_path}/kubernetes/kyverno-policies.yaml" || true

    # Restore resources per namespace
    log "  Restoring namespace resources..."
    for resource_file in "${backup_path}"/kubernetes/resources-*.yaml; do
        if [ -f "$resource_file" ]; then
            kubectl apply -f "$resource_file" || warn "Failed to restore $(basename $resource_file)"
        fi
    done

    # Restore CRD instances
    log "  Restoring CRD instances..."
    for crd_file in "${backup_path}"/kubernetes/crds-*.yaml; do
        if [ -f "$crd_file" ]; then
            kubectl apply -f "$crd_file" || warn "Failed to restore $(basename $crd_file)"
        fi
    done

    success "Kubernetes resources restored"
}

restore_database() {
    local backup_path="$1"

    if ! command -v psql &>/dev/null; then
        warn "Skipping database restore (psql not available)"
        return
    fi

    log "Restoring database..."

    local db_host="${DATABASE_HOST:-localhost}"
    local db_port="${DATABASE_PORT:-5432}"
    local db_user="${DATABASE_USER:-postgres}"
    local db_name="${DATABASE_NAME:-platform_governance}"

    # Ask for confirmation
    warn "This will DROP and recreate the database '$db_name'"
    read -p "Continue with database restore? (yes/no): " db_confirm

    if [ "$db_confirm" != "yes" ]; then
        warn "Database restore skipped"
        return
    fi

    # Drop and recreate database
    log "  Recreating database..."
    psql -h "$db_host" -p "$db_port" -U "$db_user" -d postgres <<EOF
DROP DATABASE IF EXISTS ${db_name};
CREATE DATABASE ${db_name};
EOF

    # Restore schema
    log "  Restoring schema..."
    psql -h "$db_host" -p "$db_port" -U "$db_user" -d "$db_name" \
        <"${backup_path}/database/schema.sql"

    # Restore data
    log "  Restoring data..."
    psql -h "$db_host" -p "$db_port" -U "$db_user" -d "$db_name" \
        <"${backup_path}/database/data.sql"

    success "Database restored"
}

verify_restoration() {
    log "Verifying restoration..."

    # Check pods are running
    log "  Checking pod status..."
    kubectl get pods --all-namespaces

    # Check database connectivity (if restored)
    if command -v psql &>/dev/null && [ "${KUBERNETES_ONLY}" != "true" ]; then
        log "  Verifying database..."
        psql -h "${DATABASE_HOST:-localhost}" -U "${DATABASE_USER:-postgres}" \
            -d "${DATABASE_NAME:-platform_governance}" \
            -c "SELECT COUNT(*) FROM resources;" || warn "Database verification failed"
    fi

    success "Verification complete"
}

cleanup() {
    local backup_path="$1"

    log "Cleaning up temporary files..."
    rm -rf "$backup_path"
    success "Cleanup complete"
}

# Main
main() {
    local backup_name=""
    local dry_run=false
    local kubernetes_only=false
    local database_only=false

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
        --dry-run)
            dry_run=true
            shift
            ;;
        --kubernetes-only)
            kubernetes_only=true
            shift
            ;;
        --database-only)
            database_only=true
            shift
            ;;
        -h | --help)
            usage
            ;;
        *)
            backup_name="$1"
            shift
            ;;
        esac
    done

    if [ -z "$backup_name" ]; then
        error "No backup name specified"
        usage
    fi

    export KUBERNETES_ONLY=$kubernetes_only
    export DATABASE_ONLY=$database_only

    log "Starting Platform Governance restore..."
    log "Backup: ${backup_name}"

    check_prerequisites

    if [ "$dry_run" = false ]; then
        confirm_restore "$backup_name"
    else
        warn "DRY RUN MODE - No changes will be made"
    fi

    local backup_path
    backup_path=$(extract_backup "$backup_name")

    verify_backup "$backup_path"

    if [ "$dry_run" = false ]; then
        if [ "$database_only" = false ]; then
            restore_kubernetes_resources "$backup_path"
        fi

        if [ "$kubernetes_only" = false ]; then
            restore_database "$backup_path"
        fi

        verify_restoration
    else
        log "Dry run complete - would have restored:"
        log "  - Kubernetes resources: $([ "$database_only" = false ] && echo "YES" || echo "NO")"
        log "  - Database: $([ "$kubernetes_only" = false ] && echo "YES" || echo "NO")"
    fi

    cleanup "$backup_path"

    success "Restore completed successfully!"
    log ""
    warn "IMPORTANT: Verify all services are running correctly!"
}

main "$@"
