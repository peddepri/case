# Frontend Dockerfile
FROM node:20-alpine AS build
WORKDIR /app
ARG VITE_BACKEND_URL=/api
ENV VITE_BACKEND_URL=${VITE_BACKEND_URL}
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
COPY tsconfig*.json ./
COPY vite.config.ts ./
COPY index.html ./
COPY src ./src
RUN npm run build

FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
