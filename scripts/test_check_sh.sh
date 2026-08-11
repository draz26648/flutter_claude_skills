#!/usr/bin/env bash
# Behavioural tests for the review-gate script.
#
# These exist because the gate shipped for its whole life with a check that could never
# fail: `grep -E 'TODO(?!\()|FIXME'` is a PCRE lookahead handed to POSIX ERE, it exited 2
# every run, and the call site discarded both the error and the exit code. The gate
# printed "ok" forever. Anything that can regress into a silent pass is asserted here.

set -uo pipefail

GATE="$(cd "$(dirname "$0")/.." && pwd)/plugins/flutter-code-quality/skills/review-gate/scripts/check.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

FAILURES=0
ok()   { printf '  ok   %s\n' "$1"; }
bad()  { FAILURES=$((FAILURES + 1)); printf '  FAIL %s\n' "$1"; }

expect_contains() {
  local haystack="$1" needle="$2" what="$3"
  case "$haystack" in
    *"$needle"*) ok "$what" ;;
    *)           bad "$what (expected to find: $needle)" ;;
  esac
}

expect_absent() {
  local haystack="$1" needle="$2" what="$3"
  case "$haystack" in
    *"$needle"*) bad "$what (unexpectedly found: $needle)" ;;
    *)           ok "$what" ;;
  esac
}

expect_exit() {
  local actual="$1" expected="$2" what="$3"
  if [ "$actual" -eq "$expected" ]; then ok "$what"; else bad "$what (exit $actual, wanted $expected)"; fi
}

# The carve-outs apply to the grep checks only. `flutter analyze` legitimately reports on
# generated files — whether to silence that is the project's call via analysis_options.yaml,
# not the gate's — so assertions about exclusions must look at that section alone.
patterns_section() {
  printf '%s\n' "$1" | sed -n '/=== Forbidden patterns ===/,/=== Tests ===/p'
}

new_project() {
  local dir="$WORK/$1"
  flutter create --quiet "$dir" >/dev/null 2>&1 || return 1
  ( cd "$dir" \
    && git init -q . \
    && git add -A >/dev/null \
    && git -c user.email=t@t -c user.name=t commit -qm base >/dev/null )
  printf '%s' "$dir"
}

# ---------------------------------------------------------------- violations fixture

echo "== project with known violations =="
PROJ="$(new_project violations)" || { echo "flutter create failed"; exit 2; }

mkdir -p "$PROJ/lib/core/theme" "$PROJ/lib/features/wallet/presentation"

# Literal colors and numbers are CORRECT here. Flagging them would make the gate lie.
cat > "$PROJ/lib/core/theme/app_colors.dart" <<'EOF'
import 'package:flutter/material.dart';

class AppColors {
  static const brand = Color(0xFF1B6EF3);
  static const pad = EdgeInsets.all(16);
  static final radius = BorderRadius.circular(12);
}
EOF

cat > "$PROJ/lib/features/wallet/presentation/wallet_page.dart" <<'EOF'
import 'package:flutter/material.dart';

// final dead = 1;
class WalletPage extends StatelessWidget {
  const WalletPage({super.key, this.balance});
  final String? balance;

  @override
  Widget build(BuildContext context) {
    print('rendering');
    debugPrint('also this');
    // TODO untracked
    // TODO(WAL-42) tracked, must not be flagged
    if (balance != null && balance != 'x') {
      return Text(balance!.trim());
    }
    return Container(
      color: Color(0xFFAABBCC),
      padding: EdgeInsets.only(left: 16, right: 8),
      child: Text('Your current balance'),
    );
  }
}
EOF

# Generated code is not the author's to fix.
cat > "$PROJ/lib/features/wallet/wallet.freezed.dart" <<'EOF'
import 'package:flutter/material.dart';
const gen = Color(0xFF000000);
void x() { print('generated'); }
EOF

( cd "$PROJ" && git add -A >/dev/null )
OUT="$(cd "$PROJ" && bash "$GATE" --skip-tests 2>&1)"
CODE=$(cd "$PROJ" && bash "$GATE" --skip-tests >/dev/null 2>&1; echo $?)

expect_exit "$CODE" 1 "exits 1 when something blocks"
expect_contains "$OUT" "wallet_page.dart:10:    print(" "flags print()"
expect_contains "$OUT" "debugPrint"                     "flags debugPrint()"
expect_contains "$OUT" "// TODO untracked"              "flags an untracked TODO"
expect_absent   "$OUT" "WAL-42"                         "does not flag a TODO with a ticket"
expect_contains "$OUT" "// final dead = 1;"             "flags commented-out code"
expect_contains "$OUT" "Color(0xFFAABBCC)"              "flags a hardcoded color in a widget"
expect_contains "$OUT" "EdgeInsets.only(left:"          "flags a non-directional EdgeInsets"
expect_contains "$OUT" "balance!.trim()"                "flags a force-unwrap"
expect_absent   "$OUT" "balance != null"                "does not mistake != for a force-unwrap"
expect_contains "$OUT" "Your current balance"           "flags a hardcoded user-facing string"
PATTERNS="$(patterns_section "$OUT")"
expect_absent   "$PATTERNS" "app_colors.dart"           "does not flag the token layer"
expect_absent   "$PATTERNS" "wallet.freezed.dart"       "does not flag generated code"
expect_contains "$OUT" "BLOCKING"                       "prints a BLOCKING section"
expect_contains "$OUT" "WORTH FIXING"                   "prints a WORTH FIXING section"

# ---------------------------------------------------------------- clean fixture

echo "== clean project =="
CLEAN="$(new_project clean)" || { echo "flutter create failed"; exit 2; }
rm -rf "${CLEAN:?}/test"
cat > "$CLEAN/lib/main.dart" <<'EOF'
import 'package:flutter/material.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(home: Scaffold());
}
EOF
( cd "$CLEAN" && git add -A >/dev/null )
CLEAN_OUT="$(cd "$CLEAN" && bash "$GATE" --skip-tests 2>&1)"
CLEAN_CODE=$(cd "$CLEAN" && bash "$GATE" --skip-tests >/dev/null 2>&1; echo $?)
expect_exit "$CLEAN_CODE" 0 "exits 0 on a clean project"
expect_contains "$CLEAN_OUT" "Nothing blocking" "says so plainly when nothing blocks"

# ---------------------------------------------------------------- profile
#
# The fixture is analyzer-clean on purpose. The violations fixture above trips
# `flutter analyze --fatal-infos`, and analysis blocks under every profile — so it could
# never show that a profile setting changed a verdict.

echo "== profile =="
PP="$(new_project profile)" || { echo "flutter create failed"; exit 2; }
rm -rf "${PP:?}/test"
cat > "$PP/lib/main.dart" <<'EOF'
import 'package:flutter/material.dart';

void main() => runApp(const BalanceCard());

class BalanceCard extends StatelessWidget {
  const BalanceCard({super.key});

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFAABBCC),
    padding: const EdgeInsets.only(left: 16, right: 8),
    child: const Text('Your current balance'),
  );
}
EOF
( cd "$PP" && git add -A >/dev/null )

write_profile() { mkdir -p "$PP/.claude" && printf '%s\n' "$1" > "$PP/.claude/flutter-profile.yaml"; }
run_profiled()  { ( cd "$PP" && bash "$GATE" --skip-tests 2>&1 ); }
code_profiled() { ( cd "$PP" && bash "$GATE" --skip-tests >/dev/null 2>&1; echo $? ); }

# Baseline: no profile must behave exactly as it did before profiles existed.
rm -rf "$PP/.claude"
BASE_OUT="$(run_profiled)"

# The fixture has to be format-clean and analyzer-clean, or those block under every
# profile and no assertion below can distinguish a profile effect from a formatting one.
expect_absent "$BASE_OUT" "FAIL: dart format" "profile fixture is format-clean"
expect_absent "$BASE_OUT" "FAIL: flutter analyze" "profile fixture is analyzer-clean"
expect_exit "$(code_profiled)" 1 "no profile: hardcoded values still block"
expect_contains "$BASE_OUT" "defaults (no .claude/flutter-profile.yaml)" "no profile: says so in the header"
expect_contains "$BASE_OUT" "FAIL: no hardcoded colors" "no profile: colors block"
expect_contains "$BASE_OUT" "FAIL: use EdgeInsetsDirectional" "no profile: RTL blocks with locales undeclared"

# tokens: none — the project has no token layer, so the token checks have nothing to
# point at and must not run. A skipped check has to say it was skipped.
write_profile 'tokens: none'
TN_OUT="$(run_profiled)"
expect_contains "$TN_OUT" "skipped: no hardcoded colors" "tokens: none skips the colour check"
expect_contains "$TN_OUT" "skipped: no numeric EdgeInsets" "tokens: none skips the EdgeInsets check"
expect_contains "$TN_OUT" "skipped: no hardcoded radii" "tokens: none skips the radius check"
expect_contains "$TN_OUT" "not checked: no hardcoded colors" "a skipped check is listed in NOTES"
expect_absent   "$TN_OUT" "FAIL: no hardcoded colors" "tokens: none does not block on colours"

# theme_only — the values should still be centralised, just not through AppTokens.
write_profile 'tokens: theme_only'
TO_OUT="$(run_profiled)"
expect_contains "$TO_OUT" "WARN: no hardcoded colors" "tokens: theme_only downgrades to a warning"
expect_absent   "$TO_OUT" "FAIL: no hardcoded colors" "tokens: theme_only does not block"

# locales — declaring an LTR-only set downgrades RTL; declaring an RTL locale blocks.
write_profile 'locales: [en]'
L_OUT="$(run_profiled)"
expect_contains "$L_OUT" "WARN: use EdgeInsetsDirectional" "locales: [en] downgrades the RTL check"
write_profile 'locales: [en, ar]'
LA_OUT="$(run_profiled)"
expect_contains "$LA_OUT" "FAIL: use EdgeInsetsDirectional" "an RTL locale keeps the RTL check blocking"

# l10n: none — no strings mechanism, so a literal in Text() is not a finding.
write_profile 'l10n: none'
LN_OUT="$(run_profiled)"
expect_contains "$LN_OUT" "skipped: user-facing strings" "l10n: none skips the string check"

# strictness: warn — every convention finding drops, and the gate stops blocking.
write_profile 'strictness: warn'
SW_OUT="$(run_profiled)"
expect_exit "$(code_profiled)" 0 "strictness: warn stops convention findings from blocking"
expect_contains "$SW_OUT" "WARN: no hardcoded colors" "strictness: warn still reports the finding"
expect_absent   "$SW_OUT" "BLOCKING" "strictness: warn prints no BLOCKING section"

# ...but never for the things that are not house style.
cat > "$PP/lib/secrets.dart" <<'EOF'
const apiKey = 'sk_live_abcdef0123456789';
EOF
( cd "$PP" && git add -A >/dev/null )
write_profile 'strictness: warn'
SEC_OUT="$(run_profiled)"
expect_exit "$(code_profiled)" 1 "strictness: warn still blocks committed credentials"
expect_contains "$SEC_OUT" "FAIL: no committed credentials" "credentials block under every profile"
rm -f "$PP/lib/secrets.dart"
( cd "$PP" && git add -A >/dev/null )

# A typo must not be read as the default. Enforcing bloc conventions on a project that
# asked for riverpod, with nothing in the output to say so, is the worst outcome here.
write_profile 'tokens: theme_extensionn'
BAD_OUT="$(run_profiled)"
expect_exit "$(code_profiled)" 2 "an unrecognised profile value exits 2"
expect_contains "$BAD_OUT" "is not a recognised value" "and names the offending field"
expect_absent   "$BAD_OUT" "=== Summary ===" "and does not go on to report on the code"

rm -rf "$PP/.claude"

# ---------------------------------------------------------------- reuse and assets

echo "== reuse and assets =="
RA="$(new_project reuse)" || { echo "flutter create failed"; exit 2; }
rm -rf "${RA:?}/test"
mkdir -p "$RA/assets/images" "$RA/lib/core/widgets" "$RA/lib/features/wallet"
printf 'x' > "$RA/assets/images/logo.png"

for f in core/widgets features/wallet; do
  cat > "$RA/lib/$f/app_button.dart" <<'EOF'
import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
  const AppButton({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox();
}
EOF
done

cat > "$RA/lib/main.dart" <<'EOF'
import 'package:flutter/material.dart';

void main() => runApp(const Logo());

class Logo extends StatelessWidget {
  const Logo({super.key});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Image.asset('assets/images/logo.png'),
      Image.asset('assets/images/missing.png'),
      const Text('hi', style: TextStyle(fontSize: 14)),
    ],
  );
}
EOF
( cd "$RA" && git add -A >/dev/null )

RA_OUT="$(cd "$RA" && bash "$GATE" --skip-tests --all 2>&1)"
RA_CODE=$(cd "$RA" && bash "$GATE" --skip-tests --all >/dev/null 2>&1; echo $?)

expect_contains "$RA_OUT" "assets/images/missing.png" "flags an asset path that does not resolve"
expect_absent   "$RA_OUT" "assets/images/logo.png"    "does not flag an asset that exists"
expect_contains "$RA_OUT" "widget class 'AppButton' is defined in more than one file" \
                                                      "flags a widget class defined twice"
expect_contains "$RA_OUT" "WARN: no inline TextStyle" "flags an inline TextStyle"

# All three are new in this release. A new check that blocks would fail projects that
# passed yesterday, which this repo treats as a breaking change — so they warn.
expect_exit "$RA_CODE" 0 "the new reuse and asset checks warn rather than block"

# tokens: none has no typography source to point at either.
mkdir -p "$RA/.claude" && printf 'tokens: none\n' > "$RA/.claude/flutter-profile.yaml"
RA_TN="$(cd "$RA" && bash "$GATE" --skip-tests --all 2>&1)"
expect_contains "$RA_TN" "skipped: no inline TextStyle" "tokens: none skips the TextStyle check"
rm -rf "$RA/.claude"

# Scope: a duplicate the current change is not part of belongs to some other commit.
# Reporting it here buries the findings that are actually this diff's.
( cd "$RA" && git add -A >/dev/null \
  && git -c user.email=t@t -c user.name=t commit -qm widgets >/dev/null )
printf '\n// touched\n' >> "$RA/lib/main.dart"
RA_SCOPED="$(cd "$RA" && bash "$GATE" --skip-tests 2>&1)"
expect_contains "$RA_SCOPED" "1 changed Dart file(s)" "scoped run sees only the changed file"
expect_absent   "$RA_SCOPED" "widget class 'AppButton'" \
                "does not report a duplicate the change is not part of"
expect_contains "$RA_SCOPED" "assets/images/missing.png" \
                "still reports a bad asset path in the changed file"

# ---------------------------------------------------------------- guards

echo "== guards =="
BARE="$WORK/bare"
mkdir -p "$BARE"
BARE_CODE=$(cd "$BARE" && bash "$GATE" --skip-tests >/dev/null 2>&1; echo $?)
expect_exit "$BARE_CODE" 2 "exits 2 outside a Flutter project rather than reporting clean"

# ---------------------------------------------------------------- the original bug

echo "== a broken check must fail loudly, never report ok =="
#
# grep implementations disagree about this exact pattern, which is why the original bug
# survived so long. GNU grep prints a warning and exits 1, which is indistinguishable from
# "no violations found". ugrep exits 2. A fix that only inspects the exit code catches the
# second and silently passes the first, so run the canary under every grep on this machine.
BROKEN="$WORK/broken.sh"
python3 - "$GATE" "$BROKEN" <<'PY'
import sys
src = open(sys.argv[1]).read()
needle = 'check_pattern "no print() calls" "$(sev block)"'
inject = (
    'check_pattern "canary" block \\\n'
    "  'TODO(?!\\()|FIXME' \\\n"
    '  "" \\\n'
    '  "  // TODO untracked"\n\n'
)
assert needle in src, "anchor for the canary injection moved"
open(sys.argv[2], 'w').write(src.replace(needle, inject + needle, 1))
PY

run_canary() {
  local label="$1" extra_path="$2" out
  if [ -n "$extra_path" ]; then
    out="$(cd "$PROJ" && PATH="$extra_path:$PATH" bash "$BROKEN" --skip-tests 2>&1)"
  else
    out="$(cd "$PROJ" && bash "$BROKEN" --skip-tests 2>&1)"
  fi
  expect_contains "$out" "check 'canary' is broken" "[$label] surfaces a broken pattern"
  expect_absent   "$out" "ok: canary"               "[$label] never reports ok for a broken check"
}

run_canary "default grep" ""

# Homebrew keeps GNU grep out of the default PATH on macOS. If it is here, this is the
# case CI hits, so exercise it locally too.
GNU_GREP_DIR=/opt/homebrew/opt/grep/libexec/gnubin
if [ -x "$GNU_GREP_DIR/grep" ]; then
  run_canary "GNU grep" "$GNU_GREP_DIR"
else
  echo "  note: GNU grep not installed locally; CI covers that case"
fi

# Every real check must also declare a sample, or the self-test is vacuous.
MISSING="$WORK/missing.sh"
python3 - "$GATE" "$MISSING" <<'PY'
import sys
src = open(sys.argv[1]).read()
needle = 'check_pattern "no print() calls" "$(sev block)"'
inject = 'check_pattern "sampleless" block \\\n  \'print\\(\' \\\n  ""\n\n'
assert needle in src, "anchor for the sampleless injection moved"
open(sys.argv[2], 'w').write(src.replace(needle, inject + needle, 1))
PY
MISSING_OUT="$(cd "$PROJ" && bash "$MISSING" --skip-tests 2>&1)"
expect_contains "$MISSING_OUT" "no self-test sample was declared" "rejects a check with no sample"

# ----------------------------------------------------------------

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "all review-gate tests passed"
  exit 0
fi
echo "$FAILURES review-gate test(s) failed"
exit 1
