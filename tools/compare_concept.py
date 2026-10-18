"""Compare a 'concept' capture against the concept art (art direction gate).

Usage:
  python tools/compare_concept.py previews/concept_v011.png
  (optional 2nd arg: concept path; default design/Campfire in the Eternal Library.png)

Writes <capture>_compare.png (side by side + 50% overlay) and prints mean
luminance (0-255) per region against the concept. A region "passes" when it is
within +-15% of the concept value. Regions are fractions of the frame so any
resolution works.
"""
import os
import sys

from PIL import Image, ImageStat

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REGIONS = {
    # name: (left, top, right, bottom) as fractions of the frame
    "whole frame": (0, 0, 1, 1),
    "centre arch / garden (hero)": (.40, .07, .59, .47),
    "hearth + pot": (.37, .52, .56, .78),
    "left foreground": (0, 0, .22, .50),
    "right archive": (.81, .09, 1, .50),
    "rug / right floor": (.56, .70, 1, 1),
}


def stats(img, box):
    w, h = img.size
    crop = img.crop((int(box[0] * w), int(box[1] * h), int(box[2] * w), int(box[3] * h)))
    lum = ImageStat.Stat(crop.convert("L")).mean[0]
    r, g, b = ImageStat.Stat(crop.convert("RGB")).mean
    return lum, (r - b)  # warmth: red minus blue


def main():
    capture = sys.argv[1]
    concept = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "design", "Campfire in the Eternal Library.png")
    a = Image.open(concept).convert("RGB")
    b = Image.open(capture).convert("RGB").resize(a.size)
    print("%-30s %8s %8s %8s   %s" % ("region", "concept", "capture", "ratio", "warmth c/r"))
    fails = 0
    for name, box in REGIONS.items():
        la, wa = stats(a, box)
        lb, wb = stats(b, box)
        ratio = lb / max(la, 1)
        ok = .85 <= ratio <= 1.15
        fails += not ok
        print("%-30s %8.0f %8.0f %8.2f %s %6.0f/%-6.0f" % (name, la, lb, ratio, "ok  " if ok else "MISS", wa, wb))
    side = Image.new("RGB", (a.width * 2, a.height))
    side.paste(a, (0, 0))
    side.paste(b, (a.width, 0))
    overlay = Image.blend(a, b, .5)
    out = Image.new("RGB", (a.width * 2, a.height * 2), (0, 0, 0))
    out.paste(side, (0, 0))
    out.paste(overlay.resize((a.width, a.height)), (a.width // 2, a.height))
    path = os.path.splitext(capture)[0] + "_compare.png"
    out.save(path)
    print("%d region(s) outside +-15%%. Comparison sheet: %s" % (fails, path))


if __name__ == "__main__":
    main()
