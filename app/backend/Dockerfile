# Backend Dockerfile
FROM node:20-alpine AS base
WORKDIR /app
COPY package.json package-lock.json* pnpm-lock.yaml* yarn.lock* ./
# Robust npm install with retries to avoid EINTEGRITY on CI networks
RUN npm config set registry https://registry.npmjs.org/ \
    && npm config set fetch-retries 5 \
    && npm config set fetch-retry-mintimeout 30000 \
    && npm config set fetch-retry-maxtimeout 120000 \
    && npm config set prefer-online true \
    && attempts=0; \
       until [ "$attempts" -ge 5 ]; do \
         npm ci --no-audit --no-fund && break; \
         attempts=$((attempts+1)); \
         npm cache clean --force || true; \
         sleep 5; \
       done; \
       if [ "$attempts" -ge 5 ]; then \
         npm install --no-audit --no-fund --legacy-peer-deps; \
       fi
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

FROM node:20-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY --from=base /app/package.json ./
COPY --from=base /app/node_modules ./node_modules
COPY --from=base /app/dist ./dist
EXPOSE 3000
CMD ["node", "dist/index.js"]
