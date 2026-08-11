# Flutter Skills for Claude Code

Eleven Agent Skills for production Flutter work, packaged as an installable plugin
marketplace. They teach Claude Code the conventions that normally live in three senior
developers' heads: design tokens instead of hardcoded values, a verification loop instead
of a single render, and the RTL and accessibility requirements no design file ever
specifies.

They adapt to your codebase rather than imposing one. A nine-line project profile records
the stack — Bloc or Riverpod, feature-first or layer-first, ARB or none — and a generated
conventions file records where your shared widgets, typography, and assets live, so
generated code reuses what you have instead of building a second copy of it.

## Install

```
/plugin marketplace add draz26648/flutter_claude_skills
/plugin install flutter-design-fidelity@draz-flutter
/plugin install flutter-code-quality@draz-flutter
/reload-plugins
```

Then, once, from your project root:

```
/flutter-code-quality:flutter-adapt
```

That writes two files — `.claude/flutter-profile.yaml` and
`.claude/flutter-conventions.md` — which is how the skills learn your codebase instead of
assuming mine. See [Your stack, not mine](#your-stack-not-mine) and
[Your components, not new ones](#your-components-not-new-ones).

Or from the terminal:

```bash
claude plugin marketplace add draz26648/flutter_claude_skills
claude plugin install flutter-design-fidelity@draz-flutter
claude plugin install flutter-code-quality@draz-flutter
```

Two plugins rather than one because the design-fidelity four are substantially more
useful with the Figma MCP server connected, and the quality six need nothing at all.
No reason to make you take both.

## How these actually work

A skill is a folder with a `SKILL.md` inside. Claude loads only the `description` field
at startup, then loads the full body when it decides the skill is relevant to what you
just asked. You don't invoke them — you say "build the login screen from this Figma
frame" and the relevant skills pull themselves in.

You *can* run one by hand. Plugin skills are namespaced by plugin name:

```
/flutter-design-fidelity:design-tokens
/flutter-code-quality:review-gate
```

Most of the value is in the automatic path. Manual invocation is for when you want a
specific audit on demand, like running the review gate before a PR.

## Your stack, not mine

These skills hold opinions, and some of them will be wrong about your codebase. A skill
that is wrong about the codebase loses every argument it has with the developer, so the
project gets to state which opinions apply:

```yaml
# .claude/flutter-profile.yaml
state: riverpod          # bloc | riverpod | provider | signals | setstate
models: freezed          # freezed | dart_mappable | json_serializable | manual
structure: feature_first # feature_first | layer_first
di: riverpod             # get_it | injectable | riverpod | provider | none
routing: go_router       # go_router | auto_route | navigator
tokens: theme_extension  # theme_extension | theme_only | constants | none
l10n: arb                # arb | easy_localization | slang | none
locales: [en, ar]
strictness: block        # block | warn
```

`/flutter-adapt` generates it by reading `pubspec.yaml` and `lib/`. Every field defaults
to what the skills already assumed, so a project that agrees with them needs no file and
sees no change.

Two settings do most of the work:

**`tokens`** decides whether a hardcoded `Color(0xFF...)` is a blocking finding, a warning,
or not a finding at all. A project with no token layer stops being told to use one on
every commit.

**`strictness: warn`** is for an existing codebase adopting this partway through its life,
where a gate that blocks on day one gets switched off on day two. It downgrades every
convention finding and leaves formatting, static analysis, failing tests, and committed
credentials blocking — those are not matters of house style.

An unrecognised value stops the gate with exit `2` rather than falling back to the
default. Reading `riverpood` as `bloc` would enforce the opposite of what you asked for,
with nothing in the output to say so.

## Your components, not new ones

The profile records decisions. `.claude/flutter-conventions.md` records what your code
actually does — where the shared widgets live, which class owns typography, which asset
directories are declared, whether routed widgets are `*Page` or `*Screen`.

`/flutter-adapt` generates it too. It's read by the `codebase-conventions` skill on every
code-writing task, and it exists because of one specific failure:

> An agent greps for `PrimaryButton`, finds nothing, and builds one. The project already
> had `AppButton`.

Nothing catches that in review. The diff is all additions, every line is defensible, and
the duplication surfaces months later when a brand change has to be applied twice. The
fix is to search by **role** rather than by the name you had in mind — `class .*Button`,
not `PrimaryButton` — and the skill makes that the required first step.

**The file records locations and rules, never an inventory.** "Shared widgets live in
`lib/core/widgets/`, named `App<Thing>`" stays true for years. "The project has
`AppButton`, `AppCard`, `AppChip`…" is wrong after the next merge — and a stale list is
worse than no list, because it gets trusted, so the search that would have found the real
answer never happens.

---

# flutter-design-fidelity

Four skills that keep the implementation matching the design.

## design-tokens

**Triggers on:** implementing UI from a design, adding or changing any color, spacing,
radius, shadow, or text style, touching the theme.

Enforces one rule without exception: no raw visual values in widget code. Everything
resolves through an `AppTokens` ThemeExtension.

```dart
// What Claude produces without the skill
Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: const Color(0xFFF7F8FA),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Text('Balance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
)

// What it produces with it
Container(
  padding: context.tokens.space.md,
  decoration: BoxDecoration(
    color: context.tokens.color.surfaceRaised,
    borderRadius: context.tokens.radius.card,
  ),
  child: Text('Balance', style: context.tokens.text.titleMedium),
)
```

The rule that does the real work isn't the prohibition — it's the instruction for what to
do when a token is missing: **add it to the token file first, never inline a one-off.** An
agent without that rule hardcodes any value it can't find, and hardcoded values are
invisible in review because they look identical to correct code.

A second rule catches design-file mistakes: if the design uses a value that doesn't fit
the existing scale — 14px where the scale is 4/8/12/16 — the skill stops and reports it
rather than adding a `space.s14` token. Silently encoding an outlier makes the scale
meaningless.

Ships `references/theme-extension-template.dart`, a complete token class covering colors
with light/dark lerp, spacing, radii, typography, elevation, and motion.

## figma-to-widget

**Triggers on:** any Figma link, frame, or mockup; any request to build a screen from a
design.

Without this, an agent reads pixel positions off the frame and reproduces them with
`Stack` and `Positioned`. The result matches the artboard exactly and breaks on every
other screen size.

Figma's layout system maps cleanly onto Flutter's, and the skill is mostly that mapping:

| Figma | Flutter |
|---|---|
| Auto Layout, vertical/horizontal | `Column` / `Row` |
| Auto Layout gap | `spacing:` or a `Gap` widget |
| Hug contents | `MainAxisSize.min` |
| Fill container | `Expanded` |
| Absolute position | `Stack` — last resort only |
| Component variant | a parameter, not a new widget |

Three rules beyond the table. `Stack` is valid only where elements genuinely overlap — an
avatar badge, a FAB over content. The artboard width is never hardcoded. And before
building any component, search the codebase for an existing one: a Figma component
instance almost always corresponds to a widget that already exists, and building a second
`PrimaryButton` because the first wasn't found is the most common form of duplication in
agent-generated UI.

The skill also checks whether the Figma MCP server is connected and says so plainly if it
isn't, rather than guessing at values from a screenshot.

## visual-verification

**Triggers on:** finishing any UI implementation; asking whether something matches the
design.

The one that closes the feedback loop. An agent with no verification declares a screen
finished the moment it compiles — it wrote code, the code ran, task complete.

This skill turns that into an actual loop: build, screenshot through `integration_test`,
diff against the exported frame, iterate until the difference is under threshold. Capped
at four iterations, because past that the remaining difference is usually something a
diff can't fix — a missing font, a wrong export scale, a design updated after export.

Ships `scripts/compare.py`, which reports not just the difference percentage but where it
clusters, plus a guide to interpreting the result:

- Sharp offset of the whole content block → a padding token is wrong
- Text differing at the edges only → font weight, letter spacing, or line height
- Everything shifted by a constant → export scale doesn't match capture DPR; fix the
  export, not the code
- Text differing in shape entirely → the font isn't bundled; check `pubspec.yaml` before
  touching the widget

That last one matters more than it sounds. Without the guide, an agent "fixes" a
font-loading problem by nudging padding until the numbers improve.

Needs `pillow` and `numpy` on first run.

## golden-tests

**Triggers on:** adding or modifying any widget; any golden mismatch failure.

Visual verification proves a screen matches today. Goldens stop it drifting tomorrow.

Covers the test matrix — small phone, large phone, tablet, light and dark, text scale 1.0
and 2.0, LTR and RTL — with a note that the full cross-product is too many images for
anyone to review. Baseline on every device, then one variant each for dark, large text,
and RTL.

The rule worth singling out: **never run `--update-goldens` as a reflex when a test
fails.** That command always makes the test pass, which is exactly the problem. Regenerate
only after confirming the change was intended, then open the changed PNGs and look at
them. A golden that changed and nobody can explain is a bug being committed, not a test
being updated.

Also covers the failure modes that make goldens flaky rather than useful: fonts not
loaded (everything renders as black boxes and the test proves nothing about typography),
unfrozen clocks, unmocked network images, and goldens generated on a different platform
than CI.

---

# flutter-code-quality

Seven skills covering structure, robustness, and the gate.

## architecture

**Triggers on:** creating a feature, adding a file, any question about where code belongs.

Feature-first, three layers per feature, dependencies pointing inward. The rule with the
most practical bite: **domain imports nothing from Flutter** — not `material.dart`, not
even for `Color`. The moment domain depends on Flutter it needs a binding to test, and
unit tests go from milliseconds to seconds.

Includes a "where does this go" table, which resolves more arguments than the folder
diagram does:

| Thing | Layer |
|---|---|
| "Transfer requires balance ≥ amount" | domain/usecases |
| "Balance shows two decimals" | presentation |
| "The API returns cents as an int" | data/models |
| "Failed transfers retry twice" | data/repositories |

And an explicit permission to skip ceremony: a use case that only forwards a call to a
repository adds a file and no behaviour. Agents love generating full Clean Architecture
scaffolding for a settings toggle, and a skill that only says "follow the layers"
encourages exactly that.

## codebase-conventions

**Triggers on:** writing any widget, screen, shared component, text style, or asset
reference. Effectively every code-writing task.

The one that makes generated code look like it belongs. Four rules:

**Reuse before create.** Search by role, not by name, in a fixed order: by suffix
(`class .*Button`), by the noun in the request, then in the shared directories. Read what
you found before deciding. A widget doing 80% of the job is usually one parameter away
from doing all of it, and adding the parameter is a smaller change than adding a file.

**Typography comes from the project's source.** Never inline `TextStyle(...)`. A single
`copyWith` on an existing style is fine; reaching for three properties at once means the
style itself is missing.

**Never invent an asset path.** Confirm the file exists and its directory is declared in
`pubspec.yaml`. If it doesn't exist, stop and say so — don't substitute a Material icon
for a missing brand asset and don't write the path you expect someone to export later. A
plausible placeholder is worse than a blocked task, because the blocked task gets resolved.

**Match the house style.** File naming, `*Page` vs `*Screen` (count before choosing), the
widget base class in use, `package:` vs relative imports. None of it is correctness — it's
the difference between a change that reads as part of the codebase and one that reads as
pasted in.

Explicitly *not* covered: anything `dart format` and `analysis_options.yaml` already
enforce. Run the formatter and let the analyzer speak.

## state-management

**Triggers on:** writing or modifying any Cubit, Bloc, Notifier, provider, or state class;
wiring a widget to state.

Stack-agnostic. Four rules that hold everywhere — an exhaustively switchable state type, a
liveness guard after every `await`, the narrowest subscription that works, and no
`BuildContext` in the state holder — with the code for them in `references/bloc.md` and
`references/riverpod.md`, chosen by the profile's `state` field. `provider`, `signals`,
and `setstate` get a translation table instead of a full reference.

The instruction that matters most is the one about not mixing stacks. Adding a Cubit to a
Riverpod codebase because a Cubit is what the model knows is the single most damaging
thing it does to a state layer: it compiles, it works on the screen it was added to, and
it leaves two sources of truth nobody asked for.

The rule that catches a real production bug:

```dart
Future<void> load() async {
  emit(const WalletState.loading());
  final result = await _repository.fetchWallet();
  if (isClosed) return;   // <- this line
  ...
}
```

Without the guard, navigating away mid-request throws. It's intermittent, depends on
network timing, and is very hard to reproduce from a bug report. An agent will not add it
unless told to. Riverpod's version is `if (!ref.mounted) return;`, and `autoDispose` makes
it matter more rather than less — the provider is torn down the moment the last listener
leaves the screen, which is exactly the navigate-away case.

Also covers rebuild scope — `BlocSelector` or `ref.watch(p.select(...))` when a widget
reads one field — and the test pattern for each stack, with the rule that every method
gets both a success and a failure test, asserting the *sequence* of states rather than
the final one. A method that reaches `loaded` without passing through `loading` renders no
spinner, and a test that only checks the endpoint passes anyway.

## responsive-adaptive

**Triggers on:** layout work, overflow errors, tablet or desktop targets, any fixed pixel
dimension.

A design file gives you one width. The app runs on hundreds.

The distinction at the centre of it: `LayoutBuilder` for how a component lays *itself*
out, `MediaQuery` for screen-level decisions like navigation pattern. A card in a 400pt
sidebar on a 1200pt screen should lay out as a narrow card — `MediaQuery` would report a
wide screen and be wrong.

Also: use `MediaQuery.sizeOf(context)`, not `MediaQuery.of(context).size`. The latter
subscribes the widget to every MediaQuery change including keyboard appearance, which
means rebuilds on every keystroke.

Plus a breakpoint table, the rule that percentage-of-screen sizing breaks at 2.0 text
scale, and scroll-by-default for anything with more than three elements.

## a11y-and-rtl

**Triggers on:** any user-facing widget, string, icon, or directional padding.

The category your design file will never mention. Every Figma file arrives laid out left
to right, at a fixed width, at default text scale, in one language — so these
requirements live entirely on the implementer's side, which makes them what gets skipped
under deadline and discovered by users.

`EdgeInsets.only(left: 16)` puts padding on the left in every language. In Arabic the
layout mirrors and the padding doesn't, which looks subtly broken in a way that's hard to
name and easy to notice. So: `EdgeInsetsDirectional`, `AlignmentDirectional`,
`PositionedDirectional` — `start` and `end`, never `left` and `right`.

The part needing actual judgement is icon mirroring, so the skill carries a table:

| Mirrors | Doesn't mirror |
|---|---|
| Back and forward arrows | Play and pause |
| Navigation chevrons | Clock faces |
| Send | Checkmarks |
| Undo and redo | Logos and brand marks |

Then text scaling, the most common Flutter accessibility failure and entirely
preventable: no fixed heights on containers holding text, no `maxLines: 1` with ellipsis
on content the user needs to read, buttons that grow with their label. And explicitly:
**never clamp the scale factor globally to protect the layout** — that overrides a
setting the user deliberately chose, and on iOS it's grounds for review rejection.

Plus semantics labels on icon-only buttons, `ExcludeSemantics` on decorative images, 48dp
minimum touch targets, 4.5:1 contrast, and no hardcoded strings — including semantics
labels, which are read aloud and therefore read in the wrong language if untranslated.

## performance

**Triggers on:** list or grid implementation, image loading, animation work, jank reports.

The structural rule with the largest impact: **extract widgets rather than helper
methods.** A `Widget _buildHeader()` rebuilds with its parent every time. A separate
`const HeaderWidget()` does not.

The one that prevents crashes: always set `cacheWidth` on network images. Without it a
2000px image decodes at full size to fill a 100px avatar, holding roughly 16MB for
something that needs 40KB. On a scrolling list of avatars that's the difference between a
smooth list and an out-of-memory crash on a mid-range Android device.

Also covers builder constructors with `itemExtent`, stable keys for list items, a caution
against scattering `RepaintBoundary` everywhere (each is a layer with real memory cost),
`AnimatedBuilder` with a `child` so the static subtree builds once, and the reminder to
profile in profile mode — debug-mode numbers are meaningless.

## review-gate

**Triggers on:** finishing a task, preparing a commit, opening a PR, asking whether
something is ready to merge.

Formatting, static analysis with `--fatal-infos`, forbidden-pattern grep, tests,
coverage. One design decision makes it worth having:

```yaml
allowed-tools: Read, Grep, Glob, Bash
```

No write access. A quality gate that can edit code will eventually satisfy its own checks
by deleting the assertion that failed. Restricting the tools makes that structurally
impossible rather than relying on good behaviour.

Ships `scripts/check.sh`, which scopes its audit to files changed against HEAD — a report
covering the whole codebase buries the three findings that relate to the current change.
It greps for `print(`, untracked TODOs, hardcoded colors and numeric `EdgeInsets`,
non-directional insets, and committed credentials, and flags changed golden PNGs
explicitly since those are the easiest thing to approve without looking.

Reports in three groups: blocking, worth fixing, notes. With the instruction that if
nothing is blocking it should say so plainly rather than manufacturing findings — a gate
that always reports problems teaches people to ignore it.

It reads `.claude/flutter-profile.yaml` on its own and prints which profile it applied. A
check the profile switches off prints as *skipped*, with the setting responsible — a check
that vanishes without explanation is indistinguishable from one that passed, which is the
bug the 2.0.0 release existed to fix.

---

## When the profile is not enough

The profile covers the decisions that recur across projects. It will not cover a
home-grown DI container, a custom navigation wrapper, or a token layer with two competing
entry points — and a skill that is wrong about those still loses the argument.

For divergence that deep, fork. Installed plugins live in `~/.claude/plugins/cache/` and
are overwritten on update, so editing them in place does not survive; fork the repo,
adjust the `SKILL.md` files, and point the marketplace at your copy:

```
/plugin marketplace add your-username/flutter_claude_skills
```

The fastest way to work out whether you need that is to ask. From your project root:

> Read the installed flutter-code-quality and flutter-design-fidelity skills and my
> `.claude/flutter-profile.yaml`. Inspect this codebase — pubspec.yaml,
> analysis_options.yaml, the lib/ structure, the theme setup, and three representative
> widgets. Tell me where the skills' conventions still differ from what this project
> actually does after the profile is applied, and which of those the profile has no field
> for.

## The Figma piece

`figma-to-widget` and `visual-verification` are substantially more useful with the
[Figma MCP server](https://help.figma.com/hc/en-us/articles/39888612464151) connected,
which gives Claude structured access to real design values — actual color tokens, actual
spacing numbers — instead of reading a rasterized screenshot. It requires a paid Figma
Dev or Full seat.

Without it both skills still work, but you'll need to supply the token values and spacing
scale yourself. The skills say so explicitly rather than guessing silently, which is the
behaviour you want.

## Install without the marketplace

If you'd rather vendor the skills into a single project and commit them to git — which
makes them reviewable in pull requests alongside the code they govern:

```bash
git clone https://github.com/draz26648/flutter_claude_skills.git
cd flutter_claude_skills
./install.sh --project ~/path/to/your/flutter-app
```

That copies the nine project-scoped skills into `<project>/.claude/skills/`, the two
machine-scoped ones (`performance`, `review-gate`) into `~/.claude/skills/`, and
`/flutter-adapt` into `<project>/.claude/commands/`. Restart Claude Code once after
creating a `.claude/skills` directory that didn't exist when the session started; after
that, edits are picked up live.

`${CLAUDE_PLUGIN_ROOT}` is unset outside a plugin install, so the installer also gives
each vendored skill its own copy of the profile spec and rewrites the cross-skill link to
point at it. Without that the links resolve to nothing, which is the same failure the old
`$SKILL_DIR` had.

Re-running the script leaves already-installed skills alone so local edits survive. To
take a newer version, re-run with `--force` — and diff first if you've adapted them:

```bash
./install.sh --project ~/path/to/your/flutter-app --force
```

Trade-off: vendored skills only update when you ask them to, but they're visible in code
review and can diverge per project. Marketplace install gets updates automatically but
lives outside the repo.

## Upgrading from the flat layout

Before v1.0.0 this repo held skills in a top-level `skills/` directory, copied manually.
Those copies still work and nothing breaks if you leave them — but they won't receive
updates, and having both the vendored copies and the plugin installed means Claude sees
each skill twice.

To switch, remove the vendored copies first:

```bash
cd your-flutter-project
rm -rf .claude/skills/design-tokens .claude/skills/figma-to-widget \
       .claude/skills/visual-verification .claude/skills/golden-tests \
       .claude/skills/architecture .claude/skills/state-management \
       .claude/skills/responsive-adaptive .claude/skills/a11y-and-rtl
rm -rf ~/.claude/skills/performance ~/.claude/skills/review-gate
```

Then install through the marketplace as above.

## Why skills instead of CLAUDE.md

`CLAUDE.md` loads on every session. As it grows, the rules near the bottom quietly stop
being followed, because everything loaded at startup competes for attention with
everything else.

Skills load in two stages. Only the `description` field sits in context at startup; the
body loads when Claude decides the skill is relevant. Ten skills cost almost nothing
until one is needed, at which point you get the full document instead of a bullet point
that survived summarization.

That's the whole argument. Long, specific instructions become affordable.

## Writing your own

The `description` field is the entire triggering mechanism and the thing most people get
wrong. Skills undertrigger far more often than they overtrigger, so write descriptions as
trigger conditions rather than summaries, and lean pushy — name the specific phrases and
situations that should activate the skill, including cases where you wouldn't think to
ask for it by name.

Keep bodies under about 200 lines. Push depth into `references/` and point at those files
with a sentence saying when to read them. Put anything deterministic in `scripts/` —
scripts execute without loading into context, so a 200-line bash check costs nothing
while 200 lines of prose describing the same check costs tokens on every trigger.

Compare the `description` in `design-tokens/SKILL.md` against a summary-style one to see
the difference.

## Repository layout

```
.claude-plugin/marketplace.json      the catalog Claude Code reads
plugins/
  flutter-design-fidelity/
    .claude-plugin/plugin.json
    skills/design-tokens/SKILL.md
    skills/design-tokens/references/theme-extension-template.dart
    skills/design-tokens/references/flutter-profile.md      copy — kept identical by CI
    skills/figma-to-widget/SKILL.md
    skills/visual-verification/SKILL.md
    skills/visual-verification/scripts/compare.py
    skills/golden-tests/SKILL.md
  flutter-code-quality/
    .claude-plugin/plugin.json
    commands/flutter-adapt.md
    skills/architecture/SKILL.md
    skills/architecture/references/flutter-profile.md       the profile spec
    skills/codebase-conventions/SKILL.md
    skills/state-management/SKILL.md
    skills/state-management/references/bloc.md
    skills/state-management/references/riverpod.md
    skills/responsive-adaptive/SKILL.md
    skills/a11y-and-rtl/SKILL.md
    skills/performance/SKILL.md
    skills/review-gate/SKILL.md
    skills/review-gate/scripts/check.sh
install.sh                           for vendoring into a project instead
```

`flutter-profile.md` exists twice because each plugin has to work when it is the only one
installed. `validate.py` fails the build if the copies drift — the top-level `skills/`
mirror removed in 2.0.0 went stale precisely because nothing compared them.

`plugins/` is the only source of truth. There is deliberately no top-level `skills/`
mirror — it existed before v1.0.0, drifted behind the plugin copies within a handful of
commits, and was removed. Edit skills in `plugins/`; nothing else needs updating.

Scripts inside a skill are addressed with `${CLAUDE_PLUGIN_ROOT}`, the environment
variable Claude Code sets to the installed plugin's root. It expands on its own — a skill
should never ask the model to work out its own path by hand.

Validate before pushing:

```bash
claude plugin validate .
claude plugin validate ./plugins/flutter-design-fidelity
claude plugin validate ./plugins/flutter-code-quality
```

Bump `version` in each `plugin.json` on every release. If the string doesn't change,
Claude Code keeps the cached copy and existing users never see the update.

## Contributing

These skills reflect one set of conventions. If yours differ and you think the difference
is worth arguing about, open an issue — disagreement about what a skill should enforce is
more useful than agreement.

## License

MIT.