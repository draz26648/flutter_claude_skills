---
name: responsive-adaptive
description: Breakpoint rules and adaptive layout conventions for Flutter — LayoutBuilder for component decisions, MediaQuery for screen decisions, and the rule that the design artboard width is a reference and never a hardcoded target. Use this whenever writing layout code, whenever a RenderFlex overflow appears, whenever tablet or desktop or foldable support comes up, whenever a fixed pixel dimension is about to be written, and whenever a design only provides one artboard size. Trigger it on any layout task, because designs are delivered at a single width and code written to that width breaks everywhere else.
---

# Responsive and Adaptive Layout

A design file gives you one width. The app runs on hundreds. Every fixed dimension copied
from the artboard is a future overflow.

## Breakpoints

| Name | Width | Typical |
|---|---|---|
| compact | < 600 | phones, portrait |
| medium | 600–839 | small tablets, phones landscape, unfolded |
| expanded | ≥ 840 | tablets, desktop |

Define these once in `core/layout/breakpoints.dart`. Never inline a magic number
comparison in a widget.

## Which tool for which decision

**`LayoutBuilder`** for how a component lays itself out. It reports the space the widget
actually has, which is what the widget needs to know. A card in a 400pt sidebar on a
1200pt screen should lay out as a narrow card — `MediaQuery` would tell it the screen is
wide and it would be wrong.

**`MediaQuery`** for screen-level decisions: navigation pattern, number of grid columns
for the whole page, whether to show a modal or a side panel.

Reading `MediaQuery.sizeOf(context)` inside a leaf widget is almost always the wrong tool.
Note `sizeOf` rather than `MediaQuery.of(context).size` — the latter subscribes the widget
to every MediaQuery change including keyboard appearance, causing rebuilds on every
keystroke.

## Rules

**No hardcoded screen dimensions.** `width: 390` is a bug regardless of what the design
says. Fixed sizes are only valid for things that are genuinely fixed: an icon, an avatar,
a fixed-height app bar.

**Avoid percentage-of-screen sizing for text containers.** `width: screenWidth * 0.8`
looks fine at the design width and breaks at 2.0 text scale. Let content determine height
and constrain with `ConstrainedBox` where a maximum is genuinely needed.

**Scroll by default.** Any screen that can plausibly overflow — which is any screen with
more than three elements once text scale is raised — goes in a scroll view. Wrap fixed
layouts in `SingleChildScrollView` with `physics: ClampingScrollPhysics()` rather than
discovering the overflow on a small device.

**Handle the keyboard.** `resizeToAvoidBottomInset` plus a scroll view, or the form
disappears behind the keyboard on short screens.

**Safe areas are not optional.** `SafeArea` on every screen, and mind that a bottom
navigation bar needs the bottom inset while the content above it does not.

## Orientation and foldables

Do not lock orientation without a product reason. If landscape is supported, a
two-column layout above the medium breakpoint is usually the right move rather than
stretching a single column to 900pt — a text line longer than about 75 characters is
measurably harder to read.

## Common mistakes

- `MediaQuery.of(context).size.width * 0.44` to fit two cards in a row. Use
  `GridView` or `Expanded` — the arithmetic version breaks the moment padding changes.
- Testing only on the simulator's default device. Check the smallest supported device
  and the largest, at 2.0 text scale, before considering layout work finished.
- Using `Wrap` where `Flexible` was needed. `Wrap` moves the overflowing item to the
  next line, which is rarely what a design intends for a row of two elements.
