# Flutter Skills for Claude Code

A plugin marketplace containing ten Agent Skills for production Flutter work — design
tokens instead of hardcoded values, a verification loop instead of a single render, and
the RTL and accessibility requirements no design file will ever specify for you.

## Install

```
/plugin marketplace add draz26648/flutter_claude_skills
/plugin install flutter-design-fidelity@draz-flutter
/plugin install flutter-code-quality@draz-flutter
/reload-plugins
```

Or from the terminal:

```bash
claude plugin marketplace add draz26648/flutter_claude_skills
claude plugin install flutter-design-fidelity@draz-flutter
claude plugin install flutter-code-quality@draz-flutter
```

Skills load automatically when relevant. To run one by hand, plugin skills are
namespaced by plugin name:

```
/flutter-design-fidelity:design-tokens
/flutter-code-quality:review-gate
```

## What's in each plugin

### flutter-design-fidelity

Four skills that keep the implementation matching the design.

| Skill | What it prevents |
|---|---|
| `design-tokens` | Hardcoded values that look identical to correct code in review |
| `figma-to-widget` | `Stack` and `Positioned` everywhere instead of Auto Layout mapping |
| `visual-verification` | Treating the first render as the final one |
| `golden-tests` | Drift after the match |

Ships `scripts/compare.py`, a screenshot differ that reports where differences cluster
and what each pattern usually means. Needs `pillow` and `numpy` on first run.

Substantially more useful with the [Figma MCP server](https://help.figma.com/hc/en-us/articles/39888612464151)
connected, which requires a paid Figma Dev or Full seat. Without it the agent reads a
rasterized screenshot and guesses at values — the skills say so explicitly rather than
guessing silently.

### flutter-code-quality

Six skills covering structure, robustness, and the gate.

| Skill | What it prevents |
|---|---|
| `architecture` | Files landing in the wrong layer |
| `state-management` | Emission after close, and over-broad rebuild scope |
| `responsive-adaptive` | Code written to the artboard width |
| `a11y-and-rtl` | The entire category your design file never mentions |
| `performance` | Fixes that are free now and expensive to retrofit |
| `review-gate` | The gate satisfying its own checks |

`review-gate` is deliberately restricted to read-only tools via `allowed-tools`. A
quality gate with write access eventually satisfies a failing check by deleting the
assertion. Ships `scripts/check.sh`, which scopes its audit to files changed against HEAD.

## Adapt before you rely on them

These skills describe a specific set of conventions — freezed sealed states, Cubit,
feature-first structure, a `ThemeExtension` for tokens. If your codebase does something
different, the skills will fight it, and the skill loses.

Installed plugins live in `~/.claude/plugins/cache/` and are overwritten on update, so
edit them by forking this repo rather than in place. Fork, adjust the `SKILL.md` files
to your conventions, and point the marketplace at your fork:

```
/plugin marketplace add your-username/flutter_claude_skills
```

The fastest way to adapt them is to let Claude Code do it. From your project root:

> Read the installed flutter-code-quality and flutter-design-fidelity skills. Inspect
> this codebase — pubspec.yaml, analysis_options.yaml, the lib/ structure, the theme
> setup, and three representative widgets. Tell me where the skills' conventions differ
> from what this project actually does, and rewrite them to match. Where a convention
> does not exist here yet, flag it as a new rule rather than inventing one silently.

## Install without the marketplace

If you would rather vendor the skills into a single project and commit them to git —
which makes them reviewable in pull requests alongside the code they govern:

```bash
git clone https://github.com/draz26648/flutter_claude_skills.git
cd flutter_claude_skills
./install.sh --project ~/path/to/your/flutter-app
```

That copies the design and architecture skills into `<project>/.claude/skills/` and the
two machine-scoped ones into `~/.claude/skills/`. Restart Claude Code once after
creating a `.claude/skills` directory that did not exist when the session started; after
that, edits are picked up live.

## Why skills instead of CLAUDE.md

`CLAUDE.md` loads on every session. As it grows, the rules near the bottom quietly stop
being followed, because everything loaded at startup competes for attention with
everything else.

Skills load in two stages. Only the `description` field sits in context at startup — the
body loads when Claude decides the skill is relevant. Ten skills cost almost nothing
until one is needed, at which point you get the full document instead of a bullet point
that survived summarization.

That is the whole argument. Long, specific instructions become affordable.

## Writing your own

The `description` field is the entire triggering mechanism and the thing most people get
wrong. Skills undertrigger far more often than they overtrigger, so write descriptions as
trigger conditions rather than summaries, and lean pushy — name the specific phrases and
situations that should activate the skill, including cases where you would not think to
ask for it by name.

Keep bodies under about 200 lines. Push depth into `references/` and point at those files
with a sentence saying when to read them. Put anything deterministic in `scripts/`.

Compare the description in `design-tokens/SKILL.md` against a summary-style one to see
the difference.

## Repository layout

```
.claude-plugin/marketplace.json      the catalog Claude Code reads
plugins/
  flutter-design-fidelity/
    .claude-plugin/plugin.json
    skills/<name>/SKILL.md
  flutter-code-quality/
    .claude-plugin/plugin.json
    skills/<name>/SKILL.md
install.sh                           for vendoring into a project instead
article/                             the writeup these skills came from
```

Validate changes before pushing:

```bash
claude plugin validate .
claude plugin validate ./plugins/flutter-design-fidelity
claude plugin validate ./plugins/flutter-code-quality
```

Bump `version` in each `plugin.json` on every release — if the string does not change,
Claude Code keeps the cached copy and existing users never see the update.

## Upgrading from the flat layout

Before v1.0.0 this repo held skills in a top-level `skills/` directory, copied manually
into `.claude/skills/`. Those copies still work and nothing breaks if you leave them —
but they will not receive updates, and having both the vendored copies and the plugin
installed means Claude sees each skill twice.

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

## Contributing

These skills reflect one set of conventions. If yours differ and you think the difference
is worth arguing about, open an issue — disagreement about what a skill should enforce is
more useful than agreement.

## License

MIT.
