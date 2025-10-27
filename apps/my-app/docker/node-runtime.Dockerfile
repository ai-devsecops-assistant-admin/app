FROM node:20-alpine

LABEL maintainer="platform-team@example.com"
LABEL org.opencontainers.image.source="https://github.com/example/platform-governance"
LABEL org.opencontainers.image.description="Node.js Runtime Service"

WORKDIR /app

RUN corepack enable && corepack prepare pnpm@8.14.0 --activate

RUN apk add --no-cache tini && \
    addgroup -g 1001 nodeapp && \
    adduser -D -u 1001 -G nodeapp nodeapp

COPY apps/my-app/node-runtime/package.json apps/my-app/node-runtime/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile --prod

COPY --chown=nodeapp:nodeapp apps/my-app/node-runtime/ ./

USER nodeapp

EXPOSE 3000

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "src/index.js"]
