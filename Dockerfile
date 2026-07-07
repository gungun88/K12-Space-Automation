FROM node:22-bookworm-slim AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

FROM deps AS builder
COPY . .
RUN npm run build

FROM node:22-bookworm-slim AS prod-deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

FROM node:22-bookworm-slim AS runner
ENV NODE_ENV=production
ENV HOST=0.0.0.0
ENV PORT=8796
ENV SENTINEL_BROWSER_PATH=/usr/bin/chromium
ENV SENTINEL_BROWSER_ARGS=--no-sandbox,--disable-dev-shm-usage
WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        chromium \
        dumb-init \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --system app \
    && useradd --system --gid app --create-home --home-dir /home/app app

COPY --from=prod-deps /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/server ./server
COPY --from=builder /app/codex_register ./codex_register
COPY --from=builder /app/sdk.js ./sdk.js
COPY --from=builder /app/package.json ./package.json

RUN mkdir -p /app/data /app/json /app/auth /app/.web-data /app/codex_register \
    && touch /app/pool_tokens.txt /app/2925-account.json \
    && chown -R app:app /app /home/app

USER app
EXPOSE 8796

ENTRYPOINT ["dumb-init", "--"]
CMD ["npm", "run", "start"]
