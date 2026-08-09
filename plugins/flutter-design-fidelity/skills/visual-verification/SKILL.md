---
name: visual-verification
description: Closes the feedback loop on UI work by building the screen, capturing a screenshot, diffing it against the reference design export, and iterating until the difference falls under threshold. Use this after implementing or modifying any screen or widget from a design, whenever asked whether something matches the design, and before declaring any UI task complete. Trigger it proactively at the end of UI work rather than waiting to be asked, because generated UI that compiles is not the same as UI that matches, and without this loop the first render is treated as the final one.
---

# Visual Verification

An agent with no feedback loop declares a screen finished the moment it compiles. That
is the single largest source of "looks roughly right but is wrong" UI. This skill
supplies the loop.

## The loop

1. Run the widget in the harness and capture a screenshot.
2. Diff it against the reference export from the design.
3. If the difference is above threshold, read the diff output to find where, fix, and
   repeat from step 1.
4. Stop when under threshold, or after four iterations — at which point report what is
   still off rather than continuing to guess.

Four iterations is a deliberate cap. Beyond that the remaining difference is usually
something the diff cannot fix on its own: a missing font, a wrong export scale, or a
design that was updated after the export.

## Running it

```bash
# Capture the current implementation
flutter test integration_test/screenshot_test.dart --dart-define=CAPTURE=true

# Diff against the reference
python3 "${CLAUDE_PLUGIN_ROOT}/skills/visual-verification/scripts/compare.py" \
  --actual build/screenshots/login_screen.png \
  --expected design/exports/login_screen.png \
  --output build/screenshots/login_screen_diff.png \
  --threshold 0.02
```

`CLAUDE_PLUGIN_ROOT` is set by Claude Code and expands on its own; it does not need
resolving by hand. If the skill was vendored into the project rather than installed as a
plugin, that variable is unset — use `.claude/skills/visual-verification/scripts/compare.py`
instead.

The comparison logic lives in a script rather than in prose so it executes without
loading into context. Anything deterministic belongs in a script — prose describing a
comparison algorithm costs tokens on every trigger and is less reliable than running the
algorithm.

First run only, install its dependencies:

```bash
pip install pillow numpy
```

Exit codes: `0` match, `1` difference above threshold, `2` could not run — a missing file,
an unreadable image, or bad arguments. **A `2` is not a pass**, and it is not a failing
screen either; it means the comparison never happened.

## Two thresholds

`--threshold` (default 0.02) is the share of differing pixels across the whole image.
`--max-cluster` (default 0.25) is the share within the worst single cell of a 12×12 grid.
Either one being exceeded fails the comparison.

The second exists because a global percentage hides the defects that matter most. A
button rendered with the wrong color token covers about 1.5% of a phone screen — under
the global threshold, and the first thing anyone notices. Judged locally it is a solid
block of wrong, and it fails. When a run fails on the cluster threshold alone, the
problem is one specific element, not a global color or scale issue, and the output says
so.

If a screen has inherently dynamic content — a status bar clock, a live avatar — exclude
it with `--ignore-region X,Y,W,H` rather than raising the threshold until it passes.
Raising the threshold blinds the whole screen to fix one rectangle.

## Reading a diff

The output image is the capture, faded, with differing pixels burned in as red. Interpret
the red:

- **A sharp offset of the entire content block** — padding or a margin token is wrong.
- **Red outlining every glyph edge** — font weight, letter spacing, or line height.
- **A solid red block over one element** — wrong color token, or a missing opacity.
- **Red everywhere, evenly** — the export scale does not match the capture device pixel
  ratio. Fix the export, not the code.
- **Text differing in shape entirely** — the font is not bundled. Check `pubspec.yaml`
  before changing anything in the widget.

Alongside the image the script prints the bounding box of all differences and the
densest region. Read those before opening the PNG — they usually identify the element on
their own.

## Size mismatch is an error, not something to work around

If the capture and the reference are different sizes the script stops. That is
deliberate: rescaling one to fit the other manufactures edge noise along every boundary
in the image, which buries the real defect under artifacts. A size mismatch nearly always
means the export scale does not match the capture's device pixel ratio — fix that.
`--allow-resize` overrides it when you genuinely need a rough comparison, and the output
warns that the noise is expected.

## Export requirements

The reference export must match the capture conditions or the diff is meaningless:
same device pixel ratio, same logical width, same theme, same locale, same text scale.
Export at 2x from a 390pt frame and capture at 3x, and the diff will report failure on
a pixel-perfect implementation.

State these conditions in the test harness rather than assuming them.

## What this does not catch

Static comparison verifies one state on one device. It says nothing about scroll
behaviour, animation, keyboard interaction, text overflow at larger scale factors, or
RTL. Those need their own checks — see the a11y-and-rtl and responsive-adaptive skills.
Passing a visual diff is a floor, not a ceiling.
