# Build stage
FROM golang:1.21-alpine AS builder

WORKDIR /build

RUN apk add --no-cache git ca-certificates tzdata

COPY apps/my-app/go.mod apps/my-app/go.sum ./
RUN go mod download

COPY apps/my-app/ ./

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags='-w -s -extldflags "-static"' \
    -a -installsuffix cgo \
    -o api ./cmd/api

# Runtime stage
FROM gcr.io/distroless/static-debian12:nonroot

LABEL maintainer="platform-team@example.com"
LABEL org.opencontainers.image.source="https://github.com/example/platform-governance"
LABEL org.opencontainers.image.description="My App API Service"

COPY --from=builder /build/api /app/api
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

WORKDIR /app

USER nonroot:nonroot

EXPOSE 8080

ENTRYPOINT ["/app/api"]
