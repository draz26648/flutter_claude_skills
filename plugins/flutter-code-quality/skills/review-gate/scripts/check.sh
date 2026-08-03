#!/usr/bin/env bash
# Pre-commit quality gate for Flutter projects.
# Reports findings; does not modify code.

set -uo pipefail

BLOCKING=0
FINDINGS=""

section() { printf "\n=== %s ===\n" "$1"; }
fail()    { BLOCKING=1; FINDINGS="${FINDINGS}\n  BLOCKING: $1"; printf "  FAIL: %s\n" "$1"; }
warn()    { FINDINGS="${FINDINGS}\n  WORTH FIXING: $1"; printf "  WARN: %s\n" "$1"; }
pass()    { printf "  ok: %s\n" "$1"; }

# Confine the audit to changed Dart files where possible.
CHANGED=$(git diff --name-only --diff-filter=ACM HEAD 2>/dev/null | grep '\.dart$' || true)
if [ -z "$CHANGED" ]; then
  echo "No changed Dart files against HEAD; auditing lib/ and test/."
  SCOPE="lib test"
else
  SCOPE="$CHANGED"
fi

section "Formatting"
if dart format --set-exit-if-changed --output=none $SCOPE >/dev/null 2>&1; then
  pass "formatted"
else
  fail "dart format would change files — run: dart format ."
fi

section "Static analysis"
ANALYZE=$(flutter analyze --fatal-infos 2>&1)
if [ $? -eq 0 ]; then
  pass "analyzer clean"
else
  fail "flutter analyze reported issues"
  echo "$ANALYZE" | tail -20
fi

section "Forbidden patterns"

check_pattern() {
  local pattern="$1" label="$2" severity="$3"
  local hits
  hits=$(grep -rn --include='*.dart' -E "$pattern" $SCOPE 2>/dev/null | grep -v '_test\.dart' || true)
  if [ -n "$hits" ]; then
    if [ "$severity" = "block" ]; then fail "$label"; else warn "$label"; fi
    echo "$hits" | head -8 | sed 's/^/    /'
  else
    pass "$label"
  fi
}

check_pattern '(^|[^a-zA-Z_.])print\(' "no print() calls" block
check_pattern 'TODO(?!\()|FIXME' "TODOs carry a ticket reference" warn
check_pattern 'Color\(0x' "no hardcoded colors in widget code" block
check_pattern 'EdgeInsets\.(all|symmetric|only)\([0-9]' "no numeric EdgeInsets" block
check_pattern 'EdgeInsets\.only\((left|right):' "use EdgeInsetsDirectional" block
check_pattern 'BorderRadius\.circular\([0-9]' "no hardcoded radii" warn
check_pattern 'apiKey|api_key|secret\s*=\s*.[A-Za-z0-9]{16}' "no committed credentials" block

section "Tests"
if flutter test >/dev/null 2>&1; then
  pass "tests pass"
else
  fail "flutter test failed"
fi

GOLDEN_CHANGES=$(git diff --name-only --diff-filter=ACM HEAD 2>/dev/null | grep 'goldens/.*\.png$' || true)
if [ -n "$GOLDEN_CHANGES" ]; then
  warn "golden images changed — confirm each was visually reviewed:"
  echo "$GOLDEN_CHANGES" | sed 's/^/    /'
fi

section "Summary"
if [ -n "$FINDINGS" ]; then
  printf "%b\n" "$FINDINGS"
else
  echo "  Nothing blocking."
fi

exit $BLOCKING
