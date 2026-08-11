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
FORCE=false

usage() {
  cat <<USAGE
Usage: ./install.sh [options]

  --project <path>   Copy project-scoped skills into <path>/.claude/skills/
  --personal         Copy only the machine-scoped skills into ~/.claude/skills/
  --all-personal     Copy every skill into ~/.claude/skills/
  --force            Overwrite skills that are already installed
  -h, --help         Show this message

Without --force an already-installed skill is left alone, so local edits survive.
That also means it never updates — re-run with --force to take a new version, and
diff first if you have adapted it.

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
    --force) FORCE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

ROOT="$(cd "$(dirname "$0")" && pwd)"
DESIGN="$ROOT/plugins/flutter-design-fidelity/skills"
QUALITY="$ROOT/plugins/flutter-code-quality/skills"
COMMANDS="$ROOT/plugins/flutter-code-quality/commands"
PROFILE_SPEC="$QUALITY/architecture/references/flutter-profile.md"

# `${CLAUDE_PLUGIN_ROOT}` is set by Claude Code for an installed plugin and unset for a
# vendored copy, so a cross-skill link that works under the marketplace is a dead path
# here. Give each vendored skill its own copy of the spec and point it at that. Vendoring
# is already a copy; the alternative is a link that silently resolves to nothing, which is
# the same failure the old `$SKILL_DIR` had.
localise_profile_link() {
  local skill_dir="$1" md="$1/SKILL.md"
  [ -f "$md" ] || return 0
  grep -q 'CLAUDE_PLUGIN_ROOT.*flutter-profile\.md' "$md" || return 0
  mkdir -p "$skill_dir/references"
  cp "$PROFILE_SPEC" "$skill_dir/references/flutter-profile.md"
  sed 's|\${CLAUDE_PLUGIN_ROOT}/skills/[a-z-]*/references/flutter-profile\.md|references/flutter-profile.md|g' \
    "$md" > "$md.tmp" && mv "$md.tmp" "$md"
}

copy_skill() {
  local src="$1" dest="$2" name
  name="$(basename "$src")"
  if [ -d "$dest/$name" ]; then
    if [ "$FORCE" = true ]; then
      rm -rf "${dest:?}/${name:?}"
      cp -r "$src" "$dest/"
      localise_profile_link "$dest/$name"
      echo "  updated $name"
    else
      echo "  skip $name (already installed — re-run with --force to update)"
    fi
  else
    cp -r "$src" "$dest/"
    localise_profile_link "$dest/$name"
    echo "  added $name"
  fi
}

# The command is only useful where the architecture skill also landed, since that is where
# it reads the field list from.
copy_command() {
  local dest="$1" spec_path="$2" src="$COMMANDS/flutter-adapt.md" out="$1/flutter-adapt.md"
  mkdir -p "$dest"
  if [ -f "$out" ] && [ "$FORCE" = false ]; then
    echo "  skip flutter-adapt.md (already installed — re-run with --force to update)"
    return 0
  fi
  sed "s|\${CLAUDE_PLUGIN_ROOT}/skills/architecture/references/flutter-profile.md|$spec_path|g" \
    "$src" > "$out"
  echo "  added /flutter-adapt"
}

project_skills() {
  echo "$DESIGN/design-tokens $DESIGN/figma-to-widget $DESIGN/visual-verification $DESIGN/golden-tests $QUALITY/architecture $QUALITY/state-management $QUALITY/responsive-adaptive $QUALITY/a11y-and-rtl $QUALITY/codebase-conventions"
}

personal_skills() {
  echo "$QUALITY/performance $QUALITY/review-gate"
}

if [ "$ALL_PERSONAL" = true ]; then
  echo "Copying all skills to ~/.claude/skills/"
  mkdir -p "$HOME/.claude/skills"
  for s in $(project_skills) $(personal_skills); do copy_skill "$s" "$HOME/.claude/skills"; done
  echo "Copying the command to ~/.claude/commands/"
  copy_command "$HOME/.claude/commands" "$HOME/.claude/skills/architecture/references/flutter-profile.md"

elif [ "$PERSONAL_ONLY" = true ]; then
  echo "Copying machine-scoped skills to ~/.claude/skills/"
  mkdir -p "$HOME/.claude/skills"
  for s in $(personal_skills); do copy_skill "$s" "$HOME/.claude/skills"; done
  echo "  note: /flutter-adapt not installed — it needs the architecture skill, which"
  echo "        --personal does not copy. Use --project or --all-personal for it."

elif [ -n "$PROJECT" ]; then
  [ -f "$PROJECT/pubspec.yaml" ] || echo "Warning: no pubspec.yaml at $PROJECT — is that a Flutter project?"
  echo "Copying project skills to $PROJECT/.claude/skills/"
  mkdir -p "$PROJECT/.claude/skills"
  for s in $(project_skills); do copy_skill "$s" "$PROJECT/.claude/skills"; done
  echo "Copying the command to $PROJECT/.claude/commands/"
  copy_command "$PROJECT/.claude/commands" ".claude/skills/architecture/references/flutter-profile.md"
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
  3. Run /flutter-adapt to generate .claude/flutter-profile.yaml, so the skills describe
     your stack rather than the defaults they ship with.
NEXT
