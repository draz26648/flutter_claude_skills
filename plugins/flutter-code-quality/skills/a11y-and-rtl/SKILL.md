---
name: a11y-and-rtl
description: Accessibility and right-to-left requirements that design files never specify — directional insets, mirrored icons, text scaling to 2.0 without overflow, semantics labels, touch target minimums, and contrast. Use this on any user-facing widget, any hardcoded string, any icon, any directional padding, and any app that ships Arabic, Hebrew, Farsi, or Urdu. Trigger it on every UI task without waiting to be asked, because these requirements live entirely on the implementer's side, are absent from every design handoff, and are discovered by users rather than by review.
---

# Accessibility and RTL

> **Profile first.** Read `.claude/flutter-profile.yaml` in the project root. `locales`
> sets how hard the RTL section below pushes: directional insets are better practice in
> any project, but a project shipping an RTL locale (`ar`, `he`, `fa`, `ur`, `ps`, `sd`,
> `ug`, `dv`, `yi`) has a visible bug rather than a habit, and there it blocks. `l10n:
> none` suspends the hardcoded-string rule and nothing else — semantics, text scaling, and
> touch targets apply to every project regardless. Field list:
> `${CLAUDE_PLUGIN_ROOT}/skills/architecture/references/flutter-profile.md`.

Design files are laid out left to right, at a fixed width, at default text scale, in one
language. None of them specify what happens otherwise. That gap is the implementer's
responsibility, and it is skipped under deadline unless it is written down.

## RTL

**`EdgeInsetsDirectional`, always.** `EdgeInsets.only(left: 16)` puts padding on the
left in every language. In Arabic the layout mirrors and the padding does not, which
looks subtly broken in a way that is hard to name and easy to notice.

```dart
padding: const EdgeInsetsDirectional.only(start: 16, end: 8)
```

The same applies to `AlignmentDirectional`, `BorderRadiusDirectional`, and
`PositionedDirectional`. Use `start` and `end`, never `left` and `right`.

**Icons that mirror, and icons that do not.** This is the part that requires judgement:

| Mirrors | Does not mirror |
|---|---|
| Back and forward arrows | Play and pause |
| Chevrons in navigation | Clock faces |
| Send | Checkmarks |
| Undo and redo | Logos and brand marks |
| Text alignment icons | Numerals in most contexts |
| List and indent controls | Media progress direction |

Mirror with `Transform(transform: Matrix4.rotationY(math.pi))` guarded on
`Directionality.of(context)`, or use the icon set's built-in directional variants where
they exist.

**Numbers and mixed text.** Arabic text containing Latin numerals or a Latin brand name
runs into bidirectional text handling. Test with real content, not lorem ipsum — bidi
bugs only appear with mixed-script strings.

**Test RTL explicitly.** Every widget test gets an RTL variant, or the mirroring is
verified by nobody.

## Text scaling

Layouts must survive `textScaler` up to 2.0 without overflow. This is the single most
common accessibility failure in Flutter apps and it is entirely preventable.

- Never set a fixed height on a container holding text.
- Never use `maxLines: 1` with `overflow: TextOverflow.ellipsis` on content the user
  needs to read. Ellipsizing a balance or an error message is a bug.
- Buttons grow with their label. A fixed-height button clips its text at 1.5x.
- Test at 1.0 and 2.0 in goldens.

Never clamp the scale factor globally to "protect the layout". That overrides an
accessibility setting the user deliberately chose, and on iOS it is grounds for review
rejection.

## Semantics

- Every interactive element has a label. Icon-only buttons are unlabelled by default and
  are silent to a screen reader.
- Decorative images are `ExcludeSemantics`, so the reader does not announce filenames.
- Group related elements with `MergeSemantics` — a price and its currency read as one
  item, not two.
- Announce state changes. A loading spinner that appears silently leaves a screen reader
  user with no indication anything happened.

```dart
Semantics(
  label: 'Transfer funds',
  button: true,
  child: IconButton(icon: const Icon(Icons.send), onPressed: onTransfer),
)
```

## Touch targets and contrast

Minimum 48x48 logical pixels for anything tappable, regardless of the icon's visual size.
Use `MaterialTapTargetSize.padded` or wrap in a sized container.

Text contrast of at least 4.5:1 against its background, 3:1 for large text. Check the
tokens once at the theme level rather than per screen. Secondary text colors are the
usual failure — they are chosen for aesthetics on white and fail against a raised surface.

## Localization

No hardcoded user-facing strings. Every string goes through ARB files, including error
messages, empty states, and semantics labels. Semantics labels are read aloud, so an
untranslated one is read in the wrong language.

Never concatenate translated fragments. Word order differs between languages; use
parameterized messages instead.

## Common mistakes

- Adding `textDirection: TextDirection.rtl` to individual widgets instead of letting
  `Directionality` inherit from the app locale.
- Assuming Arabic just needs the text translated. Layout, icons, animation direction,
  and swipe gestures all mirror.
- Testing RTL by switching the device language and glancing at one screen.
