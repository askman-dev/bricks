# User Sandbox Runtime Refactor

## Background

Move AI coding shell execution away from the host machine and into a persistent per-user sandbox, while preserving the existing channel workspace product model. Channels remain directories inside one user's sandbox rather than hard security boundaries.

## Implementation Summary

- Added `userSandboxService` as the persistent per-user sandbox filesystem and command runner abstraction.
- Moved channel filesystem roots under the per-user sandbox filesystem.
- Kept channel workspace APIs stable for existing `site_*` AI tools.
- Routed site shell execution and initial site git setup through the sandbox runner instead of direct host shell execution.
- Added local runner support for container-level isolation, Docker runner support for single-host sandbox workers, and HTTP runner support for a separate sandbox-worker service.
- Updated code maps for the channel React site workspace feature.

## Acceptance Criteria

- Different users resolve to different sandbox filesystem roots.
- The same user's channels resolve under one shared sandbox root.
- Workspace shell execution delegates to a sandbox runner abstraction.
- Existing channel path traversal protections remain in place.
- Validation commands pass for node backend checks relevant to this change.

## Validation

- `cd apps/node_backend && npm run type-check`
- `cd apps/node_backend && npm test -- --run src/services/channelFileService.test.ts src/services/userSandboxService.test.ts src/services/channelSiteService.test.ts src/routes/channelSiteHost.test.ts src/services/localAgentLoopService.test.ts`
- `ruby -e "require 'yaml'; YAML.load_file('docs/code_maps/feature_map.yaml'); YAML.load_file('docs/code_maps/logic_map.yaml'); puts 'code maps yaml ok'"`

## Notes

- Python YAML validation was not available because PyYAML is not installed in this environment; Ruby YAML validation was used instead.
- Flutter/Dart workspace checks were not run because this change only touches the Node backend and repository code maps.
