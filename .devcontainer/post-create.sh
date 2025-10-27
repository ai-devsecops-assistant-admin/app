#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Setting up development environment..."

# Create necessary directories
mkdir -p bin/ .cache/ logs/

# Configure Git
echo "📝 Configuring Git..."
git config --global --add safe.directory /workspace

# Check if GitHub authentication is available
echo "🔐 Checking GitHub authentication..."
if command -v gh &> /dev/null; then
    if gh auth status &> /dev/null; then
        echo "✅ GitHub CLI authenticated successfully"
    else
        echo "⚠️  GitHub CLI not authenticated. Please run: gh auth login"
        echo "   This is required for GitHub operations in Codespaces"
    fi
else
    echo "⚠️  GitHub CLI not found. Installing..."
fi

# Install Go dependencies for main app
echo "📦 Installing Go dependencies for my-app..."
if [ -f "apps/my-app/go.mod" ]; then
    cd apps/my-app
    go mod download
    cd /workspace
fi

# Install Go dependencies for auto-fix-bot
echo "📦 Installing Go dependencies for auto-fix-bot..."
if [ -f "apps/auto-fix-bot/go.mod" ]; then
    cd apps/auto-fix-bot
    go mod download
    cd /workspace
fi

# Install pnpm dependencies for web UI
echo "📦 Installing Node.js dependencies..."
if [ -f "apps/my-app/web/package.json" ]; then
    cd apps/my-app/web
    pnpm install
    cd /workspace
fi

# Set up Git hooks
echo "🎣 Setting up Git hooks..."
if [ -d ".git" ]; then
    mkdir -p .git/hooks
    cat > .git/hooks/pre-commit << 'HOOKEOF'
#!/usr/bin/env bash
set -e

echo "Running pre-commit checks..."

# Run Conftest on Kubernetes manifests
if command -v conftest >/dev/null 2>&1; then
    if [ -d "deploy" ]; then
        echo "Testing Kubernetes manifests with Conftest..."
        conftest test deploy/ -p .config/conftest/policies/ || exit 1
    fi
fi

# Run linters
echo "Running linters..."
make lint || exit 1

echo "✅ Pre-commit checks passed!"
HOOKEOF
    chmod +x .git/hooks/pre-commit
    echo "✅ Git hooks configured"
fi

# Verify tool installations
echo "🔍 Verifying tool installations..."
tools=("go" "node" "pnpm" "docker" "kubectl" "helm" "golangci-lint" "conftest" "trivy" "cosign" "syft" "opa" "gitleaks" "gh")
missing_tools=()

for tool in "${tools[@]}"; do
    if command -v "$tool" &> /dev/null; then
        echo "  ✅ $tool"
    else
        echo "  ❌ $tool (missing)"
        missing_tools+=("$tool")
    fi
done

if [ ${#missing_tools[@]} -eq 0 ]; then
    echo ""
    echo "🎉 All tools installed successfully!"
else
    echo ""
    echo "⚠️  Missing tools: ${missing_tools[*]}"
    echo "   Some features may not work correctly"
fi

# Display helpful information
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✨ Development environment setup complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📚 Available commands:"
echo "  make help              - Show all available make targets"
echo "  make build             - Build all components"
echo "  make test              - Run all tests"
echo "  make lint              - Run linters"
echo "  make security          - Run security scans"
echo ""
echo "🔐 GitHub Authentication:"
echo "  gh auth status         - Check authentication status"
echo "  gh auth login          - Authenticate with GitHub"
echo ""
echo "📖 Documentation: docs/"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
