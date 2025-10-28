.PHONY: dev.up dev.down gen.openapi validate.artifact test.e2e init

dev.up:
	docker-compose up --build -d

dev.down:
	docker-compose down

gen.openapi:
	chmod +x scripts/gen-openapi.sh
	./scripts/gen-openapi.sh

validate.artifact:
	node scripts/validate-artifact.mjs

test.e2e:
	chmod +x scripts/test-e2e.sh
	./scripts/test-e2e.sh

init:
	npm install --prefix web
	go mod tidy
