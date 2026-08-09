#!/usr/bin/env python3
"""Repository validator for the draz-flutter skill marketplace.

Checks the things that silently rot: skill frontmatter, name/directory agreement,
description limits, manifest consistency, and the duplicate-tree regression that this
repo already suffered once.

Usage: python3 scripts/validate.py
Exit codes: 0 clean, 1 at least one error.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Claude Code truncates past this; well before it a description stops being read closely.
DESCRIPTION_HARD_LIMIT = 1024
DESCRIPTION_SOFT_LIMIT = 800
NAME_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")

errors: list[str] = []
warnings: list[str] = []


def error(msg: str) -> None:
    errors.append(msg)


def warn(msg: str) -> None:
    warnings.append(msg)


def rel(p: Path) -> str:
    return str(p.relative_to(ROOT))


def parse_frontmatter(path: Path) -> dict[str, str] | None:
    """Minimal YAML frontmatter reader.

    Deliberately not using PyYAML so CI needs no dependencies. Handles the flat
    `key: value` shape these skills use, including values that wrap onto later lines.
    """
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        error(f"{rel(path)}: missing YAML frontmatter (must start with '---')")
        return None
    end = text.find("\n---\n", 4)
    if end == -1:
        error(f"{rel(path)}: frontmatter is not closed with '---'")
        return None

    fields: dict[str, str] = {}
    key: str | None = None
    for line in text[4:end].split("\n"):
        m = re.match(r"^([A-Za-z][A-Za-z0-9_-]*):\s?(.*)$", line)
        if m:
            key = m.group(1)
            fields[key] = m.group(2).strip()
        elif key and line.strip():
            fields[key] += " " + line.strip()
    return fields


def check_skill(skill_dir: Path) -> str | None:
    """Validate one skill directory. Returns its declared name, if any."""
    md = skill_dir / "SKILL.md"
    if not md.is_file():
        error(f"{rel(skill_dir)}: no SKILL.md")
        return None

    fields = parse_frontmatter(md)
    if fields is None:
        return None

    name = fields.get("name")
    if not name:
        error(f"{rel(md)}: frontmatter has no 'name'")
    else:
        if not NAME_RE.match(name):
            error(f"{rel(md)}: name '{name}' must be lowercase-kebab-case")
        if name != skill_dir.name:
            error(f"{rel(md)}: name '{name}' does not match directory '{skill_dir.name}'")

    desc = fields.get("description")
    if not desc:
        error(f"{rel(md)}: frontmatter has no 'description' — the skill will never trigger")
    else:
        n = len(desc)
        if n > DESCRIPTION_HARD_LIMIT:
            error(f"{rel(md)}: description is {n} chars, over the {DESCRIPTION_HARD_LIMIT} limit")
        elif n > DESCRIPTION_SOFT_LIMIT:
            warn(f"{rel(md)}: description is {n} chars, over the {DESCRIPTION_SOFT_LIMIT} soft limit")

    # Referenced scripts and references must exist, and must be addressed portably.
    body = md.read_text(encoding="utf-8")
    if "$SKILL_DIR" in body:
        error(
            f"{rel(md)}: uses $SKILL_DIR, which is not a real variable. "
            "Use ${CLAUDE_PLUGIN_ROOT} instead."
        )
    for ref in re.findall(r"(?:scripts|references)/[A-Za-z0-9_.-]+", body):
        if not (skill_dir / ref).is_file():
            error(f"{rel(md)}: references '{ref}' which does not exist")

    for script in (skill_dir / "scripts").glob("*"):
        if script.is_file() and script.suffix in {".sh", ".py"} and not script.stat().st_mode & 0o111:
            warn(f"{rel(script)}: not executable")

    return name


def main() -> int:
    # --- the regression that already happened once -------------------------------
    if (ROOT / "skills").exists():
        error(
            "a top-level skills/ directory is back. plugins/ is the only source of "
            "truth; the mirror drifted out of sync before v1.0.0 and was removed."
        )

    # --- marketplace ---------------------------------------------------------------
    marketplace_path = ROOT / ".claude-plugin" / "marketplace.json"
    if not marketplace_path.is_file():
        error("missing .claude-plugin/marketplace.json")
        return report()

    try:
        marketplace = json.loads(marketplace_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        error(f"marketplace.json is not valid JSON: {exc}")
        return report()

    declared = marketplace.get("plugins", [])
    if not declared:
        error("marketplace.json declares no plugins")

    on_disk = sorted(p.name for p in (ROOT / "plugins").iterdir() if p.is_dir())
    listed = sorted(p.get("name", "") for p in declared)
    if on_disk != listed:
        error(f"marketplace.json lists {listed} but plugins/ contains {on_disk}")

    # --- each plugin ---------------------------------------------------------------
    all_skill_names: dict[str, str] = {}

    for entry in declared:
        pname = entry.get("name", "<unnamed>")
        source = entry.get("source", "")
        plugin_dir = (ROOT / source.lstrip("./")).resolve() if source else None

        if not plugin_dir or not plugin_dir.is_dir():
            error(f"marketplace.json: plugin '{pname}' source '{source}' does not exist")
            continue

        manifest_path = plugin_dir / ".claude-plugin" / "plugin.json"
        if not manifest_path.is_file():
            error(f"{rel(plugin_dir)}: missing .claude-plugin/plugin.json")
            continue

        try:
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            error(f"{rel(manifest_path)}: not valid JSON: {exc}")
            continue

        if manifest.get("name") != pname:
            error(
                f"{rel(manifest_path)}: name '{manifest.get('name')}' does not match "
                f"marketplace entry '{pname}'"
            )
        if manifest.get("version") != entry.get("version"):
            error(
                f"plugin '{pname}': version {manifest.get('version')!r} in plugin.json "
                f"but {entry.get('version')!r} in marketplace.json"
            )
        if not manifest.get("version"):
            error(f"{rel(manifest_path)}: no version — users never receive updates without one")

        skills_dir = plugin_dir / "skills"
        if not skills_dir.is_dir():
            error(f"{rel(plugin_dir)}: no skills/ directory")
            continue

        for skill_dir in sorted(p for p in skills_dir.iterdir() if p.is_dir()):
            name = check_skill(skill_dir)
            if name:
                if name in all_skill_names:
                    error(
                        f"skill name '{name}' is declared twice: "
                        f"{all_skill_names[name]} and {rel(skill_dir)}"
                    )
                all_skill_names[name] = rel(skill_dir)

    if all_skill_names:
        print(f"Validated {len(all_skill_names)} skills across {len(declared)} plugins.")

    return report()


def report() -> int:
    for w in warnings:
        print(f"warning: {w}")
    for e in errors:
        print(f"error: {e}")
    if errors:
        print(f"\n{len(errors)} error(s), {len(warnings)} warning(s).")
        return 1
    print(f"OK — {len(warnings)} warning(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
