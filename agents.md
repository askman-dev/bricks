# agents.md

This repository supports natural-language use case files for Copilot and human authors.

## Location

- Store use case files under `tests/usercases/`.
- Name each file as `tests/usercases/<module-name>.yaml`.
- `<module-name>` must be the module or package being validated, for example `agent_core.yaml` or `workspace_fs.yaml`.

## Authoring rules

When Copilot creates or updates a file in `tests/usercases/`, it must follow these rules:

1. Write all descriptions in English.
2. Use natural language sentences instead of code-like assertions.
3. Use the first level of the YAML file for the capability or feature being validated.
4. Under each capability, use a `given` list.
5. Each `given` item may contain multiple `when` items.
6. Each `when` item may contain multiple `then` items.
7. Keep the structure explicit and stable so the file can be reviewed by humans and parsed by tools later.

## Required YAML shape

```yaml
module: <module-name>

<capability-name>:
  description: <what this capability validates>
  given:
    - description: <initial context in natural language>
      when:
        - description: <user action or system event in natural language>
          then:
            - <expected outcome in natural language>
            - <another expected outcome in natural language>
```

## Example

```yaml
module: agent_core

conversation_continuity:
  description: Verify that an agent session keeps the right conversation context across follow-up turns.
  given:
    - description: A workspace already contains a saved conversation with earlier user and assistant messages.
      when:
        - description: The user resumes the same conversation in the chat app.
          then:
            - The agent restores the existing conversation history before generating a new reply.
            - The next assistant response is based on the restored context instead of starting a new session.
```

## Copilot guidance

When Copilot is asked to add a natural-language test case:

- choose the target module name first, then create or update `tests/usercases/<module-name>.yaml`
- add or extend the relevant top-level capability section
- keep `given`, `when`, and `then` descriptions readable and specific
- prefer multiple `when` branches under the same `given` when they share the same starting context
- prefer multiple `then` outcomes under the same `when` when one action produces several expectations
