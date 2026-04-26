---
title: Quickstart
sidebar_position: 1
---

# Quickstart

## 1) Initialize environment

From repository root:

```bash
./tools/init_dev_env.sh
```

## 2) Run automated checks

```bash
./build.sh
```

## 3) Common manual checks

```bash
melos bootstrap
melos analyze
melos test
```

For mobile app package-specific tests, run from the package directory:

```bash
cd apps/mobile_chat_app
flutter test
```

## 4) Build web app

```bash
cd apps/mobile_chat_app
flutter build web --release
```

For full build details, see `BUILD.md` at the repository root.
