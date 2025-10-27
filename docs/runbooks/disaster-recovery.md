# Disaster Recovery Runbook

## Overview

This runbook describes procedures for backing up and restoring the Platform Governance system.

## Backup Procedures

### Automated Backups

Automated backups run daily at 02:00 UTC via cron job:

```bash
# View backup cron job
crontab -l | grep backup

# Expected output:
# 0 2 * * * /path/to/platform-governance/scripts/dr/backup.sh
```

### Manual Backup

To create a manual backup:

```bash
# Basic backup
./scripts/dr/backup.sh

# Custom backup location
BACKUP_DIR=/custom/path ./scripts/dr/backup.sh

# Custom retention
BACKUP_RETENTION_DAYS=90 ./scripts/dr/backup.sh
```

### What Gets Backed Up

1. **Kubernetes Resources**:
   - All namespaces (prod, staging, dev, observability, etc.)
   - Deployments, Services, ConfigMaps, Secrets
   - CRDs (Canaries, SealedSecrets, Kustomizations)
   - ClusterRoles, ClusterRoleBindings, StorageClasses
   - Policies (Gatekeeper, Kyverno, OPA)

2. **Database**:
   - Schema (DDL)
   - Data (DML)
   - Full compressed dump

3. **Configurations**:
   - Policy files (.config/*)
   - Root configs (.root.*.yaml)
   - Deployment gates (gate-lock-attest.yaml)
   - Observability configs

4. **Secrets**:
   - SealedSecrets (encrypted)
   - Sealed Secrets controller keys (CRITICAL!)

### Backup Storage

Backups are stored at: `/backups/platform-governance/`

Format: `backup-YYYYMMDD-HHMMSS.tar.gz`

**CRITICAL**: The sealed-secrets-keys.yaml file contains encryption keys and MUST be:
- Encrypted at rest
- Stored in a secure location (HSM, KMS, encrypted S3)
- Access-controlled
- Never committed to Git

## Restore Procedures

### Pre-Restoration Checklist

- [ ] Verify backup integrity
- [ ] Confirm target cluster is correct
- [ ] Ensure database is accessible
- [ ] Review MANIFEST.txt in backup
- [ ] Notify team of restoration
- [ ] Create incident ticket

### Full System Restore

```bash
# List available backups
ls -lh /backups/platform-governance/

# Restore from backup
./scripts/dr/restore.sh backup-20251027-120000

# Follow prompts and confirm restoration
```

### Kubernetes-Only Restore

```bash
./scripts/dr/restore.sh backup-20251027-120000 --kubernetes-only
```

### Database-Only Restore

```bash
# Set database connection details
export DATABASE_HOST=db.example.com
export DATABASE_PORT=5432
export DATABASE_USER=postgres
export DATABASE_NAME=platform_governance

# Restore
./scripts/dr/restore.sh backup-20251027-120000 --database-only
```

### Dry Run

To see what would be restored without making changes:

```bash
./scripts/dr/restore.sh backup-20251027-120000 --dry-run
```

## Recovery Time Objective (RTO)

- **Full System Restore**: 2-4 hours
- **Kubernetes Only**: 1-2 hours
- **Database Only**: 30-60 minutes

## Recovery Point Objective (RPO)

- **Automated Backups**: 24 hours (daily backups)
- **Critical Changes**: 0 hours (manual backup before change)

## Disaster Scenarios

### Scenario 1: Complete Cluster Loss

**Impact**: Total loss of Kubernetes cluster

**Recovery Steps**:

1. Provision new Kubernetes cluster
2. Install cluster prerequisites:
   ```bash
   # Install cert-manager
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

   # Install sealed-secrets controller
   kubectl apply -f ops/secrets/sealed-secrets-controller.yaml

   # Install Prometheus Operator CRDs
   kubectl apply -f ops/observability/prometheus-deployment.yaml
   ```

3. Restore from backup:
   ```bash
   ./scripts/dr/restore.sh backup-LATEST
   ```

4. Verify services:
   ```bash
   kubectl get pods --all-namespaces
   kubectl get svc --all-namespaces
   ```

5. Run smoke tests:
   ```bash
   ./scripts/test/smoke-test.sh prod
   ```

**Estimated Recovery Time**: 3-4 hours

### Scenario 2: Database Corruption

**Impact**: Database data corruption or loss

**Recovery Steps**:

1. Stop applications to prevent writes:
   ```bash
   kubectl scale deployment -n prod prod-my-app-api-deploy-v1.0.0 --replicas=0
   ```

2. Restore database:
   ```bash
   ./scripts/dr/restore.sh backup-LATEST --database-only
   ```

3. Verify data integrity:
   ```bash
   psql -h $DATABASE_HOST -U $DATABASE_USER -d $DATABASE_NAME \
     -c "SELECT COUNT(*) FROM resources; SELECT COUNT(*) FROM violations;"
   ```

4. Restart applications:
   ```bash
   kubectl scale deployment -n prod prod-my-app-api-deploy-v1.0.0 --replicas=3
   ```

**Estimated Recovery Time**: 30-60 minutes

### Scenario 3: Accidental Resource Deletion

**Impact**: Critical Kubernetes resource accidentally deleted

**Recovery Steps**:

1. Identify deleted resource from audit logs:
   ```bash
   kubectl get events --all-namespaces --sort-by='.lastTimestamp' | grep -i delete
   ```

2. Extract specific resource from backup:
   ```bash
   # Extract backup
   tar xzf /backups/platform-governance/backup-LATEST.tar.gz

   # Find and apply specific resource
   grep -A 50 "name: my-app-api" backup-*/kubernetes/resources-prod.yaml | \
     kubectl apply -f -
   ```

3. Verify resource:
   ```bash
   kubectl get all -n prod -l app=my-app-api
   ```

**Estimated Recovery Time**: 15-30 minutes

### Scenario 4: Sealed Secrets Key Loss

**Impact**: Cannot decrypt sealed secrets

**Recovery Steps**:

1. Restore sealed secrets keys from backup:
   ```bash
   tar xzf /backups/platform-governance/backup-LATEST.tar.gz
   kubectl apply -f backup-*/secrets/sealed-secrets-keys.yaml
   ```

2. Restart sealed secrets controller:
   ```bash
   kubectl rollout restart deployment/sealed-secrets-controller -n sealed-secrets
   ```

3. Verify secrets can be decrypted:
   ```bash
   kubectl get sealedsecrets -A
   kubectl get secrets -A | grep sealed
   ```

**Estimated Recovery Time**: 10-15 minutes

### Scenario 5: Namespace Corruption

**Impact**: Specific namespace resources corrupted

**Recovery Steps**:

1. Backup current state (for rollback):
   ```bash
   kubectl get all,cm,secret,pvc -n prod -o yaml > /tmp/namespace-prod-backup.yaml
   ```

2. Delete namespace:
   ```bash
   kubectl delete namespace prod
   ```

3. Restore from backup:
   ```bash
   ./scripts/dr/restore.sh backup-LATEST --kubernetes-only
   ```

4. Verify restoration:
   ```bash
   kubectl get all -n prod
   kubectl get pods -n prod -w
   ```

**Estimated Recovery Time**: 1-2 hours

## Post-Restoration Verification

### Checklist

- [ ] All pods are running
- [ ] Services are accessible
- [ ] Database connectivity confirmed
- [ ] Metrics being collected
- [ ] Logs flowing to Loki
- [ ] Alerts configured in Prometheus
- [ ] Sealed secrets decrypting correctly
- [ ] GitOps syncing (ArgoCD/Flux)

### Verification Commands

```bash
# Check pod status
kubectl get pods --all-namespaces | grep -v Running

# Check services
kubectl get svc --all-namespaces

# Test API endpoint
curl -f http://my-app-api.prod:8080/health

# Check database
psql -h $DATABASE_HOST -U $DATABASE_USER -d $DATABASE_NAME -c "SELECT version();"

# Check metrics
curl -f http://prometheus.observability:9090/-/ready

# Check logs
kubectl logs -n observability -l app=loki --tail=10

# Check GitOps
kubectl get kustomizations -A
kubectl get gitrepositories -A
```

### Smoke Tests

```bash
# Run automated smoke tests
./scripts/test/smoke-test.sh prod

# Manual API test
curl -X POST http://my-app-api.prod:8080/api/v1/validate \
  -H "Content-Type: application/json" \
  -d '{"name":"prod-my-app-deploy-v1.0.0","type":"deployment"}'
```

## Backup Retention Policy

- **Daily backups**: 30 days
- **Weekly backups**: 90 days (first backup of week)
- **Monthly backups**: 1 year (first backup of month)
- **Yearly backups**: 7 years (compliance requirement)

## Testing

### Quarterly DR Tests

Perform full disaster recovery test quarterly:

1. Create test cluster
2. Restore from production backup
3. Verify all services
4. Document issues and timing
5. Update runbook

### Backup Verification

Verify backup integrity weekly:

```bash
# Automated verification script
./scripts/dr/verify-backup.sh backup-LATEST
```

## Escalation

If restoration fails:

1. **L1 Support**: platform-team@example.com
2. **L2 On-Call**: oncall@example.com (24/7)
3. **L3 Engineering**: engineering-leads@example.com
4. **Vendor Support**: Contact cloud provider support

## Related Documents

- [Architecture Documentation](../architecture.md)
- [Operations Runbook](./operations.md)
- [Incident Response](./incident-response.md)
- [Security Policy](../../SECURITY.md)

---

Last updated: 2025-10-27
