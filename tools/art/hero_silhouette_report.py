#!/usr/bin/env python3
"""Silhouette distinctness report for the four starting heroes.

Reads alpha-channel hero PNGs, normalises each silhouette (alpha > 40) into a
bottom-centred square and reports pairwise IoU plus basic stance metrics.
Lower IoU = more distinct silhouettes. Acceptance target for Hero Art V1 poses:
every pair <= MAX_PAIR_IOU (docs/HERO_POSE_BRIEF_V1.md).

Usage (repository root):
  python3 tools/art/hero_silhouette_report.py [dir_with_pngs] [--strict]
Default directory: assets/heroes. --strict exits 1 when a pair exceeds the target.
Requires Pillow only.
"""
import itertools
import sys
from pathlib import Path

from PIL import Image

HEROES = ["kezharyn", "vhorazel", "syrraveth", "tazhyrion"]
SIZE = 256
ALPHA_CUTOFF = 40
MAX_PAIR_IOU = 0.65


def silhouette(path: Path) -> Image.Image:
    alpha = Image.open(path).convert("RGBA").getchannel("A").point(lambda v: 255 if v > ALPHA_CUTOFF else 0)
    box = alpha.getbbox()
    crop = alpha.crop(box)
    scale = SIZE / max(crop.size)
    crop = crop.resize((max(1, round(crop.width * scale)), max(1, round(crop.height * scale))))
    canvas = Image.new("L", (SIZE, SIZE), 0)
    canvas.paste(crop, ((SIZE - crop.width) // 2, SIZE - crop.height))
    return canvas


def bits(mask: Image.Image) -> list:
    return [v > 0 for v in mask.tobytes()]


def iou(a: list, b: list) -> float:
    inter = sum(1 for x, y in zip(a, b) if x and y)
    union = sum(1 for x, y in zip(a, b) if x or y)
    return inter / union if union else 0.0


def metrics(mask: list) -> dict:
    rows = [sum(mask[y * SIZE:(y + 1) * SIZE]) for y in range(SIZE)]
    top = next(y for y, w in enumerate(rows) if w)
    height = SIZE - top

    def band(f0: float, f1: float) -> int:
        return max(rows[int(top + height * f0):int(top + height * f1)] or [0])

    def centre(f0: float, f1: float) -> float:
        xs = [x for y in range(int(top + height * f0), int(top + height * f1))
              for x in range(SIZE) if mask[y * SIZE + x]]
        return sum(xs) / len(xs) if xs else SIZE / 2

    return {
        "shoulders": band(0.15, 0.30),
        "hips": band(0.45, 0.60),
        "feet": band(0.88, 1.0),
        "lean": round(centre(0.0, 0.2) - centre(0.8, 1.0), 1),
        "fill": round(sum(mask) / (SIZE * SIZE), 3),
    }


def report(directory: Path) -> tuple[dict, dict]:
    masks = {h: bits(silhouette(directory / f"{h}.png")) for h in HEROES}
    pairs = {(a, b): iou(masks[a], masks[b]) for a, b in itertools.combinations(HEROES, 2)}
    return {h: metrics(m) for h, m in masks.items()}, pairs


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    directory = Path(args[0]) if args else Path("assets/heroes")
    stats, pairs = report(directory)
    print(f"Silhouettes from {directory} (normalised {SIZE}px, alpha > {ALPHA_CUTOFF})")
    for hero, values in stats.items():
        print(f"  {hero:10s} " + "  ".join(f"{k}={v}" for k, v in values.items()))
    worst = max(pairs.values())
    for (a, b), value in sorted(pairs.items(), key=lambda item: -item[1]):
        flag = "OVER TARGET" if value > MAX_PAIR_IOU else "ok"
        print(f"  IoU {a:10s} {b:10s} {value:.3f}  {flag}")
    print(f"Max pair IoU {worst:.3f} (target <= {MAX_PAIR_IOU})")
    return 1 if "--strict" in sys.argv and worst > MAX_PAIR_IOU else 0


if __name__ == "__main__":
    sys.exit(main())
