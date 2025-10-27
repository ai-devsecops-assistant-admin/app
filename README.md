# Platform Governance Monorepo

[![CI](https://github.com/example/platform-governance/actions/workflows/ci.yaml/badge.svg)](https://github.com/example/platform-governance/actions/workflows/ci.yaml)
[![Security Scan](https://github.com/example/platform-governance/actions/workflows/security-scan.yaml/badge.svg)](https://github.com/example/platform-governance/actions/workflows/security-scan.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Enterprise DevSecOps Platform with automated governance, compliance, and security controls.

## Features

- **Auto-Fix Bot**: Automated detection and remediation of workflow, dependency, linting, and security issues
- **Naming Governance**: OPA/Conftest policy enforcement for Kubernetes resource naming
- **Supply Chain Security**: SBOM generation, SLSA Level 3 provenance, Cosign signing
- **Security Scanning**: Trivy, CodeQL, Semgrep, Gitleaks, Checkov, kube-bench
- **Policy as Code**: OPA, Conftest, Kyverno, Gatekeeper
- **Observability**: Prometheus, Grafana, Loki, Tempo with custom dashboards
- **Compliance**: SOC2, ISO 27001, CIS Kubernetes mapped controls

## Quick Start

### Prerequisites

- Go 1.21+
- Node.js 20+
- pnpm 8.14+
- Docker 24+
- Kubernetes 1.28+
- Helm 3.13+
- kubectl 1.28+

### Installation

```bash
# Clone repository
git clone https://github.com/example/platform-governance.git
cd platform-governance

# Bootstrap environment
make bootstrap

# Build all components
make build

# Run tests
make test

# Deploy to development
make deploy ENV=dev
```

## Architecture

See [Architecture Documentation](docs/architecture.md) for detailed system design.

## Project Structure

```
.
├── .github/                    # GitHub Actions workflows
├── .config/                    # Configuration files
│   ├── policy/                # OPA policies
│   ├── conftest/              # Conftest policies
│   └── security/              # Security configurations
├── apps/                      # Application code
│   ├── auto-fix-bot/          # Auto-fix bot service
│   └── my-app/                # Main application
│       ├── cmd/               # Binaries
│       ├── internal/          # Internal packages
│       ├── web/               # Angular frontend
│       ├── docker/            # Dockerfiles
│       ├── db/                # Database migrations
│       └── tests/             # Test suites
├── deploy/                    # Deployment manifests
│   ├── helm/                  # Helm charts
│   └── kustomize/             # Kustomize overlays
├── ops/                       # Operations resources
│   ├── rbac/                  # RBAC policies
│   ├── network-policies/      # NetworkPolicies
│   └── platform-config/       # Platform configuration
├── scripts/                   # Automation scripts
│   ├── bootstrap/             # Environment setup
│   ├── auto-fix/              # Auto-fix scripts
│   ├── naming/                # Naming validation
│   └── security/              # Security tools
├── observability/             # Monitoring configuration
│   ├── dashboards/            # Grafana dashboards
│   └── alerts/                # Prometheus rules
└── docs/                      # Documentation
    ├── adr/                   # Architecture Decision Records
    ├── runbooks/              # Operational runbooks
    └── compliance/            # Compliance documentation
```

## Naming Convention

All Kubernetes resources must follow the naming pattern:

```
^(dev|staging|prod)-[a-z0-9-]+-(deploy|svc|ing|cm|secret)-v\d+\.\d+\.\d+(-[A-Za-z0-9]+)?$
```

**Examples**:
- `prod-my-app-api-deploy-v1.0.0`
- `staging-payment-svc-v2.1.0`
- `dev-auth-ing-v0.1.0-alpha`

## SLA Targets

| Metric | Target | Description |
|--------|--------|-------------|
| NCR (Naming Compliance Rate) | ≥ 95% | Percentage of compliant resources |
| VFC (Violation Fix Cycles) | ≤ 48h | Time to fix violations |
| MFR (Manual Fix Rate) | ≤ 20% | Percentage requiring manual fixes |
| ARS (Auto-Remediation Success) | ≥ 80% | Auto-fix success rate |

## Development

### Building

```bash
# Build API service
make build-api

# Build web UI
make build-web

# Build all
make build
```

### Testing

```bash
# Run unit tests
make test-unit

# Run integration tests
make test-integration

# Run all tests
make test
```

### Security Scanning

```bash
# Run all security scans
make security

# Individual scans
make scan-trivy          # Container vulnerabilities
make scan-codeql         # Code analysis
make scan-semgrep        # SAST
make scan-gitleaks       # Secrets detection
```

## Deployment

### Helm Deployment

```bash
# Deploy to production
helm upgrade --install \
  --namespace prod \
  --values deploy/helm/my-app-api/values-prod.yaml \
  prod-my-app-api-v1.0.0 \
  deploy/helm/my-app-api/
```

## Monitoring

### Dashboards

- [Naming Compliance](https://grafana.example.com/d/naming-compliance)
- [Operations SLA](https://grafana.example.com/d/ops-sla-overview)
- [Security Overview](https://grafana.example.com/d/security-overview)

## Documentation

- [Architecture](docs/architecture.md)
- [ADR 001: Naming Convention](docs/adr/001-naming-convention-standard.md)
- [ADR 002: SLSA Level 3](docs/adr/002-slsa-level-3-adoption.md)
- [ADR 003: Policy as Code](docs/adr/003-policy-as-code-with-opa.md)
- [Incident Response Runbook](docs/runbooks/incident-response.md)
- [Deployment Procedures](docs/runbooks/deployment-procedures.md)
- [SOC2 Controls Mapping](docs/compliance/soc2-controls-mapping.md)

## License

MIT License - see [LICENSE](LICENSE) for details.

## Support

- Documentation: [docs/](docs/)
- Issues: [GitHub Issues](https://github.com/example/platform-governance/issues)
- Email: platform-team@example.com
