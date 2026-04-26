# Background

The repository documentation was reorganized into a Docusaurus-friendly structure, but it still lacked an executable Docusaurus site and clickable docs links in README.

# Goals

1. Convert README docs path listings into clickable Markdown links with valid targets.
2. Add an independent `website/` Docusaurus project that renders docs from repository root `docs/`.
3. Keep existing Flutter, melos, and Vercel project structures untouched.

# Implementation Plan (phased)

## Phase 1: README link usability
- Replace code-style docs paths in README with Markdown links.
- Add a short section showing how to run and build the docs site from `website/`.

## Phase 2: Docusaurus project bootstrap
- Create `website/package.json` with Docusaurus dependencies and npm scripts.
- Add `website/docusaurus.config.ts` with docs source path set to `../docs`.
- Add `website/sidebars.ts` grouped by Introduction, Product, Get Started, Integrations, Architecture, FAQ, and Plans.
- Add basic CSS and ignore files needed for local development.

## Phase 3: Docs metadata and validation
- Add minimal frontmatter to key docs pages used by sidebar.
- Run `npm install` and `npm run build` under `website/`.
- Review `git diff --name-status` to ensure expected scope.

# Acceptance Criteria

1. README docs entries are clickable and point to real files.
2. `cd website && npm run build` succeeds.
3. Sidebar groups map to current docs information architecture.
4. Existing app and backend build structures remain unaffected.
