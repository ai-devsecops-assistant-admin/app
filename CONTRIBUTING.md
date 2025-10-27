# Contributing to Platform Governance

Thank you for your interest in contributing to the Platform Governance project! This document provides guidelines and instructions for contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Testing Requirements](#testing-requirements)
- [Commit Guidelines](#commit-guidelines)
- [Pull Request Process](#pull-request-process)
- [Security](#security)

## Code of Conduct

This project adheres to a code of conduct that all contributors are expected to follow:

- Be respectful and inclusive
- Welcome newcomers and help them get started
- Focus on constructive feedback
- Prioritize the community and project goals

## Getting Started

### Prerequisites

Before you begin, ensure you have the following installed:

- **Go** 1.21 or later
- **Node.js** 20.x or later
- **pnpm** 8.14.0 or later
- **Docker** 24.0 or later
- **kubectl** 1.28 or later
- **Helm** 3.13 or later
- **Make** and **Task** (optional but recommended)

### Setting Up Your Development Environment

1. **Fork and clone the repository**:
   ```bash
   git clone https://github.com/YOUR-USERNAME/platform-governance.git
   cd platform-governance
   ```

2. **Run the setup script**:
   ```bash
   ./scripts/bootstrap/setup-env.sh
   ```

3. **Install dependencies**:
   ```bash
   # Go dependencies
   cd apps/my-app && go mod download
   cd apps/auto-fix-bot && go mod download

   # Node.js dependencies
   cd apps/my-app/web && pnpm install
   ```

4. **Install pre-commit hooks**:
   ```bash
   git config core.hooksPath .githooks
   ```

## Development Workflow

### Branch Naming Convention

Use the following branch naming conventions:

- `feature/description` - New features
- `fix/description` - Bug fixes
- `docs/description` - Documentation updates
- `refactor/description` - Code refactoring
- `test/description` - Test improvements

### Local Development

1. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** following our coding standards

3. **Run tests locally**:
   ```bash
   make test          # Run all tests
   make lint          # Run linters
   make security      # Run security scans
   ```

4. **Build the project**:
   ```bash
   make build
   ```

## Coding Standards

### Go Code

- Follow [Effective Go](https://golang.org/doc/effective_go.html) guidelines
- Use `gofmt` for formatting
- Run `golangci-lint` before committing
- Maintain test coverage above 80%
- Document all exported functions and types

Example:
```go
// ValidateNaming validates resource naming against platform conventions.
// Returns a ValidationResult with details about compliance.
func ValidateNaming(resourceName string) (*ValidationResult, error) {
    // Implementation
}
```

### TypeScript/Angular Code

- Follow [Angular Style Guide](https://angular.io/guide/styleguide)
- Use strict TypeScript mode
- Run `eslint` and `prettier` before committing
- Maintain test coverage above 80%
- Use meaningful variable and function names

### YAML/Kubernetes Manifests

- Use 2-space indentation
- Follow [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- Always include resource limits and requests
- Use security contexts (runAsNonRoot, readOnlyRootFilesystem)
- Follow naming convention: `^(dev|staging|prod)-[a-z0-9-]+-(deploy|svc|ing|cm|secret)-v\d+\.\d+\.\d+`

## Testing Requirements

All contributions must include appropriate tests:

### Unit Tests

- Test individual functions and methods
- Mock external dependencies
- Aim for >80% code coverage

```bash
# Go unit tests
cd apps/my-app && go test ./... -v -cover

# TypeScript unit tests
cd apps/my-app/web && pnpm test
```

### Integration Tests

- Test component interactions
- Use test databases/services
- Clean up resources after tests

```bash
./scripts/test/integration-test.sh
```

### Security Tests

- Run security scanners
- Check for vulnerabilities
- Validate policies

```bash
make security
```

## Commit Guidelines

We follow [Conventional Commits](https://www.conventionalcommits.org/) specification:

### Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks
- `security`: Security improvements

### Examples

```
feat(api): add naming validation endpoint

Implement POST /api/v1/validate endpoint for resource naming
validation. Includes support for all Kubernetes resource types.

Closes #123
```

```
fix(ui): resolve dashboard metrics loading issue

Fix race condition in metrics fetching that caused intermittent
loading failures. Add retry logic with exponential backoff.

Fixes #456
```

### Commit Signing

All commits must be signed with GPG:

```bash
git config --global commit.gpgsign true
git config --global user.signingkey YOUR_GPG_KEY_ID
```

## Pull Request Process

### Before Submitting

1. Ensure all tests pass
2. Update documentation
3. Run linters and formatters
4. Verify security scans are clean
5. Rebase on latest main branch

### PR Title Format

Use the same format as commit messages:

```
feat(api): add naming validation endpoint
```

### PR Description Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Security
- [ ] Security scans pass
- [ ] No sensitive data exposed
- [ ] Dependencies updated

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex logic
- [ ] Documentation updated
- [ ] No new warnings generated
- [ ] Tests added/updated
- [ ] All CI checks pass
```

### Review Process

1. At least one approval required from maintainers
2. All CI checks must pass
3. No unresolved conversations
4. Up-to-date with main branch
5. Commits are signed

### After Approval

1. Squash commits if requested
2. Ensure CI is green
3. Maintainer will merge

## Security

- **Never commit secrets** or sensitive data
- Report security vulnerabilities to security@example.com
- See [SECURITY.md](SECURITY.md) for more details
- Use Sealed Secrets for Kubernetes secrets

## Documentation

- Update relevant documentation with your changes
- Add JSDoc/GoDoc comments for new functions
- Update README if adding new features
- Add ADRs for significant architectural decisions

## Questions?

- Open a discussion in GitHub Discussions
- Join our Slack channel: #platform-governance
- Email: platform-team@example.com

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.

---

Thank you for contributing to Platform Governance!
