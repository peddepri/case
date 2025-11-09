# Backend Dockerfile
FROM node:20-alpine AS base
WORKDIR /app
COPY package.json ./
RUN npm cache clean --force && \
    npm install --no-audit --no-fund --legacy-peer-deps --ignore-scripts --prefer-online
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
