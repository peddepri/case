# Expo web (simulation) container with observability
FROM node:20-bullseye

WORKDIR /app

# Install expo CLI and dependencies
RUN npm i -g expo-cli@6.3.10 expo@^51.0.0

# Copy package files
COPY package.json package-lock.json* yarn.lock* .npmrc* ./

# Install dependencies
RUN npm ci --legacy-peer-deps || npm install --legacy-peer-deps

# Copy application code
COPY . .

# Environment variables
ENV EXPO_NO_TELEMETRY=1
ENV EXPO_PUBLIC_BACKEND_URL=http://localhost:3000
ENV NODE_ENV=production
ENV PORT=19006

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:19006/ || exit 1

# Install curl for healthcheck
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

EXPOSE 19006

# Use expo export for static web build and serve with http-server
RUN npx expo export:web && npm install -g http-server

CMD ["http-server", "web-build", "-p", "19006", "--cors"]
