---
name: figma-to-widget
description: The translation contract from Figma structures to Flutter widgets — Auto Layout to Row and Column, constraints to Flexible or fixed sizing, absolute positioning to Stack. Use this whenever a Figma link, frame, design file, mockup, or screenshot is mentioned, whenever asked to build or implement a screen or component from a design, and whenever design specs need to become widget code. Trigger it even when the request is casual ("build this screen", "make it look like the design") because the default translation an agent produces without this skill uses Stack and hardcoded offsets, which breaks on every device that is not the artboard width.
---

# Figma to Widget

The failure mode this prevents: translating a design by reading pixel positions and
reproducing them with `Stack` and `Positioned`. That output matches the artboard exactly
and breaks on every other screen size. Figma's layout system maps cleanly onto Flutter's
— use the mapping, not the coordinates.

## Prerequisite

Check whether the Figma MCP server is connected. If it is, pull the frame directly and
read real values. If it is not, say so before starting: without it, every value is being
read off a rasterized image and is a guess. Ask for the design tokens, a Dev Mode
inspection export, or the spacing scale rather than guessing silently.

## The mapping

| Figma | Flutter |
|---|---|
| Auto Layout, vertical | `Column` |
| Auto Layout, horizontal | `Row` |
| Auto Layout gap | `spacing:` on Row/Column, or a `Gap` widget |
| Auto Layout padding | `Padding` with a directional token |
| Space between | `MainAxisAlignment.spaceBetween` |
| Hug contents | `MainAxisSize.min` |
| Fill container | `Expanded`, or `double.infinity` on a single child |
| Fixed width/height | `SizedBox`, only when the design truly requires it |
| Absolute position | `Stack` + `Positioned` — last resort only |
| Frame with clip | `ClipRRect` with a radius token |
| Component instance | An existing widget from the codebase |
| Component variant | A parameter or enum on that widget, not a new widget |

## Rules

**Auto Layout first.** If a frame uses Auto Layout, the output uses Row or Column. Reach
for `Stack` only when the design genuinely overlaps elements — an avatar badge, a
floating action button over content. Overlap is the only valid reason.

**Never hardcode the artboard width.** A 390pt frame is a reference, not a target.
Fixed widths appear only where the design is explicitly fixed regardless of screen —
an avatar, an icon, a fixed-size chip.

**Check for an existing component before building a new one.** A Figma component
instance almost always corresponds to a widget that already exists in the codebase.
Search for it. Building a second `PrimaryButton` because the first was not found is the
most common form of duplication in agent-generated UI.

**Variants are parameters.** A Figma component with Default, Hover, Disabled, and Loading
variants becomes one widget with a state parameter — not four widgets.

**Text is never `Text('...')` with an inline style.** Style comes from the tokens
(see the design-tokens skill), content comes from localization (see a11y-and-rtl).

## Workflow

1. Pull the frame and identify its layer tree.
2. List every distinct visual value in it. Resolve each against the token set. Report
   anything unmatched before writing code.
3. Identify which layers are instances of existing components. Search the codebase for
   each. Reuse.
4. Write the widget tree following the mapping table above.
5. Hand off to the visual-verification skill. Do not declare the screen done on the
   basis that it compiled.

## Common mistakes

- Nesting `Container` inside `Container` because the design has nested frames. Collapse
  them; one `Container` handles padding, color, and radius together.
- Producing one enormous `build()` method for the whole screen. Split at the same
  boundaries the design file uses for its components.
- Adding `SizedBox(height: n)` between every element instead of using the parent's
  `spacing` parameter. The design expresses it as an Auto Layout gap; express it the
  same way.
