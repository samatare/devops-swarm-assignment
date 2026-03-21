FROM node:20-alpine
WORKDIR /app
COPY app/frontend/package.json ./
RUN npm install --omit=dev 2>/dev/null || true
COPY app/frontend/ ./
RUN addgroup -g 1001 -S appgroup && adduser -u 1001 -S appuser -G appgroup
USER appuser
EXPOSE 3000
HEALTHCHECK --interval=15s --timeout=5s --retries=3 --start-period=10s \
  CMD wget -qO- http://localhost:3000/health || exit 1
CMD ["node", "server.js"]
