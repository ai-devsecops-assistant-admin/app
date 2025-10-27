# ADR 001: Naming Convention Standard

## Status
Accepted

## Context
Kubernetes resources across multiple environments require consistent naming to enable:
- Automated governance and compliance
- Clear resource identification and ownership
- Version tracking and rollback capabilities
- Environment segregation
- Audit and compliance reporting

## Decision
Adopt the following naming pattern for all Kubernetes resources:

```
^(dev|staging|prod)-[a-z0-9-]+-(deploy|svc|ing|cm|secret)-v\d+\.\d+\.\d+(-[A-Za-z0-9]+)?$
```

### Pattern Components
1. **Environment Prefix**: `dev`, `staging`, or `prod`
2. **Application Identifier**: Lowercase alphanumeric with hyphens
3. **Resource Type Suffix**: `deploy`, `svc`, `ing`, `cm`, `secret`
4. **Semantic Version**: `vMAJOR.MINOR.PATCH`
5. **Optional Build Metadata**: Alphanumeric suffix

### Examples
- `prod-my-app-api-deploy-v1.0.0`
- `staging-payment-gateway-svc-v2.1.0`
- `dev-auth-service-ing-v0.1.0-alpha`

## Consequences

### Positive
- Automated policy enforcement via OPA/Conftest/Kyverno
- Clear environment segregation
- Version tracking built into resource names
- Simplified audit and compliance reporting
- Auto-fix bot can suggest compliant names

### Negative
- Name length constraints (Kubernetes 253 char limit)
- Migration effort for existing resources
- Potential breaking changes in legacy systems

## Enforcement
1. **Pre-commit**: Conftest validation
2. **CI/CD**: Pipeline checks with failure on violations
3. **Admission Control**: Kyverno/Gatekeeper policies
4. **Monitoring**: Prometheus metrics and Grafana dashboards

## SLA Targets
- Naming Compliance Rate (NCR): ≥ 95%
- Violation Fix Cycles (VFC): ≤ 48 hours
- Manual Fix Rate (MFR): ≤ 20%
- Auto-Remediation Success (ARS): ≥ 80%
