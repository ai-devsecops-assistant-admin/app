# Deployment Procedures

## Overview
Standard operating procedures for deploying applications in the Platform Governance system.

## Pre-Deployment Checklist

- [ ] Code review approved
- [ ] All CI/CD checks passed
- [ ] Security scans clean
- [ ] SBOM generated
- [ ] SLSA provenance attached
- [ ] Image signed with Cosign
- [ ] Naming conventions validated
- [ ] Resource limits configured
- [ ] Rollback plan prepared

## Deployment Methods

### 1. Standard Deployment (Helm)

```bash
# Validate manifests
make validate ENV=prod

# Dry-run deployment
helm upgrade --install \
  --namespace prod \
  --values deploy/helm/my-app-api/values-prod.yaml \
  --dry-run \
  prod-my-app-api-v1.0.0 \
  deploy/helm/my-app-api/

# Deploy
helm upgrade --install \
  --namespace prod \
  --values deploy/helm/my-app-api/values-prod.yaml \
  --wait \
  --timeout 10m \
  prod-my-app-api-v1.0.0 \
  deploy/helm/my-app-api/
```

## Rollback Procedures

### Fast Rollback (Helm)

```bash
# List releases
helm history prod-my-app-api-v1.0.0 -n prod

# Rollback to previous revision
helm rollback prod-my-app-api-v1.0.0 -n prod
```

## Post-Deployment Verification

```bash
# Check pod health
kubectl get pods -n prod -l app=my-app-api

# Test health endpoints
curl -f https://api.example.com/health

# Run smoke tests
./scripts/test/smoke-test.sh prod
```

## Deployment Freeze Periods

- **End of Quarter**: Last 3 days of each quarter
- **Major Holidays**: Dec 24-26, Dec 31-Jan 2
- **Black Friday**: Nov 24-27

Emergency overrides require manager approval.
