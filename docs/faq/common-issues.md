# Common Issues

## Environment bootstrap not run

Symptom: dependency checks or Flutter commands fail unexpectedly.

Action: run `./tools/init_dev_env.sh` from repository root first.

## Flutter test command run from wrong path

Symptom: mobile app tests fail to resolve package layout when invoked from monorepo root with package path.

Action: run from package directory:

```bash
cd apps/mobile_chat_app
flutter test
```

## Plugin authentication failures

Symptom: platform API requests rejected.

Action:

- verify Bearer token is valid
- ensure `X-Bricks-Plugin-Id` is set
- validate JWT mode setup for OpenClaw plugin runtime

For protocol details, read [`docs/plugin_development_architecture.md`](../plugin_development_architecture.md).
