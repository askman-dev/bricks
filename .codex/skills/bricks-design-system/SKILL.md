---
name: bricks-design-system
description: Use when modifying or reviewing Bricks UI design, color choices, theme tokens, AppColors, ChatColors, component color aliases, hardcoded Color values, responsive dark surfaces, composer/message/sidebar styling, or design-system documentation. Also use when the user asks whether a color should reuse a token, whether token definitions are redundant, or how to keep code, KB docs, plans, and code maps aligned. Guides agents to preserve the surface-layer-first token model, map component aliases back to core tokens, avoid copying literal token values into aliases, avoid redundant component-specific tokens, and keep implementation and documentation consistent.
---

# Bricks Design System

Use this skill before changing UI colors, theme tokens, chat surface styling, or design-system documentation.

## Required context

Read these files first:

1. `docs/kb/color-theme-architecture.md` — canonical color/theme rules.
2. `packages/design_system/lib/src/tokens.dart` — core `AppColors` layers.
3. `packages/design_system/lib/src/chat_colors.dart` — chat feature aliases.
4. The widget files you are changing, usually under `apps/mobile_chat_app/lib/features/...`.

## Token decision rules

Prefer the core surface/text/border/accent/status layers before adding anything:

- `backgroundChrome`
- `backgroundBase`
- `surfaceDefault`
- `surfaceSubtle`
- `surfaceElevated`
- `borderSubtle`
- `borderFocus`
- `textPrimary`
- `textSecondary`
- `textTertiary`
- `accentPrimary`
- `danger`, `warning`, `success`

Do not add component-shaped core tokens such as `surfaceInput`,
`composerSurface`, or `messageCardBackground`. If the role is a surface layer,
name and reuse the layer.

Add or keep a component alias such as `ChatColors.composerBackground` only when
it represents stable product meaning and makes call sites clearer. Component
aliases should usually map back to `AppColors`.

Do not copy a core token's literal value into a component alias. For example,
if an enabled neutral composer action should use the primary readable/icon
color, write `composerActionIdle: AppColors.textPrimary`, not
`composerActionIdle: Color(0xFFE7E9EA)`.

## Responsive surfaces

Responsive color changes must be explained as surface-role changes, not device
color hacks.

Current dark chat model:

```text
Compact chat:
  page      -> AppColors.backgroundChrome
  composer  -> AppColors.backgroundBase

Wide chat:
  page      -> AppColors.backgroundBase
  composer  -> AppColors.surfaceElevated

Markdown/code:
  block     -> AppColors.surfaceDefault
```

If a responsive branch is needed, choose between existing surface roles. Do not
introduce raw colors in widgets.

## Redundancy checks

Before adding or retaining a token:

1. Search for existing definitions and consumers:
   ```bash
   rg -n "tokenName|AppColors\\.|ChatColors\\.|chatColors\\." packages/design_system apps/mobile_chat_app docs -S
   ```
2. Remove unused aliases when they are not part of a planned migration.
3. Update the KB if the design principle changes.
4. Update plans and code maps when token/docs indexes change.

## Validation

For Dart token or widget changes:

```bash
dart format <changed dart files>
cd apps/mobile_chat_app && flutter analyze
```

When code maps are touched:

```bash
python3 -c "import yaml; yaml.safe_load(open('docs/code_maps/feature_map.yaml')); yaml.safe_load(open('docs/code_maps/logic_map.yaml')); print('code maps yaml ok')"
```

## Review checklist

- No concrete `Color(...)` values in business widgets.
- New tokens are core layers or justified component aliases.
- Component aliases map to existing core layers where possible.
- Responsive differences describe changed surface roles.
- KB, plans, and code maps do not contradict the code.
