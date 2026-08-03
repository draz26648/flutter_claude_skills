#!/usr/bin/env bash
# Install the Flutter skills into a project or into the personal skills directory.

set -euo pipefail

PROJECT=""
PERSONAL_ONLY=false
ALL_PERSONAL=false

usage() {
  cat <<USAGE
Usage: ./install.sh [options]

  --project <path>   Install project-scoped skills into <path>/.claude/skills/
  --personal         Install only the machine-scoped skills into ~/.claude/skills/
  --all-personal     Install every skill into ~/.claude/skills/
  -h, --help         Show this message

With --project, the personal skills (performance, review-gate) also go to
~/.claude/skills/ so they follow you across projects.
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

SRC="$(cd "$(dirname "$0")" && pwd)/skills"
PERSONAL_SKILLS="performance review-gate"
PROJECT_SKILLS="design-tokens figma-to-widget visual-verification golden-tests architecture state-management responsive-adaptive a11y-and-rtl"

install_to() {
  local dest="$1"; shift
  mkdir -p "$dest"
  for skill in "$@"; do
    if [ -d "$dest/$skill" ]; then
      echo "  skip $skill (already exists — remove it first to reinstall)"
    else
      cp -r "$SRC/$skill" "$dest/"
      echo "  added $skill"
    fi
  done
}

if [ "$ALL_PERSONAL" = true ]; then
  echo "Installing all skills to ~/.claude/skills/"
  install_to "$HOME/.claude/skills" $PROJECT_SKILLS $PERSONAL_SKILLS

elif [ "$PERSONAL_ONLY" = true ]; then
  echo "Installing personal skills to ~/.claude/skills/"
  install_to "$HOME/.claude/skills" $PERSONAL_SKILLS

elif [ -n "$PROJECT" ]; then
  if [ ! -f "$PROJECT/pubspec.yaml" ]; then
    echo "Warning: no pubspec.yaml at $PROJECT — is that a Flutter project?"
  fi
  echo "Installing project skills to $PROJECT/.claude/skills/"
  install_to "$PROJECT/.claude/skills" $PROJECT_SKILLS
  echo "Installing personal skills to ~/.claude/skills/"
  install_to "$HOME/.claude/skills" $PERSONAL_SKILLS

else
  usage; exit 1
fi

cat <<'NEXT'

Done.

Next:
  1. Restart Claude Code once if .claude/skills did not exist before.
  2. Verify with: ls .claude/skills/*/SKILL.md
  3. Adapt the skills to your codebase — see "Adapt before you use" in the README.
     They describe one set of conventions and will fight yours until edited.
NEXT
