"""Residents' bodies (phase 21 step 1): a man and a woman with a skeleton,
dressed from the costume atlas (design/costume-atlas.html).

Builds art_src/creatures/<kind>.blend and exports actors/models/<kind>.glb,
for kind in man, woman. Run headless:

  blender --background --factory-startup --python tools/resident_body.py

Conventions (as the cat, tools/creature_cat.py): Blender Z up, metres; the
person faces Blender +Y (Godot -Z, a node's forward); their left is -X.

One skeleton, many PIECES: each garment, hair style and thing worn is its own
mesh on the same armature (objects <kind>_<piece>), and the game shows the
ones a person wears (ResidentBody.OUTFITS). `base` is always shown.

The texture is a mask, not colours. B says what a texel is, in tenths (the
codes below). R darkens it (folds, lines; in an eye, the iris). G is trim on
cloth and beard on skin. The game's shader (shaders/resident.gdshader)
colours it per person. Cloth is painted at TEXELS per metre, the head at
twice that, nearest filtering.

Animations (each an action; "-loop" ones loop in Godot): idle, walk,
sit_bench, sit_floor (cross-legged), sit_knees (kneeling), sleep.
"""
import math
import os

import bmesh
import bpy
from mathutils import Quaternion, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art_src", "creatures")
OUT = os.path.join(ROOT, "actors", "models")
TEXELS = 64.0            # texels per metre (cloth)
TEX = 512                # mask size (square)
SIDES = 8                # ring sides
FPS = 24

# What a texel is (B * 10).
A, B, C, SKIN, HAIR, EYE, GLOW, METAL, D, FLAME, PALE = range(11)
# A the main garment, B the under garment and leather, C the sash and head
# cloth, D what is worn over (cloak, cape, shawl); GLOW glow thread; METAL
# brass; FLAME a lantern; PALE undyed white cloth (mouth cloth, veil).

KINDS = {
    "man": {"k": 1.0, "sh": 0.2, "hipx": 0.09, "neck": 0.052, "head": 1.0, "wide": 1.06,
            "arm": [0.062, 0.055, 0.05], "leg": [0.082, 0.062, 0.05],
            # torso rings above the hips, shared by his garments: (z, half-width, half-depth)
            "torso": [(0.93, 0.178, 0.13), (1.06, 0.158, 0.118), (1.27, 0.185, 0.128), (1.375, 0.186, 0.114), (1.43, 0.12, 0.092), (1.458, 0.078, 0.072)],
            "belt": (1.01, 1.085)},
    "woman": {"k": 0.945, "sh": 0.172, "hipx": 0.085, "neck": 0.044, "head": 0.97, "wide": 1.02,
              "arm": [0.053, 0.047, 0.044], "leg": [0.075, 0.056, 0.045],
              "torso": [(0.93, 0.185, 0.14), (1.07, 0.138, 0.108), (1.26, 0.168, 0.13), (1.375, 0.16, 0.104), (1.43, 0.105, 0.085), (1.458, 0.07, 0.066)],
              "belt": (1.03, 1.095)},
}


def bones_of(K):
    """name, head, tail, parent."""
    k, sh, hx = K["k"], K["sh"], K["hipx"]
    out = [
        ("root", (0, -0.03, 0.0), (0, 0.08, 0.0), None),
        ("hips", (0, 0, 0.95 * k), (0, 0, 1.08 * k), "root"),
        ("spine", (0, 0, 1.08 * k), (0, 0, 1.25 * k), "hips"),
        ("chest", (0, 0, 1.25 * k), (0, 0, 1.45 * k), "spine"),
        ("neck", (0, 0, 1.45 * k), (0, 0.012, 1.535 * k), "chest"),
        ("head", (0, 0.012, 1.535 * k), (0, 0.012, 1.72 * k), "neck"),
    ]
    for side, s in (("l", -1.0), ("r", 1.0)):
        a = [(s * sh, 0, 1.405 * k), (s * (sh + 0.04), -0.012, 1.13 * k), (s * (sh + 0.05), 0.03, 0.885 * k), (s * (sh + 0.048), 0.05, 0.79 * k)]
        out += [("upper_arm_" + side, a[0], a[1], "chest"), ("forearm_" + side, a[1], a[2], "upper_arm_" + side),
                ("hand_" + side, a[2], a[3], "forearm_" + side)]
        g = [(s * hx, 0, 0.93 * k), (s * hx, 0.012, 0.5 * k), (s * hx, -0.012, 0.085 * k), (s * hx * 1.12, 0.135, 0.02)]
        out += [("thigh_" + side, g[0], g[1], "hips"), ("shin_" + side, g[1], g[2], "thigh_" + side),
                ("foot_" + side, g[2], g[3], "shin_" + side)]
    return out


class Mask:
    """The mask image, filled part by part; regions packed in rows."""

    def __init__(self):
        self.px = [[(0.0, 0.0, 0.0)] * TEX for _ in range(TEX)]
        self.x = 0
        self.y = 0
        self.row = 0

    def region(self, w, h):
        w = max(2, min(TEX, w))
        h = max(2, h)
        if self.x + w > TEX:
            self.x = 0
            self.y += self.row
            self.row = 0
        r = (self.x, self.y, w, h)
        self.x += w
        self.row = max(self.row, h)
        assert self.y + h <= TEX, "mask full"
        return r

    def paint(self, r, fn):
        x0, y0, w, h = r
        for y in range(h):
            for x in range(w):
                c = fn((x + 0.5) / w, y, w, h)
                self.px[y0 + y][x0 + x] = (c[0], c[1], c[2] / 10.0)


def col(s, w):
    """Texels from the front ridge, signed: + toward the person's left."""
    return (s if s < 0.5 else s - 1.0) * w


def roundel(x, y, step=14.0):
    """Pearl roundels on a staggered grid of texels: 'ring', 'pearl', 'dot' or None."""
    n = int(step)
    gy = int(y) // n
    yy = int(y) - gy * n - n // 2
    xx = (int(x) + (n // 2 if gy % 2 else 0)) % n - n // 2
    if (abs(xx), abs(yy)) in ((5, 0), (0, 5), (4, 4)):
        return "pearl"                           # eight single pearls round the ring
    d = math.hypot(xx, yy)
    if 3.5 <= d < 4.5:
        return "ring"
    return "dot" if d < 1.2 else None


class Sculpt:
    """Builds the pieces: begin(name), then tubes and flats into it."""

    def __init__(self, mask):
        self.mask = mask
        self.pieces = {}

    def begin(self, name):
        self.bm = bmesh.new()
        self.uvl = self.bm.loops.layers.uv.new("UVMap")
        self.part = self.bm.verts.layers.int.new("part")
        self.soft = self.bm.faces.layers.int.new("soft")     # 1: shaded smooth (skin); cloth is faceted
        self.parts = []
        self.pieces[name] = (self.bm, self.parts)

    def tube(self, path, radii, allowed, fn, fwd=Vector((0, 1, 0)), cap0=True, cap1=True, dens=1.0, sq=1.0, bulge=0.35,
             smooth=False, skip=(), off=None):
        """Rings of SIDES points round `path`. radii: (half-width, half-depth)
        per ring, depth along `fwd`; column 0 of its texels is the ridge that
        faces `fwd`. sq pushes the diagonal points out (a boxier ring). skip:
        columns left open (0 and 7 are either side of the front ridge).
        off(i, j): moves ring i's point j."""
        bm, uvl, mask = self.bm, self.uvl, self.mask
        pid = len(self.parts)
        self.parts.append(allowed)
        path = [Vector(p) for p in path]
        n = len(path)
        rows = [0.0]
        for i in range(1, n):
            rows.append(rows[-1] + (path[i] - path[i - 1]).length * TEXELS * dens)
        girth = max(math.tau * math.sqrt((rw * rw + rd * rd) / 2.0) for rw, rd in radii)
        r = mask.region(int(round(girth * TEXELS * dens)), int(round(rows[-1])) + 1)
        mask.paint(r, fn)
        rings = []
        for i, p in enumerate(path):
            t = (path[min(i + 1, n - 1)] - path[max(i - 1, 0)]).normalized()
            u = fwd - t * fwd.dot(t)
            u.normalize()
            side = t.cross(u).normalized()
            ring = []
            for j in range(SIDES):
                a = math.tau * j / SIDES
                d = sq if j % 2 else 1.0
                co = p + u * math.cos(a) * radii[i][1] * d + side * math.sin(a) * radii[i][0] * d
                if off is not None:
                    co = co + off(i, j)
                v = bm.verts.new(co)
                v[self.part] = pid
                ring.append(v)
            rings.append(ring)

        def uv(j, i):
            # Kept a little inside the region: a texel on its edge would read its neighbour's.
            return ((r[0] + 0.05 + (r[2] - 0.1) * j / SIDES) / TEX, 1.0 - (r[1] + max(0.5, min(rows[i], r[3] - 0.5))) / TEX)

        for i in range(n - 1):
            for j in range(SIDES):
                if j in skip:
                    continue
                j1 = (j + 1) % SIDES
                f = bm.faces.new([rings[i][j], rings[i][j1], rings[i + 1][j1], rings[i + 1][j]])
                f[self.soft] = 1 if smooth else 0
                for lp, (jj, ii) in zip(f.loops, ((j, i), (j + 1, i), (j + 1, i + 1), (j, i + 1))):
                    lp[uvl].uv = uv(jj, ii)
        for end, cap in ((0, cap0), (n - 1, cap1)):
            if not cap:
                continue
            out = (path[end] - path[1 if end == 0 else n - 2]).normalized()
            bl = bulge[0 if end == 0 else 1] if isinstance(bulge, tuple) else bulge
            c = bm.verts.new(path[end] + out * max(radii[end]) * bl)
            c[self.part] = pid
            for j in range(SIDES):
                j1 = (j + 1) % SIDES
                vs = [rings[end][j], rings[end][j1], c] if end == n - 1 else [rings[end][j1], rings[end][j], c]
                f = bm.faces.new(vs)
                f[self.soft] = 1 if smooth else 0
                for lp, jj in zip(f.loops, (j, j + 1, j + 0.5) if end == n - 1 else (j + 1, j, j + 0.5)):
                    lp[uvl].uv = uv(jj, end)
        return pid

    def flat(self, points, code, allowed, out_from):
        """A flat piece of one mask value, facing away from `out_from`."""
        fr = self.mask.region(2, 2)
        self.mask.paint(fr, lambda s, t, w, h: code)
        pid = len(self.parts)
        self.parts.append(allowed)
        vs = []
        for p in points:
            v = self.bm.verts.new(Vector(p))
            v[self.part] = pid
            vs.append(v)
        f = self.bm.faces.new(vs)
        f.normal_update()
        if f.normal.dot(f.calc_center_median() - Vector(out_from)) < 0:
            f.normal_flip()
        for lp in f.loops:
            lp[self.uvl].uv = ((fr[0] + 1.0) / TEX, 1.0 - (fr[1] + 1.0) / TEX)


SKIRT = ["hips", "spine", "chest", "thigh_l", "thigh_r", "shin_l", "shin_r"]


def build_pieces(kind, K, mask):
    k = K["k"]
    S = Sculpt(mask)
    bones = {b[0]: b for b in bones_of(K)}
    woman = kind == "woman"
    hk = K["head"]
    HY = 0.02                                               # the head sits a little forward of the spine
    chin_z = 1.492 * k
    # (height over the chin, half-width, half-depth, forward)
    if woman:
        HEAD = [(0.0, 0.034, 0.042, 0.022), (0.035, 0.06, 0.077, 0.008), (0.095, 0.075, 0.093, 0.0), (0.16, 0.078, 0.097, -0.002),
                (0.215, 0.064, 0.082, -0.006)]
    else:
        HEAD = [(0.0, 0.038, 0.046, 0.03), (0.035, 0.066, 0.08, 0.008), (0.095, 0.076, 0.094, 0.0), (0.16, 0.078, 0.097, -0.002),
                (0.215, 0.064, 0.082, -0.006)]
    HEAD = [(dz * hk, w * hk * K["wide"], d * hk, y * hk) for dz, w, d, y in HEAD]
    head_h = HEAD[-1][0]
    head_mid = (0, HY, chin_z + head_h * 0.5)

    def hz(f):
        return chin_z + head_h * f

    def head_at(f, grow=0.0):
        """The head's (half-width, half-depth, forward) at this share of its height."""
        dz = head_h * f
        for i in range(len(HEAD) - 1):
            a, b = HEAD[i], HEAD[i + 1]
            if a[0] <= dz <= b[0]:
                t = (dz - a[0]) / (b[0] - a[0])
                return (a[1] + t * (b[1] - a[1]) + grow, a[2] + t * (b[2] - a[2]) + grow, HY + a[3] + t * (b[3] - a[3]))
        return (HEAD[-1][1] + grow, HEAD[-1][2] + grow, HY + HEAD[-1][3])

    def front_y(f):
        w, d, y = head_at(f)
        return y + d

    # ======================= base: what everyone has ==========================
    S.begin("base")
    for side, sx in (("l", -1.0), ("r", 1.0)):
        sn, ft = bones["shin_" + side], bones["foot_" + side]
        ankle, toe = Vector(sn[2]), Vector(ft[2])
        heel = Vector((ankle.x, ankle.y - 0.055, 0.045))
        S.tube([heel, Vector((ankle.x, ankle.y + 0.03, 0.05)), Vector((toe.x, toe.y - 0.02, 0.04)), Vector((toe.x, toe.y + 0.04, 0.03))],
               [(0.036, 0.04), (0.043, 0.05), (0.045, 0.038), (0.028, 0.02)], ["shin_" + side, "foot_" + side],
               lambda s, t, w, h: (0.55, 0.0, B), fwd=Vector((0, 0, 1)))
        fa, hn = bones["forearm_" + side], bones["hand_" + side]
        wrist, tip = Vector(fa[2]), Vector(hn[2])
        S.tube([wrist.lerp(Vector(fa[1]), 0.1), wrist.lerp(tip, 0.4), wrist.lerp(tip, 0.95), wrist.lerp(tip, 1.45)],
               [(0.019, 0.028), (0.021, 0.039), (0.019, 0.035), (0.012, 0.02)], ["forearm_" + side, "hand_" + side],
               lambda s, t, w, h: (0.0, 0.0, SKIN), cap0=False, smooth=True)
        palm = wrist.lerp(tip, 0.35)
        S.tube([palm + Vector((0, 0.03, 0)), palm + Vector((0, 0.058, -0.03)), palm + Vector((0, 0.064, -0.055))],
               [(0.011, 0.012), (0.01, 0.01), (0.007, 0.007)], ["hand_" + side], lambda s, t, w, h: (0.08, 0.0, SKIN), cap0=False, smooth=True)
    nk = K["neck"]
    S.tube([(0, 0.0, 1.4 * k), (0, 0.006, 1.47 * k), (0, 0.016, 1.55 * k)], [(nk * 1.15, nk * 1.1), (nk, nk), (nk, nk * 1.05)],
           ["chest", "neck", "head"], lambda s, t, w, h: (0.25 if t >= h - 3 else 0.0, 0.0, SKIN), cap0=False, cap1=False, smooth=True)

    def head_fn(s, t, w, h):
        c = col(s, w)
        ci = int(abs(c))                                    # whole texels from the ridge
        v = t / (h - 1.0)                                   # 0 the chin, 1 the crown
        around = min(s, 1.0 - s)                            # 0 the face, 0.5 the back
        row = int(t)
        eye_row = int(round(0.5 * h))
        if woman:
            # Parted hair, drawn back over the ears to the nape.
            if v > 0.74 or (around > 0.185 and v > 0.2) or (around > 0.3 and v > 0.08):
                part = v > 0.74 and ci < 1 and around < 0.25
                return (0.45 if part else (0.2 if (row * 3 + int(s * w)) % 7 == 0 else 0.0), 0.0, HAIR)
        else:
            if v > 0.76 or (around > 0.19 and v > 0.34) or (around > 0.3 and v > 0.16):
                return (0.2 if (row + int(s * w)) % 5 == 0 else 0.0, 0.0, HAIR)
        if row in (eye_row, eye_row + 1) and 2 <= ci <= 5:
            return (1.0 if ci in (3, 4) else 0.0, 0.0, EYE)
        if row == eye_row + 2 and 2 <= ci <= 5:
            return (0.3, 0.0, HAIR) if woman else (0.5, 0.0, SKIN)       # her lashes, his lid
        if row == eye_row + 4 and 2 <= ci <= (5 if woman else 6):
            return (0.1, 0.0, HAIR)                         # the brow
        mouth_row = int(round(0.2 * h))
        beard = (not woman) and (v < 0.3 or (around > 0.1 and v < 0.42)) and not (row == mouth_row and ci < 2)
        if row == mouth_row and ci < 3:
            return (0.55 if woman else 0.75, 0.0, SKIN)
        if woman and row == mouth_row - 1 and ci < 2:
            return (0.3, 0.0, SKIN)                         # the lower lip
        if (not woman) and row in (mouth_row + 1, mouth_row + 2) and ci < 4:
            return (0.0, 1.0, SKIN)                         # the moustache
        if beard:
            return (0.0, 1.0, SKIN)
        return (0.0, 0.0, SKIN)
    S.tube([(0, HY + y, chin_z + dz) for dz, _w, _d, y in HEAD], [(w, d) for _dz, w, d, _y in HEAD], ["head"], head_fn,
           dens=2.0, bulge=0.3, smooth=True)
    # The nose: a small wedge on the ridge, between the eyes and the mouth.
    nsz = 0.8 if woman else 1.0
    nz0, nz1 = hz(0.35), hz(0.53)
    tip = Vector((0, front_y(0.37) + 0.017 * hk * nsz, nz0 + 0.006))
    bridge = Vector((0, front_y(0.53) - 0.002, nz1))
    under = Vector((0, front_y(0.33) - 0.002, nz0 - 0.006))
    for sx in (-1.0, 1.0):
        wing = Vector((sx * 0.012 * hk * nsz, front_y(0.35) - 0.006, nz0 - 0.001))
        S.flat([bridge, tip, wing], (0.0 if sx < 0 else 0.1, 0.0, SKIN), ["head"], head_mid)
        S.flat([tip, under, wing], (0.4, 0.0, SKIN), ["head"], head_mid)
    for sx in (-1.0, 1.0):
        ew = head_at(0.5)[0]
        S.tube([(sx * (ew - 0.006), HY - 0.012, hz(0.5) - 0.022), (sx * (ew + 0.006), HY - 0.02, hz(0.5)), (sx * (ew - 0.002), HY - 0.016, hz(0.5) + 0.026)],
               [(0.006, 0.014), (0.007, 0.018), (0.005, 0.012)], ["head"], lambda s, t, w, h: (0.12, 0.0, SKIN), dens=2.0)

    # ======================= legs ================================================
    def legs(name, wide):
        S.begin(name)
        for side in ("l", "r"):
            th, sn = bones["thigh_" + side], bones["shin_" + side]
            lg = K["leg"]
            if wide:
                def fn(s, t, w, h):
                    if t >= h - 3:
                        return (0.0, 1.0, B)                              # gathered at the ankle
                    return (0.3 if (int(t) % 7 == 3 and int(s * w) % 11 < 8) else 0.0, 0.0, B)
                knee = Vector(th[2])
                S.tube([Vector(th[1]) + Vector((0, 0, 0.02)), knee.lerp(Vector(th[1]), 0.4), knee, knee.lerp(Vector(sn[2]), 0.55),
                        Vector(sn[2]) + Vector((0, 0, 0.05)), Vector(sn[2]) + Vector((0, 0, 0.02))],
                       [(lg[0] * 1.05, lg[0] * 1.2), (lg[0] * 1.3, lg[0] * 1.4), (lg[0] * 1.35, lg[0] * 1.45), (lg[0] * 1.3, lg[0] * 1.4),
                        (lg[2] * 1.7, lg[2] * 1.8), (lg[2] * 1.15, lg[2] * 1.2)],
                       ["hips", "thigh_" + side, "shin_" + side], fn, cap0=False, cap1=False)
            else:
                S.tube([Vector(th[1]) + Vector((0, 0, 0.02)), th[2], Vector(sn[2]) + Vector((0, 0, 0.02))],
                       [(lg[0], lg[0] * 1.08), (lg[1], lg[1]), (lg[2] * 1.25, lg[2] * 1.25)], ["hips", "thigh_" + side, "shin_" + side],
                       lambda s, t, w, h: (0.55 if t >= h - 2 else (0.22 if int(s * w) % 6 == 2 else 0.0), 0.0, B), cap0=False, cap1=False)
    legs("legs_narrow", False)
    legs("legs_baggy", True)

    # ======================= garments ============================================
    torso = [(z * k, w, d) for z, w, d in K["torso"]]

    def garment(skirt, fn, dip=0.0, lined=True):
        """One tube, hem to collar: `skirt` rings below the hips, then the torso."""
        rings = [(z * k, w, d) for z, w, d in skirt] + torso
        off = None
        if dip:
            off = lambda i, j: Vector((0, 0, -dip * math.cos(math.tau * j / SIDES) ** 2)) if i == 0 else Vector()
        S.tube([(0, 0.004, z) for z, _w, _d in rings], [(w, d) for _z, w, d in rings], SKIRT, fn, cap0=False, cap1=False, sq=1.06, off=off)
        # Inside the hem: dark, so you don't see through the skirt from low down.
        # Not under a floor-length skirt: nobody sees in, and it folds badly when its wearer sits.
        z0, hw, hd = rings[0]
        if lined:
            S.tube([(0, 0.004, z0 + 0.07), (0, 0.004, z0 + 0.071)], [(hw * 0.97, hd * 0.97), (0.01, 0.01)], ["thigh_l", "thigh_r", "shin_l", "shin_r"],
                   lambda s, t, w, h: (0.92, 0.0, A), cap0=False, cap1=False, sq=1.06)
        return rings[0][0]

    def rows_of(z0):
        return [(z * k - z0) * TEXELS for z in K["belt"]]

    def sleeves(kind_, trim_rows=2, glow=False, bound=False):
        for side, sx in (("l", -1.0), ("r", 1.0)):
            ua, fa = bones["upper_arm_" + side], bones["forearm_" + side]
            ar = K["arm"]
            wrist = Vector(fa[2])
            # The sleeve's head sits straight over its second ring: a ring across a
            # path that leans outward tips its outer edge UP, which read as a pointed shoulder.
            top = Vector(ua[1]) + Vector((sx * 0.014, 0, -0.045))
            nxt = Vector(ua[1]) + Vector((sx * 0.014, 0, -0.1))

            def fn(s, t, w, h):
                if kind_ == "bell" and t >= h - 2:
                    return (0.0, 1.0, A)
                if t >= h - trim_rows:
                    return (0.0, 1.0, A)
                if glow and int(t) == h - trim_rows - 2 and int(s * w) % 2 == 0:
                    return (0.0, 0.0, GLOW)
                if bound and t >= h - 12 and int(t) % 3 == 0:
                    return (0.0, 1.0, A)                                  # the wrist's bindings
                return (0.25 if (int(t) % 9 == 6 and h * 0.35 < t < h * 0.7) else 0.0, 0.0, A)
            if kind_ == "bell":
                # A wide sleeve that hangs open at the wrist (the court robe's wing).
                S.tube([top, nxt, ua[2], wrist.lerp(Vector(fa[1]), 0.35), wrist + Vector((0, -0.01, -0.02))],
                       [(ar[0] * 0.72, ar[0] * 0.8), (ar[0], ar[0] * 1.08), (ar[1] * 1.15, ar[1] * 1.4), (ar[1] * 1.3, ar[1] * 2.0), (ar[1] * 1.45, ar[1] * 2.7)],
                       ["chest", "upper_arm_" + side, "forearm_" + side], fn, cap0=True, cap1=False, bulge=0.3)
                S.tube([wrist + Vector((0, -0.01, 0.03)), wrist + Vector((0, -0.01, 0.031))], [(ar[1] * 1.3, ar[1] * 2.3), (0.008, 0.008)],
                       ["forearm_" + side], lambda s, t, w, h: (0.9, 0.0, A), cap0=False, cap1=False)
            else:
                S.tube([top, nxt, ua[2], wrist.lerp(Vector(fa[1]), 0.08)],
                       [(ar[0] * 0.72, ar[0] * 0.8), (ar[0], ar[0] * 1.05), (ar[1], ar[1]), (ar[2], ar[2] * 1.12)],
                       ["chest", "upper_arm_" + side, "forearm_" + side], fn, cap0=True, cap1=True, bulge=(0.3, -0.25))

    def belt_or_none(t, c, b0, b1):
        """A leather belt with a brass buckle."""
        if b0 <= t < b1:
            return (0.0, 0.0, METAL) if abs(c) < 2.5 else (0.55, 0.0, B)
        return None

    def hem(s, t, w, glow=True):
        if t < 2:
            return (0.0, 1.0, A)
        if glow and int(t) == 3 and int(s * w) % 2 == 0:
            return (0.0, 0.0, GLOW)
        return None

    if not woman:
        # --- the lane coat (Median): to the knee, open down the front, belted
        S.begin("coat")
        skirt = [(0.52, 0.235, 0.19), (0.72, 0.208, 0.162)]
        b0, b1 = rows_of(skirt[0][0] * k)

        def coat_fn(s, t, w, h):
            c = col(s, w)
            got = hem(s, t, w) or belt_or_none(t, c, b0, b1)
            if got:
                return got
            if t >= h - 2:
                return (0.0, 1.0, A)                                      # the neckband
            if -2.5 <= c < -1.5:
                return (0.65, 0.0, A)                                     # the front opening
            if -1.5 <= c < 0.5:
                return (0.0, 1.0, A)                                      # its trimmed edge
            return (0.28 if (t < b0 - 1 and int(s * w) % 8 == 5) else 0.0, 0.0, A)
        garment(skirt, coat_fn)
        sleeves("narrow", glow=True)

        # --- the scholar's robe (Achaemenid): full, pleated, wide sleeves
        S.begin("robe")
        skirt = [(0.07, 0.29, 0.25), (0.5, 0.235, 0.2)]
        b0, b1 = rows_of(skirt[0][0] * k)

        def robe_fn(s, t, w, h):
            c = col(s, w)
            ac = abs(c)
            if t < 2:
                return (0.0, 1.0, A)
            if b0 <= t < b1:
                return (0.3 if int(t) == int(b0) else 0.0, 0.0, C)       # the sash
            if b0 - 22 <= t < b0 and 3 <= c < 6:
                return (0.0, 0.0, C)                                      # its tails
            if t >= h - 2:
                return (0.0, 1.0, A)
            chest = b1 + 12
            if (int(t), int(ac)) in ((int(chest), 6), (int(chest) + 1, 6), (int(chest) + 4, 2), (int(chest) + 5, 2), (int(chest) - 3, 3), (int(chest) - 2, 3)) \
                    or (int(t) in (int(chest) + 8, int(chest) + 9) and int(ac) == 0):
                return (0.0, 0.0, METAL)                                  # brass discs
            if t < b0:
                if ac < 2:
                    return (0.0, 0.4, A)                                  # the fluted fold down the front
                return (0.32 if int(s * w) % 5 == 2 else 0.0, 0.0, A)     # pleats
            return (0.0, 0.0, A)
        garment(skirt, robe_fn, lined=False)
        sleeves("bell")

        # --- the merchant's caftan (Sasanian): crossed, rounded hem, roundels
        S.begin("caftan")
        skirt = [(0.44, 0.25, 0.205), (0.7, 0.215, 0.17)]
        b0, b1 = rows_of(skirt[0][0] * k)

        def caftan_fn(s, t, w, h):
            c = col(s, w)
            got = hem(s, t, w, glow=False) or belt_or_none(t, c, b0, b1)
            if got:
                return got
            if t >= h - 2:
                return (0.0, 1.0, A)
            if t >= b1:
                edge = 6.0 - (t - b1) / max(h - b1, 1.0) * 12.0           # crossed over the chest
                if abs(c - edge) < 1.1:
                    return (0.0, 1.0, A)
            what = roundel(s * w, t)
            if what == "pearl":
                return (0.0, 0.0, GLOW)
            if what:
                return (0.0, 1.0, A)
            return (0.0, 0.0, A)
        garment(skirt, caftan_fn, dip=0.07)
        sleeves("narrow", glow=True)
    else:
        # --- the house dress (Achaemenid): long, pleated, wide sleeves
        S.begin("dress")
        skirt = [(0.06, 0.31, 0.27), (0.45, 0.25, 0.215)]
        b0, b1 = rows_of(skirt[0][0] * k)

        def dress_fn(s, t, w, h):
            c = col(s, w)
            got = hem(s, t, w)
            if got:
                return got
            if 4 <= t < 9:                                                # a patterned band over the hem
                on = (int(s * w) + int(t)) % 4 == 0 or (int(s * w) - int(t)) % 4 == 0
                return (0.0, 1.0 if on else 0.0, A)
            if b0 <= t < b1:
                return (0.3 if int(t) == int(b0) else 0.0, 0.0, C)
            if b0 - 20 <= t < b0 and -6 <= c < -3:
                return (0.0, 0.0, C)
            if t >= h - 3 and abs(c) < 4:
                return (0.0, 1.0, A)
            return (0.3 if (t < b0 - 2 and int(s * w) % 5 == 2) else 0.0, 0.0, A)
        garment(skirt, dress_fn, lined=False)
        sleeves("bell")

        # --- the bazaar gown (Sasanian): close, belted high, roundels
        S.begin("gown")
        skirt = [(0.06, 0.25, 0.21), (0.5, 0.21, 0.175)]
        z0 = skirt[0][0] * k
        hb0, hb1 = (1.165 * k - z0) * TEXELS, (1.21 * k - z0) * TEXELS

        def gown_fn(s, t, w, h):
            got = hem(s, t, w, glow=False)
            if got:
                return got
            if hb0 <= t < hb1:
                return (0.0, 1.0, A)                                      # the high belt
            if t >= h - 2:
                return (0.0, 1.0, A)
            what = roundel(s * w, t)
            if what == "pearl":
                return (0.0, 0.0, GLOW)
            if what:
                return (0.0, 1.0, A)
            return (0.0, 0.0, A)
        garment(skirt, gown_fn, dip=0.03, lined=False)
        sleeves("narrow", glow=True)

        # --- the copyist's jacket (Parthian): wrapped, quilted with pages
        S.begin("jacket")
        skirt = [(0.78, 0.215, 0.165)]
        b0, b1 = rows_of(skirt[0][0] * k)

        def jacket_fn(s, t, w, h):
            c = col(s, w)
            got = hem(s, t, w) or belt_or_none(t, c, b0, b1)
            if got:
                return got
            if t >= h - 2:
                return (0.0, 1.0, A)
            edge = 7.0 - (t / h) * 16.0 if t >= b1 else -5.0              # wrapped across
            if abs(c - edge) < 1.1:
                return (0.0, 1.0, A)
            if int(t) % 6 == 0 or int(s * w) % 7 == 0:
                return (0.3, 0.0, A)                                      # the quilting
            if int(t) % 6 == 3 and int(s * w) % 7 not in (1, 6) and (int(s * w) * 7 + int(t)) % 5 != 0:
                return (0.16, 0.0, A)                                     # a line of old writing
            return (0.0, 0.0, A)
        garment(skirt, jacket_fn)
        sleeves("narrow", bound=True)

    # ======================= worn over ===========================================
    sh = K["sh"]
    if not woman:
        # --- the sleeved cloak (kandys) on the shoulders, its sleeves empty
        S.begin("cloak")

        def cloak_fn(s, t, w, h):
            around = min(s, 1.0 - s)
            if around < 0.155:
                return (0.0, 1.0, D)                                      # the lining at the front edges
            if t < 2:
                return (0.0, 1.0, D)
            return (0.25 if int(s * w) % 9 == 4 else 0.0, 0.0, D)
        S.tube([(0, -0.005, z * k) for z in (0.3, 0.9, 1.3, 1.395, 1.462)], [(0.31, 0.255), (0.262, 0.2), (0.245, 0.175), (0.215, 0.138), (0.1, 0.092)],
               SKIRT, cloak_fn, cap0=False, cap1=False, sq=1.06, skip=(7, 0))
        for sx in (-1.0, 1.0):
            S.tube([(sx * (sh + 0.045), -0.03, 1.4 * k), (sx * (sh + 0.085), -0.04, 1.2 * k), (sx * (sh + 0.1), -0.03, 0.82 * k)],
                   [(0.03, 0.05), (0.032, 0.055), (0.03, 0.05)], ["chest", "spine"],
                   lambda s, t, w, h: (0.0, 1.0 if t >= h - 2 else 0.0, D), bulge=0.2)

        # --- hides over the shoulders (the hunter)
        S.begin("hides")
        S.tube([(0, 0.0, z * k) for z in (1.16, 1.3, 1.392, 1.462)], [(0.245, 0.18), (0.24, 0.165), (0.21, 0.135), (0.09, 0.085)],
               ["chest", "spine"], lambda s, t, w, h: (0.35 if (int(s * w) * 5 + int(t) * 3) % 11 < 3 else (0.5 if t < 2 else 0.0), 0.0, D),
               cap0=False, cap1=False, sq=1.06, off=lambda i, j: Vector((0, 0, -0.05 if (i == 0 and j % 2 == 0) else 0.0)))
    else:
        # --- a shawl round the shoulders
        S.begin("shawl")
        S.tube([(0, 0.0, z * k) for z in (1.08, 1.28, 1.392, 1.462)], [(0.235, 0.17), (0.225, 0.16), (0.185, 0.125), (0.082, 0.078)],
               ["chest", "spine"], lambda s, t, w, h: (0.0, 1.0, D) if (t < 2 or min(s, 1.0 - s) < 0.16) else ((0.2 if int(s * w) % 6 == 2 else 0.0), 0.0, D),
               cap0=False, cap1=False, sq=1.06, skip=(7, 0), off=lambda i, j: Vector((0, 0, -0.07 if (i == 0 and j == 4) else 0.0)))

    # ======================= hair ================================================
    hair_fn = lambda s, t, w, h: (0.25 if (int(t) + int(s * w)) % 4 == 0 else 0.0, 0.0, HAIR)
    if not woman:
        # Curls bunched at the nape (Achaemenid).
        S.begin("hair_curls")
        S.tube([(-0.075, HY - 0.075, hz(0.3)), (0.0, HY - 0.105, hz(0.27)), (0.075, HY - 0.075, hz(0.3))], [(0.04, 0.045), (0.045, 0.05), (0.04, 0.045)],
               ["head"], hair_fn, fwd=Vector((0, 0, 1)), dens=2.0, bulge=0.5)
        # A squared beard to the collar bone.
        S.begin("beard_square")
        S.tube([(0, HY + 0.035, hz(0.24)), (0, HY + 0.045, hz(0.02)), (0, HY + 0.05, hz(-0.3))], [(0.058, 0.045), (0.056, 0.04), (0.05, 0.03)],
               ["head"], lambda s, t, w, h: (0.4 if int(t) % 4 == 0 else 0.0, 0.0, HAIR), dens=2.0, cap0=False, bulge=0.1, sq=1.12)
        # Bushy hair to both sides (Parthian), held by a band.
        S.begin("hair_bushy")
        for sx in (-1.0, 1.0):
            ew = head_at(0.5)[0]
            S.tube([(sx * (ew - 0.01), HY - 0.02, hz(0.26)), (sx * (ew + 0.025), HY - 0.025, hz(0.48)), (sx * (ew + 0.005), HY - 0.02, hz(0.72))],
                   [(0.03, 0.05), (0.045, 0.07), (0.03, 0.05)], ["head"], hair_fn, dens=2.0, bulge=0.5)
        w0, d0, y0 = head_at(0.68, 0.006)
        w1, d1, y1 = head_at(0.76, 0.006)
        S.tube([(0, y0, hz(0.68)), (0, y1, hz(0.76))], [(w0, d0), (w1, d1)], ["head"],
               lambda s, t, w, h: (0.0, 0.0, METAL) if min(s, 1.0 - s) < 0.03 else (0.5, 0.0, B), dens=2.0, cap0=False, cap1=False)
    else:
        # One long braid down the back, its ribbon ends in glow thread.
        S.begin("braid")
        pts, rad = [], []
        n = 11
        for i in range(n):
            f = i / (n - 1.0)
            z = hz(0.3) + (0.93 * k - hz(0.3)) * f
            y = HY - 0.085 - 0.06 * math.sin(min(f * 3.0, 1.0) * math.pi / 2.0) + 0.02 * f
            pts.append((0.0, y, z))
            r = 0.03 if i % 2 == 0 else 0.022
            rad.append((r, r * 0.85))
        S.tube(pts, rad, ["head", "neck", "chest", "spine"],
               lambda s, t, w, h: (0.0, 0.0, GLOW) if t >= h - 3 else ((0.3 if int(t + s * w) % 4 == 0 else 0.0), 0.0, HAIR), cap0=False, bulge=0.6)
        # A topknot (Sasanian).
        S.begin("topknot")
        S.tube([(0, HY - 0.02, hz(0.93)), (0, HY - 0.022, hz(1.08)), (0, HY - 0.024, hz(1.22))], [(0.035, 0.035), (0.05, 0.05), (0.032, 0.032)],
               ["head"], hair_fn, dens=2.0, cap0=False, bulge=0.5)
        # Braids pinned up over the ears.
        S.begin("pinned")
        for sx in (-1.0, 1.0):
            ew = head_at(0.5)[0]
            S.tube([(sx * (ew - 0.004), HY - 0.03, hz(0.3)), (sx * (ew + 0.012), HY - 0.035, hz(0.48)), (sx * (ew - 0.002), HY - 0.03, hz(0.66))],
                   [(0.022, 0.035), (0.028, 0.042), (0.022, 0.035)], ["head"], hair_fn, dens=2.0, bulge=0.5)

    # ======================= on the head =========================================
    def band(name, f0, f1, fn, grow=0.006, zig=0.0):
        S.begin(name)
        w0, d0, y0 = head_at(f0, grow)
        w1, d1, y1 = head_at(f1, grow)
        S.tube([(0, y0, hz(f0)), (0, y1, hz(f1))], [(w0, d0), (w1, d1)], ["head"], fn, dens=2.0, cap0=False, cap1=False,
               off=(lambda i, j: Vector((0, 0, zig if (i == 1 and j % 2 == 1) else 0.0))) if zig else None)

    def ribbons(code):
        """Two ribbons from the back of a band, down between the shoulders."""
        for sx in (-1.0, 1.0):
            x = sx * 0.02
            top = Vector((x, HY - 0.1 * hk, hz(0.7)))
            S.flat([top, top + Vector((sx * 0.022, 0, 0)), Vector((sx * 0.06, -0.125, hz(-0.75))), Vector((sx * 0.035, -0.125, hz(-0.75)))],
                   code, ["head", "neck"], head_mid)

    if not woman:
        # A round felt cap.
        S.begin("cap_felt")
        w0, d0, y0 = head_at(0.78, 0.008)
        S.tube([(0, y0, hz(0.78)), (0, y0, hz(0.92)), (0, y0, hz(1.12)), (0, y0, hz(1.22))],
               [(w0, d0), (w0 + 0.002, d0 + 0.002), (w0 * 0.82, d0 * 0.82), (w0 * 0.45, d0 * 0.45)], ["head"],
               lambda s, t, w, h: (0.35 if t < 4 else 0.0, 1.0 if int(t) == 4 else 0.0, C), dens=2.0, cap0=False, bulge=0.25)
        # A tall rounded cap (kolah), a band of glow pearls round it.
        S.begin("cap_tall")
        S.tube([(0, y0, hz(0.78)), (0, y0, hz(0.95)), (0, y0 - 0.004, hz(1.3)), (0, y0 - 0.006, hz(1.5))],
               [(w0, d0), (w0 + 0.003, d0 + 0.003), (w0 * 0.9, d0 * 0.9), (w0 * 0.55, d0 * 0.55)], ["head"],
               lambda s, t, w, h: (0.0, 0.0, GLOW) if (int(t) == 5 and int(s * w) % 2 == 0) else ((0.0, 1.0, C) if int(t) in (3, 7) else (0.0, 0.0, C)),
               dens=2.0, cap0=False, bulge=0.3)
        # A fillet with ribbons (the scholar's bookmarks).
        band("fillet", 0.66, 0.74, lambda s, t, w, h: (0.0, 0.0, C))
        ribbons((0.0, 0.0, C))
        # The lamp tender's cap with its lantern globe.
        S.begin("globe")
        S.tube([(0, y0, hz(0.78)), (0, y0, hz(0.92)), (0, y0, hz(1.12)), (0, y0, hz(1.2))],
               [(w0, d0), (w0 + 0.002, d0 + 0.002), (w0 * 0.82, d0 * 0.82), (w0 * 0.4, d0 * 0.4)], ["head"],
               lambda s, t, w, h: (0.3 if t < 4 else 0.0, 0.0, PALE), dens=2.0, cap0=False, bulge=0.2)
        S.tube([(0, y0, hz(1.2)), (0, y0, hz(1.4))], [(0.008, 0.008), (0.008, 0.008)], ["head"], lambda s, t, w, h: (0.0, 0.0, METAL), cap0=False, cap1=False)
        S.tube([(0, y0, hz(1.36)), (0, y0, hz(1.5)), (0, y0, hz(1.68)), (0, y0, hz(1.8))], [(0.025, 0.025), (0.052, 0.052), (0.052, 0.052), (0.025, 0.025)],
               ["head"], lambda s, t, w, h: (0.0, 0.0, FLAME), bulge=0.3)
        # The mouth cloth (padam).
        S.begin("padam")
        fs = (0.06, 0.2, 0.44)
        hs = [head_at(f, 0.007) for f in fs]
        S.tube([(0, h_[2], hz(f)) for f, h_ in zip(fs, hs)], [(h_[0], h_[1] + (0.012 if i == 1 else 0.0)) for i, h_ in enumerate(hs)], ["head"],
               lambda s, t, w, h: (0.25 if t >= h - 1 else 0.0, 0.0, PALE), dens=2.0, cap0=False, cap1=False, skip=(2, 3, 4, 5))
    else:
        # A low crenellated band.
        band("band", 0.7, 0.8, lambda s, t, w, h: (0.25 if t < 2 else 0.0, 0.0, METAL), zig=0.016)
        # The keeper's veil, from the crown down the back.
        S.begin("veil")
        w0, d0, y0 = head_at(0.8, 0.012)
        S.tube([(0, y0 - 0.01, hz(0.82)), (0, HY - 0.02, hz(0.1)), (0, -0.01, 1.36 * k), (0, -0.02, 0.9 * k), (0, -0.02, 0.4 * k)],
               [(w0, d0), (0.105, 0.12), (0.2, 0.16), (0.22, 0.19), (0.24, 0.21)], ["head", "chest", "spine", "hips"],
               lambda s, t, w, h: (0.0, 1.0, PALE) if t >= h - 2 else ((0.22 if int(s * w) % 6 == 3 else 0.0), 0.0, PALE),
               fwd=Vector((0, 1, 0)), cap0=False, cap1=False, skip=(6, 7, 0, 1))
        S.tube([(0, y0 - 0.006, hz(0.8)), (0, y0 - 0.008, hz(0.9)), (0, y0 - 0.012, hz(1.0))], [(w0, d0), (w0 - 0.002, d0), (w0 * 0.8, d0 * 0.82)], ["head"],
               lambda s, t, w, h: (0.0, 0.0, PALE), dens=2.0, cap0=False, bulge=0.36)
        # A fillet with floating ribbons.
        band("fillet", 0.68, 0.75, lambda s, t, w, h: (0.0, 0.0, C))
        ribbons((0.0, 0.0, C))

    # ======================= at the belt =========================================
    S.begin("belt_things")
    bz = K["belt"][0] * k
    hipw = torso[1][1]
    lx, ly = -hipw * 0.72, torso[1][2] * 0.86
    S.flat([(lx - 0.006, ly, bz), (lx + 0.006, ly, bz), (lx + 0.006, ly + 0.01, bz - 0.09), (lx - 0.006, ly + 0.01, bz - 0.09)], (0.55, 0.0, B), ["hips"], (0, 0, bz))
    S.tube([(lx, ly + 0.012, bz - 0.085), (lx, ly + 0.014, bz - 0.115), (lx, ly + 0.014, bz - 0.15)], [(0.008, 0.008), (0.026, 0.026), (0.008, 0.008)],
           ["hips"], lambda s, t, w, h: (0.0, 0.0, FLAME), bulge=0.4)
    px = hipw * 0.72
    S.tube([(px, ly + 0.01, bz - 0.02), (px, ly + 0.02, bz - 0.07), (px, ly + 0.02, bz - 0.12)], [(0.012, 0.01), (0.04, 0.026), (0.034, 0.022)],
           ["hips"], lambda s, t, w, h: (0.0, 0.0, METAL) if int(t) == 2 else (0.4, 0.0, B), bulge=0.3)
    for bm, _parts in S.pieces.values():
        bm.normal_update()
    return S.pieces


def armature(name, K):
    data = bpy.data.armatures.new(name + "_rig")
    ob = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    for bname, head, tail, parent in bones_of(K):
        e = data.edit_bones.new(bname)
        e.head = head
        e.tail = tail
        e.roll = 0.0
        if parent:
            e.parent = data.edit_bones[parent]
            e.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob


def seg_distance(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (a + ab * t - p).length


def skin(mesh_ob, parts, rig, K):
    me = mesh_ob.data
    bl = bones_of(K)
    groups = {b[0]: mesh_ob.vertex_groups.new(name=b[0]) for b in bl}
    segs = {b[0]: (Vector(b[1]), Vector(b[2])) for b in bl}
    pids = me.attributes["part"].data
    for v in me.vertices:
        allowed = parts[pids[v.index].value]
        ws = sorted(((1.0 / (seg_distance(v.co, *segs[b]) + 0.01) ** 4, b) for b in allowed), reverse=True)[:2]
        total = sum(w for w, _ in ws)
        for w, b in ws:
            groups[b].add([v.index], w / total, "REPLACE")
    mod = mesh_ob.modifiers.new("rig", "ARMATURE")
    mod.object = rig
    mesh_ob.parent = rig


def mask_material(kind, mask):
    img = bpy.data.images.new(kind + "_mask", TEX, TEX, alpha=False)
    img.colorspace_settings.name = "Non-Color"
    flat = []
    for y in range(TEX):                  # Blender images start at the bottom row
        for x in range(TEX):
            r, g, b = mask.px[TEX - 1 - y][x]
            flat += [r, g, b, 1.0]
    img.pixels = flat
    # As its own file: the game's shader reads the mask from there, imported
    # lossless (a compressed mask would smear the codes).
    img.filepath_raw = os.path.join(OUT, kind + "_mask.png")
    img.file_format = "PNG"
    img.save()
    m = bpy.data.materials.new(kind + "_mask")
    m.diffuse_color = (0.6, 0.55, 0.5, 1.0)
    return m


# --- poses and animations ---------------------------------------------------
AXES = {"X": Vector((1, 0, 0)), "Y": Vector((0, 1, 0)), "Z": Vector((0, 0, 1))}


def local_q(rig, bone, turns):
    """Rotations about world axes (rest frame), in the bone's own frame."""
    b = rig.data.bones[bone]
    inv = b.matrix_local.to_3x3().inverted()
    q = Quaternion()
    for axis, deg in turns:
        q = Quaternion((inv @ AXES[axis]).normalized(), math.radians(deg)) @ q
    return q


def key(rig, frame, pose, root_z=0.0, root_y=0.0, root_x=0.0):
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = local_q(rig, pb.name, pose.get(pb.name, []))
        pb.location = Vector()
        pb.keyframe_insert("rotation_quaternion", frame=frame)
    root = rig.pose.bones["root"]
    inv = rig.data.bones["root"].matrix_local.to_3x3().inverted()
    root.location = inv @ Vector((root_x, root_y, root_z))
    root.keyframe_insert("location", frame=frame)
    for pb in rig.pose.bones:
        if pb.name != "root":
            pb.keyframe_insert("location", frame=frame)


def stand(t=0.0):
    """Standing at ease, breathing: the weight a little on one leg, the arms
    hanging in to the sides with the elbows soft and the hands forward."""
    b = math.sin(t * math.tau)
    return {
        "hips": [("Y", 1.5)], "spine": [("Y", -1.5)],
        "chest": [("X", 0.7 * b), ("Y", -1.0)], "neck": [("X", 4)], "head": [("X", -4 - 0.5 * b), ("Z", 4)],
        "upper_arm_l": [("Y", -6), ("X", -5 + 0.4 * b)], "upper_arm_r": [("Y", 6), ("X", -3 + 0.4 * b)],
        "forearm_l": [("X", 12)], "forearm_r": [("X", 17)],
        "hand_l": [("X", -4)], "hand_r": [("X", -4)],
        "thigh_r": [("X", 3)], "shin_r": [("X", -6)],
    }


# One walk cycle covers this far (m, times the kind's k) in WALK_FRAMES frames:
# the game plays it faster or slower to match the ground covered.
WALK_STRIDE = 1.36
WALK_FRAMES = 26


def walk(t):
    """An unhurried walk: the arms swing against the legs, the hips turn a
    little, the body rises as the legs pass."""
    p = {}
    for side, ph in (("l", 0.0), ("r", 0.5)):
        a = (t + ph) * math.tau
        swing = math.sin(a)
        lift = max(0.0, math.cos(a))               # moving forward: the foot is off the ground
        push = max(0.0, -math.cos(a))
        p["thigh_" + side] = [("X", 21 * swing + 7 * lift)]
        p["shin_" + side] = [("X", -46 * lift - 5 - 8 * push * max(0.0, -swing))]
        p["foot_" + side] = [("X", 12 * lift - 14 * push * max(0.0, -swing))]
        p["upper_arm_" + side] = [("Y", -5 if side == "l" else 5), ("X", -15 * swing - 2)]
        p["forearm_" + side] = [("X", 14 + 9 * max(0.0, -swing))]
    sway = math.sin(t * math.tau)
    bob = math.cos(2 * t * math.tau)
    # The weight goes over the standing leg. The left foot is in the air round
    # t = 0 and on the ground round t = 0.5, so the body is over the left
    # then: it shifts that way, the swinging leg's hip drops, and the
    # shoulders tip back the other way to stay level.
    over = -math.cos(t * math.tau)                         # + : over the left leg
    p.update({"hips": [("Z", 5 * sway), ("Y", 3.5 * over)], "spine": [("Z", -3 * sway), ("Y", -2.5 * over)],
              "chest": [("Z", -5 * sway), ("Y", -2.0 * over), ("X", -3)],
              "neck": [("X", 3), ("Z", 2 * sway)], "head": [("X", -1), ("Z", 1 * sway), ("Y", 1.0 * over)]})
    return p, -0.016 + 0.014 * bob, 0.0, -0.018 * over


def sit_bench(t, k):
    """Sitting on a bench or a low wall, the hands on the thighs. The seat is
    0.42 * k m high."""
    b = math.sin(t * math.tau)
    p = {
        "spine": [("X", -4)], "chest": [("X", -3 + 0.7 * b)], "neck": [("X", 4)], "head": [("X", -2)],
        "thigh_l": [("X", 84), ("Z", 8)], "thigh_r": [("X", 84), ("Z", -8)],
        "shin_l": [("X", -82)], "shin_r": [("X", -86)],
        "upper_arm_l": [("X", 30), ("Y", -3)], "upper_arm_r": [("X", 31), ("Y", 3)],
        "forearm_l": [("X", 30), ("Z", -10)], "forearm_r": [("X", 28), ("Z", 10)],
        "hand_l": [("X", 22)], "hand_r": [("X", 22)],
    }
    return p, -0.43 * k


def sit_floor(t, k):
    """Sitting cross-legged on a cushion or a rug, the hands on the knees."""
    b = math.sin(t * math.tau)
    p = {
        "spine": [("X", -7)], "chest": [("X", -6 + 0.7 * b)], "neck": [("X", 5)], "head": [("X", 3)],
        "thigh_l": [("Z", 75), ("X", 76), ("Z", 44)], "thigh_r": [("Z", -75), ("X", 76), ("Z", -44)],
        "shin_l": [("X", -138)], "shin_r": [("X", -132)],
        "foot_l": [("X", 25)], "foot_r": [("X", 25)],
        "upper_arm_l": [("X", 26), ("Z", 20)], "upper_arm_r": [("X", 26), ("Z", -20)],
        "forearm_l": [("X", 16), ("Z", 4)], "forearm_r": [("X", 16), ("Z", -4)],
        "hand_l": [("X", 30)], "hand_r": [("X", 30)],
    }
    return p, -(0.93 * k - 0.12)


def sit_knees(t, k):
    """Kneeling, sitting back on the heels (do-zanu, the formal way), the
    hands on the thighs. What a long robe sits in: the skirt tucks under."""
    b = math.sin(t * math.tau)
    p = {
        "spine": [("X", -3)], "chest": [("X", -3 + 0.7 * b)], "neck": [("X", 4)], "head": [("X", 0)],
        "thigh_l": [("X", 64), ("Z", 7)], "thigh_r": [("X", 64), ("Z", -7)],
        "shin_l": [("X", -152)], "shin_r": [("X", -152)],
        "foot_l": [("X", -62)], "foot_r": [("X", -62)],
        "upper_arm_l": [("X", 22), ("Y", -3)], "upper_arm_r": [("X", 23), ("Y", 3)],
        "forearm_l": [("X", 34), ("Z", -8)], "forearm_r": [("X", 32), ("Z", 8)],
        "hand_l": [("X", 24)], "hand_r": [("X", 24)],
    }
    return p, -(0.93 * k - 0.25)


def sleep(t, k):
    """Asleep on the back, the hands on the belly, one knee a little up. The
    body lies along the node's Z with its middle over the node's origin, the
    head toward +Z (Godot)."""
    b = math.sin(t * math.tau)
    p = {
        "root": [("X", 90)],
        "chest": [("X", 1.2 * b)], "neck": [("X", -6)], "head": [("Z", 16), ("X", -4)],
        "upper_arm_l": [("X", 16), ("Y", -8)], "upper_arm_r": [("X", 14), ("Y", 8)],
        "forearm_l": [("X", 64 + 1.0 * b), ("Z", -38)], "forearm_r": [("X", 58 + 1.0 * b), ("Z", 40)],
        "thigh_r": [("X", 16), ("Z", -6)], "shin_r": [("X", -30)],
        "foot_l": [("X", -24), ("Z", 10)], "foot_r": [("X", -24), ("Z", -10)],
    }
    return p, 0.15, 0.86 * k


# --- work: what the arms, head and back do, laid over a way of sitting --------
def with_upper(base, upper):
    """A base result (pose[, root offsets]) with `upper`'s bones laid over it."""
    if isinstance(base, tuple):
        pose = dict(base[0])
        pose.update(upper)
        return (pose,) + tuple(base[1:])
    pose = dict(base)
    pose.update(upper)
    return pose


def pulse(t, at, width):
    """0..1..0 round `at` (0..1 of the cycle), `width` wide."""
    d = abs(((t - at + 0.5) % 1.0) - 0.5)
    return max(0.0, 1.0 - d / (width * 0.5)) if width > 0 else 0.0


def up_read(t):
    """A book held open before the chest, the head bent to it; now and then a
    page is turned with the right hand."""
    b = math.sin(t * math.tau)
    turn = pulse(t, 0.55, 0.16)
    return {
        "chest": [("X", -7 + 0.6 * b)], "neck": [("X", -8)], "head": [("X", -16 - 1.5 * b)],
        "upper_arm_l": [("X", 34), ("Y", -4)], "upper_arm_r": [("X", 34 + 6 * turn), ("Y", 4)],
        "forearm_l": [("X", 78), ("Z", -22)], "forearm_r": [("X", 78 - 10 * turn), ("Z", 22 + 20 * turn)],
        "hand_l": [("X", 10)], "hand_r": [("X", 10 + 20 * turn)],
    }


def up_mend(t):
    """Work in the lap: the left hand holds it, the right draws a thread out
    and back, the head bent over it."""
    pull = 0.5 - 0.5 * math.cos(2 * t * math.tau)
    return {
        "chest": [("X", -9)], "neck": [("X", -8)], "head": [("X", -18), ("Z", -4)],
        "upper_arm_l": [("X", 24), ("Y", -3)], "upper_arm_r": [("X", 24 + 10 * pull), ("Y", 6 + 14 * pull)],
        "forearm_l": [("X", 62), ("Z", -26)], "forearm_r": [("X", 66 - 14 * pull), ("Z", 24 - 16 * pull)],
        "hand_l": [("X", 14)], "hand_r": [("X", 14 + 10 * pull)],
    }


def up_eat(t):
    """Eating with the right hand: down to the dish, up to the mouth, twice a
    cycle; the left hand rests."""
    lift = 0.5 - 0.5 * math.cos(2 * t * math.tau)
    lift = lift * lift * (3 - 2 * lift)
    return {
        "chest": [("X", -6 + 2 * lift)], "neck": [("X", -3)], "head": [("X", -9 + 5 * lift)],
        "upper_arm_r": [("X", 30 + 6 * lift), ("Y", 4), ("Z", 30 * lift)],
        "forearm_r": [("X", 46 + 94 * lift), ("Z", 12 + 10 * lift)],
        "hand_r": [("X", 16 + 14 * lift)],
    }


def stir(t, k):
    """Kneeling at the hearth, stirring the pot with the right hand."""
    a = 2 * t * math.tau
    upper = {
        "spine": [("X", -8)], "chest": [("X", -8)], "neck": [("X", -5)], "head": [("X", -12)],
        "upper_arm_r": [("X", 52 + 7 * math.cos(a)), ("Z", 7 * math.sin(a))],
        "forearm_r": [("X", 36 + 6 * math.sin(a)), ("Z", 6 + 6 * math.cos(a))],
        "hand_r": [("X", 30)],
    }
    return with_upper(sit_knees(t, k), upper)


def dip(t, k):
    """Kneeling at the water's edge, leaning over to fill a jar held in both
    hands: down, held under, up."""
    down = pulse(t, 0.5, 0.9)
    down = down * down * (3 - 2 * down)
    upper = {
        "spine": [("X", -6 - 16 * down)], "chest": [("X", -5 - 12 * down)], "neck": [("X", -2 + 6 * down)], "head": [("X", -8)],
        "upper_arm_l": [("X", 38 + 26 * down), ("Y", -3)], "upper_arm_r": [("X", 38 + 26 * down), ("Y", 3)],
        "forearm_l": [("X", 44 - 24 * down), ("Z", -14)], "forearm_r": [("X", 44 - 24 * down), ("Z", 14)],
        "hand_l": [("X", 10)], "hand_r": [("X", 10)],
    }
    return with_upper(sit_knees(t, k), upper)


def weigh(t):
    """Standing at a counter, the hands at its height: one lifts as the other
    lowers, like the pans of a scale, then a rest."""
    busy = pulse(t, 0.35, 0.6)
    tip = math.sin(3 * t * math.tau) * busy
    upper = {
        "chest": [("X", -4)], "neck": [("X", -2)], "head": [("X", -11), ("Z", 3 * tip)],
        "upper_arm_l": [("X", 18), ("Y", -5)], "upper_arm_r": [("X", 18), ("Y", 5)],
        "forearm_l": [("X", 66 + 9 * tip), ("Z", -8)], "forearm_r": [("X", 66 - 9 * tip), ("Z", 8)],
        "hand_l": [("X", 6)], "hand_r": [("X", 6)],
    }
    return with_upper(stand(t), upper)


def reach(t):
    """Standing under a lamp, the right arm up to it, the head back to see:
    trimming the wick."""
    b = math.sin(2 * t * math.tau)
    upper = {
        "chest": [("X", 4)], "neck": [("X", 8)], "head": [("X", 14), ("Z", -4)],
        "upper_arm_r": [("X", 152 + 4 * b), ("Y", 6)], "forearm_r": [("X", 18 + 8 * b)], "hand_r": [("X", 8 * b)],
    }
    return with_upper(stand(t), upper)


def walk_carry(t):
    """The walk with something held in the right hand at the hip: that arm
    doesn't swing."""
    r = walk(t)
    upper = {"upper_arm_r": [("Y", 7), ("X", 6)], "forearm_r": [("X", 74), ("Z", 10)], "hand_r": [("X", 4)]}
    return with_upper(r, upper)


def animate(rig, K):
    k = K["k"]
    rig.animation_data_create()
    made = []

    def action(name, frames, fn):
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        rig.animation_data.action = act
        for f in range(frames + 1):
            r = fn(f / frames)
            pose, z, y, x = (r + (0.0, 0.0))[:4] if isinstance(r, tuple) else (r, 0.0, 0.0, 0.0)
            key(rig, f, pose, z, y, x)
        made.append(act)

    action("idle-loop", 96, lambda t: stand(t))
    action("walk-loop", WALK_FRAMES, walk)
    action("sit_bench-loop", 96, lambda t: sit_bench(t, k))
    action("sit_floor-loop", 96, lambda t: sit_floor(t, k))
    action("sit_knees-loop", 96, lambda t: sit_knees(t, k))
    action("sleep-loop", 120, lambda t: sleep(t, k))
    # Work (phase 21 step 4). Reading, mending and eating go over each way of
    # sitting: <what>_<floor|knees|bench>.
    for way, base in (("floor", sit_floor), ("knees", sit_knees), ("bench", sit_bench)):
        action("read_%s-loop" % way, 144, lambda t, base=base: with_upper(base(t, k), up_read(t)))
        action("mend_%s-loop" % way, 96, lambda t, base=base: with_upper(base(t, k), up_mend(t)))
        action("eat_%s-loop" % way, 120, lambda t, base=base: with_upper(base(t, k), up_eat(t)))
    action("stir-loop", 96, lambda t: stir(t, k))
    action("dip-loop", 144, lambda t: dip(t, k))
    action("weigh-loop", 168, weigh)
    action("reach-loop", 96, reach)
    action("walk_carry-loop", WALK_FRAMES, walk_carry)
    rig.animation_data.action = made[0]
    return made


def build(kind):
    K = KINDS[kind]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    mask = Mask()
    pieces = build_pieces(kind, K, mask)
    mat = mask_material(kind, mask)
    rig = armature(kind, K)
    obs, verts = [], 0
    for name, (bm, parts) in pieces.items():
        me = bpy.data.meshes.new("%s_%s" % (kind, name))
        bm.to_mesh(me)
        bm.free()
        me.materials.append(mat)
        soft = me.attributes["soft"].data
        for poly in me.polygons:
            poly.use_smooth = soft[poly.index].value == 1
        ob = bpy.data.objects.new("%s_%s" % (kind, name), me)
        bpy.context.collection.objects.link(ob)
        skin(ob, parts, rig, K)
        obs.append(ob)
        verts += len(me.vertices)
    animate(rig, K)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SRC, kind + ".blend"))
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    for ob in obs:
        ob.select_set(True)
    glb = os.path.join(OUT, kind + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=glb, export_format="GLB", use_selection=True, export_yup=True, export_apply=False,
        export_texcoords=True, export_normals=True, export_materials="EXPORT", export_lights=False, export_cameras=False,
        export_animations=True, export_animation_mode="ACTIONS", export_skins=True, export_def_bones=False,
        export_force_sampling=True, export_optimize_animation_size=False)
    print("resident_body: %s %d pieces (%s), %d verts in all, %d bones, mask rows used %d of %d -> %s" % (
        kind, len(obs), " ".join(pieces.keys()), verts, len(bones_of(K)), mask.y + mask.row, TEX, os.path.relpath(glb, ROOT)))


def main():
    os.makedirs(SRC, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    for kind in ("man", "woman"):
        build(kind)


main()
