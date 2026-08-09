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

# ---------------------------------------------------------------- guards

echo "== guards =="
BARE="$WORK/bare"
mkdir -p "$BARE"
BARE_CODE=$(cd "$BARE" && bash "$GATE" --skip-tests >/dev/null 2>&1; echo $?)
expect_exit "$BARE_CODE" 2 "exits 2 outside a Flutter project rather than reporting clean"

# ---------------------------------------------------------------- the original bug

echo "== a broken check must fail loudly, never report ok =="
BROKEN="$WORK/broken.sh"
python3 - "$GATE" "$BROKEN" <<'PY'
import sys
src = open(sys.argv[1]).read()
needle = 'check_pattern "no print() calls" block'
inject = 'check_pattern "canary" block \\\n  \'TODO(?!\\()|FIXME\' \\\n  ""\n\n'
assert needle in src, "anchor for the canary injection moved"
open(sys.argv[2], 'w').write(src.replace(needle, inject + needle, 1))
PY
BROKEN_OUT="$(cd "$PROJ" && bash "$BROKEN" --skip-tests 2>&1)"
expect_contains "$BROKEN_OUT" "check 'canary' could not run" "surfaces a malformed pattern"
expect_absent   "$BROKEN_OUT" "ok: canary"                   "never reports ok for a check that errored"

# ----------------------------------------------------------------

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "all review-gate tests passed"
  exit 0
fi
echo "$FAILURES review-gate test(s) failed"
exit 1
