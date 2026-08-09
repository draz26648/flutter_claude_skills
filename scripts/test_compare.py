#!/usr/bin/env python3
"""Behavioural tests for the visual-verification comparison script.

Covers the things that made the previous version quietly unhelpful: a diff image that was
98% black, a silent rescale on size mismatch, a raw traceback on a missing file, and a
global-percentage pass on a defect a designer would spot immediately.
"""

from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

try:
    import numpy as np
    from PIL import Image, ImageDraw
except ImportError:
    sys.exit("Install dependencies first: pip install pillow numpy")

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "plugins/flutter-design-fidelity/skills/visual-verification/scripts/compare.py"

failures: list[str] = []


def check(condition: bool, what: str, detail: str = "") -> None:
    if condition:
        print(f"  ok   {what}")
    else:
        failures.append(what)
        print(f"  FAIL {what}{(' — ' + detail) if detail else ''}")


def run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), *args], capture_output=True, text=True, check=False
    )


def reference(size=(400, 800)) -> Image.Image:
    """A phone-shaped screen with a single small primary button."""
    img = Image.new("RGB", size, (250, 250, 252))
    d = ImageDraw.Draw(img)
    d.rectangle([140, 300, 260, 340], fill=(27, 110, 243))  # the button
    d.text((40, 120), "Balance", fill=(16, 24, 40))
    return img


def main() -> int:
    tmp = Path(tempfile.mkdtemp())

    ref = reference()
    ref_path = tmp / "expected.png"
    ref.save(ref_path)

    # ---------------------------------------------------------------- identical
    print("== identical images ==")
    same = tmp / "same.png"
    ref.save(same)
    r = run("--actual", str(same), "--expected", str(ref_path))
    check(r.returncode == 0, "exits 0 when identical", r.stdout + r.stderr)
    check("PASS" in r.stdout, "prints PASS")

    # ---------------------------------------------------------------- localized defect
    print("== one button using the wrong color token ==")
    wrong = reference()
    ImageDraw.Draw(wrong).rectangle([140, 300, 260, 340], fill=(217, 45, 32))
    wrong_path = tmp / "wrong_color.png"
    wrong.save(wrong_path)

    # The button is 1.5% of the screen, comfortably under the 2% global threshold — the
    # previous script called this a PASS. Locally it is a solid block of wrong color.
    r = run("--actual", str(wrong_path), "--expected", str(ref_path))
    check(r.returncode == 1, "fails a localized defect the global threshold would miss", r.stdout)
    check("Differing pixels: 1." in r.stdout, "global share really is under threshold", r.stdout)
    check("localized difference" in r.stdout, "explains that the defect is localized", r.stdout)
    check("densest at" in r.stdout, "reports where the difference is densest")
    shifted_path = wrong_path

    # ---------------------------------------------------------------- diff image is legible
    print("== diff image legibility ==")
    out = tmp / "diff.png"
    run("--actual", str(shifted_path), "--expected", str(ref_path), "--output", str(out))
    check(out.is_file(), "writes the diff image")
    arr = np.asarray(Image.open(out).convert("RGB"))
    black_share = float((arr.sum(axis=2) == 0).mean())
    red_share = float(((arr[:, :, 0] > 200) & (arr[:, :, 1] < 80) & (arr[:, :, 2] < 80)).mean())
    check(black_share < 0.5, "diff image is not mostly black", f"{black_share:.1%} black")
    check(red_share > 0.005, "differing pixels are marked in red", f"{red_share:.2%} red")

    # ---------------------------------------------------------------- size mismatch
    print("== size mismatch ==")
    small = ref.resize((150, 150))
    small_path = tmp / "small.png"
    small.save(small_path)

    r = run("--actual", str(small_path), "--expected", str(ref_path))
    check(r.returncode == 2, "size mismatch is an error, not a silent rescale", r.stdout + r.stderr)
    check("export scale" in r.stderr, "names the likely cause")

    r = run("--actual", str(small_path), "--expected", str(ref_path), "--allow-resize")
    check(r.returncode in (0, 1), "--allow-resize opts back in", r.stderr)
    check("warning" in r.stdout, "warns when it rescales")

    # ---------------------------------------------------------------- ignore regions
    print("== ignore regions ==")
    clock = reference()
    ImageDraw.Draw(clock).rectangle([0, 0, 200, 20], fill=(12, 17, 29))
    clock_path = tmp / "clock.png"
    clock.save(clock_path)

    r = run("--actual", str(clock_path), "--expected", str(ref_path))
    check(r.returncode == 1, "a changed status bar fails by default")
    r = run(
        "--actual", str(clock_path), "--expected", str(ref_path), "--ignore-region", "0,0,200,21"
    )
    check(r.returncode == 0, "--ignore-region excludes it", r.stdout)

    # ---------------------------------------------------------------- errors
    print("== error handling ==")
    r = run("--actual", str(tmp / "nope.png"), "--expected", str(ref_path))
    check(r.returncode == 2, "missing file exits 2, distinct from a real difference")
    check("Traceback" not in r.stderr, "no raw traceback", r.stderr[:200])
    check("not found" in r.stderr, "says what is missing")

    r = run("--actual", str(same), "--expected", str(ref_path), "--ignore-region", "junk")
    check(r.returncode == 2, "a malformed --ignore-region exits 2")

    print()
    if failures:
        print(f"{len(failures)} compare.py test(s) failed")
        return 1
    print("all compare.py tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
