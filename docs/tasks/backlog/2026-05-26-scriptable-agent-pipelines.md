# Scriptable Agent Pipelines

## Confirmed Need

Bricks should support scriptable Agent pipelines that can run around a user message or an Agent response.

The pipeline should be able to execute code, call tools, transform input, and then continue the Agent flow.

## Example Use Cases

- Before sending a message, check grammar, rewrite the query in English, and send the improved message to the AI.
- Before sending a message, optimize or enrich the user query.
- Use a framework such as Genkit as a possible way to define AI workflows in TypeScript.

## Notes

- The feature is about scriptable hooks or flows, not only prompt templates.
- Exact trigger points, permissions, storage, and runtime model are not decided yet.
