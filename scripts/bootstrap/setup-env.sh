#!/usr/bin/env bash
set -euo pipefail

echo "Setting up development environment..."

# Check prerequisites
command -v go >/dev/null 2>&1 || { echo "Go is required but not installed"; exit 1; }
command -v node >/dev/null 2>&1 || { echo "Node.js is required but not installed"; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "Docker is required but not installed"; exit 1; }

# Create necessary directories
mkdir -p bin/
mkdir -p .cache/
mkdir -p logs/

# Set up Git hooks
if [ -d ".git" ]; then
    echo "Setting up Git hooks..."
    cat > .git/hooks/pre-commit << 'HOOKEOF'
#!/usr/bin/env bash
set -e

echo "Running pre-commit checks..."

# Run Conftest on Kubernetes manifests
if command -v conftest >/dev/null 2>&1; then
    if [ -d "deploy" ]; then
        conftest test deploy/ -p .config/conftest/policies/ || exit 1
    fi
fi

# Run linters
make lint || exit 1

echo "Pre-commit checks passed!"
HOOKEOF
    chmod +x .git/hooks/pre-commit
fi

echo "Development environment setup complete!"
