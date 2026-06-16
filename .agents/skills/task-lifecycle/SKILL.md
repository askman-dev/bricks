---
name: task-lifecycle
description: Manage task file transitions across docs/tasks/ (backlog→doing→done→trash). Use when a user says a task has started, is complete, is on hold, or is being abandoned. Moves plan files to the correct folder and triggers code map updates on completion.
---

# Task Lifecycle

Use this skill whenever a task changes state:
- A task is picked up and work begins → `backlog → doing`
- A task is finished → `doing → done`
- A task is put on hold or deprioritized → `doing → backlog`
- A task is abandoned or superseded → `any → trash`

This skill manages **documentation flow only**. It does not manage git branches, PRs, or worktrees.

## Folder Meanings

| Folder | Meaning |
|---|---|
| `docs/tasks/backlog/` | Ideas and drafts not yet started |
| `docs/tasks/doing/` | Actively in progress |
| `docs/tasks/done/` | Completed and shipped |
| `docs/tasks/trash/` | Abandoned or superseded |

## Transition Playbooks

### backlog → doing

When the user selects a task to start:

1. Identify the plan file in `docs/tasks/backlog/`.
2. Move it to `docs/tasks/doing/`.
3. Confirm the move to the user.

### doing → done

When the user says a task is complete:

1. Identify the plan file in `docs/tasks/doing/`.
2. Move it to `docs/tasks/done/`.
3. Invoke the `code-map-maintainer` skill to check whether `docs/code_maps/feature_map.yaml` or `docs/code_maps/logic_map.yaml` need updating based on what the task changed.
4. Remind the user: if a `.worktree/` directory exists for this task, it can be manually removed.

### doing → backlog

When the user puts a task on hold:

1. Identify the plan file in `docs/tasks/doing/`.
2. Move it to `docs/tasks/backlog/`.
3. Confirm the move to the user.

### any → trash

When the user abandons or supersedes a task:

1. Identify the plan file in its current folder.
2. Move it to `docs/tasks/trash/`.
3. Confirm the move to the user.

## Identifying the Right File

When the user refers to a task by name (not exact filename):

1. List files in the relevant folder(s).
2. Match by keywords in the filename.
3. If ambiguous, show the user the candidates and ask them to confirm before moving.

## What This Skill Does NOT Do

- Does not merge, close, or create PRs or branches.
- Does not delete worktrees — only reminds the user to clean up manually.
- Does not check whether code is actually implemented or merged before moving a file.
- Does not manage tasks outside `docs/tasks/`.
