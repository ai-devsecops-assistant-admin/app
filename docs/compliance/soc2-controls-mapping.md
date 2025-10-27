# SOC2 Controls Mapping

## Overview
This document maps platform governance controls to SOC2 Trust Service Criteria.

## Common Criteria (CC)

### CC6: Logical and Physical Access

| Control ID | Description | Implementation | Evidence |
|------------|-------------|----------------|----------|
| CC6.1 | Access management | RBAC, ServiceAccounts | `ops/rbac/` manifests |
| CC6.2 | Authentication | OIDC, JWT tokens | Auth service logs |
| CC6.3 | Authorization | Kubernetes RBAC, OPA policies | Authorization decisions in logs |
| CC6.6 | Encryption | TLS, encryption at rest | Network policies, PVC encryption |
| CC6.7 | Secrets management | Kubernetes Secrets | Secrets inventory |

### CC7: System Operations

| Control ID | Description | Implementation | Evidence |
|------------|-------------|----------------|----------|
| CC7.1 | Change management | GitOps, PR approvals | Git history, ArgoCD sync logs |
| CC7.2 | Incident management | Runbooks, PagerDuty | Incident tickets, resolution times |
| CC7.3 | Capacity planning | HPA, resource monitoring | Prometheus metrics, scaling events |
| CC7.4 | Backup and recovery | Database backups | Backup logs, restore tests |

### CC8: Change Management

| Control ID | Description | Implementation | Evidence |
|------------|-------------|----------------|----------|
| CC8.1 | Change authorization | PR approvals, deployment gates | GitHub PR history |
| CC8.2 | Change design | ADRs, design reviews | `docs/adr/` |
| CC8.3 | Change testing | CI/CD tests, staging validation | Test results, pipeline logs |
| CC8.4 | Change deployment | Helm releases, GitOps sync | Helm history, ArgoCD logs |

## Evidence Collection

### Automated Evidence Generation

```bash
# Generate compliance report
./scripts/compliance/generate-report.sh --framework soc2 --period Q1-2025

# Collect audit logs
./scripts/compliance/collect-audit-logs.sh --start 2025-01-01 --end 2025-03-31
```

### Evidence Locations

| Evidence Type | Location | Retention |
|---------------|----------|-----------|
| Audit Logs | PostgreSQL `audit_logs` table | 7 years |
| Access Logs | Kubernetes API audit logs | 1 year |
| Change Logs | Git history | Permanent |
| Security Scans | `.github/security/` | 1 year |
| SBOMs | OCI registry | 3 years |
