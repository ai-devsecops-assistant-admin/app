#!/bin/bash
set -e

echo "🚀 Running post-create setup..."

# Update Go dependencies
if [ -f "apps/my-app/go.mod" ]; then
    echo "📦 Updating Go dependencies..."
    cd apps/my-app && go mod download && cd ../..
fi

# Install npm dependencies for web UI
if [ -f "apps/my-app/web/package.json" ]; then
    echo "📦 Installing web UI dependencies..."
    cd apps/my-app/web && pnpm install && cd ../../..
fi

# Install auto-fix-bot dependencies
if [ -f "apps/auto-fix-bot/go.mod" ]; then
    echo "📦 Installing auto-fix-bot dependencies..."
    cd apps/auto-fix-bot && go mod download && cd ../..
fi

# Setup Git configuration
echo "🔧 Setting up Git..."
git config --global --add safe.directory /workspace || true
git config --global init.defaultBranch main || true

# Install additional Go tools
echo "🛠️  Installing Go development tools..."
go install golang.org/x/tools/cmd/goimports@latest || true
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest || true

# Create necessary directories
echo "📁 Creating project directories..."
mkdir -p apps/my-app/bin
mkdir -p apps/auto-fix-bot/bin
mkdir -p .cache

# Set permissions
echo "🔐 Setting permissions..."
chmod -R 755 scripts/ || true

# Display environment info
echo ""
echo "✅ Post-create setup complete!"
echo ""
echo "Environment Info:"
echo "  Go:      $(go version 2>/dev/null || echo 'not found')"
echo "  Node:    $(node --version 2>/dev/null || echo 'not found')"
echo "  pnpm:    $(pnpm --version 2>/dev/null || echo 'not found')"
echo "  kubectl: $(kubectl version --client --short 2>/dev/null || echo 'not found')"
echo "  Helm:    $(helm version --short 2>/dev/null || echo 'not found')"
echo ""
echo "🎉 Ready to start developing!"
