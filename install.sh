#!/usr/bin/env bash
# Vendor the skills directly into a project or into the personal skills directory,
# as an alternative to installing through the plugin marketplace.
#
# Marketplace install (recommended):
#   claude plugin marketplace add draz26648/flutter_claude_skills
#   claude plugin install flutter-design-fidelity@draz-flutter
#   claude plugin install flutter-code-quality@draz-flutter

set -euo pipefail

PROJECT=""
PERSONAL_ONLY=false
ALL_PERSONAL=false

usage() {
  cat <<USAGE
Usage: ./install.sh [options]

  --project <path>   Copy project-scoped skills into <path>/.claude/skills/
  --personal         Copy only the machine-scoped skills into ~/.claude/skills/
  --all-personal     Copy every skill into ~/.claude/skills/
  -h, --help         Show this message

With --project, the machine-scoped skills (performance, review-gate) also go to
~/.claude/skills/ so they follow you across projects.

Vendoring is the right choice when you want the skills committed to the repo and
reviewable in pull requests alongside the code they govern. Otherwise prefer the
marketplace, which gives you updates.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2 ;;
    --personal) PERSONAL_ONLY=true; shift ;;
    --all-personal) ALL_PERSONAL=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

ROOT="$(cd "$(dirname "$0")" && pwd)"
DESIGN="$ROOT/plugins/flutter-design-fidelity/skills"
QUALITY="$ROOT/plugins/flutter-code-quality/skills"

copy_skill() {
  local src="$1" dest="$2" name
  name="$(basename "$src")"
  if [ -d "$dest/$name" ]; then
    echo "  skip $name (already exists — remove it first to reinstall)"
  else
    cp -r "$src" "$dest/"
    echo "  added $name"
  fi
}

project_skills() {
  echo "$DESIGN/design-tokens $DESIGN/figma-to-widget $DESIGN/visual-verification $DESIGN/golden-tests $QUALITY/architecture $QUALITY/state-management $QUALITY/responsive-adaptive $QUALITY/a11y-and-rtl"
}

personal_skills() {
  echo "$QUALITY/performance $QUALITY/review-gate"
}

if [ "$ALL_PERSONAL" = true ]; then
  echo "Copying all skills to ~/.claude/skills/"
  mkdir -p "$HOME/.claude/skills"
  for s in $(project_skills) $(personal_skills); do copy_skill "$s" "$HOME/.claude/skills"; done

elif [ "$PERSONAL_ONLY" = true ]; then
  echo "Copying machine-scoped skills to ~/.claude/skills/"
  mkdir -p "$HOME/.claude/skills"
  for s in $(personal_skills); do copy_skill "$s" "$HOME/.claude/skills"; done

elif [ -n "$PROJECT" ]; then
  [ -f "$PROJECT/pubspec.yaml" ] || echo "Warning: no pubspec.yaml at $PROJECT — is that a Flutter project?"
  echo "Copying project skills to $PROJECT/.claude/skills/"
  mkdir -p "$PROJECT/.claude/skills"
  for s in $(project_skills); do copy_skill "$s" "$PROJECT/.claude/skills"; done
  echo "Copying machine-scoped skills to ~/.claude/skills/"
  mkdir -p "$HOME/.claude/skills"
  for s in $(personal_skills); do copy_skill "$s" "$HOME/.claude/skills"; done

else
  usage; exit 1
fi

cat <<'NEXT'

Done.

Next:
  1. Restart Claude Code once if .claude/skills did not exist before.
  2. Verify with: ls .claude/skills/*/SKILL.md
  3. Adapt the skills to your codebase — see "Adapt before you rely on them" in the
     README. They describe one set of conventions and will fight yours until edited.
NEXT
