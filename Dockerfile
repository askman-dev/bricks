FROM node:20-bookworm-slim AS node-tools

FROM ghcr.io/cirruslabs/flutter:stable AS web-build

WORKDIR /workspace
COPY --from=node-tools /usr/local/ /usr/local/
COPY . .
ENV DOCS_URL=https://craft.bricks.cool
ENV DOCS_BASE_URL=/docs/
RUN bash ./tools/vercel-build.sh

FROM node:20-bookworm-slim AS backend-build

WORKDIR /workspace/apps/node_backend
COPY apps/node_backend/package*.json ./
RUN npm ci
COPY apps/node_backend ./
RUN npm run build
RUN npm prune --omit=dev

FROM node:20-bookworm-slim

ENV NODE_ENV=production
ENV PORT=3000
ENV TRUST_PROXY=true
ENV BRICKS_STATIC_ROOT=/app/public
ENV BRICKS_CHANNEL_ROOT=/app/data/channels

WORKDIR /app
COPY --from=backend-build /workspace/apps/node_backend/package*.json ./
COPY --from=backend-build /workspace/apps/node_backend/node_modules ./node_modules
COPY --from=backend-build /workspace/apps/node_backend/dist ./dist
COPY --from=web-build /workspace/apps/mobile_chat_app/build/web ./public

EXPOSE 3000
CMD ["node", "dist/index.js"]
