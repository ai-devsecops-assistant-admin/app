# Build stage
FROM node:20-alpine AS builder

WORKDIR /build

RUN corepack enable && corepack prepare pnpm@8.14.0 --activate

COPY apps/my-app/web/package.json apps/my-app/web/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

COPY apps/my-app/web/ ./
RUN pnpm run build --configuration=production

# Runtime stage
FROM nginx:1.25-alpine

LABEL maintainer="platform-team@example.com"
LABEL org.opencontainers.image.source="https://github.com/example/platform-governance"
LABEL org.opencontainers.image.description="My App Web UI"

COPY --from=builder /build/dist/my-app-web /usr/share/nginx/html
COPY apps/my-app/docker/nginx.conf /etc/nginx/nginx.conf

RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    chown -R nginx:nginx /etc/nginx/conf.d && \
    touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid

USER nginx

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
