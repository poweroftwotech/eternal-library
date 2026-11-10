"""The cat (phase 19 step 3, atlas C07): the first animal with a skeleton.

Builds art_src/creatures/cat.blend (mesh, armature, weights, a pixel coat
mask, the animations) and exports actors/models/cat.glb. Run headless:

  blender --background --factory-startup --python tools/creature_cat.py

Conventions (as the kit): Blender Z up, metres; the cat faces Blender +Y
(Godot -Z, a node's forward). About 50 cm nose to tail tip's base, 25 cm at
the shoulder.

The texture is a mask, not colours (one cat model, many coats): R the tabby
stripes (and the pupil in an eye), G the pale parts (belly, chest, muzzle,
paws), B what a texel is: 0 fur, 0.5 nose and ear skin, 1 an eye. The game's
shader (shaders/creature_cat.gdshader) colours it per cat. Painted at
COAT_TEXELS per metre, nearest filtering.

Animations (each an action; "-loop" ones loop in Godot): idle, walk, sit,
sleep, wash loop; look and startle play once.

Posing: every rotation is given about a WORLD axis in the armature's rest
frame (pose(): "X" pitch, + turns a bone's tip from back to down to forward
to up: a forward bone's tip rises, a leg swings forward, a tail (pointing
back) droops; "Z" yaw, + turns toward the cat's left; "Y" roll), turned into
the bone's own frame here, so poses read as plain angles.
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(ROOT, "art_src", "creatures", "cat.blend")
GLB = os.path.join(ROOT, "actors", "models", "cat.glb")
MASK_PNG = os.path.join(ROOT, "actors", "models", "cat_coat.png")
COAT_TEXELS = 96.0       # texels per metre
TEX = 256                # mask size (square)
SIDES = 8                # ring sides
FPS = 24

# --- the skeleton: name, head, tail (y forward, z up), parent ---------------
L, R = 1.0, -1.0
BONES = [
    ("root", (0, -0.02, 0.0), (0, 0.06, 0.0), None),
    ("hips", (0, -0.13, 0.2), (0, 0.0, 0.203), "root"),
    ("chest", (0, 0.0, 0.203), (0, 0.125, 0.21), "hips"),
    ("neck", (0, 0.125, 0.21), (0, 0.175, 0.256), "chest"),
    ("head", (0, 0.175, 0.256), (0, 0.25, 0.26), "neck"),
]
TAIL = [(0, -0.15 - 0.056 * i, 0.215 - 0.006 * i) for i in range(6)]
for i in range(5):
    BONES.append(("tail%d" % (i + 1), TAIL[i], TAIL[i + 1], "hips" if i == 0 else "tail%d" % i))
for side, x in (("l", -0.034), ("r", 0.034)):
    # Front: shoulder, elbow, wrist, toe.
    f = [(x, 0.105, 0.185), (x, 0.098, 0.11), (x, 0.102, 0.03), (x, 0.126, 0.004)]
    BONES += [("upper_" + side, f[0], f[1], "chest"), ("lower_" + side, f[1], f[2], "upper_" + side),
              ("paw_" + side, f[2], f[3], "lower_" + side)]
    xh = x * 1.32
    h = [(xh, -0.105, 0.19), (xh, -0.074, 0.112), (xh, -0.12, 0.068), (xh, -0.106, 0.004)]
    BONES += [("thigh_" + side, h[0], h[1], "hips"), ("shin_" + side, h[1], h[2], "thigh_" + side),
              ("foot_" + side, h[2], h[3], "shin_" + side)]


class Coat:
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
        assert self.y + h <= TEX, "coat mask full"
        return r

    def paint(self, r, fn):
        x0, y0, w, h = r
        for y in range(h):
            for x in range(w):
                if 0 <= y0 + y < TEX:
                    self.px[y0 + y][x0 + x] = fn((x + 0.5) / w, y, w, h)


def stripes(s, t, period, width, wobble, top=0.32):
    """Tabby bands across a part: s round (0 top), t texels along."""
    around = min(s, 1.0 - s)                     # 0 on top, 0.5 underneath
    if around > top:
        return 0.0
    phase = (t + wobble * math.sin(s * math.tau * 2.0)) / period
    return 1.0 if (phase - math.floor(phase)) < width else 0.0


def belly(s, k=0.36):
    return 1.0 if min(s, 1.0 - s) > k else 0.0


def rows_of(path, radii, dens=1.0, surf=False):
    """Texel row of each ring along a tube; surf: measured along its skin."""
    out = [0.0]
    for i in range(1, len(path)):
        step = (Vector(path[i]) - Vector(path[i - 1])).length
        if surf:
            step = math.hypot(step, radii[i] - radii[i - 1])
        out.append(out[-1] + step * COAT_TEXELS * dens)
    return out


def build_mesh(coat):
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    part = bm.verts.layers.int.new("part")
    parts = []        # [bone names]

    def tube(path, radii, bones, fn, sx=1.0, up=Vector((0, 0, 1)), cap0=True, cap1=True, start_s=0.0, dens=1.0, surf=False):
        pid = len(parts)
        parts.append(bones)
        path = [Vector(p) for p in path]
        n = len(path)
        rows = rows_of(path, radii, dens, surf)
        circ = max(math.tau * max(radii) * (1.0 + sx) / 2.0, 0.02)
        w = int(round(circ * COAT_TEXELS * dens))
        h = int(round(rows[-1])) + 1
        r = coat.region(w, h)
        coat.paint(r, fn)
        rings = []
        for i, p in enumerate(path):
            t = (path[min(i + 1, n - 1)] - path[max(i - 1, 0)]).normalized()
            u = up - t * up.dot(t)
            if u.length < 1e-4:
                u = Vector((0, 1, 0)) - t * t.y
            u.normalize()
            side = t.cross(u).normalized()
            ring = []
            for k in range(SIDES):
                a = math.tau * (k / SIDES + start_s)
                v = bm.verts.new(p + u * math.cos(a) * radii[i] + side * math.sin(a) * radii[i] * sx)
                v[part] = pid
                ring.append(v)
            rings.append(ring)

        def uv(k, i):
            # Mask rows run top down; Blender's V runs bottom up.
            return ((r[0] + r[2] * k / SIDES) / TEX, 1.0 - (r[1] + min(rows[i], r[3] - 0.5)) / TEX)

        for i in range(n - 1):
            for k in range(SIDES):
                k1 = (k + 1) % SIDES
                f = bm.faces.new([rings[i][k], rings[i][k1], rings[i + 1][k1], rings[i + 1][k]])
                for lp, (kk, ii) in zip(f.loops, ((k, i), (k + 1, i), (k + 1, i + 1), (k, i + 1))):
                    lp[uvl].uv = uv(kk, ii)
        for end, cap in ((0, cap0), (n - 1, cap1)):
            if not cap:
                continue
            c = bm.verts.new(path[end] + (path[end] - path[1 if end == 0 else n - 2]).normalized() * radii[end] * 0.35)
            c[part] = pid
            for k in range(SIDES):
                k1 = (k + 1) % SIDES
                vs = [rings[end][k], rings[end][k1], c] if end == n - 1 else [rings[end][k1], rings[end][k], c]
                f = bm.faces.new(vs)
                for lp, kk in zip(f.loops, (k, k + 1, k + 0.5) if end == n - 1 else (k + 1, k, k + 0.5)):
                    lp[uvl].uv = uv(kk, end)
        tube.rings = rings
        return pid

    # Body, rump to chest: tabby on top, pale belly.
    tube([(0, -0.172, 0.2), (0, -0.13, 0.2), (0, -0.05, 0.195), (0, 0.03, 0.193), (0, 0.1, 0.198), (0, 0.15, 0.215)],
         [0.038, 0.074, 0.082, 0.08, 0.077, 0.048], ["hips", "chest"], lambda s, t, w, h: (stripes(s, t, 5.0, 0.42, 1.4), belly(s), 0.0), sx=0.82)
    # Neck: pale throat.
    tube([(0, 0.1, 0.212), (0, 0.145, 0.24), (0, 0.185, 0.264)], [0.06, 0.054, 0.047], ["chest", "neck", "head"],
         lambda s, t, w, h: (stripes(s, t, 4.0, 0.4, 0.8, 0.2), belly(s, 0.26), 0.0), sx=0.9, cap0=False, cap1=False)
    # --- the head: not a tube. A wide skull (broad cheeks, a flat top between
    # the ears), a flat face that looks forward with the eyes on it, a small
    # muzzle standing out low on the face, big ears on the top corners. Painted
    # at twice the coat's texel density so the face can be drawn.
    def loft(shapes, bones, fn, dens=2.0, cap0=True, cap1=True, tip=None):
        """Rings of SIDES points each, skinned in order; flat caps."""
        pid = len(parts)
        parts.append(bones)
        n = len(shapes)
        rows = [0.0]
        for i in range(1, n):
            step = sum((shapes[i][k] - shapes[i - 1][k]).length for k in range(SIDES)) / SIDES
            rows.append(rows[-1] + step * COAT_TEXELS * dens)
        girth = max(sum((s[k] - s[(k + 1) % SIDES]).length for k in range(SIDES)) for s in shapes)
        r = coat.region(int(round(girth * COAT_TEXELS * dens)), int(round(rows[-1])) + 1)
        loft.rows = rows
        coat.paint(r, fn)
        rings = []
        for s in shapes:
            ring = []
            for p in s:
                v = bm.verts.new(p)
                v[part] = pid
                ring.append(v)
            rings.append(ring)

        def uv(k, i):
            return ((r[0] + r[2] * k / SIDES) / TEX, 1.0 - (r[1] + min(rows[i], r[3] - 0.5)) / TEX)

        for i in range(n - 1):
            for k in range(SIDES):
                k1 = (k + 1) % SIDES
                f = bm.faces.new([rings[i][k], rings[i][k1], rings[i + 1][k1], rings[i + 1][k]])
                for lp, (kk, ii) in zip(f.loops, ((k, i), (k + 1, i), (k + 1, i + 1), (k, i + 1))):
                    lp[uvl].uv = uv(kk, ii)
        for end, cap in ((0, cap0), (n - 1, cap1)):
            if not cap:
                continue
            c = bm.verts.new(tip if (tip is not None and end == n - 1) else sum(shapes[end], Vector()) / SIDES)
            c[part] = pid
            for k in range(SIDES):
                k1 = (k + 1) % SIDES
                vs = [rings[end][k], rings[end][k1], c] if end == n - 1 else [rings[end][k1], rings[end][k], c]
                f = bm.faces.new(vs)
                for lp, kk in zip(f.loops, (k, k + 1, k + 0.5) if end == n - 1 else (k + 1, k, k + 0.5)):
                    lp[uvl].uv = uv(kk, end)
        return pid, rows

    HZ = 0.277                                       # the head's middle height

    def skull(y, k, z=0.0, face=False):
        """One outline of the head at y: flat top, wide cheeks, narrow chin."""
        if face:
            pts = [(0.03, 0.042, 0.0), (0.056, 0.012, -0.024), (0.052, -0.024, -0.024), (0.026, -0.046, -0.004)]
        else:
            pts = [(0.034, 0.056, 0.0), (0.07, 0.014, 0.0), (0.064, -0.03, 0.0), (0.03, -0.056, 0.0)]
        half = [Vector((x * k, y + dy, HZ + z + h * k)) for x, h, dy in pts]
        return half + [Vector((-p.x, p.y, p.z)) for p in reversed(half)]
    HS = [skull(0.15, 0.45), skull(0.168, 0.86), skull(0.194, 1.0), skull(0.214, 0.98), skull(0.246, 1.0, -0.002, True)]
    FACE_MID = Vector((0, 0.251, HZ - 0.002))        # the face is two halves meeting on this ridge

    def head(s, t, w, h):
        true = (s + 0.0625) % 1.0
        around = min(true, 1.0 - true)               # 0 the top's middle, 0.5 the chin's
        if t >= loft.rows[3]:
            return (0.0, 1.0 if around > 0.3125 else 0.0, 0.0)       # the face: pale below the eyes
        bar = 1.0 if (t > loft.rows[1] and around < 0.19 and int(t / 3) % 2 == 0) else 0.0
        return (bar, 1.0 if around > 0.4375 else 0.0, 0.0)
    head_pid, HROW = loft(HS, ["head"], head, tip=FACE_MID)

    # The muzzle: two small pads side by side low on the face and a chin under
    # them, all pale; a flat pink nose between the pads' tops, a dark line
    # down from it.
    pale_fn = lambda s, t, w, h: (0.0, 1.0, 0.0)
    for x in (-1, 1):
        tube([(0.012 * x, 0.234, 0.259), (0.012 * x, 0.254, 0.258), (0.012 * x, 0.26, 0.258)], [0.017, 0.0145, 0.008], ["head"], pale_fn,
             sx=1.15, cap0=False, dens=2.0, surf=True)
    tube([(0, 0.234, 0.243), (0, 0.25, 0.243), (0, 0.255, 0.243)], [0.013, 0.011, 0.006], ["head"], pale_fn, cap0=False, dens=2.0, surf=True)

    def flat(points, code):
        """A flat piece of one mask colour."""
        fr = coat.region(2, 2)
        coat.paint(fr, lambda s, t, w, h: code)
        vs = []
        for p in points:
            v = bm.verts.new(Vector(p))
            v[part] = head_pid
            vs.append(v)
        f = bm.faces.new(vs)
        f.normal_update()
        if f.normal.y < 0:
            f.normal_flip()
        for lp in f.loops:
            lp[uvl].uv = ((fr[0] + 1.0) / TEX, 1.0 - (fr[1] + 1.0) / TEX)
    flat([(-0.0095, 0.2632, 0.2705), (0.0095, 0.2632, 0.2705), (0, 0.265, 0.2595)], (0.0, 0.0, 0.5))
    flat([(-0.0016, 0.2647, 0.2595), (0.0016, 0.2647, 0.2595), (0, 0.262, 0.2475)], (1.0, 0.0, 0.5))

    # Eyes: almond, 12 x 8 fine texels, drawn rising to the outer corner, each on
    # its own half of the face (the halves turn outward, so an eye shows from
    # the side too). Dark rim, a tall pupil, one white glint.
    EYE = ["......XXXX..",
           "....XXiiiiX.",
           "..XXiiPPiiiX",
           ".XiiigPPPiiX",
           "XiiiiPPPPiiX",
           "XXiiiPPPPiX.",
           "..XXiiPPXX..",
           "....XXXX...."]

    def eye(s, t, w, h):
        y = min(int(t), 7)
        ch = EYE[y][min(int(s * w), 11)]
        if ch == ".":
            return (0.0, 0.0, 0.0)
        # R: 1 the rim, 0.6 the pupil. G: 1 the glint, 0.5 the row that shows
        # as a dark line when the eye is shut (asleep, blinking).
        g = 1.0 if ch == "g" else (0.5 if y == 4 else 0.0)
        return ({"X": 1.0, "P": 0.6, "i": 0.0, "g": 0.0}[ch], g, 1.0)
    er = coat.region(12, 8)
    coat.paint(er, eye)
    for x in (-1, 1):
        a, b = Vector((0.03 * x, 0.246, HZ + 0.04)), Vector((0.056 * x, 0.222, HZ + 0.01))
        n = (a - FACE_MID).cross(b - FACE_MID).normalized()
        if n.y < 0:
            n = -n
        # The point of that half's plane at the eye's place.
        ex, ez = 0.032 * x, HZ + 0.015
        ey = FACE_MID.y - (n.x * (ex - FACE_MID.x) + n.z * (ez - FACE_MID.z)) / n.y
        mid = Vector((ex, ey, ez)) + n * 0.0018
        up_f = (Vector((0, 0, 1)) - n * n.z).normalized()
        right = up_f.cross(n).normalized()
        if right.x < 0:
            right = -right
        tilt = Quaternion(n, math.radians(0.0))      # outer corner up
        up_f, right = tilt @ up_f, tilt @ right
        corners = [(-1, 1, 0, 0), (1, 1, 1, 0), (1, -1, 1, 1), (-1, -1, 0, 1)]
        vs = []
        for cx, cy, u, v in corners:
            vert = bm.verts.new(mid + right * cx * 0.0205 + up_f * cy * 0.0137)
            vert[part] = head_pid
            vs.append(vert)
        f = bm.faces.new(vs)
        f.normal_update()
        if f.normal.dot(n) < 0:
            f.normal_flip()
        for lp in f.loops:
            cx, cy, u, v = corners[vs.index(lp.vert)]
            lp[uvl].uv = ((er[0] + er[2] * (u if x > 0 else 1 - u)) / TEX, 1.0 - (er[1] + er[3] * v) / TEX)
    # Whiskers: three thin slivers a side, pale, fanned out from the muzzle.
    wr = coat.region(2, 2)
    coat.paint(wr, lambda s, t, w, h: (0.0, 1.0, 0.0))
    wuv = ((wr[0] + 1.0) / TEX, 1.0 - (wr[1] + 1.0) / TEX)
    for x in (-1, 1):
        for dz, back in ((0.022, 0.02), (0.002, 0.01), (-0.018, 0.018)):
            root = Vector((0.03 * x, 0.25, 0.26 + dz * 0.2))
            tip = Vector((0.1 * x, 0.246 - back, 0.26 + dz))
            vs = [bm.verts.new(root + Vector((0, 0, 0.002))), bm.verts.new(root - Vector((0, 0, 0.002))), bm.verts.new(tip)]
            for v in vs:
                v[part] = head_pid
            f = bm.faces.new(vs)
            for lp in f.loops:
                lp[uvl].uv = wuv
    # Ears: big triangles on the head's top corners, turned forward and a
    # little outward, skin inside.
    for x in (-1, 1):
        base = Vector((0.045 * x, 0.196, HZ + 0.03))
        tip = Vector((0.066 * x, 0.19, HZ + 0.094))
        tube([base, base.lerp(tip, 0.5), tip], [0.038, 0.021, 0.002], ["head"],
             lambda s, t, w, h, sc=(0.25 if x > 0 else 0.75): ((0.12, 0.0, 0.5) if abs(s - sc) < 0.15 else (0.6, 0.0, 0.0)), sx=0.5,
             up=Vector((0.8 * x, -0.6, 0)), cap0=False, cap1=False)
    # Tail: rings, a dark tip.
    tube(TAIL[:1] + [Vector(TAIL[i]).lerp(Vector(TAIL[i + 1]), 0.5) for i in range(5)] + TAIL[5:],
         [0.023, 0.022, 0.02, 0.019, 0.017, 0.016, 0.013], ["hips", "tail1", "tail2", "tail3", "tail4", "tail5"],
         lambda s, t, w, h: (1.0 if t > h - 4 else stripes(s, t, 4.0, 0.45, 0.0, 0.5), 0.0, 0.0), up=Vector((0, 0, 1)))
    # Legs: bands up top, pale paws ("socks").
    bones = {b[0]: b for b in BONES}
    for side in ("l", "r"):
        def leg_fn(s, t, w, h):
            return (stripes(s, t, 6.0, 0.3, 0.0, 0.5) if 4 < t < h - 6 else 0.0, 1.0 if t >= h - 4 else 0.0, 0.0)
        # The tops start inside the body, so a leg grows out of it.
        up_f = [Vector(bones["upper_" + side][1]) + Vector((0, 0.004, 0.03)), Vector(bones["upper_" + side][1]), Vector(bones["upper_" + side][2]), Vector(bones["lower_" + side][2]), Vector(bones["paw_" + side][2])]
        tube(up_f, [0.031, 0.03, 0.026, 0.021, 0.023], ["chest", "upper_" + side, "lower_" + side, "paw_" + side], leg_fn,
             sx=0.85, up=Vector((0, 1, 0)), cap0=False)
        # A broad flat haunch on the body's side, down to a thin hock.
        hl = [Vector(bones["thigh_" + side][1]) + Vector((0, -0.005, 0.03)), Vector(bones["thigh_" + side][1]), Vector(bones["thigh_" + side][2]), Vector(bones["shin_" + side][2]), Vector(bones["foot_" + side][2])]
        tube(hl, [0.046, 0.05, 0.034, 0.021, 0.022], ["hips", "thigh_" + side, "shin_" + side, "foot_" + side], leg_fn,
             sx=0.62, up=Vector((0, 1, 0)), cap0=False)
    bm.normal_update()
    return bm, part, parts


def armature():
    data = bpy.data.armatures.new("cat_rig")
    ob = bpy.data.objects.new("cat", data)
    bpy.context.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    for name, head, tail, parent in BONES:
        e = data.edit_bones.new(name)
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


def skin(mesh_ob, part_layer, parts, rig):
    me = mesh_ob.data
    groups = {b[0]: mesh_ob.vertex_groups.new(name=b[0]) for b in BONES}
    segs = {b[0]: (Vector(b[1]), Vector(b[2])) for b in BONES}
    pids = me.attributes["part"].data
    for v in me.vertices:
        allowed = parts[pids[v.index].value]
        ws = sorted(((1.0 / (seg_distance(v.co, *segs[b]) + 0.004) ** 4, b) for b in allowed), reverse=True)[:2]
        total = sum(w for w, _ in ws)
        for w, b in ws:
            groups[b].add([v.index], w / total, "REPLACE")
    mod = mesh_ob.modifiers.new("rig", "ARMATURE")
    mod.object = rig
    mesh_ob.parent = rig


def coat_material(coat):
    img = bpy.data.images.new("cat_coat", TEX, TEX, alpha=False)
    flat = []
    for y in range(TEX):                  # Blender images start at the bottom row
        for x in range(TEX):
            r, g, b = coat.px[TEX - 1 - y][x]
            flat += [r, g, b, 1.0]
    img.pixels = flat
    # Also as its own file: the game's shader reads the mask from there,
    # imported lossless (a compressed mask would smear the 0 / 0.5 / 1 codes).
    img.filepath_raw = MASK_PNG
    img.file_format = "PNG"
    img.save()
    img.pack()
    m = bpy.data.materials.new("cat_coat")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.9
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


def key(rig, frame, pose, root_z=0.0, root_y=0.0):
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = local_q(rig, pb.name, pose.get(pb.name, []))
        pb.location = Vector()
        pb.keyframe_insert("rotation_quaternion", frame=frame)
    root = rig.pose.bones["root"]
    # The root bone points +Y: its frame has local Y = world Y, Z = world -Z... so
    # move it in world terms through its rest matrix.
    inv = rig.data.bones["root"].matrix_local.to_3x3().inverted()
    root.location = inv @ Vector((0.0, root_y, root_z))
    root.keyframe_insert("location", frame=frame)
    for pb in rig.pose.bones:
        if pb.name != "root":
            pb.keyframe_insert("location", frame=frame)


def merge(*poses):
    out = {}
    for p in poses:
        for b, turns in p.items():
            out[b] = out.get(b, []) + list(turns)
    return out


def tail_curl(base, step, axis="Z", first=None):
    p = {"tail%d" % (i + 1): [(axis, step)] for i in range(5)}
    if first:
        p["tail1"] = list(first) + p["tail1"]
    return p


def stand(t=0.0):
    """Standing, breathing, tail low with a lift at the end."""
    b = math.sin(t * math.tau)
    return merge({"chest": [("X", 0.8 * b)], "neck": [("X", 4)], "head": [("X", -4 - 0.8 * b)]},
                 tail_curl(0, -11 - 3 * b, "X", [("X", 62), ("Z", 6 * math.sin(t * math.tau))]))


def sit_pose(lift=0.0):
    """Sitting upright: haunches down, front legs straight under the chest."""
    p = {
        "hips": [("X", 50)], "chest": [("X", -35)], "neck": [("X", 2)], "head": [("X", -17)],
        "upper_l": [("X", -15)], "upper_r": [("X", -15)], "lower_l": [("X", 0)], "lower_r": [("X", 0)],
        "paw_l": [("X", 0)], "paw_r": [("X", 0)],
        "thigh_l": [("X", 24)], "thigh_r": [("X", 24)], "shin_l": [("X", -53)], "shin_r": [("X", -53)],
        "foot_l": [("X", 57)], "foot_r": [("X", 57)],
    }
    return merge(p, tail_curl(0, 26, "Z", [("X", -34), ("Z", 30)]))


def walk(t):
    """A lateral-sequence walk: left hind, left fore, right hind, right fore."""
    p = {}
    for leg, phase, front in (("l", 0.0, False), ("l", 0.25, True), ("r", 0.5, False), ("r", 0.75, True)):
        a = (t + phase) * math.tau
        swing = math.sin(a)
        lift = max(0.0, math.cos(a))           # moving forward: the foot is up
        if front:
            p["upper_" + leg] = [("X", 24 * swing)]
            p["lower_" + leg] = [("X", -42 * lift)]
            p["paw_" + leg] = [("X", 30 * lift - 6 * (1 - lift))]
        else:
            p["thigh_" + leg] = [("X", 22 * swing)]
            p["shin_" + leg] = [("X", -24 * lift)]
            p["foot_" + leg] = [("X", 24 * lift)]
    sway = math.sin(t * math.tau)
    bob = math.sin(t * 2 * math.tau)
    p = merge(p, {"hips": [("Y", 2.5 * sway), ("Z", 2 * sway)], "chest": [("Y", -3 * sway), ("Z", -3 * sway)],
                  "neck": [("X", 6 + 1.5 * bob)], "head": [("X", -6 - 1.5 * bob)]},
              tail_curl(0, 7, "X", [("X", -32), ("Z", 8 * math.sin(t * math.tau + 1.0))]))
    return p, 0.004 * bob


def sleep_pose(t=0.0):
    """Lying on its belly, legs folded under, curled a little to one side,
    chin down, the tail brought round."""
    b = math.sin(t * math.tau)
    p = {
        "hips": [("Z", -14)], "chest": [("Z", 12), ("X", 1.2 * b)], "neck": [("Z", 26), ("X", -30)],
        "head": [("Z", 22), ("X", -14)],
        "upper_l": [("X", 62)], "upper_r": [("X", 66)], "lower_l": [("X", -150)], "lower_r": [("X", -150)],
        "paw_l": [("X", 70)], "paw_r": [("X", 70)],
        "thigh_l": [("X", 58)], "thigh_r": [("X", 58)], "shin_l": [("X", -120)], "shin_r": [("X", -120)],
        "foot_l": [("X", 60)], "foot_r": [("X", 60)],
    }
    return merge(p, tail_curl(0, 34, "Z", [("X", 4), ("Z", 30)]))


def wash(t):
    """Sitting, one forepaw up at the mouth, licking it, the head bobbing."""
    lick = math.sin(t * math.tau * 2.0)
    p = sit_pose()
    p = dict(p)
    p["upper_r"] = [("X", 62), ("Z", 8)]
    p["lower_r"] = [("X", -96 + 6 * lick)]
    p["paw_r"] = [("X", 30)]
    p["neck"] = [("X", -12), ("Z", 6)]
    p["head"] = [("X", -34 + 8 * lick), ("Z", 12)]
    return p


def look(t):
    """Standing; turns its head to one side, holds, turns back."""
    k = math.sin(min(1.0, t * 1.0) * math.pi)
    p = stand(0.0)
    p = merge(p, {"neck": [("Z", 28 * k)], "head": [("Z", 26 * k), ("Y", -8 * k), ("X", 6 * k)]})
    return p


def startle(t):
    """Crouch, back up, then a quick hop and the fur (tail) up."""
    crouch = math.sin(min(t / 0.3, 1.0) * math.pi / 2) if t < 0.3 else max(0.0, 1.0 - (t - 0.3) / 0.15)
    hop = math.sin(max(0.0, min((t - 0.3) / 0.35, 1.0)) * math.pi)
    p = {"hips": [("X", -6 * crouch)], "chest": [("X", 10 * crouch + 6 * hop)], "neck": [("X", -12 * crouch)],
         "head": [("X", 10 * crouch)],
         "upper_l": [("X", -14 * crouch + 18 * hop)], "upper_r": [("X", -14 * crouch + 18 * hop)],
         "lower_l": [("X", -30 * crouch)], "lower_r": [("X", -30 * crouch)],
         "thigh_l": [("X", 30 * crouch - 20 * hop)], "thigh_r": [("X", 30 * crouch - 20 * hop)],
         "shin_l": [("X", -40 * crouch + 20 * hop)], "shin_r": [("X", -40 * crouch + 20 * hop)],
         "foot_l": [("X", 20 * crouch)], "foot_r": [("X", 20 * crouch)]}
    p = merge(p, tail_curl(0, -6 * max(crouch, hop), "X", [("X", 20 - 85 * max(crouch, hop))]))
    return p, -0.05 * crouch + 0.1 * hop


def animate(rig):
    rig.animation_data_create()
    made = []

    def action(name, frames, fn):
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        rig.animation_data.action = act
        for f in range(frames + 1):
            t = f / frames
            r = fn(t)
            pose, z, y = (r + (0.0,))[:3] if isinstance(r, tuple) else (r, 0.0, 0.0)
            key(rig, f, pose, z, y)
        made.append(act)

    action("idle-loop", 72, lambda t: stand(t))
    action("walk-loop", 24, walk)
    action("sit-loop", 72, lambda t: (merge(sit_pose(), {"chest": [("X", 0.8 * math.sin(t * math.tau))]}), -0.135))
    action("sleep-loop", 96, lambda t: (sleep_pose(t), -0.108))
    action("wash-loop", 36, lambda t: (wash(t), -0.135))
    action("look", 48, look)
    action("startle", 18, startle)
    rig.animation_data.action = made[0]
    return made


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    os.makedirs(os.path.dirname(GLB), exist_ok=True)
    coat = Coat()
    bm, part_layer, parts = build_mesh(coat)
    me = bpy.data.meshes.new("cat_body")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(coat_material(coat))
    for poly in me.polygons:
        poly.use_smooth = False
    body = bpy.data.objects.new("cat_body", me)
    bpy.context.collection.objects.link(body)
    rig = armature()
    skin(body, part_layer, parts, rig)
    animate(rig)
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    os.makedirs(os.path.dirname(GLB), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    body.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=GLB, export_format="GLB", use_selection=True, export_yup=True, export_apply=False,
        export_texcoords=True, export_normals=True, export_materials="EXPORT", export_lights=False, export_cameras=False,
        export_animations=True, export_animation_mode="ACTIONS", export_skins=True, export_def_bones=False,
        export_force_sampling=True, export_optimize_animation_size=False)
    print("creature_cat: %d verts, %d faces, %d bones -> %s" % (len(me.vertices), len(me.polygons), len(BONES), os.path.relpath(GLB, ROOT)))


main()
