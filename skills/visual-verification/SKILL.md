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
python3 scripts/compare.py \
  --actual build/screenshots/login_screen.png \
  --expected design/exports/login_screen.png \
  --output build/screenshots/login_screen_diff.png \
  --threshold 0.02
```

The comparison logic lives in `scripts/compare.py` so it executes without loading into
context. Anything deterministic belongs in a script — prose describing a comparison
algorithm costs tokens on every trigger and is less reliable than running the algorithm.

## Reading a diff

The output image highlights differing regions. Interpret them:

- **A sharp offset of the entire content block** — padding or a margin token is wrong.
- **Text differing at the edges only** — font weight, letter spacing, or line height.
- **Whole regions differing in tone** — wrong color token, or a missing opacity.
- **Everything shifted by a constant** — the export scale does not match the capture
  device pixel ratio. Fix the export, not the code.
- **Text differing in shape entirely** — the font is not bundled. Check `pubspec.yaml`
  before changing anything in the widget.

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
