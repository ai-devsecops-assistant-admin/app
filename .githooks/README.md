# Git Hooks

Custom Git hooks for the Platform Governance project.

## Setup

To enable these hooks, run:

```bash
git config core.hooksPath .githooks
```

Or run the setup script:

```bash
./scripts/bootstrap/setup-env.sh
```

## Available Hooks

### pre-commit

Runs before every commit to validate code quality and prevent common issues.

**Checks performed**:

1. **Branch Protection**: Prevents direct commits to main/master
2. **Secret Scanning**: Uses gitleaks to detect secrets
3. **Go Validation**:
   - Code formatting (gofmt)
   - Linting (golangci-lint)
   - Unit tests
4. **TypeScript Validation**:
   - Linting (ESLint)
5. **YAML Validation**:
   - Syntax validation
   - Naming convention compliance (Conftest)
6. **Shell Script Validation**:
   - ShellCheck linting
   - Executable permission check
7. **Commit Message Format**: Conventional Commits validation
8. **File Size Check**: Prevents large files (>1MB)

**Bypass (NOT RECOMMENDED)**:

```bash
git commit --no-verify
```

## Prerequisites

For full functionality, install:

- **gitleaks**: Secret scanning
- **golangci-lint**: Go linting
- **yamllint**: YAML validation
- **shellcheck**: Shell script validation
- **conftest**: Policy validation

Optional:
- **npx/eslint**: TypeScript linting (requires npm)

## Troubleshooting

### Hook not running

Check if hooks are enabled:

```bash
git config core.hooksPath
# Should output: .githooks
```

### Permission denied

Make hook executable:

```bash
chmod +x .githooks/pre-commit
```

### Tool not found

Install missing prerequisites:

```bash
# macOS
brew install gitleaks golangci-lint yamllint shellcheck

# Linux
# Follow installation guides for each tool
```

## Customization

Edit `.githooks/pre-commit` to modify checks or add new ones.

## Related

- [Contributing Guide](../CONTRIBUTING.md)
- [Development Guide](../docs/development-guide.md)
