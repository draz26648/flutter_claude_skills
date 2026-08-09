---
name: codebase-conventions
description: Makes generated code look like the code already in the repository — reuse the existing widget instead of building a second one, resolve typography and colours through the project's own source, reference only assets that exist and are declared, and match the file, class, and import naming already in use. Use this before writing any widget, any screen, any shared component, any Text style, and any asset reference, and whenever a task says "add a screen", "build a component", "make it match the rest of the app", or "use our design system". Trigger it on every code-writing task without waiting to be asked, because the default failure is invisible: the code compiles, looks reasonable in isolation, and quietly duplicates a component that already existed under a different name.
---

# Codebase Conventions

The most common defect in agent-written Flutter is not a bug. It is a second
`PrimaryButton` — correct, tested, and redundant, because the project already had one
called `AppButton` and nothing looked for it.

Nothing in review catches this. The diff is all additions, every line is defensible, and
the duplication only surfaces months later when a brand change has to be applied twice.

> **Read the conventions file first.** `.claude/flutter-conventions.md` records where this
> project keeps its shared widgets, typography, colours, and assets, and what its naming
> rules are. Generate it with `/flutter-code-quality:flutter-adapt`.
>
> **If it does not exist, do the discovery below inline before writing code.** Do not skip
> it because there is no file — the file is a cache of an answer you would otherwise have
> to work out, not a precondition.
>
> It records locations and rules, never an inventory of components. A list of every widget
> in the project is out of date within a week and then actively misleads. Search live; use
> the file to know where to search.

## Reuse before create

Search first, and search by **role**, not by the name you have in mind. Searching for
`PrimaryButton`, finding nothing, and building one is the failure — the project calls it
`AppButton`, and one grep for the wrong string is what convinced you otherwise.

For a component that renders X, search in this order:

1. **By suffix.** `grep -rn "class .*Button" lib/` — every button in the project, whatever
   the prefix. Same for `Card`, `Field`, `Tile`, `Sheet`, `Dialog`, `Chip`, `Avatar`.
2. **By the noun in the request.** A "balance card" means grepping `Balance` and `Card`
   separately, not `BalanceCard`.
3. **In the shared directories** the conventions file names, then in the current feature's
   `widgets/` directory.

Then read what you found before deciding. A widget that does 80% of what you need is
usually a parameter away from doing 100%, and adding the parameter is a smaller change
than adding a file.

**Report what you found and what you decided.** "Found `AppButton`, it has no loading
state, adding an `isLoading` parameter" is a reviewable decision. Silently creating
`LoadingButton` is not.

### When a new component is the right answer

- Nothing found after searching all three ways.
- What exists is genuinely a different thing — a `FilterChip` is not a `Tag` because they
  happen to be capsule-shaped.
- Extending the existing one would need a boolean that changes what it fundamentally is.
  Three or more independent boolean parameters usually means two widgets wearing a coat.

Do not create a new component because the existing one is in an inconvenient directory,
because its API is slightly awkward, or because it is easier to write a fresh one than to
read an existing one. Those are the three reasons duplication actually happens.

## Typography

Text styles come from the project's typography source. Never write `TextStyle(...)` inline
in a widget — an inline style is invisible in review and is how a screen ends up two
points off from every other screen.

Where the source is depends on the profile's `tokens` setting: `context.tokens.text.*`,
`Theme.of(context).textTheme.*`, or the project's own constants class. The conventions
file names the exact entry point.

If the design calls for a style the project does not have, add it to the typography source
and use it from there. Do not inline it "just this once" — the token that does not exist
yet is the whole reason the next person inlines one too.

Applying a single modifier to an existing style is fine and is not an inline style:

```dart
style: context.tokens.text.bodyMedium.copyWith(color: context.tokens.color.danger)
```

Reaching for `copyWith` on three properties at once means the style itself is missing.

## Assets

**Never invent an asset path.** A path that does not resolve throws at runtime, in the
widget, on the device — `flutter analyze` says nothing, tests that do not render that
screen say nothing, and it reaches a reviewer looking like working code.

Before referencing an asset:

1. Confirm the file exists on disk at that exact path.
2. Confirm its directory is declared under `flutter: assets:` in `pubspec.yaml`. A file
   that exists but is undeclared fails the same way at runtime.
3. Match the project's naming and directory convention — the conventions file records it.

If the asset does not exist, say so and stop. Do not substitute a Material icon for a
missing brand asset, and do not write the path you expect the designer to export later.
A placeholder that looks plausible is worse than a blocked task, because the blocked task
gets resolved and the placeholder ships.

Use the project's existing loader. A project on `flutter_svg` uses `SvgPicture.asset` for
SVGs; introducing a second image library for one icon is a dependency added by accident.

## Match the house style

These are not correctness rules. They are the difference between a change that reads as
part of the codebase and one that reads as pasted in.

- **File names.** Follow the pattern already in use — `wallet_page.dart` in a project of
  `_page.dart` files, not `WalletScreen.dart`.
- **Class suffix.** If twelve routed widgets are named `*Page` and none are `*Screen`,
  the thirteenth is a `Page`. Count before choosing.
- **Widget base class.** Match what the project uses — `StatelessWidget`,
  `ConsumerWidget`, `HookWidget`. Introducing `flutter_hooks` into a project that does not
  use it is a stack decision disguised as a widget.
- **Imports.** Match the project's mix of `package:` and relative imports, and its use of
  barrel files. This one is worth checking rather than guessing; projects are consistent
  about it and the analyzer often enforces it.
- **Directory placement** is the architecture skill's job, not this one. Read it for where
  the file goes; read this for what it is called and what it reuses.

Everything `dart format` and `analysis_options.yaml` already enforce is not your concern —
run the formatter and let the analyzer speak.

## Common mistakes

- Grepping for the exact class name you had in mind, finding nothing, and treating that
  as proof nothing exists.
- Building a component in `core/widgets/` on its first use. Wait for the third — two
  usages that later diverge are cheaper to split than to un-merge.
- Copying a widget from another feature and editing it, instead of extracting the shared
  parts. This produces two widgets that drift, which is worse than either reuse or a clean
  second implementation.
- Inline `TextStyle` inside a `copyWith` chain, on the grounds that it is technically
  going through the theme. It is not.
- Referencing `assets/images/logo.png` because that is where a logo would obviously be.
