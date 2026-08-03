#!/usr/bin/env python3
"""Compare a captured screenshot against a reference design export.

Emits a diff image highlighting differing regions and exits non-zero when the
difference exceeds the threshold, so it can be used in CI.

Requires: pillow, numpy
"""

import argparse
import sys

try:
    import numpy as np
    from PIL import Image, ImageChops
except ImportError:
    sys.exit("Install dependencies first: pip install pillow numpy")


def load_aligned(actual_path, expected_path):
    actual = Image.open(actual_path).convert("RGB")
    expected = Image.open(expected_path).convert("RGB")

    if actual.size != expected.size:
        print(
            f"Size mismatch: captured {actual.size}, reference {expected.size}. "
            "Resizing the reference to compare, but this usually means the export "
            "scale does not match the capture device pixel ratio — fix that first."
        )
        expected = expected.resize(actual.size, Image.LANCZOS)

    return actual, expected


def compare(actual, expected, tolerance):
    a = np.asarray(actual, dtype=np.int16)
    e = np.asarray(expected, dtype=np.int16)

    per_pixel = np.abs(a - e).max(axis=2)
    differing = per_pixel > tolerance
    ratio = float(differing.sum()) / differing.size

    return ratio, differing


def region_summary(differing):
    """Report where the differences cluster, as thirds of the image."""
    h, w = differing.shape
    rows = ["top", "middle", "bottom"]
    cols = ["left", "center", "right"]
    out = []

    for ri, rname in enumerate(rows):
        for ci, cname in enumerate(cols):
            block = differing[
                ri * h // 3 : (ri + 1) * h // 3,
                ci * w // 3 : (ci + 1) * w // 3,
            ]
            share = float(block.sum()) / block.size
            if share > 0.01:
                out.append(f"  {rname}-{cname}: {share:.1%} of region differs")

    return out


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--actual", required=True, help="Captured screenshot")
    p.add_argument("--expected", required=True, help="Reference design export")
    p.add_argument("--output", help="Where to write the diff image")
    p.add_argument(
        "--threshold",
        type=float,
        default=0.02,
        help="Maximum acceptable share of differing pixels (default 0.02)",
    )
    p.add_argument(
        "--tolerance",
        type=int,
        default=12,
        help="Per-channel value difference tolerated before a pixel counts as differing",
    )
    args = p.parse_args()

    actual, expected = load_aligned(args.actual, args.expected)
    ratio, differing = compare(actual, expected, args.tolerance)

    print(f"Differing pixels: {ratio:.2%} (threshold {args.threshold:.2%})")

    if args.output:
        diff = ImageChops.difference(actual, expected)
        diff.save(args.output)
        print(f"Diff image: {args.output}")

    if ratio > args.threshold:
        print("\nFAIL — difference above threshold. Clustered in:")
        for line in region_summary(differing) or ["  (evenly distributed)"]:
            print(line)
        print(
            "\nEvenly distributed differences usually mean a wrong color token, a "
            "missing font, or a scale mismatch — not a layout error."
        )
        return 1

    print("PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
