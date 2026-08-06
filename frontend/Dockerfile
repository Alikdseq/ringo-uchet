# Multi-stage build для Next.js production
FROM node:20-alpine AS base

# Optional: NPM_REGISTRY=https://registry.npmmirror.com docker compose build frontend
ARG NPM_REGISTRY=https://registry.npmjs.org

# Install dependencies only when needed
FROM base AS deps
ARG NPM_REGISTRY
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Устойчивость к обрывам сети (ECONNRESET) при npm ci в Docker
COPY .npmrc package.json package-lock.json* ./
ENV HUSKY=0
RUN npm config set registry "${NPM_REGISTRY}" \
    && npm config set fetch-retries 5 \
    && npm config set fetch-retry-mintimeout 20000 \
    && npm config set fetch-retry-maxtimeout 120000 \
    && npm config set fetch-timeout 300000 \
    && set -e; \
       i=1; \
       while [ "$i" -le 5 ]; do \
         echo "npm ci attempt $i/5..."; \
         if npm ci --prefer-offline --no-audit --no-fund; then \
           exit 0; \
         fi; \
         echo "npm ci failed (attempt $i), retrying in $((i * 8))s..."; \
         sleep $((i * 8)); \
         i=$((i + 1)); \
       done; \
       echo "npm ci failed after 5 attempts"; \
       exit 1

# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Disable telemetry during build
ENV NEXT_TELEMETRY_DISABLED=1
ARG API_INTERNAL_URL=http://django-api:8000
ENV API_INTERNAL_URL=$API_INTERNAL_URL
ARG NEXT_PUBLIC_API_URL=/api/v1
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL

# Build Next.js
RUN npm run build

# Production image, copy all the files and run next
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ARG API_INTERNAL_URL=http://django-api:8000
ENV API_INTERNAL_URL=$API_INTERNAL_URL

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copy necessary files
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next ./.next
COPY --from=builder --chown=nextjs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nextjs:nodejs /app/package.json ./package.json
COPY --from=builder --chown=nextjs:nodejs /app/next.config.ts ./next.config.ts

USER nextjs

EXPOSE 3000

ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

# Запускаем Next.js production сервер
CMD ["node_modules/.bin/next", "start"]

