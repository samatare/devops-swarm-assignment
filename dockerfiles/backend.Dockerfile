FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production --ignore-scripts
FROM node:20-alpine
WORKDIR /app
ENV NODE_ENV=production
RUN addgroup -g 1001 -S app && adduser -u 1001 -S app -G app
COPY --from=deps --chown=app:app /app .
COPY --chown=app:app . .
USER app
EXPOSE 3000
HEALTHCHECK --interval=10s --timeout=5s CMD wget -qO- http://localhost:3000/health || exit 1
CMD ["node","src/index.js"]