# Task Status Cleanup

## Background

Some task files in `docs/tasks/doing/` described implementation slices that had already landed in code. The task lifecycle needed to be corrected so the remaining `doing` list reflects unfinished work.

## Completed

- Reviewed the active task files under `docs/tasks/doing/`.
- Cross-checked completed slices against code paths, tests, code maps, and recent git history.
- Moved completed task files from `docs/tasks/doing/` to `docs/tasks/done/`.
- Updated the code map task reference for Puzzle Pack Maker after moving its task file.
- Included the existing editable todo/note backlog requirement in the tracked task set.

## Validation

- `ruby -e "require 'psych'; Psych.load_file('docs/code_maps/feature_map.yaml'); puts 'feature_map yaml ok'"`
- `ruby -e "require 'psych'; Psych.load_file('docs/code_maps/logic_map.yaml'); puts 'logic_map yaml ok'"`
