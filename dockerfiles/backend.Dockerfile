# Backend Dockerfile — Multi-stage build
# Stage 1: Install dependencies
FROM node:20-alpine AS deps
WORKDIR /app
COPY app/backend/package.json ./
RUN npm install --omit=dev

# Stage 2: Production image
FROM node:20-alpine
WORKDIR /app
RUN addgroup -g 1001 -S appgroup && adduser -u 1001 -S appuser -G appgroup
COPY --from=deps /app/node_modules ./node_modules
COPY app/backend/ ./
USER appuser
EXPOSE 3000
HEALTHCHECK --interval=10s --timeout=5s --retries=3 --start-period=10s \
  CMD wget -qO- http://localhost:3000/health || exit 1
CMD ["node", "server.js"]
