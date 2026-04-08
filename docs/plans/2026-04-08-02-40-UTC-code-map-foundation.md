# Background

As the repository grows, AI agents can miss related logic when modifying code, which can leave behind stale code or cause functional regressions. We need a "code map" as a unified entry point that helps human testers, AI testers, and AI engineers quickly locate feature paths and documentation indexes.

# Goals

1. Add a feature map YAML file that records the feature list and entry paths.
2. Add a logic map YAML file that records feature-to-code/document indexes and keyword mappings.
3. Add a reusable Codex Skill to guide future maintenance of the code maps.
4. Add a working rule to AGENTS memory requiring code maps to be updated after code changes.

# Implementation Plan (phased)

## Phase 1 - Create the code map files

- Create `docs/code_maps/feature_map.yaml`.
- Create `docs/code_maps/logic_map.yaml`.
- Define a shared schema so both humans and AI can parse the files.

## Phase 2 - Standardize the maintenance prompt

- Create `.codex/skills/code-map-maintainer/SKILL.md`.
- Document the trigger conditions, maintenance steps, post-change checkpoints, and output format.

## Phase 3 - Integrate with Agent memory

- Update the root `AGENTS.md`:
  - Register `code-map-maintainer` in the list of available skills.
  - Add a standing rule that code maps must be checked and maintained after code changes.

## Phase 4 - Basic validation

- Run YAML parsing validation to ensure the new map files are correctly formatted.

# Acceptance Criteria

1. The current phase includes at least two code map YAML files: a feature map (`feature_map.yaml`) and a logic map (`logic_map.yaml`). Additional map files may be added in future phases.
2. The feature map exposes the entry path and validation entry for each feature.
3. The logic map exposes the corresponding code indexes, document indexes, and keywords for each feature, with `feature_id` values that are consistent with the feature map.
4. The repository contains a dedicated skill document for maintaining code maps, and it can be referenced by future tasks.
5. The AGENTS documentation includes an explicit memory rule requiring code map maintenance after code changes.
