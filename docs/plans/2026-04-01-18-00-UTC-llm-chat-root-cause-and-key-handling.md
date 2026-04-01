# Background
Chat requests failed with opaque backend errors when stored provider keys were not usable at runtime. Earlier iterations introduced multiple plan documents and one defensive runtime rule that could overfit to current provider key shapes.

# Goals
- Keep only one plan document for this session and remove intermediate plan noise.
- Preserve the root-cause fix for decryption mismatch without imposing provider-specific API key pattern assumptions.
- Make encrypted-key detection robust and future-compatible.

# Implementation Plan (phased)
1. Consolidate session planning artifacts into a single plan file.
2. Remove runtime rejection logic that guesses whether a provider key is encrypted ciphertext.
3. Version encrypted payload format (`enc:v1:`) and keep backward-compatible legacy decryption.
4. Add explicit `api_key_encrypted` metadata on write paths so reads do not rely on provider key shape assumptions.
5. Enforce a single encryption key source (`ENCRYPTION_KEY`) and fail fast at backend startup when it is missing/empty.
6. Validate via targeted tests and backend type-check.

# Acceptance Criteria
- Only one plan file remains from this session under `docs/plans/`.
- No provider key prefix/shape assumptions are used to reject runtime config in LLM service.
- Encrypted keys can be detected via explicit metadata and versioned format.
- Legacy encrypted values continue to decrypt.
- Backend startup fails when `ENCRYPTION_KEY` is missing/empty, preventing bad deployments.
- Tests and type-check pass.
