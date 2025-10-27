# Development Guide

Complete guide for setting up and working with the Platform Governance monorepo.

## Table of Contents

- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Local Development](#local-development)
- [Testing](#testing)
- [Deployment](#deployment)
- [Troubleshooting](#troubleshooting)

## Quick Start

### Prerequisites

Ensure you have the following tools installed:

```bash
# Check versions
go version        # Should be 1.21+
node --version    # Should be 20.x+
pnpm --version    # Should be 8.14.0+
docker --version  # Should be 24.0+
kubectl version   # Should be 1.28+
helm version      # Should be 3.13+
```

### Initial Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/example/platform-governance.git
   cd platform-governance
   ```

2. **Run setup script**:
   ```bash
   ./scripts/bootstrap/setup-env.sh
   ```

   This script will:
   - Install pre-commit hooks
   - Verify prerequisites
   - Set up development tools
   - Generate local certificates (if needed)

3. **Install dependencies**:
   ```bash
   # Using Make
   make deps

   # Or manually
   cd apps/my-app && go mod download
   cd apps/auto-fix-bot && go mod download
   cd apps/my-app/web && pnpm install
   ```

4. **Build all components**:
   ```bash
   make build
   ```

## Project Structure

```
platform-governance/
├── .config/                    # Policy configurations
│   ├── conftest/              # Conftest policies
│   ├── kyverno/               # Kyverno ClusterPolicies
│   └── policy/                # OPA & Gatekeeper policies
├── .github/
│   ├── actions/               # Custom GitHub Actions
│   └── workflows/             # CI/CD workflows
├── apps/
│   ├── auto-fix-bot/          # Auto-fix bot application
│   │   ├── cmd/               # Application entry points
│   │   ├── internal/          # Private application code
│   │   └── go.mod             # Go dependencies
│   └── my-app/                # Main application
│       ├── cmd/api/           # API service
│       ├── db/migrations/     # Database migrations
│       ├── docker/            # Dockerfiles
│       ├── internal/          # Private application code
│       ├── node-runtime/      # Node.js runtime service
│       ├── tests/             # All tests
│       └── web/               # Angular frontend
├── deploy/
│   ├── helm/                  # Helm charts
│   │   ├── my-app-api/
│   │   ├── my-app-web/
│   │   └── artifact-gateway/
│   └── kustomize/             # Kustomize configs
│       ├── base/              # Base manifests
│       └── overlays/          # Environment overlays
├── docs/                      # Documentation
│   ├── adr/                   # Architecture Decision Records
│   ├── compliance/            # Compliance documentation
│   └── runbooks/              # Operational runbooks
├── observability/
│   ├── alerts/                # Prometheus alert rules
│   └── dashboards/            # Grafana dashboards
├── ops/
│   ├── monitoring/            # Monitoring resources
│   ├── network-policies/      # NetworkPolicy manifests
│   ├── observability/         # Observability stack
│   ├── platform-config/       # Platform configurations
│   ├── progressive-delivery/  # Flagger configurations
│   ├── rbac/                  # RBAC resources
│   ├── secrets/               # Sealed Secrets
│   └── security/              # Falco and security tools
├── scripts/                   # Automation scripts
│   ├── auto-fix/              # Auto-fix scripts
│   ├── bootstrap/             # Setup scripts
│   ├── deploy/                # Deployment scripts
│   ├── gate/                  # Deployment gates
│   ├── naming/                # Naming validation
│   ├── security/              # Security scripts
│   └── test/                  # Test scripts
├── Makefile                   # Build automation
├── Taskfile.yml               # Task runner config
└── README.md                  # Project overview
```

## Local Development

### Running the API Locally

```bash
# Set environment variables
export DATABASE_HOST=localhost
export DATABASE_PORT=5432
export DATABASE_USER=postgres
export DATABASE_PASSWORD=password
export DATABASE_NAME=platform_governance
export PORT=8080
export LOG_LEVEL=debug

# Run the API
cd apps/my-app
go run ./cmd/api
```

### Running the Web UI Locally

```bash
cd apps/my-app/web

# Development server
pnpm start

# Navigate to http://localhost:4200
```

### Running with Docker Compose

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

### Database Migrations

```bash
# Run migrations
psql -h localhost -U postgres -d platform_governance -f apps/my-app/db/migrations/001_initial_schema.sql
psql -h localhost -U postgres -d platform_governance -f apps/my-app/db/migrations/002_add_sbom_tracking.sql

# Verify migrations
psql -h localhost -U postgres -d platform_governance -c "\dt"
```

### Working with Kubernetes Locally

#### Using kind (Kubernetes in Docker)

```bash
# Create cluster
kind create cluster --name platform-governance

# Load images
kind load docker-image my-app-api:latest --name platform-governance

# Apply manifests
kubectl apply -k deploy/kustomize/overlays/dev
```

#### Using minikube

```bash
# Start minikube
minikube start --cpus=4 --memory=8192

# Use minikube docker
eval $(minikube docker-env)

# Build images
docker build -t my-app-api:latest -f apps/my-app/docker/api.Dockerfile .

# Apply manifests
kubectl apply -k deploy/kustomize/overlays/dev
```

## Testing

### Unit Tests

```bash
# Go tests
cd apps/my-app
go test ./... -v -cover

# TypeScript tests
cd apps/my-app/web
pnpm test

# With coverage report
pnpm test --coverage
```

### Integration Tests

```bash
# Run integration tests
./scripts/test/integration-test.sh

# Run specific integration test
cd apps/my-app
go test -v ./tests/integration -run TestNamingValidation
```

### End-to-End Tests

```bash
# Run e2e tests
cd apps/my-app/web
pnpm e2e

# Run e2e tests headless
pnpm e2e:ci
```

### Security Tests

```bash
# Run all security scans
make security

# Individual scans
./scripts/security/scan-trivy.sh
./scripts/security/scan-gitleaks.sh
./scripts/security/scan-image.sh my-app-api:latest
```

### Load Tests

```bash
# Run load tests
./scripts/test/load-test.sh http://localhost:8080
```

## Policy Testing

### Testing OPA Policies

```bash
# Test naming policy
opa test .config/policy/naming.rego .config/policy/naming_test.rego -v

# Evaluate policy against input
echo '{"kind":"Deployment","metadata":{"name":"prod-my-app-deploy-v1.0.0"}}' | \
  opa eval -d .config/policy/naming.rego -I 'data.naming.deny'
```

### Testing Conftest Policies

```bash
# Test against manifests
conftest test deploy/kustomize/base/deployment.yaml \
  -p .config/conftest/policies/

# Test with specific namespace
conftest test deploy/kustomize/base/deployment.yaml \
  -p .config/conftest/policies/ \
  --namespace security
```

### Testing Kyverno Policies

```bash
# Validate policies
kubectl kyverno validate .config/kyverno/

# Test policies
kubectl kyverno test .config/kyverno/naming-policy.yaml \
  --values deploy/kustomize/base/deployment.yaml
```

## Building and Packaging

### Build Docker Images

```bash
# Build API image
docker build -t my-app-api:latest \
  -f apps/my-app/docker/api.Dockerfile .

# Build web image
docker build -t my-app-web:latest \
  -f apps/my-app/docker/web.Dockerfile .

# Build with build args
docker build --build-arg VERSION=1.0.0 \
  -t my-app-api:1.0.0 \
  -f apps/my-app/docker/api.Dockerfile .
```

### Build Helm Charts

```bash
# Lint chart
helm lint deploy/helm/my-app-api

# Package chart
helm package deploy/helm/my-app-api

# Test chart
helm install my-app-test deploy/helm/my-app-api \
  --dry-run --debug \
  --values deploy/helm/my-app-api/values-dev.yaml
```

### Generate SBOMs

```bash
# Generate SBOM with Syft
./scripts/security/gen-sbom.sh my-app-api:latest

# View SBOM
cat my-app-api-sbom.json | jq '.packages[].name'
```

## Deployment

### Deploy to Development

```bash
# Using Helm
helm upgrade --install my-app-dev \
  deploy/helm/my-app-api/ \
  --namespace dev \
  --values deploy/helm/my-app-api/values.yaml \
  --set image.tag=latest

# Using Kustomize
kubectl apply -k deploy/kustomize/overlays/dev
```

### Deploy to Staging

```bash
./scripts/deploy/deploy.sh staging v1.0.0
```

### Deploy to Production

```bash
# Check deployment gates
./scripts/gate/check-freeze.sh

# Verify attestations
./scripts/security/verify-provenance.sh my-app-api:v1.0.0

# Deploy
./scripts/deploy/deploy.sh prod v1.0.0

# Or use workflow
gh workflow run deploy.yaml \
  -f environment=prod \
  -f version=v1.0.0
```

## Troubleshooting

### Common Issues

#### Go Build Failures

```bash
# Clean go cache
go clean -cache -modcache -testcache

# Re-download dependencies
rm go.sum
go mod download
go mod tidy
```

#### Node/pnpm Issues

```bash
# Clear pnpm cache
pnpm store prune

# Remove node_modules and reinstall
rm -rf node_modules pnpm-lock.yaml
pnpm install
```

#### Docker Build Issues

```bash
# Clean docker build cache
docker builder prune -a

# Build without cache
docker build --no-cache -t my-app-api:latest \
  -f apps/my-app/docker/api.Dockerfile .
```

#### Kubernetes Deployment Issues

```bash
# View pod logs
kubectl logs -n dev -l app=my-app-api --tail=100

# Describe pod for events
kubectl describe pod -n dev <pod-name>

# Check events
kubectl get events -n dev --sort-by='.lastTimestamp'

# Port-forward for debugging
kubectl port-forward -n dev svc/my-app-api 8080:8080
```

### Debugging

#### Enable Debug Logging

```bash
# Go application
export LOG_LEVEL=debug

# Angular application
ng serve --verbose
```

#### Attach Debugger

**VSCode** - `.vscode/launch.json`:
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug API",
      "type": "go",
      "request": "launch",
      "mode": "debug",
      "program": "${workspaceFolder}/apps/my-app/cmd/api",
      "env": {
        "PORT": "8080",
        "LOG_LEVEL": "debug"
      }
    }
  ]
}
```

### Performance Profiling

```bash
# Go CPU profile
go test -cpuprofile=cpu.prof -bench=.
go tool pprof cpu.prof

# Go memory profile
go test -memprofile=mem.prof -bench=.
go tool pprof mem.prof

# Angular bundle analysis
cd apps/my-app/web
pnpm build --stats-json
npx webpack-bundle-analyzer dist/stats.json
```

## Useful Commands

### Makefile Targets

```bash
make help          # Show all available targets
make build         # Build all components
make test          # Run all tests
make lint          # Run all linters
make security      # Run security scans
make clean         # Clean build artifacts
make deps          # Install dependencies
```

### Task Targets

```bash
task --list        # List all tasks
task build:api     # Build API only
task build:web     # Build web UI only
task test:unit     # Run unit tests
task test:integration  # Run integration tests
```

## Additional Resources

- [Architecture Documentation](./architecture.md)
- [API Documentation](../apps/my-app/repo/api/openapi.yaml)
- [ADRs](./adr/)
- [Runbooks](./runbooks/)
- [Contributing Guide](../CONTRIBUTING.md)
- [Security Policy](../SECURITY.md)

## Getting Help

- **GitHub Discussions**: Ask questions and discuss ideas
- **Slack**: #platform-governance
- **Email**: platform-team@example.com

---

Last updated: 2025-10-27
