---
name: design-tokens
description: Enforces that every color, spacing value, radius, shadow, duration, and text style in Flutter widget code resolves through the AppTokens ThemeExtension instead of being hardcoded. Use this whenever implementing a screen or widget from a design, adding or changing any visual value, translating a Figma frame, reviewing UI code, or touching the theme. Trigger it even when the request does not mention tokens or theming — any task that produces widget code with visual values needs this skill, because hardcoded values are invisible in review and are the primary cause of design drift.
---

# Design Tokens

> **Profile first.** Read `.claude/flutter-profile.yaml` in the project root. `tokens`
> decides whether this skill applies at all: `theme_extension` (the default, everything
> below holds), `theme_only` — resolve through `Theme.of(context)` and its `ColorScheme`
> and `TextTheme` instead of `context.tokens`, `constants` — resolve through the project's
> constants class, or `none` — the project has no token layer and hardcoded values are not
> a finding. Under `none`, say once that a token layer would help and then stop asking.
> Field list: `references/flutter-profile.md`.

Widget code describes structure. It never contains raw visual values. Every color,
spacing unit, radius, shadow, duration, and text style resolves through the token
extension, because a hardcoded value looks identical to a correct value in code review
and is therefore never caught.

## Hard rules

Never write these in widget code:

- `Color(0xFF...)`, `Colors.blue`, or any literal color
- `EdgeInsets.all(16)` or any numeric padding, margin, or gap
- `BorderRadius.circular(12)` or any numeric radius
- `TextStyle(fontSize: 14, fontWeight: FontWeight.w600)` inline
- `Duration(milliseconds: 300)` for animations
- Raw `BoxShadow` definitions

Write instead:

```dart
Container(
  padding: context.tokens.space.md,
  decoration: BoxDecoration(
    color: context.tokens.color.surfaceRaised,
    borderRadius: context.tokens.radius.card,
    boxShadow: context.tokens.elevation.low,
  ),
  child: Text('Balance', style: context.tokens.text.titleMedium),
)
```

## When a token does not exist

Add it to the token file first, then use it. Never inline a one-off "just this once"
value. One inlined value becomes five within a month, and at that point the token system
is decorative.

If a design uses a value that does not fit the existing scale — 14px spacing where the
scale is 4/8/12/16 — do not add a `space.s14` token. Stop and report it. It is almost
always a mistake in the design file, and silently encoding it makes the scale meaningless.

## Naming convention

Figma variable paths map directly to Dart getters in camelCase:

| Figma variable | Dart getter |
|---|---|
| `color/surface/raised` | `tokens.color.surfaceRaised` |
| `color/text/secondary` | `tokens.color.textSecondary` |
| `spacing/md` | `tokens.space.md` |
| `radius/card` | `tokens.radius.card` |
| `type/title/medium` | `tokens.text.titleMedium` |

Semantic names only. `color.danger`, never `color.red`. A semantic name survives a
rebrand; a literal one does not, and renaming three hundred usages of `red` when the
brand changes is the exact cost this convention exists to avoid.

## Workflow when implementing from a design

1. Pull the frame. Enumerate every distinct visual value it uses.
2. Match each value against the existing token set.
3. Report unmatched values before writing any widget code. Do not begin implementation
   with unresolved values, because the resolution is guessing and the guess ships.
4. Implement using `context.tokens` only.

## Dark mode

Tokens are defined per theme, resolved at call time. A widget that reads
`context.tokens.color.surfaceRaised` works in both themes with no conditional logic.
Any `Theme.of(context).brightness == Brightness.dark` check inside a widget means a
token is missing.

## Common mistakes

- Reading tokens once into a local variable outside `build()`. Tokens must resolve per
  build or theme switching silently stops working.
- Using `Theme.of(context).colorScheme.primary` directly. Go through the extension so
  there is exactly one lookup path.
- Adding a token for a value used once. Tokens are a shared vocabulary; a single-use
  token is a hardcoded value with extra steps.

See `references/theme-extension-template.dart` for the token class structure to follow
when setting this up in a project that does not have one yet.
