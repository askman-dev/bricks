# Highlight List Rendering and Authenticated API Architecture

## Background

The merged text highlight work made the floating toolbar visible, persisted highlights through the backend, rendered normal stored ranges, and added toolbar actions for existing highlights. Main now has a usable baseline, but two larger follow-up areas remain.

First, hierarchical Markdown list content can send highlight create requests and receive responses, but the rendered structure does not reliably show the persisted highlight. The current assistant message renderer parses each Markdown list line into a marker and text row, but it does not preserve nested list structure as first-class render metadata. Highlight spans are applied to visible text ranges, while indentation and markers are rendered separately.

Second, authenticated API calls are not yet architecturally consistent. Text highlight calls now use `AuthenticatedApiClient`, but chat history, todo resources, asset table resources, LLM config, and parts of `ChatScreen` still manually fetch, cache, pass, or format auth tokens.

## Goals

- Make text highlights render reliably in hierarchical Markdown list items without losing structure, duplicating text, or depending on selected-text search.
- Represent a logical highlight as one or more visible subsegments when the source range crosses rendered Markdown structures.
- Add regression coverage for nested list highlighting, including persisted highlights after reload-like rendering.
- Move authenticated mobile API calls toward a single `AuthenticatedApiClient` path so UI code no longer formats `Authorization` headers or passes token strings as business parameters.
- Keep the two tracks staged so highlight rendering fixes can ship independently from the broader auth migration.

## Implementation Plan

1. Stabilize the highlight renderer for hierarchical lists.
   - Add focused widget tests for nested unordered and ordered list content with stored highlight ranges.
   - Verify whether failures come from source-offset mapping, list item rendering, or marker/text split boundaries.
   - Extend the Markdown block/list metadata so rendered list text keeps source ranges, nesting level, marker identity, and visible text ranges.
   - Apply highlight splitting against visible source-backed segments, allowing one persisted highlight to render as multiple subsegments when needed.
   - Preserve current behavior for paragraphs, code blocks, tables, overlapping ranges, tapped highlight toolbar, and selection toolbar actions.

2. Improve highlight selection normalization.
   - Normalize selections that include list indentation or markers to a durable visible-text range when the selected text is inside a list item.
   - Keep backend payload compatibility with `messageId`, `selectedText`, `startOffset`, `endOffset`, and `color`.
   - Avoid creating duplicate visual text when new highlights overlap existing highlight records.

3. Define the authenticated API migration boundary.
   - Treat `AuthenticatedApiClient` as the only transport for logged-in REST APIs in the mobile app.
   - Extend it only where needed for migrated services, such as additional HTTP verbs and JSON request helpers.
   - Keep auth errors typed through `MissingAuthTokenException` and `UnauthorizedApiException`.

4. Migrate authenticated API services in low-risk phases.
   - First migrate resource services that are close to text highlights: todo lists and asset tables.
   - Then migrate chat history calls, which have wider UI impact.
   - Then migrate LLM config service away from repeated manual `AuthService.getToken()` calls.
   - Finally remove UI-level token plumbing where services no longer require it.

5. Update documentation and code maps.
   - Update `docs/code_maps/feature_map.yaml` and `docs/code_maps/logic_map.yaml` if feature entry points, highlight logic, tests, or API architecture indexes change.
   - Keep the highlight floating toolbar design note aligned if toolbar behavior changes.

## Acceptance Criteria

- A stored highlight inside a nested Markdown list item renders visibly at the correct text after widget rebuild.
- Nested list indentation and markers remain visually correct while the highlighted text is rendered once.
- A highlight range that overlaps list structure boundaries is normalized or split so visible list text is highlighted instead of silently disappearing.
- Existing highlight tests for paragraphs, code blocks, tables, overlapping ranges, toolbar copy, and delete behavior continue to pass.
- Migrated services no longer accept `required String token` or manually create `Authorization: Bearer ...` headers.
- UI code does not block migrated API actions only because a cached `_authToken` field is null; missing auth is reported through the service error path.
- Code maps identify the highlight renderer and authenticated API client as regression-sensitive areas.

## Validation Commands

- `./tools/init_dev_env.sh`
- `cd apps/mobile_chat_app && flutter test test/message_list_test.dart test/highlight_selection_toolbar_web_test.dart test/text_highlight_api_service_test.dart`
- `cd apps/mobile_chat_app && flutter test`
- `npx js-yaml docs/code_maps/feature_map.yaml > /dev/null && npx js-yaml docs/code_maps/logic_map.yaml > /dev/null && echo "code maps yaml ok"`
