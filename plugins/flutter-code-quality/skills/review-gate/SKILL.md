---
name: review-gate
description: The pre-commit quality gate for Flutter work — formatting, static analysis, forbidden patterns, test and coverage checks, and a structured report of what fails. Use this when finishing any coding task, before committing, before opening a pull request, when asked whether something is ready to merge, or when asked to review changes. Trigger it at the end of substantial work without being asked, because the checks are cheap to run and the alternative is discovering the failures in CI after the context of the change has been lost.
allowed-tools: Read, Grep, Glob, Bash
---

# Review Gate

This skill audits and reports. It does not fix. That restriction is deliberate: a gate
with write access eventually satisfies its own checks by deleting the assertion that
failed, and a quality gate that can edit code to make itself pass is not a gate.

Report findings, then let the developer decide.

## Running it

```bash
bash "$SKILL_DIR/scripts/check.sh"
```

Resolve `$SKILL_DIR` to the absolute path of the directory this SKILL.md was read from.
When installed as a plugin the skill lives under `~/.claude/plugins/cache/` rather than
in the project, so a bare relative path will not find the script.

Run it from the project root — it inspects `git diff` against HEAD to scope the audit to
changed files. The script exits non-zero on the first hard failure. Read its output
rather than re-running the individual commands.

## What is checked

**Formatting.** `dart format --set-exit-if-changed .` — unformatted code produces noisy
diffs that hide real changes in review.

**Static analysis.** `flutter analyze --fatal-infos`. Infos are fatal on purpose;
tolerated infos accumulate until nobody reads the output at all.

**Forbidden patterns.** Grep for:

- `print(` — use a logger. Print statements ship to production and leak data.
- `!` force-unwrap on a nullable — every one is a potential crash. Rare exceptions are
  acceptable with a comment explaining why null is impossible.
- `TODO` or `FIXME` without a ticket reference. An untracked TODO is a note to nobody.
- `debugPrint`, `dump`, or commented-out code blocks.
- Hardcoded colors and numeric `EdgeInsets` in widget files — see the design-tokens skill.
- `EdgeInsets.only(left:` or `right:` — see the a11y-and-rtl skill.
- Hardcoded user-facing strings outside ARB files.
- API keys, tokens, or URLs with credentials.

**Tests.** `flutter test` passes. New public methods on a Cubit have tests covering both
the success and the failure path. Changed widgets have current goldens, and any changed
golden PNG has been visually reviewed — flag changed goldens explicitly in the report,
since they are the easiest thing to approve without looking.

**Dependencies.** No new package added without a note on why. Check whether the
functionality already exists in the codebase or in the SDK first.

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

Review only what changed. Run `git diff --stat` first and confine the audit to those
files. A report covering the whole codebase buries the three findings that relate to
the current change.
