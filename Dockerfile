FROM node:22-alpine AS base

WORKDIR /app
RUN apk add --no-cache dumb-init openssl libc6-compat

FROM base AS build

COPY package.json package-lock.json ./
RUN npm ci
COPY tsconfig.json ./
COPY prisma ./prisma
RUN npm run prisma:generate
COPY src ./src
RUN npm run build

FROM base AS production-dependencies

COPY package.json package-lock.json ./
COPY prisma ./prisma
RUN npm ci --omit=dev && npm run prisma:generate

FROM base AS production

ENV NODE_ENV=production
COPY --from=production-dependencies /app/node_modules ./node_modules
COPY --from=production-dependencies /app/package.json ./package.json
COPY --from=production-dependencies /app/prisma ./prisma
COPY --from=build /app/dist ./dist
RUN mkdir -p /app/logs && chown -R node:node /app
USER node
EXPOSE 4000
CMD ["dumb-init", "node", "dist/server.js"]
