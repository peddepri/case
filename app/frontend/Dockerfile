# Frontend Dockerfile
FROM node:20-alpine AS build
WORKDIR /app
ARG VITE_BACKEND_URL=/api
ENV VITE_BACKEND_URL=${VITE_BACKEND_URL}
COPY package.json ./
RUN npm cache clean --force && \
    npm install --no-audit --no-fund --legacy-peer-deps --ignore-scripts --prefer-online
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
