# Changelog

Skill text is the product here, so a wording change that alters what an agent does counts
as a release. Bump the `version` in both `plugin.json` and `.claude-plugin/marketplace.json`
together — Claude Code keys its cache on that string, and users never see an update
without it. `scripts/validate.py` fails the build if the two disagree.

Versioning follows semver from the *consumer's* point of view. A check that starts
failing a project that previously passed is a breaking change, even though nothing about
the project changed — the gate's verdict is the contract.

## 2.0.1

### Fixed

- **The "a broken check fails loudly" guarantee only held on macOS.** 2.0.0 detected a
  malformed pattern by testing for a grep exit code of 2 or higher. grep implementations
  disagree: given a PCRE lookahead, ugrep exits 2, but GNU grep prints a warning and exits
  1, which is indistinguishable from "no violations found". Since GNU grep is what Linux
  CI runs, the case the guarantee existed for was still silently green. Every check now
  declares a line its pattern is required to match, and a check that cannot find its own
  known violation reports itself broken rather than `ok`. This is behaviour-based, so it
  holds whatever grep is installed.

  No check shipped in 2.0.0 was actually broken; this closes the hole that would have let
  a future one hide. Caught by the canary test added in 2.0.0, running on Linux CI.

## 2.0.0

Breaking, because upgrading changes the verdict you get on code you have already shipped.
Nothing here is a new rule; it is the existing rules finally being enforced, plus two
scripts that used to fail open now failing closed.

### Breaking

- **`review-gate` will fail projects that passed under 1.0.0.** The TODO/FIXME check never
  ran (see below), the force-unwrap, `debugPrint`, commented-out-code and hardcoded-string
  checks were documented but never implemented, and all of them are live now. Run the gate
  once before upgrading anything else so the new findings arrive on their own.
- **`compare.py` errors instead of rescaling on a size mismatch.** A pipeline that quietly
  compared a 2x export against a 3x capture now exits `2` and explains that the export
  scale is wrong. Pass `--allow-resize` to keep the old behaviour, though the diff it
  produces was always noise.
- **`compare.py` fails localized defects that used to pass.** The new `--max-cluster`
  threshold (default 0.25) grades the worst cell of a 12×12 grid alongside the global
  share. Screens that scraped past the 2% global threshold on a single wrong-colored
  element will now fail — correctly.
- **Exit code `2` is new on both scripts** and means *the check could not run*, not *the
  code is fine*. Any CI step branching on `!= 0` is unaffected; one branching on `== 1`
  needs updating.
- **The top-level `skills/` directory is gone.** Only reachable by copying out of a git
  clone by hand, which the README has called the pre-v1.0.0 layout since 1.0.0. Marketplace
  and `install.sh` users are unaffected.

### Fixed

- **`review-gate` reported a passing check that could never fail.** The TODO/FIXME rule
  used `grep -E 'TODO(?!\()|FIXME'` — a PCRE negative lookahead handed to POSIX ERE. It
  exited 2 on every run, the call site sent stderr to `/dev/null` and ended in `|| true`,
  and the gate printed `ok: TODOs carry a ticket reference` for its entire life. Rewritten
  as an ERE match minus the ticket-carrying hits, and `check_pattern` now distinguishes
  grep's three exit states so a malformed pattern fails loudly instead of reporting clean.
- **`review-gate` failed on correct code.** `Color(0x...)` and numeric `EdgeInsets` were
  blocking with no path exclusions, so a project's own token layer — the one place those
  literals belong — failed by construction. Generated files (`*.g.dart`, `*.freezed.dart`,
  and similar), tests, and `theme/`, `tokens/`, `design_system/` are now carved out.
- **`review-gate` documented checks it did not run.** SKILL.md listed eight forbidden
  patterns; the script implemented five, one of them broken, plus one the doc never
  mentioned. The two lists are now identical, with severities stated.
- **`review-gate` could not name a failing test.** `flutter test` output went to
  `/dev/null`. Failures are captured and reported.
- **`review-gate` reported clean when it had not run.** No preconditions — pointed at a
  non-Flutter directory it produced an empty, passing report. It now exits `2`.
- **`visual-verification` wrote a diff image that measured 98% pure black.**
  `ImageChops.difference` is a near-zero delta wherever the images agree, so the artifact
  the skill told you to open carried no information. It is now the capture, faded, with
  differing pixels burned in as red.
- **`visual-verification` crashed with a raw traceback** on a missing or unreadable file.
  Clean message, exit `2`.
- **`$SKILL_DIR` is not a real variable.** Both skills instructed the model to resolve it
  by hand. Replaced with `${CLAUDE_PLUGIN_ROOT}`, which Claude Code sets and the shell
  expands on its own. `validate.py` rejects any reappearance of `$SKILL_DIR`.
- **`install.sh` could never update a vendored skill.** It skipped anything already
  present with no override, so a user who ran it once was pinned forever. Added `--force`.

### Added

- `--ignore-region X,Y,W,H` on `compare.py` (repeatable) for inherently dynamic content,
  so a status bar clock no longer forces the threshold up for the whole screen.
- `--skip-tests` and `--all` on `check.sh`.
- A "judgement the script cannot make" section in `review-gate`, naming the findings that
  need the diff read rather than grepped — whether a golden was reviewed or just
  regenerated, whether a force-unwrap's justification is true, whether a new dependency
  was necessary.
- Documentation of the exclusion carve-outs in `review-gate`, so the agent knows why some
  literals are not flagged rather than assuming the check is broken.
- `scripts/validate.py` — frontmatter, name/directory agreement, description limits,
  manifest/marketplace version agreement, duplicate skill names, dangling `scripts/` and
  `references/` links, and a guard against the duplicate tree returning.
- `scripts/test_check_sh.sh` and `scripts/test_compare.py` — 39 behavioural assertions,
  including a canary that injects a malformed pattern and asserts the gate refuses to
  report `ok`.
- `.github/workflows/validate.yml` running all three plus `shellcheck` and `ruff`.

### Removed

- **The duplicate top-level `skills/` tree.** It mirrored `plugins/*/skills/`, nothing
  synced them, and two of ten files had already drifted within a handful of commits.
  `install.sh` read from `plugins/`, so the mirror was dead weight that could only go
  stale. `plugins/` is now the only source of truth.

## 1.0.0

Initial release: `flutter-design-fidelity` (design-tokens, figma-to-widget,
visual-verification, golden-tests) and `flutter-code-quality` (architecture,
state-management, responsive-adaptive, a11y-and-rtl, performance, review-gate).
