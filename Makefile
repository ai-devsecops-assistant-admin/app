.PHONY: help bootstrap build test lint security deploy clean

help: ## Display this help message
	@echo "Platform Governance Makefile"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

bootstrap: ## Bootstrap development environment
	@echo "Bootstrapping development environment..."
	./scripts/bootstrap/setup-env.sh
	./scripts/bootstrap/install-tools.sh

build: build-api build-web build-autofix ## Build all components
	@echo "Build complete"

build-api: ## Build API service
	cd apps/my-app && go build -o bin/api ./cmd/api

build-web: ## Build web UI
	cd apps/my-app/web && pnpm install && pnpm run build

build-autofix: ## Build auto-fix bot
	cd apps/auto-fix-bot && go build -o bin/bot ./cmd/bot

test: test-unit test-integration ## Run all tests
	@echo "All tests completed"

test-unit: ## Run unit tests
	cd apps/my-app && go test ./...
	cd apps/auto-fix-bot && go test ./...

test-integration: ## Run integration tests
	cd apps/my-app && go test -tags=integration ./tests/integration/...

test-e2e: ## Run E2E tests
	cd apps/my-app && go test -tags=e2e ./tests/e2e/...

lint: ## Run linters
	cd apps/my-app && golangci-lint run ./...
	cd apps/auto-fix-bot && golangci-lint run ./...
	cd apps/my-app/web && pnpm run lint

security: scan-trivy scan-gitleaks ## Run security scans
	@echo "Security scans complete"

scan-trivy: ## Run Trivy container scan
	trivy image --severity CRITICAL,HIGH my-app-api:latest

scan-gitleaks: ## Run Gitleaks secret scan
	gitleaks detect --source . --verbose

policy-test: policy-test-opa policy-test-conftest ## Test all policies
	@echo "Policy tests complete"

policy-test-opa: ## Test OPA policies
	opa test .config/policy/

policy-test-conftest: ## Test Conftest policies
	conftest test deploy/k8s/ -p .config/conftest/policies/

deploy: ## Deploy to environment (ENV=dev|staging|prod)
	@if [ -z "$(ENV)" ]; then echo "ENV not set. Use: make deploy ENV=dev"; exit 1; fi
	./scripts/deploy/deploy.sh $(ENV)

clean: ## Clean build artifacts
	rm -rf apps/my-app/bin/
	rm -rf apps/auto-fix-bot/bin/
	rm -rf apps/my-app/web/dist/
