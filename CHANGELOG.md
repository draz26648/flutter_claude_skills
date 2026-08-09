# Changelog

Skill text is the product here, so a wording change that alters what an agent does counts
as a release. Bump the `version` in both `plugin.json` and `.claude-plugin/marketplace.json`
together — Claude Code keys its cache on that string, and users never see an update
without it.

## 1.1.0

### Fixed

- **`review-gate` reported a passing check that could never fail.** The TODO/FIXME rule
  used `grep -E 'TODO(?!\()|FIXME'` — a PCRE negative lookahead handed to POSIX ERE. It
  exited 2 on every run, the call site sent stderr to `/dev/null` and ended in `|| true`,
  and the gate printed `ok: TODOs carry a ticket reference` for its entire life. Rewritten
  as an ERE match plus a subtraction of ticket-carrying matches, and `check_pattern` now
  distinguishes grep's three exit states so a broken pattern fails loudly instead of
  reporting clean.
- **`review-gate` failed on correct code.** `Color(0x...)` and numeric `EdgeInsets` were
  blocking with no path exclusions, so a project's own token layer — the one place those
  literals belong — failed the gate. Generated files (`*.g.dart`, `*.freezed.dart`, and
  similar), tests, and `theme/`, `tokens/`, `design_system/` are now carved out.
- **`review-gate` documented checks it did not run.** SKILL.md listed eight forbidden
  patterns; the script implemented five, one of them broken, plus one the doc never
  mentioned. Force-unwrap, `debugPrint`, commented-out code, and hardcoded user-facing
  strings are now implemented, and the doc lists exactly what runs and at what severity.
- **`review-gate` could not name a failing test.** `flutter test` output went to
  `/dev/null`. Failures are now captured and reported.
- **`visual-verification` wrote a diff image that was 98% black.** `ImageChops.difference`
  produces a near-zero raw delta everywhere the images agree, so the artifact the skill
  told you to open was unreadable. It is now the capture, faded, with differing pixels
  burned in as red.
- **`visual-verification` passed defects a designer would spot instantly.** A single
  button with the wrong color token covers ~1.5% of a phone screen and cleared the 2%
  global threshold. Added `--max-cluster`, which grades the worst cell of a 12×12 grid
  alongside the global share.
- **`visual-verification` silently rescaled mismatched images**, manufacturing edge noise
  that hid the real defect. A size mismatch is now an error explaining that the export
  scale is wrong; `--allow-resize` opts back in.
- **`$SKILL_DIR` is not a real variable.** Both skills told the model to resolve it by
  hand. Replaced with `${CLAUDE_PLUGIN_ROOT}`, which Claude Code sets and the shell
  expands on its own.

### Added

- `--ignore-region X,Y,W,H` on `compare.py` for inherently dynamic content, so a status
  bar clock no longer forces the threshold up for the whole screen.
- Distinct exit codes on both scripts: `0` clean, `1` findings, `2` could not run. A `2`
  is not a pass.
- Preconditions on `check.sh` — it now refuses to run outside a Flutter project instead
  of reporting a clean bill of health.
- `--skip-tests` and `--all` on `check.sh`.
- A "judgement the script cannot make" section in `review-gate`, naming the findings that
  need the diff read rather than grepped.
- `scripts/validate.py`, `scripts/test_check_sh.sh`, `scripts/test_compare.py`, and a
  GitHub Actions workflow running all three plus shellcheck and ruff.

### Removed

- **The duplicate top-level `skills/` tree.** It mirrored `plugins/*/skills/`, nothing
  synced them, and two of ten files had already drifted. `install.sh` read from
  `plugins/`, so the mirror was dead weight that could only ever go stale. `plugins/` is
  now the only source of truth, and CI fails if a mirror reappears.

## 1.0.0

Initial release: `flutter-design-fidelity` (design-tokens, figma-to-widget,
visual-verification, golden-tests) and `flutter-code-quality` (architecture,
state-management, responsive-adaptive, a11y-and-rtl, performance, review-gate).
