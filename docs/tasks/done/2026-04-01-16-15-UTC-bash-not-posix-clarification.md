# Background
A review comment flagged wording mismatch: implementation is bash-specific but some PR narrative used "POSIX shell" language.

# Goals
- Make repository docs explicit that the resolver script requires bash.
- Avoid implying POSIX `sh` compatibility.

# Implementation Plan (phased)
## Phase 1: Clarify skill docs
- Add an explicit note in SKILL.md that resolver script requires bash and is not POSIX `sh` compatible.

## Phase 2: Clarify script header
- Add a short comment near shebang highlighting bash-only features.

## Phase 3: Validate
- Run `bash -n` on the resolver script.
- Search for remaining "POSIX" references in relevant skill/plan files.

# Acceptance Criteria
- Skill docs state bash requirement clearly.
- Script itself warns readers that it is bash-only.
- No contradictory POSIX wording remains in skill/plan docs touched by this workflow.
