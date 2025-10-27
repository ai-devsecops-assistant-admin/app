# ADR 003: Policy as Code with Open Policy Agent

## Status
Accepted

## Context
Infrastructure and application governance requires:
- Consistent policy enforcement across environments
- Version-controlled policy definitions
- Automated policy validation
- Policy decision auditability
- Separation of policy from application logic

## Decision
Adopt Open Policy Agent (OPA) as the primary policy engine with multiple enforcement points.

### Enforcement Points
1. **Pre-commit**: Conftest validation of manifests
2. **CI/CD Pipeline**: OPA policy checks in workflows
3. **Admission Control**: Gatekeeper for runtime enforcement
4. **Application Runtime**: OPA sidecar for authorization

### Policy Domains
1. **Naming Conventions**: Resource naming compliance
2. **Security**: Pod security standards, network policies
3. **Resource Limits**: CPU/memory requirements
4. **Compliance**: Regulatory requirements (SOC2, ISO 27001)
5. **Cost Governance**: Resource quota and limits

## Consequences

### Positive
- Declarative policy definitions (Rego language)
- Version control for policies (GitOps)
- Automated enforcement with fast feedback
- Decision logging for compliance audits
- Reusable policy libraries

### Negative
- Learning curve for Rego language
- Performance overhead in admission control
- Policy maintenance overhead
- Testing complexity

## References
- [OPA Documentation](https://www.openpolicyagent.org/docs/)
- [Gatekeeper Documentation](https://open-policy-agent.github.io/gatekeeper/)
- [Conftest Documentation](https://www.conftest.dev/)
