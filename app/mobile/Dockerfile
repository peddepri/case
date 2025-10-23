# Expo web (simulation) container
FROM node:20-bullseye
WORKDIR /app

# Install expo CLI
RUN npm i -g expo@^51.0.0

COPY package.json package-lock.json* yarn.lock* .npmrc* ./
RUN npm i || true

COPY . .
ENV EXPO_NO_TELEMETRY=1
ENV EXPO_PUBLIC_BACKEND_URL=${EXPO_PUBLIC_BACKEND_URL}

EXPOSE 19006
CMD ["bash","-lc","npm run start -- --web --port 19006 --clear"]
