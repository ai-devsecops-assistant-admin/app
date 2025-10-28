# GitHub Codespaces Configuration

This directory contains the configuration for GitHub Codespaces to provide a fully-featured development environment for the Platform Governance project.

## What's Included

### Development Tools
- **Go 1.21+**: Backend development
- **Node.js 20+**: Frontend development with pnpm
- **Docker**: Container management and builds
- **Kubernetes Tools**: kubectl, helm, and minikube
- **GitHub CLI**: For GitHub operations

### Security & DevOps Tools
- **golangci-lint**: Go code linting
- **Trivy**: Container vulnerability scanning
- **Conftest**: Policy testing
- **Cosign**: Container signing
- **Syft**: SBOM generation
- **OPA**: Policy enforcement
- **Gitleaks**: Secret scanning

### VS Code Extensions
- Go language support
- ESLint and Prettier
- Docker and Kubernetes tools
- GitHub Copilot
- YAML support

## Getting Started

### 1. Open in Codespaces

Click the "Code" button on GitHub and select "Create codespace on [branch]"

### 2. Authenticate with GitHub

After the Codespace starts, authenticate with GitHub CLI:

```bash
gh auth login
```

Follow the prompts to authenticate. This is **required** for:
- Pushing commits
- Creating pull requests
- Accessing private repositories
- Using GitHub APIs

### 3. Verify Setup

Check that all tools are installed:

```bash
make help
```

### 4. Build the Project

```bash
make build
```

### 5. Run Tests

```bash
make test
```

## Troubleshooting

### GitHub Authentication Issues

If you see authentication errors:

1. **Check authentication status**:
   ```bash
   gh auth status
   ```

2. **Re-authenticate if needed**:
   ```bash
   gh auth login
   ```

3. **Use HTTPS instead of SSH**:
   ```bash
   git config --global url."https://github.com/".insteadOf git@github.com:
   ```

### Container Build Fails

If the devcontainer fails to build:

1. Check the build logs in the Codespaces creation panel
2. Ensure you have access to the repository
3. Try rebuilding the container: `Cmd/Ctrl + Shift + P` → "Codespaces: Rebuild Container"

### Missing Tools

If a tool is missing after setup:

1. Rebuild the container (see above)
2. Manually run the post-create script:
   ```bash
   bash .devcontainer/post-create.sh
   ```

### Git Configuration Issues

If git operations fail:

```bash
git config --global --add safe.directory /workspace
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

## Port Forwarding

The following ports are automatically forwarded:

- **3000**: Web UI (development server)
- **4200**: Angular development server
- **8080**: API Server
- **9090**: Prometheus

## Environment Variables

The following environment variables are configured:

- `GITHUB_TOKEN`: Automatically set from your GitHub authentication
- `PATH`: Includes Go and local bin directories
- `GOPATH`: Set to `/home/vscode/go`

## Customization

### Adding VS Code Extensions

Edit `devcontainer.json`:

```json
"customizations": {
  "vscode": {
    "extensions": [
      "your.extension.id"
    ]
  }
}
```

### Adding System Packages

Edit `Dockerfile`:

```dockerfile
RUN apt-get update && apt-get install -y \
    your-package-name \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*
```

### Adding Node Packages

Edit `post-create.sh` to add global npm/pnpm packages.

## Performance Tips

1. **Use shallow clones**: The devcontainer is optimized for development, not full history
2. **Close unused tabs**: Save resources in the browser
3. **Use terminal multiplexing**: tmux or screen are pre-installed
4. **Pause when not in use**: Codespaces automatically pause after inactivity

## Support

For issues with:
- **Codespaces**: [GitHub Codespaces Documentation](https://docs.github.com/en/codespaces)
- **Project setup**: See main [README.md](../README.md)
- **Contributing**: See [CONTRIBUTING.md](../CONTRIBUTING.md)

## Related Documentation

- [GitHub Codespaces Docs](https://docs.github.com/en/codespaces)
- [Dev Container Specification](https://containers.dev/)
- [VS Code Remote Development](https://code.visualstudio.com/docs/remote/remote-overview)
