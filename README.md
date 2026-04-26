# Bricks

**The agent console for tinkerers.**

Bricks is a native console for connecting external agent platforms, running multiple agent threads side by side, and keeping each run observable and controllable.

## Documentation

The repository docs are now organized in a Docusaurus-friendly information architecture under `docs/`:

- [docs/intro.md](docs/intro.md) — entry page
- [docs/product/](docs/product/overview.md) — product overview and capabilities
- [docs/get-started/](docs/get-started/quickstart.md) — quick setup and local run path
- [docs/integrations/](docs/integrations/openclaw-plugin.md) — OpenClaw / platform integration guidance
- [docs/architecture/](docs/architecture/system-overview.md) — system architecture and package layout
- [docs/faq/](docs/faq/common-issues.md) — common issues and troubleshooting pointers


## Docs site (Docusaurus)

The docs site is managed as an independent project in `apps/docs_site/` and renders content from the repository root `docs/` directory.

```bash
cd apps/docs_site
npm install
npm run start
npm run build
```

## Quick setup

```bash
./tools/init_dev_env.sh
```

For complete local setup and validation commands, see:

- [docs/get-started/quickstart.md](docs/get-started/quickstart.md)
- `BUILD.md`
