# Flutter Skills for Claude Code

Ten Agent Skills that teach Claude Code how to write Flutter the way your team writes it —
design tokens instead of hardcoded values, a verification loop instead of a single render,
and RTL support that no design file will ever specify for you.

Built for production Flutter work. Every skill is a starting point meant to be edited to
match your codebase, not a drop-in that works untouched.

## Why skills instead of CLAUDE.md

`CLAUDE.md` loads on every session. As it grows, the rules at the bottom quietly stop
being followed, because everything loaded at startup competes for attention with
everything else.

Skills load in two stages. Only the `description` field sits in context at startup — the
body loads when Claude decides the skill is relevant. Fifty skills cost almost nothing
until one of them is needed, at which point you get the full document instead of a bullet
point that survived summarization.

That is the whole argument. Long, specific instructions become affordable.

## The skills

| Skill | What it enforces |
|---|---|
| `design-tokens` | No hardcoded color, spacing, radius, or text style in widget code |
| `figma-to-widget` | Auto Layout maps to Row/Column, not Stack with pixel offsets |
| `visual-verification` | Build, screenshot, diff against the design, iterate until it matches |
| `golden-tests` | Freeze the match; regenerated goldens require visual review |
| `architecture` | Feature-first layering, pure Dart domain, dependencies point inward |
| `state-management` | Sealed states, safe emission, selective rebuilds |
| `responsive-adaptive` | The artboard width is a reference, never a hardcoded target |
| `a11y-and-rtl` | Directional insets, mirrored icons, 2.0 text scale, semantics |
| `performance` | const, RepaintBoundary, builder lists, image cache sizing |
| `review-gate` | Pre-commit audit — reports findings, deliberately cannot fix them |

Two of them ship executable scripts: `visual-verification/scripts/compare.py` for
screenshot diffing and `review-gate/scripts/check.sh` for the quality gate. Scripts run
without loading into context, which is the right home for anything deterministic.

## Install

```bash
git clone https://github.com/<your-username>/flutter-claude-skills.git
cd flutter-claude-skills
./install.sh --project ~/path/to/your/flutter-app
```

Or copy them by hand:

```bash
# Project-scoped — commits to the repo, shared with your team
mkdir -p ~/your-app/.claude/skills
cp -r skills/* ~/your-app/.claude/skills/

# Machine-scoped — follows you across every project
mkdir -p ~/.claude/skills
cp -r skills/performance skills/review-gate ~/.claude/skills/
```

Restart Claude Code once after creating a `.claude/skills` directory that did not exist
when the session started. After that, edits to `SKILL.md` files are picked up live.

Verify:

```bash
ls .claude/skills/*/SKILL.md
```

## Project vs. personal

Skills that encode *this codebase's* conventions belong in the project, committed to git
so the whole team gets them and so they show up in pull requests like any other code:
`design-tokens`, `architecture`, `state-management`, `figma-to-widget`, `golden-tests`.

Skills that encode *your* habits belong in `~/.claude/skills/`: `performance`,
`review-gate`, and usually `a11y-and-rtl` if accessibility is your standard rather than
your team's.

## Adapt before you use

These skills describe a specific set of conventions — freezed sealed states, Cubit,
feature-first structure, a `ThemeExtension` for tokens. If your codebase does something
different, the skills will fight it, and the skill loses.

Before using them, open each `SKILL.md` and replace the conventions with yours. The
structure is the reusable part; the specifics are not.

The fastest way to do this is to let Claude Code do it. From your project root:

> Read the SKILL.md files in .claude/skills/. Inspect this codebase — pubspec.yaml,
> analysis_options.yaml, the lib/ structure, the theme setup, and three representative
> widgets. Rewrite each skill so it describes the conventions that actually exist here.
> Where a convention does not exist yet, flag it to me as a new rule rather than
> inventing one silently.

## The Figma piece

`figma-to-widget` and `visual-verification` are far more useful with the Figma MCP server
connected, which gives Claude structured access to real design values instead of guessing
from a rasterized screenshot. It requires a paid Figma Dev or Full seat.

Setup: https://help.figma.com/hc/en-us/articles/39888612464151

Without it, both skills still work but you will need to supply the token values and
spacing scale yourself. The skills say so explicitly rather than guessing.

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

## Contributing

The skills here reflect one set of conventions. If yours differ and you think the
difference is worth arguing about, open an issue — disagreements about what a skill
should enforce are more useful than agreement.

## License

MIT. Use them, fork them, rewrite them entirely.
