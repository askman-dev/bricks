# Building Bricks (React + Node)

## Prerequisites

- Node.js 20+
- npm 10+

## Install dependencies

```bash
./tools/init_dev_env.sh
```

## Run checks

```bash
npm --prefix apps/web_chat_app run test
npm --prefix apps/web_chat_app run build
npm --prefix apps/node_backend run test
```

## Build for deployment

```bash
./build.sh
```

Frontend output is generated at `apps/web_chat_app/dist`.
