# Build stage
FROM golang:1.21-alpine AS builder

WORKDIR /build

RUN apk add --no-cache git ca-certificates tzdata

COPY apps/artifact-gateway/go.mod apps/artifact-gateway/go.sum ./
RUN go mod download

COPY apps/artifact-gateway/ ./

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags='-w -s -extldflags "-static"' \
    -a -installsuffix cgo \
    -o artifact-gateway ./cmd/gateway

# Runtime stage
FROM gcr.io/distroless/static-debian12:nonroot

LABEL maintainer="platform-team@example.com"
LABEL org.opencontainers.image.source="https://github.com/example/platform-governance"
LABEL org.opencontainers.image.description="Artifact Gateway Service"

COPY --from=builder /build/artifact-gateway /app/artifact-gateway
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

WORKDIR /app

USER nonroot:nonroot

EXPOSE 8080

ENTRYPOINT ["/app/artifact-gateway"]
