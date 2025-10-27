# Incident Response Runbook

## Overview
This runbook provides step-by-step procedures for responding to common incidents in the Platform Governance system.

## Severity Levels

| Level | Description | Response Time | Examples |
|-------|-------------|---------------|----------|
| P0 | Critical | < 15 minutes | Complete outage, data breach |
| P1 | High | < 1 hour | Partial outage, security vulnerability |
| P2 | Medium | < 4 hours | Performance degradation |
| P3 | Low | < 24 hours | Minor issues, feature requests |

## Common Incidents

### High Naming Violation Rate

**Alert**: `NamingComplianceRateCritical`

**Investigation**:
```bash
# Check current compliance rate
kubectl exec -it prometheus-0 -- promtool query instant \
  'http://localhost:9090' \
  '100 * (1 - (sum(naming_compliance_violations_total) / sum(naming_compliance_resources_total)))'

# List recent violations
kubectl logs -l app=naming-validator --tail=100
```

**Resolution**:
1. Identify source of non-compliant resources
2. Run manual naming validation
3. Generate suggested names
4. Create bulk fix PR
5. Monitor compliance rate recovery

### Container Vulnerability Detection

**Alert**: `HighSeverityVulnerabilitiesDetected`

**Investigation**:
```bash
# Scan specific image
trivy image --severity CRITICAL,HIGH registry.example.com/my-app-api:v1.0.0

# Check SBOM
cosign download sbom registry.example.com/my-app-api:v1.0.0 | jq .
```

**Resolution**:
1. Assess vulnerability impact
2. Update base images or dependencies
3. Rebuild and scan
4. Deploy patched version
5. Verify vulnerability resolved

### Deployment Failure

**Investigation**:
```bash
# Check pod status
kubectl get pods -n <namespace>

# View pod events
kubectl describe pod <pod-name> -n <namespace>

# Check pod logs
kubectl logs <pod-name> -n <namespace>
```

**Resolution**: Based on error type (ImagePullBackOff, CrashLoopBackOff, Admission Denial)

## Escalation Contacts

| Role | Contact | Escalation Time |
|------|---------|-----------------|
| On-Call Engineer | PagerDuty | Immediate |
| Platform Lead | Slack @platform-lead | P0: Immediate, P1: 30m |
| Security Team | security@example.com | Security incidents: Immediate |
