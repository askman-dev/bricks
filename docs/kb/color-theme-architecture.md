# Color & Theme Architecture Guidelines

## 1. Goals

The color system in this project must serve long-term maintenance rather than
serve as a quick fix for a single screen.

Color-related code must satisfy these requirements:

- Designs can be unified centrally.
- Light and dark themes can be switched transparently.
- Components are reusable.
- Screen-level visual style can be adjusted without touching component code.
- Colors are testable by verifying token usage, not concrete values.
- Local fixes must not break the global theme.

Business components must not decide colors themselves.
Business components must only read pre-defined semantic color tokens.

---

## 2. Core Principles

### 2.1 No concrete color values in business components

Business components must not contain explicit color literals, for example:

```dart
// ❌ Do not do this in a widget
const Color(0xFFF2F2F2)
```

Concrete color values belong only in theme files, design-token files, or
`ThemeExtension` definitions.

Business components consume semantic tokens only, for example:

```dart
// ✅ Correct
chatColors.userMessageContainer
```

Not:

```dart
// ❌ Incorrect
const Color(0xFFF2F2F2)
```

### 2.2 No light/dark branching inside business components

Business components must not branch on the current brightness themselves.

Do not write:

```dart
// ❌ Do not do this in a widget
Theme.of(context).brightness == Brightness.dark ? darkColor : lightColor
```

The difference between light and dark is handled entirely by the theme layer.
The component reads the same semantic token in both modes; the theme provides
the correct color for each mode.

### 2.3 Do not use Material `ColorScheme` as business semantics

Do not treat Material's general-purpose colors as chat-specific meanings:

- `colorScheme.primary`
- `colorScheme.onPrimary`
- `colorScheme.surface`
- `colorScheme.surfaceContainerHighest`

These express Material Design's structural semantics, not this product's chat
bubbles, input fields, agent messages, or model selection chips.

`ColorScheme` can serve as a foundation for Material base widgets (Scaffold,
Dialog, Button, etc.), but core product components must use product-level
semantic tokens.

---

## 3. Color Layer Architecture

Colors are organized in three layers:

```
Primitive Colors   →   Semantic Colors   →   Component Colors
(raw palette)          (app-wide meaning)      (feature-specific meaning)
```

---

## 4. Primitive Colors (`AppPrimitiveColors` / `AppColors`)

Primitive colors are the lowest-level color palette. They express the color
itself, not any business meaning.

Examples:
- black scale, grey scale, white scale
- blue scale, warning scale, danger scale

Primitive colors must only appear in the theme definition layer.
Business components must never reference primitive colors directly.

| ❌ Wrong | ✅ Correct |
|---------|-----------|
| `message bubble uses gray900` | `message bubble uses userMessageContainer` |

`gray900` is a raw color. `userMessageContainer` is a business semantic.

---

## 5. Semantic Colors (`AppSemanticColors`)

Semantic colors express application-level meaning. Recommended tokens:

| Token | Usage |
|-------|-------|
| `pageBackground` | Screen background |
| `surface` | Standard card background |
| `surfaceRaised` | Floating card / overlay background |
| `surfaceOverlay` | Modal scrim / drawer overlay |
| `borderSubtle` | Low-emphasis borders |
| `borderStrong` | High-emphasis borders |
| `textPrimary` | Primary body text |
| `textSecondary` | Secondary / supporting text |
| `textTertiary` | Weak hints / disabled labels |
| `iconPrimary` | Primary icons |
| `iconSecondary` | Secondary / supporting icons |
| `accent` | Brand accent / interactive highlight |
| `warning` | Warning state |
| `danger` | Error / destructive state |

Use semantic tokens for generic page structure: page backgrounds, ordinary
cards, primary text, secondary explanations, and weak hints.

---

## 6. Component Colors (`ChatColors`, etc.)

Core business components must define their own component-level color tokens.

The chat screen must not rely solely on generic `surface` or `primary` tokens,
because the chat screen contains distinct product semantics:

- User messages
- Agent (assistant) messages
- System prompts
- Composer / input area
- Model selector chip
- Toolbar buttons
- Status information
- Error information

Define a dedicated `ChatColors` `ThemeExtension` for the chat module.

---

## 7. `ChatColors` Token Definitions

### User Message Bubble

| Token | Description |
|-------|-------------|
| `userMessageContainer` | User bubble background |
| `userMessageBorder` | User bubble border (if any) |
| `onUserMessageContainer` | Text and icon foreground inside user bubble |
| `userMessageMeta` | Secondary / timestamp / delivery status text |

### Agent (Assistant) Message

| Token | Description |
|-------|-------------|
| `agentMessageContainer` | Agent bubble background (`null` = no bubble) |
| `agentMessageBorder` | Agent bubble border (if any) |
| `onAgentMessageContainer` | Main text color of agent message |
| `agentMessageMeta` | Secondary / timestamp / model label text |

### Agent Header & Badge

| Token | Description |
|-------|-------------|
| `agentName` | Agent name label color |
| `agentBadgeContainer` | nodeType badge background |
| `onAgentBadgeContainer` | nodeType badge text color |

### Agent Accent

| Token | Description |
|-------|-------------|
| `agentAccent` | Thinking spinner, streaming spinner, routing label accent |

### System Prompt Capsule

| Token | Description |
|-------|-------------|
| `promptBubbleContainer` | Background |
| `promptBubbleBorder` | Border |
| `onPromptBubbleContainer` | Text |

### Composer / Input Area

| Token | Description |
|-------|-------------|
| `composerContainer` | Input area background |
| `composerBorder` | Input area border |
| `composerPlaceholder` | Placeholder text |
| `onComposer` | User-typed text |
| `composerIconContainer` | Toolbar icon background |
| `onComposerIcon` | Toolbar icon foreground |

### Model Selector Chip

| Token | Description |
|-------|-------------|
| `modelChipContainer` | Chip background |
| `modelChipBorder` | Chip border |
| `onModelChipContainer` | Chip label text |

### Status & Emphasis

| Token | Description |
|-------|-------------|
| `link` | Hyperlink / tappable text |
| `selected` | Selected / active state highlight |
| `thinking` | AI "thinking" animation color |
| `warning` | Warning indicator |
| `error` | Error indicator |

Token names express **where** the color is used, not what it looks like.

---

## 8. Light and Dark Theme Definitions

Every color token must have both a light and a dark value.

```dart
static const ChatColors light = ChatColors(
  userMessageContainer: Color(0xFFF2F2F2),
  // ...
);

static const ChatColors dark = ChatColors(
  userMessageContainer: AppColors.surface2,
  // ...
);
```

Business components do not care about the current theme mode.
The theme system is responsible for switching between `light` and `dark`.

Always write component code as:

```dart
// ✅ Correct — theme decides which value applies
chatColors.userMessageContainer
```

Never:

```dart
// ❌ Incorrect — component decides the color itself
isDark ? AppColors.surface2 : const Color(0xFFF2F2F2)
```

---

## 9. Component Usage Rules

**Allowed inside business components:**

```dart
chatColors.userMessageContainer
chatColors.onUserMessageContainer
chatColors.composerContainer
chatColors.composerBorder
semanticColors.pageBackground
```

**Not allowed inside business components:**

- Explicit color literals (`const Color(...)`)
- Light/dark branching (`brightness == Brightness.dark ? ... : ...`)
- Ad-hoc opacity helpers (`.withOpacity(0.5)` written directly in a widget)
- Material `ColorScheme` tokens used as product-specific semantics

If transparency is needed, define a dedicated token:

```dart
// ✅ Correct
borderSubtle          // already encodes the desired opacity
overlayWeak           // pre-defined overlay with correct alpha
```

---

## 10. Boundary of Material `ColorScheme`

`ColorScheme` is appropriate for Material base widgets:

- `Scaffold`
- `Dialog`
- Default `Button` and `IconButton` theming
- Default `TextField` theming

Product-core components must use product semantic tokens, not `ColorScheme`
directly. Binding chat bubbles to `colorScheme.primary` or
`colorScheme.surfaceContainerHighest` is fragile because:

- `primary` is typically a brand accent, not a message bubble background.
- `surfaceContainerHighest` is a Material container-hierarchy concept.
- Adjusting the Material theme in the future must not accidentally change chat
  message appearance.
- The chat screen requires finer design control than generic Material semantics
  provide.

---

## 11. User Message Bubble Design Semantics

The user message bubble is a standalone component semantic:

- `userMessageContainer` — bubble background
- `userMessageBorder` — bubble border (if used)
- `onUserMessageContainer` — text and icon foreground inside the bubble
- `userMessageMeta` — meta / timestamp / delivery status text

Design requirements:

- No large-area brand color.
- No dependency on `colorScheme.primary`.
- No hard-coded light or dark color value inside the component.
- No brightness branching inside the component.
- `ChatColors` provides the correct color for both light and dark modes.
- Changes to the bubble color must not affect other cards, buttons, or inputs.

---

## 12. Agent Message Design Semantics

Agent messages also need dedicated semantics. Agent messages have different
information structure from user messages:

- User messages represent submitted input.
- Agent messages are system responses that may contain long text, code blocks,
  lists, error details, and tool-call information.

Therefore, agent messages need a stable, reading-friendly color layer that is
separate from user message styling.

---

## 13. Composer / Input Area Design Semantics

The composer is the core interaction zone, separate from message content.
Define it independently from message bubble colors.

---

## 14. Recommended Code Structure

```
lib/
  theme/
    app_primitive_colors.dart   ← raw color palette
    app_semantic_colors.dart    ← app-wide semantic tokens
    app_chat_colors.dart        ← chat module ThemeExtension
    app_theme.dart              ← registers light/dark ThemeData
```

Or, within the `design_system` package:

```
packages/design_system/lib/src/
  tokens.dart            ← AppColors (primitive) + BricksSpacing / BricksRadius
  app_chat_colors.dart   ← ChatColors ThemeExtension
  bricks_theme.dart      ← BricksTheme (registers extensions)
```

Business components import only theme tokens; they never define colors.

---

## 15. Testing Guidelines

Tests must not assert that a component contains a specific concrete color value.

| ❌ Wrong test target | ✅ Correct test target |
|---------------------|----------------------|
| "User bubble color equals `0xFFF2F2F2`." | "User bubble color comes from `chatColors.userMessageContainer`." |

Tests can inject a custom test theme with known token values, then verify that
the component reads those tokens correctly.

This approach tests the architecture relationship, not a design value. When a
designer changes a color, tests must not fail because of the color change — they
must only fail when the component stops reading the correct theme token.

```dart
// ✅ Correct pattern
final chatColors =
    Theme.of(tester.element(find.byKey(key)))
        .extension<ChatColors>() ??
    ChatColors.light;
expect(deliveryIcon.color, chatColors.onUserMessageContainer);

// ❌ Incorrect pattern
expect(deliveryIcon.color, const Color(0xFF1C1C1E));
```

---

## 16. Code Review Checklist

When reviewing color-related changes, verify:

1. Does the business component introduce a new concrete color literal?
2. Does the business component branch on `brightness`?
3. Is `colorScheme.primary` used directly as a chat bubble color?
4. Is a Material surface token used directly as a product component color?
5. Should a new semantic token be added instead?
6. Is the new color defined in the theme/token layer?
7. Are both light and dark values defined?
8. Does the test verify token consumption, not a hard-coded color value?
9. Could this color change accidentally affect unrelated components?
10. Does the token name express purpose (where it is used) rather than
    appearance (what it looks like)?

---

## 17. Requirements for AI Agents and Developers

When modifying UI colors, follow these rules without exception:

- **Do not** write `const Color(...)` in a business component.
- **Do not** write `brightness == Brightness.dark` in a business component.
- **Do not** substitute `colorScheme.primary` for a user message bubble.
- **Do not** substitute a Material surface token for a product component color.
- Identify whether the color belongs to the primitive, semantic, or component
  layer.
- If the color is chat-page-specific, define it in `ChatColors`.
- If the color is app-wide, define it in `SemanticColors` (or `AppColors`).
- If the color is a raw palette entry, define it in `PrimitiveColors`.
- Components only read semantic tokens.
- Tests verify that components read the correct tokens.

---

## 18. Summary Rule

Concrete color values may exist — but only in the theme layer.

**Business components should see:**

```dart
chatColors.userMessageContainer
chatColors.onUserMessageContainer
chatColors.composerContainer
semanticColors.pageBackground
```

**Business components must not see:**

- Concrete color literals
- Brightness-mode branching
- Ad-hoc color fixes
- Material general-purpose colors used as product semantics

The boundary is:

> **Theme decides color. Component decides structure. Business code does not
> decide the design system.**
