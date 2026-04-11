# ── 빌드 스테이지 ────────────────────────────────────────────────────────────
FROM node:18-alpine AS builder
WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY tsconfig.json ./
COPY src/ ./src/
RUN npm run build

# ── 런타임 스테이지 ───────────────────────────────────────────────────────────
FROM node:18-alpine
WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY --from=builder /app/dist ./dist

EXPOSE 3000
CMD ["node", "dist/app.js"]
