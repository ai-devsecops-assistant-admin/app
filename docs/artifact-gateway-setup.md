# Artifact Gateway Setup Guide

## Overview

The Artifact Gateway is a Contract-First API framework that uses declarative YAML flows to define API behavior. This eliminates the need to write boilerplate code for CRUD operations.

## Quick Start

### 1. Run the Setup Script

```bash
cd /path/to/your/workspace
bash /path/to/scripts/setup-artifact-gateway.sh my-api github.com/myorg/my-api
```

**Parameters:**
- `APP_NAME` (default: `my-app`): The name of your application directory
- `MODULE_NAME` (default: `example.com/${APP_NAME}`): Go module name

### 2. Navigate and Test

```bash
cd my-api
go mod tidy
go run cmd/artifact-gateway/main.go
```

The server will start on `http://localhost:8080` by default.

### 3. Test the API

```bash
# List all users
curl http://localhost:8080/mock/v1/users

# Get a specific user
curl http://localhost:8080/mock/v1/users/u_1

# Create a new user
curl -X POST http://localhost:8080/mock/v1/users \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "name": "Test User"}'

# Update a user
curl -X PUT http://localhost:8080/mock/v1/users/u_1 \
  -H "Content-Type: application/json" \
  -d '{"name": "Updated Name"}'

# Delete a user
curl -X DELETE http://localhost:8080/mock/v1/users/u_1
```

## Project Structure

```
my-api/
├── cmd/
│   └── artifact-gateway/
│       └── main.go              # Main application entry point
├── platform/
│   └── artifact/
│       ├── types.go             # Core types and structures
│       ├── loader.go            # Flow and index loaders
│       ├── utils.go             # Utility functions
│       └── engine.go            # Flow execution engine
├── repo/
│   ├── api/
│   │   └── index.json           # Route definitions
│   ├── flows/
│   │   ├── users.list.flow.yaml
│   │   ├── users.detail.flow.yaml
│   │   ├── users.create.flow.yaml
│   │   ├── users.update.flow.yaml
│   │   └── users.delete.flow.yaml
│   └── data/
│       └── seed.users.v1.json   # Seed data
└── .runtime/
    └── state/
        └── users.json           # Runtime state (created automatically)
```

## Flow Operations

The engine supports the following operations:

### Data Operations
- **loadDataset**: Load data from state or seed files
- **findById**: Find a record by ID
- **filterAndPaginate**: Filter and paginate records
- **insertRecord**: Insert a new record
- **updateRecord**: Update an existing record
- **deleteRecord**: Delete a record

### Validation Operations
- **validateBody**: Validate request body against JSON schema
- **checkUnique**: Check field uniqueness (with optional excludeId for updates)

### Utility Operations
- **assignId**: Generate a unique ID with prefix
- **now**: Get current timestamp in RFC3339 format
- **set**: Set a value in the runtime context
- **respond**: Send HTTP response

## Example Flow

Here's a complete CRUD flow for user creation:

```yaml
steps:
  - id: validate
    op: validateBody
    args:
      schema:
        type: object
        required: [email, name]
        properties:
          email: { type: string, format: email }
          name: { type: string, minLength: 1 }

  - id: load
    op: loadDataset
    args:
      dataset: users
    out: users

  - id: ensureUniqueEmail
    op: checkUnique
    args:
      source: $ctx.users
      field: email
      value: $request.body.email

  - id: genId
    op: assignId
    args:
      prefix: u_
    out: newId

  - id: setId
    op: set
    args:
      path: $request.body.id
      value: $ctx.newId

  - id: setCreatedAt
    op: now
    out: nowVal

  - id: assignCreatedAt
    op: set
    args:
      path: $request.body.createdAt
      value: $ctx.nowVal

  - id: insert
    op: insertRecord
    args:
      dataset: users
      record: $request.body
    out: created

  - id: respond
    op: respond
    args:
      status: 201
      bodyFrom: $ctx.created
```

## Configuration

### Environment Variables

- `REPO_PATH` (default: `repo`): Path to the repository directory
- `ADDR` (default: `:8080`): Server listen address
- `GIN_MODE` (default: `debug`): Gin framework mode (`debug`, `release`, `test`)

### Route Index Format

The `repo/api/index.json` file defines your API routes:

```json
{
  "routes": [
    {
      "method": "GET",
      "path": "/v1/users",
      "flow": "users.list.flow.yaml"
    },
    {
      "method": "POST",
      "path": "/v1/users",
      "flow": "users.create.flow.yaml"
    }
  ]
}
```

## Advanced Features

### Conditional Execution

Use the `when` field to conditionally execute steps:

```yaml
- id: updateEmail
  when: $request.body.email != null
  op: checkUnique
  args:
    source: $ctx.users
    field: email
    value: $request.body.email
    excludeId: $request.params.id
```

### Error Handling

Use `onConflict` to handle errors gracefully:

```yaml
- id: checkUnique
  op: checkUnique
  args:
    source: $ctx.users
    field: email
    value: $request.body.email
  onConflict:
    op: respond
    args:
      status: 409
      body:
        error:
          message: "Email already exists"
```

### Expression Language

Access request data and context using expressions:

- `$request.method` - HTTP method
- `$request.path` - Request path
- `$request.params.id` - Path parameter
- `$request.query.page` - Query parameter
- `$request.headers.Authorization` - Request header
- `$request.body.email` - Request body field
- `$ctx.users` - Context variable

## Development Workflow

### 1. Define Routes

Edit `repo/api/index.json` to add new routes.

### 2. Create Flows

Add flow definitions in `repo/flows/`:

```bash
cat > repo/flows/my-entity.list.flow.yaml <<EOF
steps:
  - id: load
    op: loadDataset
    args:
      dataset: my-entity
    out: items
  - id: respond
    op: respond
    args:
      status: 200
      bodyFrom: \$ctx.items
EOF
```

### 3. Add Seed Data

Create seed data in `repo/data/`:

```bash
cat > repo/data/seed.my-entity.v1.json <<EOF
[
  { "id": "1", "name": "Item 1" },
  { "id": "2", "name": "Item 2" }
]
EOF
```

### 4. Test

Restart the server and test your endpoints:

```bash
curl http://localhost:8080/mock/v1/my-entity
```

## Linting and CI

The template includes a `.golangci.yml` configuration for code quality:

```bash
# Install golangci-lint
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

# Run linter
golangci-lint run ./...
```

## Troubleshooting

### Port Already in Use

Change the listen address:

```bash
ADDR=:8081 go run cmd/artifact-gateway/main.go
```

### State File Issues

Delete the state directory to reset:

```bash
rm -rf .runtime/state
```

The state will be rebuilt from seed data on next request.

### Flow Parsing Errors

Validate your YAML syntax:

```bash
# Install yq
brew install yq  # macOS
# or
apt-get install yq  # Ubuntu

# Validate flow
yq repo/flows/your-flow.flow.yaml
```

## Production Deployment

### Build Binary

```bash
CGO_ENABLED=0 go build -o artifact-gateway cmd/artifact-gateway/main.go
```

### Docker

```dockerfile
FROM golang:1.23-alpine AS builder
WORKDIR /app
COPY . .
RUN go mod download
RUN CGO_ENABLED=0 go build -o gateway cmd/artifact-gateway/main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/gateway .
COPY --from=builder /app/repo ./repo
EXPOSE 8080
CMD ["./gateway"]
```

### Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: artifact-gateway
spec:
  replicas: 3
  selector:
    matchLabels:
      app: artifact-gateway
  template:
    metadata:
      labels:
        app: artifact-gateway
    spec:
      containers:
      - name: gateway
        image: your-registry/artifact-gateway:latest
        ports:
        - containerPort: 8080
        env:
        - name: GIN_MODE
          value: "release"
        - name: ADDR
          value: ":8080"
        volumeMounts:
        - name: repo
          mountPath: /root/repo
      volumes:
      - name: repo
        configMap:
          name: artifact-gateway-repo
```

## Next Steps

1. **Add Authentication**: Implement auth middleware in `main.go`
2. **Add Rate Limiting**: Use Gin middleware for rate limiting
3. **Add Logging**: Integrate structured logging (zerolog, zap)
4. **Add Metrics**: Add Prometheus metrics
5. **Add OpenAPI**: Generate OpenAPI spec from flows
6. **Add Testing**: Write integration tests for flows

## Support

For issues and questions:
- GitHub Issues: [your-repo/issues](https://github.com/your-org/your-repo/issues)
- Documentation: [docs/](../docs/)

## License

[Your License Here]
