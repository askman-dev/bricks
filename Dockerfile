FROM ghcr.io/cirruslabs/flutter:stable AS flutter-web-build

WORKDIR /workspace
COPY pubspec.yaml melos.yaml ./
COPY packages ./packages
COPY apps/mobile_chat_app ./apps/mobile_chat_app
RUN flutter config --enable-web >/dev/null \
  && cd apps/mobile_chat_app \
  && flutter pub get \
  && flutter build web --release

FROM node:20-bookworm-slim AS docs-build

WORKDIR /workspace
COPY apps/docs_site/package*.json ./apps/docs_site/
RUN cd apps/docs_site && npm ci
COPY apps/docs_site ./apps/docs_site
COPY docs ./docs
ENV DOCS_URL=https://craft.bricks.cool
RUN cd apps/docs_site && npm run build

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
ENV BRICKS_SANDBOX_ROOT=/app/data/sandboxes
ENV BRICKS_SANDBOX_RUNNER=http
ENV BRICKS_SANDBOX_RUNNER_URL=http://172.17.0.1:8787

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates git \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=backend-build /workspace/apps/node_backend/package*.json ./
COPY --from=backend-build /workspace/apps/node_backend/node_modules ./node_modules
COPY --from=backend-build /workspace/apps/node_backend/dist ./dist
COPY --from=backend-build /workspace/apps/node_backend/src/db/migrations ./dist/db/migrations
COPY --from=flutter-web-build /workspace/apps/mobile_chat_app/build/web ./public
COPY --from=docs-build /workspace/apps/docs_site/build ./public/docs

EXPOSE 3000
CMD ["node", "dist/index.js"]
