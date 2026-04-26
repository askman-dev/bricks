# Color & Theme Architecture Guidelines

## 1. Goals

The color system must stay small, reusable, and predictable. A color change
should usually happen in one design-system layer instead of spreading across
widgets.

Color-related code must satisfy these requirements:

- Components do not contain concrete color literals.
- Components consume named design-system tokens.
- Dark and light values are supplied by the theme layer.
- Most UI surfaces reuse a small set of background/surface layers.
- Component-specific tokens are thin aliases for product semantics, not a new
  color scale for every widget.
- Tests verify token consumption, not exact color values.

---

## 2. Layer Model

Colors are organized in two practical layers:

```text
Core layer tokens  ->  Component aliases
AppColors              ChatColors, future feature ThemeExtensions
```

`AppColors` is the small shared vocabulary. It defines the app's surface,
border, text, accent, and status layers.

`ChatColors` is a feature-level alias layer. It gives chat code readable names
such as `composerBackground` and `codeBlockBackground`, but those values should
usually map back to `AppColors` rather than introduce one-off colors.

---

## 3. Core Layer Tokens

Use these roles before adding new tokens:

| Token | Meaning |
|---|---|
| `backgroundChrome` | Lowest shell/chrome background. In dark mode this is pure black. |
| `backgroundBase` | Main reading/page background. |
| `surfaceDefault` | Recessed or embedded content block surface, such as markdown/code blocks. |
| `surfaceSubtle` | Low-emphasis secondary surface, such as badges or quote blocks. |
| `surfaceElevated` | Raised/floating interaction surface, such as composer or overlays. |
| `borderSubtle` | Low-emphasis borders. |
| `borderFocus` | Focused or high-emphasis borders. |
| `textPrimary` | Primary readable text. |
| `textSecondary` | Supporting text. |
| `textTertiary` | Weak hints or tertiary metadata. |
| `accentPrimary` | Brand/interactive accent. |
| `danger`, `warning`, `success` | Status colors. |

Do not add component-shaped core tokens such as `surfaceInput` or
`messageCardBackground`. If the color is a surface layer, name the layer.

---

## 4. Component Aliases

Component aliases are useful when they express product meaning or make widget
code easier to read. They should be limited and should usually point at the
core layer tokens.

Examples:

```dart
composerBackground: AppColors.surfaceElevated
codeBlockBackground: AppColors.surfaceDefault
quoteBackground: AppColors.surfaceSubtle
agentBadgeContainer: AppColors.surfaceSubtle
```

Add a new component alias only when all of these are true:

1. The component role is stable and product-specific.
2. Existing core layer names would make call sites unclear.
3. The alias is expected to be reused by more than a single ad-hoc state.
4. The alias can be mapped to existing core layers unless a genuinely new
   visual role is being introduced.

Avoid adding aliases only because one widget needs a different color once.

---

## 5. Business Component Rules

Business widgets must not contain concrete color literals:

```dart
// Incorrect
const Color(0xFF303030)
```

Business widgets should read tokens:

```dart
// Correct
chatColors.composerBackground
AppColors.surfaceElevated
```

Prefer feature aliases in reusable feature widgets. Screen composition code may
choose between existing core layer tokens when the layout changes the surface
role, for example compact chat using `backgroundChrome` for the page and
`backgroundBase` for the composer while wide chat uses `backgroundBase` and
`surfaceElevated`.

The important boundary is: widgets may choose a surface role, but they must not
invent a color value.

---

## 6. Responsive Surface Roles

Responsive color changes must be explained as surface role changes, not as
device-specific color hacks.

Current dark chat model:

```text
Compact chat:
  page      -> backgroundChrome (#000000)
  composer  -> backgroundBase (#212121)

Wide chat:
  page      -> backgroundBase (#212121)
  composer  -> surfaceElevated (#303030)

Markdown/code:
  block     -> surfaceDefault (#181818)
```

This follows the rule that the composer is one visual layer above the current
page surface, while markdown/code blocks are embedded content surfaces.

---

## 7. Material `ColorScheme`

`ColorScheme` is appropriate for Material defaults:

- `Scaffold`
- `Dialog`
- default Material buttons
- default Material text fields

Product-core surfaces should not depend directly on generic Material meanings
such as `colorScheme.primary` or `surfaceContainerHighest`. Map our product
layers into the Material theme in `BricksTheme`, then keep product widgets on
`AppColors`/`ChatColors`.

---

## 8. Testing Guidelines

Tests should verify token use, not concrete color values.

| Avoid | Prefer |
|---|---|
| "Composer color equals `0xFF303030`." | "Composer reads `chatColors.composerBackground` unless layout overrides the surface role." |
| "Delivery icon is blue." | "Delivery icon reads the expected status/accent token." |

When possible, inject a test theme with known token values and assert the widget
reads the expected token.

---

## 9. Review Checklist

When reviewing color changes, check:

1. Does the widget introduce a concrete `Color(...)` value?
2. Can an existing `AppColors` layer express the visual role?
3. Is a new component alias truly reusable product semantics?
4. Does the alias map to an existing core layer where possible?
5. Does a responsive difference reflect a changed surface role?
6. Are light and dark values defined in the theme layer?
7. Does the test verify token usage instead of exact color values?
8. Could the change affect unrelated components?

---

## 10. Summary Rule

Use a small surface vocabulary first. Add component aliases sparingly.

```text
Core surface role first.
Component alias second.
Concrete color value only in the design-system layer.
```
