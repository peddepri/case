# Mobile service container with metrics endpoint
FROM node:20-alpine

WORKDIR /app

# Install curl for health checks (alpine package)
RUN apk add --no-cache curl

# Copy only the server file
COPY server.js ./

# Install only express (no package.json conflicts)
RUN npm init -y && npm install express

# Environment variables
ENV NODE_ENV=production
ENV PORT=19006

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:19006/healthz || exit 1

EXPOSE 19006

# Start the metrics server directly
CMD ["node", "server.js"]
