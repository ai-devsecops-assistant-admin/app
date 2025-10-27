#!/usr/bin/env bash
set -euo pipefail

echo "Installing development tools..."

# Install golangci-lint
if ! command -v golangci-lint &> /dev/null; then
    echo "Installing golangci-lint..."
    curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin latest
fi

# Install Conftest
if ! command -v conftest &> /dev/null; then
    echo "Installing Conftest..."
    wget -O - https://github.com/open-policy-agent/conftest/releases/download/v0.47.0/conftest_0.47.0_Linux_x86_64.tar.gz | tar xz
    sudo mv conftest /usr/local/bin/
fi

# Install Trivy
if ! command -v trivy &> /dev/null; then
    echo "Installing Trivy..."
    wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
    echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
    sudo apt-get update && sudo apt-get install trivy
fi

# Install Cosign
if ! command -v cosign &> /dev/null; then
    echo "Installing Cosign..."
    wget "https://github.com/sigstore/cosign/releases/download/v2.2.2/cosign-linux-amd64"
    sudo mv cosign-linux-amd64 /usr/local/bin/cosign
    sudo chmod +x /usr/local/bin/cosign
fi

# Install Syft
if ! command -v syft &> /dev/null; then
    echo "Installing Syft..."
    curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin
fi

echo "All tools installed successfully!"
