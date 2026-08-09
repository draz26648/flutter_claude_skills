#!/usr/bin/env bash
# Pre-commit quality gate for Flutter projects.
# Reports findings; never modifies code.
#
# Reads .claude/flutter-profile.yaml if present, so the conventions it enforces are the
# ones the project actually holds. With no profile it behaves exactly as it did before
# the profile existed.
#
# Written for bash 3.2 (the version macOS ships) — no mapfile, no associative arrays.
#
# Exit codes:
#   0  no blocking findings (warnings may still be present)
#   1  at least one blocking finding
#   2  the gate could not run — missing tooling, wrong directory, bad profile, broken check
#
# Usage: bash check.sh [--skip-tests] [--all] [--profile PATH]

set -uo pipefail

SKIP_TESTS=false
FORCE_ALL=false
PROFILE_PATH=".claude/flutter-profile.yaml"

while [ $# -gt 0 ]; do
  case "$1" in
    --skip-tests) SKIP_TESTS=true; shift ;;
    --all)        FORCE_ALL=true; shift ;;
    --profile)    PROFILE_PATH="${2:-}"; [ -n "$PROFILE_PATH" ] || { printf 'gate: --profile needs a path\n' >&2; exit 2; }; shift 2 ;;
    -h|--help)    sed -n '2,16p' "$0"; exit 0 ;;
    *) printf 'gate: unknown option %s\n' "$1" >&2; exit 2 ;;
  esac
done

BLOCKING=0
BLOCKERS=""
WARNINGS=""
NOTES=""

section() { printf '\n=== %s ===\n' "$1"; }
fail()    { BLOCKING=1; BLOCKERS="${BLOCKERS}  - $1"$'\n'; printf '  FAIL: %s\n' "$1"; }
warn()    { WARNINGS="${WARNINGS}  - $1"$'\n'; printf '  WARN: %s\n' "$1"; }
note()    { NOTES="${NOTES}  - $1"$'\n'; }
pass()    { printf '  ok: %s\n' "$1"; }
# A skipped check is announced with the reason. Silently omitting one makes it
# indistinguishable from a check that passed, which is the whole bug class this gate
# had in 1.0.0.
skipped() { NOTES="${NOTES}  - not checked: $1 — $2"$'\n'; printf '  skipped: %s (%s)\n' "$1" "$2"; }

# A gate that cannot run must say so loudly rather than reporting a clean bill of health.
die() { printf '\ngate: %s\n' "$1" >&2; exit 2; }

# ---------------------------------------------------------------- preconditions

command -v flutter >/dev/null 2>&1 || die "flutter is not on PATH"
command -v dart    >/dev/null 2>&1 || die "dart is not on PATH"
[ -f pubspec.yaml ] || die "no pubspec.yaml here — run this from the project root, not from the skill directory"

# ---------------------------------------------------------------- profile
#
# Defaults are the conventions the gate enforced before the profile existed, so a project
# with no .claude/flutter-profile.yaml sees exactly the behaviour it saw before.
#
# An unrecognised value is fatal rather than ignored. Treating `riverpood` as the default
# would enforce the opposite of what the project asked for, with nothing in the output to
# say so.

P_TOKENS=theme_extension
P_L10N=arb
P_STRICTNESS=block
P_LOCALES=""
LOCALES_DECLARED=false
PROFILE_LABEL="defaults (no $PROFILE_PATH)"

# Flat `key: value` only, with `#` comments stripped. Deliberately not a YAML parser: the
# profile is nine scalar fields and one inline list, and a dependency on PyYAML would put
# the gate behind a pip install.
profile_get() {
  sed -n "s/^[[:space:]]*$1:[[:space:]]*\([^#]*\).*\$/\1/p" "$PROFILE_PATH" 2>/dev/null \
    | head -1 | sed 's/[[:space:]]*$//'
}

require_value() { # require_value <field> <value> <allowed...>
  case " $3 " in
    *" $2 "*) return 0 ;;
  esac
  die "profile: $1: '$2' is not a recognised value. Expected one of: $3"
}

if [ -f "$PROFILE_PATH" ]; then
  v=$(profile_get tokens);     [ -n "$v" ] && P_TOKENS="$v"
  v=$(profile_get l10n);       [ -n "$v" ] && P_L10N="$v"
  v=$(profile_get strictness); [ -n "$v" ] && P_STRICTNESS="$v"

  # locales: [en, ar]  ->  " en ar "
  v=$(profile_get locales)
  if [ -n "$v" ]; then
    LOCALES_DECLARED=true
    P_LOCALES=" $(printf '%s' "$v" | tr -d '[]"'"'" | tr ',' ' ' | tr -s ' ') "
  fi

  require_value tokens     "$P_TOKENS"     "theme_extension theme_only constants none"
  require_value l10n       "$P_L10N"       "arb easy_localization slang none"
  require_value strictness "$P_STRICTNESS" "block warn"

  PROFILE_LABEL="$PROFILE_PATH (tokens: $P_TOKENS, l10n: $P_L10N, strictness: $P_STRICTNESS"
  if [ "$LOCALES_DECLARED" = true ]; then
    PROFILE_LABEL="$PROFILE_LABEL, locales:$P_LOCALES)"
  else
    PROFILE_LABEL="$PROFILE_LABEL, locales: not declared)"
  fi
fi

# strictness: warn downgrades house-style findings only. Formatting, static analysis,
# failing tests and committed credentials block under every profile — a project that
# wants those off wants a different tool.
sev() {
  if [ "$1" = block ] && [ "$P_STRICTNESS" = warn ]; then
    printf 'warn'
  else
    printf '%s' "$1"
  fi
}

case "$P_TOKENS" in
  theme_extension)      TOKEN_SEV=$(sev block) ;;
  theme_only|constants) TOKEN_SEV=warn ;;
  none)                 TOKEN_SEV="skip:profile says tokens: none" ;;
esac

# Some checks warn under every token setting that has a token layer at all, so they only
# follow the token severity when it says to skip.
case "$TOKEN_SEV" in
  skip:*) TOKEN_SOFT_SEV="$TOKEN_SEV" ;;
  *)      TOKEN_SOFT_SEV=warn ;;
esac

if [ "$P_L10N" = none ]; then
  STRING_SEV="skip:profile says l10n: none"
else
  STRING_SEV=warn
fi

# An undeclared `locales` keeps the RTL check blocking. The gate cannot tell whether the
# project ships an RTL language, and the safe assumption is that it might — so the
# downgrade needs the project to say so explicitly.
RTL_SEV=$(sev block)
if [ "$LOCALES_DECLARED" = true ]; then
  case "$P_LOCALES" in
    *" ar "*|*" he "*|*" fa "*|*" ur "*|*" ps "*|*" sd "*|*" ug "*|*" dv "*|*" yi "*) ;;
    *) RTL_SEV=warn ;;
  esac
fi

# ---------------------------------------------------------------- scope

FILES=()
SCOPE_LABEL=""

if [ "$FORCE_ALL" = false ] && git rev-parse --git-dir >/dev/null 2>&1 \
   && git rev-parse --verify -q HEAD >/dev/null 2>&1; then
  while IFS= read -r f; do
    case "$f" in
      *.dart) [ -f "$f" ] && FILES[${#FILES[@]}]="$f" ;;
    esac
  done < <(git diff --name-only --diff-filter=ACM HEAD 2>/dev/null)
fi

if [ ${#FILES[@]} -eq 0 ]; then
  while IFS= read -r f; do
    FILES[${#FILES[@]}]="$f"
  done < <(find lib test -name '*.dart' -type f 2>/dev/null)
  if [ "$FORCE_ALL" = true ]; then
    SCOPE_LABEL="all of lib/ and test/ (--all)"
  else
    SCOPE_LABEL="all of lib/ and test/ (nothing changed against HEAD)"
  fi
else
  SCOPE_LABEL="${#FILES[@]} changed Dart file(s) vs HEAD"
fi

[ ${#FILES[@]} -gt 0 ] || die "found no Dart files to audit under lib/ or test/"

printf 'Scope: %s\n' "$SCOPE_LABEL"
printf 'Profile: %s\n' "$PROFILE_LABEL"

# ---------------------------------------------------------------- exclusions
#
# Applied to the whole "path:line:content" match line, so they can filter on either
# the path or the matched text.

EX_GENERATED='\.(g|freezed|mocks|config|gr|pb|pbenum|pbjson)\.dart:'
EX_TEST='(^|/)(test|integration_test)/|_test\.dart:'
# The token/theme layer is the one place literal colors and numbers belong. Without
# this carve-out the gate fails on correct code, and a gate that cries wolf is ignored.
EX_THEME='(^|/)(theme|themes|tokens|design_system)/|app_(colors|theme|tokens|typography|spacing|elevation)\.dart:'
EX_L10N='(^|/)(l10n|generated|intl)/'
# Path-only form, for checks that work on transformed lines rather than grep output.
EX_GENERATED_FILE='\.(g|freezed|mocks|config|gr|pb|pbenum|pbjson)\.dart$'

# ---------------------------------------------------------------- pattern engine

# check_pattern <label> <block|warn|skip:reason> <ere-pattern> <exclusion-ere> <must-match-sample>
#
# The sample is a line the pattern is required to match. A check that cannot find its own
# known violation is broken, and says so instead of reporting "ok".
#
# The self-test runs even for a check the profile switches off, so a pattern that rots
# while it is skipped is caught the moment someone changes the profile rather than months
# later.
#
# Exit codes alone are not enough to detect a bad pattern, because grep implementations
# disagree. Given the PCRE lookahead this script used to carry, GNU grep prints a warning
# and exits 1 — indistinguishable from "no violations found" — while ugrep exits 2. Testing
# only for exit >= 2 leaves the GNU case silently green, which is the majority of CI.
check_pattern() {
  local label="$1" severity="$2" pattern="$3" exclude="${4:-}" sample="${5:-}"
  local hits status errfile

  if [ -z "$sample" ]; then
    fail "check '$label' is broken: no self-test sample was declared for it"
    return
  fi
  if ! printf '%s\n' "$sample" | grep -qE -- "$pattern" 2>/dev/null; then
    fail "check '$label' is broken: its pattern does not match its own test sample"
    return
  fi

  case "$severity" in
    skip:*) skipped "$label" "${severity#skip:}"; return ;;
  esac

  errfile=$(mktemp) || die "mktemp failed"
  hits=$(grep -HnE -- "$pattern" "${FILES[@]}" 2>"$errfile")
  status=$?

  if [ "$status" -ge 2 ]; then
    fail "check '$label' is broken: $(tr '\n' ' ' <"$errfile")"
    rm -f "$errfile"
    return
  fi
  rm -f "$errfile"

  if [ -n "$exclude" ] && [ -n "$hits" ]; then
    hits=$(printf '%s\n' "$hits" | grep -vE -- "$exclude")
    if [ $? -ge 2 ]; then
      fail "check '$label' exclusion filter is malformed"
      return
    fi
  fi

  if [ -n "$hits" ]; then
    local count
    count=$(printf '%s\n' "$hits" | grep -c .)
    if [ "$severity" = "block" ]; then
      fail "$label ($count)"
    else
      warn "$label ($count)"
    fi
    printf '%s\n' "$hits" | head -8 | sed 's/^/    /'
    [ "$count" -gt 8 ] && printf '    ... and %s more\n' "$((count - 8))"
  else
    pass "$label"
  fi
}

# ---------------------------------------------------------------- formatting

section "Formatting"
if dart format --set-exit-if-changed --output=none "${FILES[@]}" >/dev/null 2>&1; then
  pass "formatted"
else
  fail "dart format would change files — run: dart format ."
fi

# ---------------------------------------------------------------- static analysis

section "Static analysis"
# Deliberately whole-project: a change in one file breaks analysis in another, and
# scoping the analyzer to the diff hides exactly that class of breakage.
ANALYZE_OUT=$(mktemp) || die "mktemp failed"
if flutter analyze --fatal-infos >"$ANALYZE_OUT" 2>&1; then
  pass "analyzer clean (whole project)"
else
  fail "flutter analyze reported issues"
  grep -E '^[[:space:]]*(error|warning|info)' "$ANALYZE_OUT" | head -15 | sed 's/^/    /'
  tail -3 "$ANALYZE_OUT" | sed 's/^/    /'
fi
rm -f "$ANALYZE_OUT"

# ---------------------------------------------------------------- forbidden patterns

section "Forbidden patterns"

check_pattern "no print() calls" "$(sev block)" \
  '(^|[^a-zA-Z0-9_.])print\(' \
  "$EX_GENERATED|$EX_TEST" \
  "    print('rendering');"

check_pattern "no debugPrint() in shipped code" warn \
  '(^|[^a-zA-Z0-9_.])debugPrint\(' \
  "$EX_GENERATED|$EX_TEST" \
  "    debugPrint('rendering');"

# ERE has no negative lookahead. Match every TODO/FIXME, then subtract the ones that
# carry a ticket reference. The previous PCRE-style `TODO(?!\()` never worked: GNU grep
# warned and exited 1, ugrep exited 2, and either way the call site discarded it, so
# this check reported "ok" for its entire life.
check_pattern "TODOs carry a ticket reference" warn \
  '(TODO|FIXME)' \
  "$EX_GENERATED|(TODO|FIXME)[[:space:]]*\([A-Z][A-Z0-9]*-[0-9]+\)" \
  "  // TODO untracked"

check_pattern "no commented-out code" warn \
  '^[[:space:]]*//[[:space:]]*(final|var|const|return|await|if|for|while|switch|import|Widget|Navigator|setState)[[:space:](]' \
  "$EX_GENERATED|$EX_TEST" \
  "  // final dead = 1;"

check_pattern "no hardcoded colors in widget code" "$TOKEN_SEV" \
  'Color\(0x|[^a-zA-Z0-9_.]Colors\.[a-z]' \
  "$EX_GENERATED|$EX_TEST|$EX_THEME|Colors\.transparent" \
  "      color: Color(0xFFAABBCC),"

check_pattern "no numeric EdgeInsets" "$TOKEN_SEV" \
  'EdgeInsets\.(all|symmetric|only|fromLTRB)\([^)]*[0-9]' \
  "$EX_GENERATED|$EX_TEST|$EX_THEME" \
  "      margin: EdgeInsets.all(12),"

check_pattern "use EdgeInsetsDirectional (start/end, not left/right)" "$RTL_SEV" \
  'EdgeInsets\.(only|fromLTRB)\([^)]*(left|right):' \
  "$EX_GENERATED|$EX_TEST" \
  "      padding: EdgeInsets.only(left: 16, right: 8),"

check_pattern "no hardcoded radii" "$TOKEN_SOFT_SEV" \
  'BorderRadius\.circular\([0-9]' \
  "$EX_GENERATED|$EX_TEST|$EX_THEME" \
  "      borderRadius: BorderRadius.circular(8),"

# Force-unwrap: `x!.foo`, `x!,`, `x!)`, `x!;`. The `!=` operator is excluded because
# `=` is not in the trailing set. Warn rather than block — the token file's
# `Theme.of(context).extension<AppTokens>()!` is a legitimate use.
check_pattern "force-unwrap needs a comment justifying it" warn \
  '[]a-zA-Z0-9_)]!(\.|,|;|\))' \
  "$EX_GENERATED|$EX_TEST" \
  "      return Text(balance!.trim());"

check_pattern "user-facing strings belong in ARB files" "$STRING_SEV" \
  'Text\([[:space:]]*.[^'"'"'"]*[[:space:]][^'"'"'"]*.[[:space:]]*[,)]' \
  "$EX_GENERATED|$EX_TEST|$EX_L10N" \
  "      child: Text('Your current balance'),"

check_pattern "no committed credentials" block \
  '(api[_-]?key|apiKey|secret|password|access[_-]?token)[[:space:]]*[:=][[:space:]]*.[A-Za-z0-9_/+-]{16}|https?://[^[:space:]"'"'"']*:[^[:space:]"'"'"']*@' \
  "$EX_TEST" \
  "    final apiKey = 'sk_live_abcdef0123456789';"

check_pattern "no inline TextStyle in widget code" "$TOKEN_SOFT_SEV" \
  '[^a-zA-Z0-9_.]TextStyle\(' \
  "$EX_GENERATED|$EX_TEST|$EX_THEME" \
  "      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),"

# ---------------------------------------------------------------- reuse and assets

section "Reuse and assets"

# An asset path that does not resolve throws at runtime, in the widget, on the device.
# `flutter analyze` says nothing about it, and a test that never renders that screen says
# nothing either, so it reaches review looking like working code. This is the one check
# here that is a fact rather than a convention.
check_assets() {
  local hits line loc path missing="" count=0
  hits=$(grep -HnoE "\.asset\([[:space:]]*['\"][^'\"\$]+['\"]" "${FILES[@]}" 2>/dev/null)

  if [ -z "$hits" ]; then
    pass "no literal asset paths in scope"
    return
  fi

  while IFS= read -r line; do
    [ -n "$line" ] || continue
    loc=$(printf '%s' "$line" | sed -E 's|^(.*\.dart:[0-9]+):.*|\1|')
    path=$(printf '%s' "$line" | sed -E "s|.*\.asset\([[:space:]]*['\"]||; s|['\"]\$||")
    # A `packages/<name>/...` path resolves inside another package, not this checkout.
    case "$path" in
      packages/*) continue ;;
    esac
    if [ ! -f "$path" ]; then
      count=$((count + 1))
      missing="${missing}    $loc -> $path"$'\n'
    fi
  done <<EOF
$hits
EOF

  if [ "$count" -eq 0 ]; then
    pass "every referenced asset exists on disk"
  else
    warn "asset paths that do not resolve ($count) — these throw at runtime, not at compile time"
    printf '%s' "$missing" | head -8
    [ "$count" -gt 8 ] && printf '    ... and %s more\n' "$((count - 8))"
  fi
}
check_assets

# The second PrimaryButton. Correct, tested, redundant, and invisible in review because
# the diff is all additions.
check_duplicate_widgets() {
  local defs dups name where in_change
  if [ ! -d lib ]; then
    skipped "no duplicate widget classes" "no lib/ directory"
    return
  fi

  defs=$(grep -rHnE '^class [A-Z][A-Za-z0-9_]*[[:space:]]+extends[[:space:]]+(StatelessWidget|StatefulWidget|ConsumerWidget|ConsumerStatefulWidget|HookWidget|HookConsumerWidget)' \
      lib --include='*.dart' 2>/dev/null \
    | sed -E 's|^([^:]+):[0-9]+:class ([A-Za-z0-9_]+).*|\2 \1|' \
    | grep -vE "$EX_GENERATED_FILE")

  if [ -z "$defs" ]; then
    pass "no duplicate widget classes"
    return
  fi

  dups=$(printf '%s\n' "$defs" | awk '{print $1}' | sort | uniq -d)
  if [ -z "$dups" ]; then
    pass "no duplicate widget classes"
    return
  fi

  local reported=0
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    where=$(printf '%s\n' "$defs" | awk -v n="$name" '$1 == n {print $2}')
    # Report only duplicates the current change is part of. A pre-existing duplicate three
    # features away is real but is not this diff's finding, and burying the change's own
    # results is how a report stops being read.
    in_change=false
    while IFS= read -r f; do
      for changed in "${FILES[@]}"; do
        [ "$changed" = "$f" ] && in_change=true && break
      done
    done <<EOF
$where
EOF
    [ "$in_change" = true ] || continue
    reported=$((reported + 1))
    warn "widget class '$name' is defined in more than one file — reuse one, or give them distinct names:"
    printf '%s\n' "$where" | sed 's/^/    /'
  done <<EOF
$dups
EOF

  [ "$reported" -eq 0 ] && pass "no duplicate widget classes in this change"
  return 0
}
check_duplicate_widgets

# ---------------------------------------------------------------- tests

section "Tests"
if [ "$SKIP_TESTS" = true ]; then
  note "test run skipped (--skip-tests)"
  printf '  skipped\n'
else
  TEST_OUT=$(mktemp) || die "mktemp failed"
  if flutter test >"$TEST_OUT" 2>&1; then
    pass "tests pass"
  else
    fail "flutter test failed"
    # Name the failures. Discarding this output was the reason the old report could
    # say "tests failed" without saying which.
    grep -E '(\[E\]|^Failed|Expected:|Actual:|.*_test\.dart)' "$TEST_OUT" \
      | head -20 | sed 's/^/    /'
    tail -3 "$TEST_OUT" | sed 's/^/    /'
  fi
  rm -f "$TEST_OUT"
fi

GOLDEN_CHANGES=""
if git rev-parse --verify -q HEAD >/dev/null 2>&1; then
  GOLDEN_CHANGES=$(git diff --name-only --diff-filter=ACM HEAD 2>/dev/null | grep 'goldens/.*\.png$')
fi
if [ -n "$GOLDEN_CHANGES" ]; then
  warn "golden images changed — confirm each was opened and visually reviewed:"
  printf '%s\n' "$GOLDEN_CHANGES" | sed 's/^/    /'
fi

# ---------------------------------------------------------------- dependencies

section "Dependencies"
NEW_DEPS=""
if git rev-parse --verify -q HEAD >/dev/null 2>&1; then
  NEW_DEPS=$(git diff -U0 HEAD -- pubspec.yaml 2>/dev/null \
    | grep -E '^\+[[:space:]]+[a-z0-9_]+:' | grep -v '^+++')
fi
if [ -n "$NEW_DEPS" ]; then
  warn "new dependencies added — each needs a note on why, and a check that the SDK or the codebase does not already cover it:"
  printf '%s\n' "$NEW_DEPS" | sed 's/^/    /'
else
  pass "no new dependencies"
fi

# ---------------------------------------------------------------- report

section "Summary"
if [ -n "$BLOCKERS" ]; then
  printf '\nBLOCKING — must fix before merge\n%s' "$BLOCKERS"
fi
if [ -n "$WARNINGS" ]; then
  printf '\nWORTH FIXING — should fix, will not break anything today\n%s' "$WARNINGS"
fi
if [ -n "$NOTES" ]; then
  printf '\nNOTES\n%s' "$NOTES"
fi
if [ -z "$BLOCKERS" ] && [ -z "$WARNINGS" ] && [ -z "$NOTES" ]; then
  printf '\nNothing blocking, nothing worth fixing.\n'
elif [ -z "$BLOCKERS" ]; then
  printf '\nNothing blocking.\n'
fi

exit $BLOCKING
