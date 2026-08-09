---
name: review-gate
description: The pre-commit quality gate for Flutter work — formatting, static analysis, forbidden patterns, test and coverage checks, and a structured report of what fails. Use this when finishing any coding task, before committing, before opening a pull request, when asked whether something is ready to merge, or when asked to review changes. Trigger it at the end of substantial work without being asked, because the checks are cheap to run and the alternative is discovering the failures in CI after the context of the change has been lost.
allowed-tools: Read, Grep, Glob, Bash
---

# Review Gate

This skill audits and reports. It does not fix. That restriction is deliberate: a gate
with write access eventually satisfies its own checks by deleting the assertion that
failed, and a quality gate that can edit code to make itself pass is not a gate. `Edit`
and `Write` are absent from `allowed-tools` for that reason — do not reach for them from
inside this skill, and do not "helpfully" fix a finding on the way past.

Report findings, then let the developer decide.

## Running it

Run from the **project root** — the script reads `pubspec.yaml` and `git diff` there.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/review-gate/scripts/check.sh"
```

`CLAUDE_PLUGIN_ROOT` is set by Claude Code and expands on its own; it does not need
resolving by hand. If the skill was vendored into the project rather than installed as a
plugin, that variable is unset — use the path it was copied to instead:

```bash
bash .claude/skills/review-gate/scripts/check.sh
```

Options: `--skip-tests` when you only want lint feedback, `--all` to audit all of `lib/`
and `test/` instead of just what changed.

Exit codes: `0` nothing blocking, `1` at least one blocking finding, `2` the gate could
not run. **A `2` is not a pass.** It means a precondition failed or a check itself broke,
and the result carries no information about the code.

Read the script's output rather than re-running the individual commands — it already
separates blocking from non-blocking, and re-running by hand loses that.

## What is checked

**Formatting.** `dart format --set-exit-if-changed` over the files in scope. Unformatted
code produces noisy diffs that hide real changes in review.

**Static analysis.** `flutter analyze --fatal-infos`, whole project. Infos are fatal on
purpose; tolerated infos accumulate until nobody reads the output at all. This one is
deliberately not scoped to the diff — a change in one file breaks analysis in another,
and scoping to the diff hides exactly that.

**Forbidden patterns.** Blocking:

- `print(` — use a logger. Print statements ship to production and leak data.
- Hardcoded colors — `Color(0x...)` or `Colors.<name>` — see the design-tokens skill.
- Numeric `EdgeInsets` — see the design-tokens skill.
- `EdgeInsets.only(left:` or `right:` — see the a11y-and-rtl skill.
- API keys, tokens, or URLs with embedded credentials.

Non-blocking:

- `debugPrint(` in shipped code.
- `TODO` or `FIXME` without a ticket reference. `TODO(WAL-42)` passes; a bare `TODO` does
  not. An untracked TODO is a note to nobody.
- Commented-out code.
- `BorderRadius.circular(<number>)`.
- `!` force-unwrap on a nullable — every one is a potential crash. Acceptable with a
  comment explaining why null is impossible, which is why this warns rather than blocks.
- Hardcoded user-facing strings in `Text(...)` — see a11y-and-rtl.

**Where these are not enforced.** Generated files (`*.g.dart`, `*.freezed.dart`,
`*.mocks.dart`, and similar), tests, and the token layer (`theme/`, `tokens/`,
`design_system/`, `app_colors.dart`, `app_theme.dart`) are excluded from the literal-value
checks. Raw colors and numbers are exactly what belongs in the token file. A gate that
fails on correct code gets switched off, so the carve-out is load-bearing rather than a
convenience.

**Tests.** `flutter test` passes, and failures are named in the report. New public methods
on a Cubit have tests covering both the success and the failure path. Changed golden PNGs
are flagged explicitly, since they are the easiest thing to approve without looking.

**Dependencies.** New entries in `pubspec.yaml` are flagged. Each needs a note on why, and
a check that the functionality does not already exist in the codebase or the SDK.

## Judgement the script cannot make

The script finds mechanical violations. These need reading the diff:

- Whether a new Cubit method's tests cover the failure path, not just that tests exist.
- Whether a changed golden was actually reviewed, or just regenerated until green.
- Whether a force-unwrap's justifying comment is true.
- Whether a new dependency was necessary.

Report on these alongside the script's output. They are the findings a human reviewer
would have caught and the script never will.

## Report format

Report as three groups, in this order:

```
BLOCKING — must fix before merge
  - [file:line] what is wrong, and why it matters

WORTH FIXING — should fix, will not break anything today
  - [file:line] ...

NOTES — observations, no action required
  - ...
```

If nothing is blocking, say so plainly rather than manufacturing findings to look
thorough. A gate that always reports problems teaches people to ignore it.

## Scope

The pattern checks confine themselves to Dart files changed against `HEAD`, so the report
tracks the current change rather than the whole codebase. Analysis and tests are
whole-project because they have to be. When the report cites a file the change did not
touch, that is analysis or tests talking, and it still needs fixing.
