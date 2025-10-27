# Use official Microsoft devcontainer base image with common utilities
FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Install system dependencies
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    build-essential \
    curl \
    git \
    wget \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    apt-transport-https \
    unzip \
    jq \
    vim \
    sudo \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install pnpm
RUN npm install -g pnpm@8.14.0

# Install additional security and DevOps tools
RUN curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b /usr/local/bin latest

# Install Conftest
RUN wget -O - https://github.com/open-policy-agent/conftest/releases/download/v0.47.0/conftest_0.47.0_Linux_x86_64.tar.gz | tar xz -C /usr/local/bin

# Install Trivy
RUN wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor -o /usr/share/keyrings/trivy.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | tee -a /etc/apt/sources.list.d/trivy.list \
    && apt-get update \
    && apt-get install -y trivy \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install Cosign
RUN wget "https://github.com/sigstore/cosign/releases/download/v2.2.2/cosign-linux-amd64" -O /usr/local/bin/cosign \
    && chmod +x /usr/local/bin/cosign

# Install Syft
RUN curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

# Install OPA
RUN curl -L -o /usr/local/bin/opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64 \
    && chmod +x /usr/local/bin/opa

# Install Gitleaks
RUN wget https://github.com/gitleaks/gitleaks/releases/download/v8.18.0/gitleaks_8.18.0_linux_x64.tar.gz \
    && tar -xzf gitleaks_8.18.0_linux_x64.tar.gz \
    && mv gitleaks /usr/local/bin/ \
    && rm gitleaks_8.18.0_linux_x64.tar.gz

# Set up working directory
WORKDIR /workspace

# Configure git to trust workspace directory
RUN git config --global --add safe.directory /workspace

# Set default shell to bash
ENV SHELL=/bin/bash

# Create necessary directories with proper permissions
RUN mkdir -p /home/vscode/.cache /home/vscode/.local /home/vscode/go \
    && chown -R vscode:vscode /home/vscode

# Switch to vscode user
USER vscode

# Set environment variables
ENV PATH="/home/vscode/go/bin:/home/vscode/.local/bin:${PATH}"
ENV GOPATH="/home/vscode/go"
