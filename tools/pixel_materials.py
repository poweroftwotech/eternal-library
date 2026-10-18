"""Pixel-art material generator for The Eternal Library (art direction v0.11).

Rule set (see ART_DIRECTION.md):
  * 32 texels per metre on every surface (TEXEL_DENSITY). Tiles are authored in
    texels; the engine sets uv1_scale = 32 / tile_size so a texel is ~3 cm.
  * Each material uses a small hand-picked palette (6-10 colours). Values are
    quantised to that palette with light ordered dithering, so every texel reads
    as one flat colour once nearest filtering is applied.
  * Shapes (blocks, mortar, bevel light/shadow, motifs) are drawn into the
    albedo. Normal maps are derived per texel from a height field, so relief is
    chunky as well. Roughness is a simple per-texel map.

Output: assets/textures/px/<name>.png, <name>_normal.png, <name>_rough.png and
assets/textures/px/manifest.json  ({name: {"size":[w,h], "mapping":"world"|"uv"}}).
asset_factory.gd loads px/ maps in preference to the legacy maps.

Usage:  python tools/pixel_materials.py         (needs numpy + Pillow)
"""
import json
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "textures", "px")
TEXEL_DENSITY = 32
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.5
MANIFEST = {}


def hexes(*codes):
    return np.array([[int(c[i:i + 2], 16) for i in (1, 3, 5)] for c in codes], dtype=np.float32)


def noise(w, h, cell, seed, octaves=3):
    """Tileable value noise in 0..1 (bilinear between wrapped random lattice points)."""
    rng = np.random.default_rng(seed)
    total = np.zeros((h, w), np.float32)
    amp, norm = 1.0, 0.0
    for o in range(octaves):
        c = max(1, cell // (2 ** o))
        gw, gh = max(1, w // c), max(1, h // c)
        grid = rng.random((gh, gw)).astype(np.float32)
        y = np.arange(h) * gh / h
        x = np.arange(w) * gw / w
        y0 = np.floor(y).astype(int); x0 = np.floor(x).astype(int)
        fy = (y - y0)[:, None]; fx = (x - x0)[None, :]
        fy = fy * fy * (3 - 2 * fy); fx = fx * fx * (3 - 2 * fx)
        a = grid[y0 % gh][:, x0 % gw]; b = grid[y0 % gh][:, (x0 + 1) % gw]
        c_ = grid[(y0 + 1) % gh][:, x0 % gw]; d = grid[(y0 + 1) % gh][:, (x0 + 1) % gw]
        total += amp * ((a * (1 - fx) + b * fx) * (1 - fy) + (c_ * (1 - fx) + d * fx) * fy)
        norm += amp
        amp *= 0.5
    return total / norm


def quantise(value, palette, dither=0.35):
    """Map 0..1 values onto palette indices with ordered dithering."""
    h, w = value.shape
    n = len(palette)
    bayer = np.tile(BAYER, (h // 4 + 1, w // 4 + 1))[:h, :w]
    idx = np.clip(np.floor(value * n + bayer * dither), 0, n - 1).astype(int)
    return palette[idx]


def normal_from_height(height, strength=2.0):
    dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * strength
    dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * strength
    n = np.dstack([-dx, dy, np.ones_like(height)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


def save(name, rgb, height, rough, mapping="world", normal_strength=2.0):
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).save(os.path.join(OUT, name + ".png"))
    Image.fromarray(normal_from_height(height, normal_strength)).save(os.path.join(OUT, name + "_normal.png"))
    r = (np.clip(rough, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(np.dstack([r, r, r])).save(os.path.join(OUT, name + "_rough.png"))
    MANIFEST[name] = {"size": [rgb.shape[1], rgb.shape[0]], "mapping": mapping}


# ---------------------------------------------------------------- generators
def ashlar(name, palette, size=64, course=8, min_w=12, max_w=22, seed=1, mortar_index=0, chip=0.08):
    """Coursed stone blocks with baked pixel bevels (light top-left, shadow bottom-right)."""
    rng = np.random.default_rng(seed)
    w = h = size
    block_id = np.zeros((h, w), int)
    edge = np.zeros((h, w), np.float32)  # +1 lit bevel, -1 shadow bevel, -2 mortar
    bid = 0
    for row in range(h // course):
        y0 = row * course
        x = rng.integers(0, max_w)
        start = x
        while x < start + w:
            bw = int(rng.integers(min_w, max_w + 1))
            if start + w - x < min_w:  # close the row seamlessly
                bw = start + w - x
            bid += 1
            for yy in range(y0, y0 + course):
                for xx in range(x, x + bw):
                    block_id[yy % h, xx % w] = bid
            for xx in range(x, x + bw):
                edge[y0 % h, xx % w] = -2  # bed joint
                edge[(y0 + 1) % h, xx % w] = max(edge[(y0 + 1) % h, xx % w], 1)
                edge[(y0 + course - 1) % h, xx % w] = -1
            for yy in range(y0, y0 + course):
                edge[yy % h, x % w] = -2  # head joint
                if edge[yy % h, (x + 1) % w] > -2:
                    edge[yy % h, (x + 1) % w] = 1
                if edge[yy % h, (x + bw - 1) % w] > -2:
                    edge[yy % h, (x + bw - 1) % w] = -1
            x += bw
    tone = np.random.default_rng(seed + 7).random(bid + 1)[block_id] * 0.30 - 0.15
    grain = noise(w, h, 8, seed + 3) * 0.55 + noise(w, h, 2, seed + 4, 1) * 0.45
    value = 0.25 + grain * 0.6 + tone
    value = np.where(edge == 1, value + 0.22, value)
    value = np.where(edge == -1, value - 0.20, value)
    chips = noise(w, h, 3, seed + 9, 1) > 1 - chip
    value = np.where(chips, value - 0.25, value)
    n = len(palette)
    lo = (mortar_index + 1) / n
    value = lo + np.clip(value, 0, 1) * (1 - lo)
    rgb = quantise(np.clip(value, 0, 0.999), palette)
    rgb[edge == -2] = palette[mortar_index]
    height = np.where(edge == -2, 0.0, 0.75 + grain * 0.25 - chips * 0.3)
    height = np.where(edge == 1, height + 0.05, height)
    rough = 0.82 + grain * 0.15
    save(name, rgb, height, rough)


def flagstones(name, palette, size=64, seed=2, rows=(14, 22), cols=(16, 28)):
    rng = np.random.default_rng(seed)
    w = h = size
    value = np.zeros((h, w), np.float32)
    joint = np.zeros((h, w), bool)
    lit = np.zeros((h, w), bool)
    shade = np.zeros((h, w), bool)
    y = 0
    heights = []
    while y < h:
        rh = int(rng.integers(*rows))
        if h - y - rh < rows[0]:
            rh = h - y
        heights.append((y, rh))
        y += rh
    for (y0, rh) in heights:
        offset = int(rng.integers(0, w))
        x = 0
        while x < w:
            cw = int(rng.integers(*cols))
            if w - x - cw < cols[0]:
                cw = w - x
            t = rng.random() * 0.35 - 0.17
            for yy in range(y0, y0 + rh):
                for xx in range(x, x + cw):
                    X = (xx + offset) % w
                    value[yy, X] = t
                    if yy == y0 or xx == x:
                        joint[yy, X] = True
                    elif yy == y0 + 1 or xx == x + 1:
                        lit[yy, X] = True
                    elif yy == y0 + rh - 1 or xx == x + cw - 1:
                        shade[yy, X] = True
            x += cw
    grain = noise(w, h, 10, seed + 1) * 0.6 + noise(w, h, 2, seed + 2, 1) * 0.4
    v = 0.30 + grain * 0.55 + value
    v[lit] += 0.15
    v[shade] -= 0.18
    rgb = quantise(np.clip(v, 0.15, 0.999), palette)
    rgb[joint] = palette[0]
    height = np.where(joint, 0.0, 0.8 + grain * 0.2)
    save(name, rgb, height, 0.78 + grain * 0.18)


def mottled(name, palette, size=32, cell=6, seed=3, contrast=1.0, specks=0.0, rough=0.88, mapping="world", strength=2.0):
    w = h = size
    grain = noise(w, h, cell, seed) * 0.65 + noise(w, h, 2, seed + 1, 1) * 0.35
    v = 0.5 + (grain - 0.5) * 1.6 * contrast
    if specks:
        s = noise(w, h, 1, seed + 5, 1) > 1 - specks
        v = np.where(s, v + 0.35, v)
    rgb = quantise(np.clip(v, 0, 0.999), palette)
    save(name, rgb, grain, rough + (grain - 0.5) * 0.1, mapping, strength)


def mosaic(name, size=32, seed=4):
    """Turquoise / lapis faience with ochre lozenge chains, one tessera per texel."""
    pal = hexes("#0d2a2c", "#14514f", "#1f7470", "#2f9690", "#c08a3c", "#e2b866", "#efe0b8", "#1d3d6b")
    w = h = size
    yy, xx = np.mgrid[0:h, 0:w]
    rng = np.random.default_rng(seed)
    field = np.where((xx + yy) % 2 == 0, 2, 1)
    field = np.where(rng.random((h, w)) < 0.12, 3, field)
    cx = (xx % 16) - 7.5
    cy = (yy % 16) - 7.5
    d = np.abs(cx) + np.abs(cy)
    img = field.copy()
    img = np.where((d > 6) & (d <= 7.5), 4, img)          # ochre lozenge outline
    img = np.where((d > 4) & (d <= 5), 5, img)            # inner gold ring
    img = np.where(d <= 2, 6, img)                        # cream heart
    img = np.where((d > 2) & (d <= 3), 7, img)            # lapis core ring
    img = np.where((xx % 16 == 0) | (yy % 16 == 0), 0, img)  # dark grout lines between panels
    rgb = pal[img]
    rgb = rgb * (0.92 + rng.random((h, w, 1)) * 0.16)     # glaze variation per tessera
    height = np.where(img == 0, 0.2, 0.8 + rng.random((h, w)) * 0.15)
    rough = np.where(img == 0, 0.95, 0.35 + rng.random((h, w)) * 0.15)
    save(name, rgb, height, rough)


def iron(name, base, seed=5):
    w = h = 32
    grain = noise(w, h, 5, seed) * 0.7 + noise(w, h, 2, seed + 1, 1) * 0.3
    v = np.clip(0.15 + grain * 0.75, 0, 0.999)
    rgb = quantise(v, base, 0.5)
    rust = noise(w, h, 4, seed + 2, 2) > 0.72
    rgb[rust] = rgb[rust] * 0.6 + np.array([120, 62, 28]) * 0.4
    save(name, rgb, grain, 0.55 + grain * 0.35)


def wood(name, palette, seed=6, w=32, h=64, mapping="world"):
    rng = np.random.default_rng(seed)
    xx = np.arange(w)[None, :]
    plank = (xx // 8)
    tone = rng.random(w // 8 + 1)[plank] * 0.3 - 0.15
    streak = noise(w, h, 2, seed, 1)
    streak = np.repeat(streak[:1, :], h, 0) * 0.5 + noise(w, h, 16, seed + 2) * 0.5
    v = 0.25 + streak * 0.6 + tone
    v = np.where(xx % 8 == 0, 0.02, v)
    v = np.where(xx % 8 == 1, v + 0.12, v)
    rgb = quantise(np.clip(np.broadcast_to(v, (h, w)), 0, 0.999), palette)
    height = np.where(np.broadcast_to(xx % 8 == 0, (h, w)), 0.0, 0.7 + streak * 0.3)
    save(name, rgb, height, 0.8 + streak * 0.15, mapping)


def bark(name, seed=7):
    pal = hexes("#1c140e", "#2e2118", "#3f2e20", "#54402c", "#6b5238", "#83694a")
    w, h = 32, 64
    fiss = noise(w, h, 3, seed, 1)
    fiss = (fiss[:, :] + np.roll(fiss, 1, 0) + np.roll(fiss, 2, 0)) / 3
    long = noise(w, h * 4, 6, seed + 1)[::4, :]
    v = 0.2 + long * 0.5 + fiss * 0.4
    v = np.where(fiss < 0.3, 0.05, v)
    rgb = quantise(np.clip(v, 0, 0.999), pal)
    save(name, rgb, v, 0.92)


def pottery(name, body, motif, size=(96, 48), seed=8, glazed=False):
    """UV-mapped (lathe) pottery: band of stepped lozenges round the belly."""
    w, h = size
    rng = np.random.default_rng(seed)
    grain = noise(w, h, 6, seed)
    v = 0.3 + grain * 0.5
    rgb = quantise(np.clip(v, 0, 0.999), body)
    yy, xx = np.mgrid[0:h, 0:w]
    band_lo, band_hi = int(h * 0.38), int(h * 0.62)
    band = (yy >= band_lo) & (yy < band_hi)
    rows = band_hi - band_lo
    cx = (xx % 12) - 5.5
    cy = (yy - band_lo) - rows / 2 + 0.5
    d = np.abs(cx) + np.abs(cy) * 1.2
    rgb[band] = motif[0]
    rgb[band & (d < 6)] = motif[1]
    rgb[band & (d < 4)] = motif[2]
    rgb[band & (d < 2)] = motif[3]
    for edge in (band_lo - 2, band_hi + 1):
        rgb[edge % h, :] = motif[0]
    for edge in (band_lo - 4, band_hi + 3):
        rgb[edge % h, ::2] = motif[3]
    rough = np.full((h, w), 0.35 if glazed else 0.85) + grain * 0.1
    save(name, rgb, grain * 0.5, rough, "uv", 1.0)


def kilim(name, w=140, h=102, seed=9):
    """Woven rug, one weft knot per texel."""
    pal = hexes("#1a0f0b", "#5a1d14", "#7c2a1c", "#9c3a22", "#c8913f", "#e3cf9c", "#2a6a6a", "#203a5a")
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w]
    img = np.where(rng.random((h, w)) < 0.5, 2, 1 + (rng.random((h, w)) < 0.15) * 2)
    bx = np.minimum(xx, w - 1 - xx)
    by = np.minimum(yy, h - 1 - yy)
    b = np.minimum(bx, by)
    img = np.where(b < 2, 0, img)
    img = np.where((b >= 3) & (b < 5), 4, img)
    img = np.where((b >= 5) & (b < 10), 7, img)
    stripe = (b >= 5) & (b < 10) & (((xx + yy) // 3) % 2 == 0)
    img = np.where(stripe, 5, img)
    img = np.where(b == 10, 0, img)
    inner = b > 11
    cx = ((xx - 12) % 20) - 9.5
    cy = ((yy - 12) % 20) - 9.5
    d = np.abs(cx) + np.abs(cy)
    img = np.where(inner & (d >= 8) & (d < 9.5), 4, img)
    img = np.where(inner & (d >= 5) & (d < 6.5), 6, img)
    img = np.where(inner & (d >= 2.5) & (d < 3.5), 5, img)
    img = np.where(inner & (d < 1.5), 0, img)
    hook = inner & (np.abs(cx) < 0.6) & (np.abs(cy) > 9) | inner & (np.abs(cy) < 0.6) & (np.abs(cx) > 9)
    img = np.where(hook, 0, img)
    rgb = pal[img] * (0.9 + (xx % 2)[..., None] * 0.08 + rng.random((h, w, 1)) * 0.06)
    height = 0.6 + (xx % 2) * 0.2 + rng.random((h, w)) * 0.2
    save(name, rgb, height, np.full((h, w), 0.97), "uv", 1.0)


def main():
    sand = hexes("#3a2a1d", "#6b5038", "#8a6a4b", "#a0805c", "#b39570", "#c4a983", "#d4bd98", "#7a7266")
    lime = hexes("#5d5244", "#7c705f", "#968a76", "#ab9f88", "#bdb29b", "#cfc5ae", "#ddd5c0")
    ashlar("sandstone", sand, seed=11, course=10, min_w=14, max_w=24)
    ashlar("brick", sand, seed=12, course=9, min_w=13, max_w=21)
    ashlar("arch_stone", lime, seed=13, course=8, min_w=10, max_w=16)
    ashlar("stone_surface", lime, seed=14, course=12, min_w=16, max_w=26)
    mottled("limestone", lime, cell=5, seed=15, contrast=1.1, specks=0.04)
    hearth = hexes("#1a140f", "#2e241b", "#463628", "#5e4a37", "#776049", "#8f775c")
    mottled("hearth_stone", hearth, cell=4, seed=16, contrast=1.2, specks=0.03)
    floor = hexes("#2a221b", "#4a3d31", "#5f4f40", "#72604e", "#86735e", "#9a8670", "#ad9a82")
    flagstones("floor_stone", floor, seed=17)
    flagstones("paving", floor, seed=18)
    flagstones("floor_grout", floor, seed=19)
    plaster = hexes("#8a7a62", "#9d8d73", "#ae9e83", "#bdae93", "#cbbda3", "#d8cbb2")
    mottled("plaster", plaster, size=64, cell=12, seed=20, contrast=0.7)
    mottled("vault_plaster", plaster, size=64, cell=12, seed=21, contrast=0.7)
    mosaic("mosaic")
    mosaic("tile", seed=22)
    iron("iron_cook", hexes("#0f0d0c", "#1a1715", "#24201c", "#2f2a24", "#3c352d", "#4c4338", "#5e5345"))
    iron("iron", hexes("#202224", "#2d3033", "#3b3f42", "#4a4f52", "#5c6164", "#6e7376"), seed=23)
    wood("wood", hexes("#24170e", "#3b2716", "#53371f", "#6a4828", "#805a33", "#966d40"))
    bark("bark")
    soil = hexes("#17110c", "#241a12", "#32251a", "#413122", "#52402d")
    mottled("soil", soil, cell=4, seed=24, specks=0.05)
    moss = hexes("#1b2410", "#2a3816", "#3a4b1c", "#4d5f25", "#627330", "#7a8a3c")
    mottled("moss", moss, cell=3, seed=25, contrast=1.2)
    cave = hexes("#14181a", "#1f2528", "#2a3236", "#374045", "#465055", "#566166")
    mottled("cave", cave, size=64, cell=10, seed=26, contrast=1.2)
    pottery("earthenware", hexes("#5a2a16", "#7a3a1e", "#9a4e28", "#b06234", "#c27a44"),
            hexes("#2a1a12", "#e2cfa0", "#1f6a68", "#c8913f"))
    pottery("glazed_ceramic", hexes("#123c3e", "#1a5556", "#226c6b", "#2e8380", "#3f9993"),
            hexes("#0e1f24", "#d9b56a", "#efe0b8", "#1d3d6b"), size=(64, 32), seed=27, glazed=True)
    kilim("rug")
    with open(os.path.join(OUT, "manifest.json"), "w") as f:
        json.dump({"texel_density": TEXEL_DENSITY, "materials": MANIFEST}, f, indent=1)
    print("wrote %d pixel materials to %s" % (len(MANIFEST), OUT))


if __name__ == "__main__":
    main()
