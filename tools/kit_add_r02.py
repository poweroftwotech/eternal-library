"""Creates or extends art_src/kit/kit_stacks.blend: the Stack Galleries' own
lights (stacks rework part 2, 2026-11-04). Your note: fewer lights hung from
the ceiling; candles, table lamps, torches and glowing plants instead, slightly
spooky but never dangerous.

  blender --background --factory-startup --python tools/kit_add_r02.py

Additive like kit_add_dressing.py (only modules not yet in the file are built;
REBUILD bumps a revision). Then run tools/export_kit.bat kit_stacks.blend.

Every piece is family "dressing", origin on the floor at the face of the pier
between two bays (Blender axes: the corridor is +Y, up is +Z), so the gallery
grammar places them all the same way (slot light:*). The flame meshes use
emit_* materials, so LampState can gutter or darken them with the light.
"""
import math
import os
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit_blender import add_box, add_lathe, add_ngon_prism, add_prism, add_tube, arch_outline, marker, mesh_object, module, rebuild  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(ROOT, "art_src", "kit", "kit_stacks.blend")
LAMP_SOCKET = {"socket_set": "lamp_state", "socket_mode": "state"}


def props(tags):
    return {"kit_shape": "free", "kit_family": "dressing", "size_cells": [0, 0, 0],
            "edge": "", "tags": tags, "weight": 1.0}




def lathe_at(bm, profile, x, y, z, segs=10, mat=0):
    """add_lathe with the profile lifted by z."""
    add_lathe(bm, [(r, h + z) for (r, h) in profile], cx=x, cy=y, segs=segs, mat=mat)


# --- a brass wall sconce: the kept stacks -------------------------------------

def stack_sconce(r):
    """A brass back plate on the pier, an arm out, an oil lamp bowl with a
    glass chimney and its flame at 2.3 m."""
    bm = bmesh.new()
    add_box(bm, -0.09, 0.09, 0.0, 0.03, 1.95, 2.45, 0)              # back plate
    add_box(bm, -0.11, 0.11, 0.0, 0.035, 2.43, 2.47, 0)             # its cap
    add_tube(bm, [(0.0, 0.03, 2.05), (0.0, 0.16, 2.08), (0.0, 0.28, 2.16), (0.0, 0.3, 2.2)], 0.014, mat=0)
    lathe_at(bm, [(0.0, 0.0), (0.05, 0.01), (0.09, 0.05), (0.1, 0.08), (0.05, 0.1)], 0.0, 0.3, 2.18, mat=0)   # bowl
    fl = bmesh.new()
    lathe_at(fl, [(0.0, 0.0), (0.022, 0.03), (0.014, 0.07), (0.0, 0.1)], 0.0, 0.3, 2.29, segs=6)
    mesh_object("stack_sconce__body", bm, ["brass"], r)
    mesh_object("stack_sconce__flame", fl, ["emit_lantern"], r)
    marker("LIGHT_sconce__stack", r, (0.0, 0.42, 2.35))     # rev 3: back by the pier (your walk: keep the glare, shorten the reach)
    marker("SOCKET_lamp_state__sconce", r, (0.0, 0.42, 2.35), LAMP_SOCKET)


# --- an iron torch: further out --------------------------------------------------

def stack_torch(r):
    """An iron ring bracket on the pier holding a wooden torch tilted out, its
    head wrapped in pitch-black cloth and burning."""
    bm = bmesh.new()
    add_box(bm, -0.05, 0.05, 0.0, 0.025, 1.6, 2.05, 0)              # strap
    add_tube(bm, [(0.0, 0.02, 1.72), (0.0, 0.14, 1.74)], 0.012, mat=0)
    add_tube(bm, [(0.0, 0.02, 1.95), (0.0, 0.16, 1.98)], 0.012, mat=0)
    ring = [(0.045 * math.cos(a), 0.15 + 0.045 * math.sin(a), 1.85) for a in [i * math.tau / 8 for i in range(9)]]
    add_tube(bm, ring, 0.01, mat=0)
    # The torch: a shaft tilted 18 degrees out from the wall.
    tilt = math.radians(18)
    base = (0.0, 0.12, 1.52)
    top = (0.0, base[1] + math.sin(tilt) * 0.62, base[2] + math.cos(tilt) * 0.62)
    add_tube(bm, [base, top], 0.022, segs=6, mat=1)
    head = (0.0, top[1] + math.sin(tilt) * 0.08, top[2] + math.cos(tilt) * 0.08)
    add_tube(bm, [top, head], 0.04, segs=6, mat=2)
    fl = bmesh.new()
    lathe_at(fl, [(0.0, 0.0), (0.06, 0.06), (0.045, 0.16), (0.02, 0.24), (0.0, 0.3)], head[0], head[1] + 0.02, head[2], segs=6)
    mesh_object("stack_torch__body", bm, ["iron", "wood", "cloth"], r)
    mesh_object("stack_torch__flame", fl, ["emit_ember"], r)
    marker("LIGHT_torch__stack", r, (0.0, head[1] + 0.1, head[2] + 0.2))
    marker("SOCKET_lamp_state__torch", r, (0.0, head[1] + 0.1, head[2] + 0.2), LAMP_SOCKET)


# --- candles at the foot of the pier --------------------------------------------

CANDLES = [(-0.1, 0.12, 0.26), (0.05, 0.08, 0.34), (0.14, 0.18, 0.18), (-0.02, 0.24, 0.12), (-0.17, 0.26, 0.21)]


def candle_group(r, name, lit):
    bm = bmesh.new()
    lathe_at(bm, [(0.0, 0.0), (0.24, 0.0), (0.25, 0.02), (0.22, 0.03), (0.0, 0.03)], 0.0, 0.18, 0.0, segs=12, mat=0)   # brass tray
    fl = bmesh.new()
    for i, (x, y, h) in enumerate(CANDLES):
        hh = h if lit else h * 0.3
        lathe_at(bm, [(0.0, 0.0), (0.03, 0.0), (0.03, hh), (0.024, hh + 0.008), (0.0, hh + 0.004)], x, y, 0.03, segs=8, mat=1)
        # Wax run down the side and pooled on the tray.
        add_box(bm, x + 0.022, x + 0.034, y - 0.006, y + 0.006, 0.03, 0.03 + hh * 0.6, 1)
        lathe_at(bm, [(0.0, 0.0), (0.05, 0.0), (0.045, 0.008), (0.0, 0.01)], x + 0.02, y, 0.03, segs=8, mat=1)
        if lit:
            lathe_at(fl, [(0.0, 0.0), (0.012, 0.015), (0.008, 0.035), (0.0, 0.05)], x, y, 0.03 + hh + 0.01, segs=5)
    if not lit:
        # Spent: a few stubs knocked over and a smear of old wax on the floor.
        add_box(bm, 0.2, 0.3, 0.3, 0.33, 0.0, 0.02, 1)
        add_box(bm, -0.3, -0.1, 0.36, 0.42, 0.0, 0.006, 1)
    mesh_object(name + "__body", bm, ["brass", "wax"], r)
    if lit:
        mesh_object(name + "__flame", fl, ["emit_lantern"], r)
        marker("LIGHT_candle__" + name, r, (0.0, 0.3, 0.55))     # rev 3: back by the pier
        marker("SOCKET_lamp_state__" + name, r, (0.0, 0.3, 0.55), LAMP_SOCKET)


def stack_candles(r):
    candle_group(r, "stack_candles", True)


def stack_candles_spent(r):
    candle_group(r, "stack_candles_spent", False)


# --- an oil lamp on a stool --------------------------------------------------------

def stack_lamp_stool(r):
    """A low wooden stool against the pier with a brass oil lamp on it: someone
    reads here."""
    bm = bmesh.new()
    add_box(bm, -0.22, 0.22, 0.12, 0.5, 0.42, 0.47, 0)             # seat
    for (x, y) in ((-0.19, 0.15), (0.19, 0.15), (-0.19, 0.47), (0.19, 0.47)):
        add_box(bm, x - 0.025, x + 0.025, y - 0.025, y + 0.025, 0.0, 0.42, 0)
    add_box(bm, -0.19, 0.19, 0.29, 0.33, 0.12, 0.15, 0)             # stretcher
    lathe_at(bm, [(0.0, 0.0), (0.05, 0.0), (0.04, 0.02), (0.07, 0.05), (0.04, 0.08), (0.012, 0.09), (0.01, 0.16)], 0.06, 0.3, 0.47, mat=1)
    add_tube(bm, [(0.13, 0.3, 0.54), (0.17, 0.3, 0.55)], 0.012, mat=1)     # spout
    fl = bmesh.new()
    lathe_at(fl, [(0.0, 0.0), (0.015, 0.02), (0.01, 0.045), (0.0, 0.065)], 0.175, 0.3, 0.56, segs=5)
    mesh_object("stack_lamp_stool__body", bm, ["wood", "brass"], r)
    mesh_object("stack_lamp_stool__flame", fl, ["emit_lantern"], r)
    marker("LIGHT_desk__stool", r, (0.15, 0.32, 0.75))
    marker("SOCKET_lamp_state__stool", r, (0.15, 0.32, 0.75), LAMP_SOCKET)


# --- blue glowcaps: the abandoned stacks -----------------------------------------

GLOWCAPS = [(-0.12, 0.14, 0.2, 0.09), (0.04, 0.1, 0.27, 0.11), (0.17, 0.2, 0.14, 0.07), (-0.24, 0.3, 0.1, 0.06),
            (0.02, 0.32, 0.09, 0.05), (0.28, 0.12, 0.11, 0.06), (-0.04, 0.2, 0.06, 0.04)]


def stack_glowcaps(r):
    """A clump of pale mushrooms at the foot of the pier, their caps glowing a
    cold blue, with moss round them: the light of the abandoned stacks."""
    stems = bmesh.new()
    caps = bmesh.new()
    for (x, y, h, cr) in GLOWCAPS:
        lathe_at(stems, [(0.0, 0.0), (cr * 0.35, 0.0), (cr * 0.25, h * 0.5), (cr * 0.22, h), (0.0, h)], x, y, 0.0, segs=6)
        lathe_at(caps, [(0.0, -cr * 0.15), (cr, -cr * 0.05), (cr * 0.9, cr * 0.2), (cr * 0.5, cr * 0.45), (0.0, cr * 0.5)], x, y, h, segs=8)
    moss = bmesh.new()
    add_ngon_prism(moss, 9, 0.38, 0.0, 0.025, cx=0.0, cy=0.2)
    mesh_object("stack_glowcaps__stems", stems, ["linen"], r)
    mesh_object("stack_glowcaps__caps", caps, ["emit_glowcap"], r)
    mesh_object("stack_glowcaps__moss", moss, ["moss"], r)
    marker("LIGHT_glowcap__stack", r, (0.0, 0.35, 0.45))
    marker("SOCKET_lamp_state__glowcap", r, (0.0, 0.35, 0.45), LAMP_SOCKET)


# --- part 3: the rock the stacks are carved in, and standing water --------------

def recess_half(z):
    """Half-width of the gallery's shelf recess (arch_outline(3.0, 1.9)) at height z."""
    if z <= 1.9:
        return 1.5
    rr = 1.8
    return 1.5 - (rr - math.sqrt(max(0.0, rr * rr - (z - 1.9) ** 2)))


def _lump(x, z, seed):
    """Smooth pseudo-noise for the rock face: a few summed sines (no Python
    random field needed, so every rebuild is the same)."""
    return (0.5 * math.sin(1.7 * x + 0.9 * z + seed) + 0.3 * math.sin(3.1 * x - 2.3 * z + 2.0 * seed)
            + 0.2 * math.sin(5.3 * x + 4.1 * z - seed))


def stack_rock_breach(r):
    """A shelf recess where the brick lining has fallen away and the raw rock
    the stacks are carved from shows (stacks rework part 3, your note: the
    stacks are caves carved into solid rock). Fills the recess (x -1.5..1.5,
    up into the arch; recess back at y -0.3): a lumpy rock face bulging up to
    0.2 m forward, with a few loose bricks still clinging round the edge.
    The gallery grammar lays a rubble strip at its foot."""
    rock = bmesh.new()
    nx, nz = 18, 24
    top = 1.9 + math.sqrt(1.8 ** 2 - 0.3 ** 2) - 0.02
    rows = []
    for j in range(nz + 1):
        z = top * j / nz
        hw = recess_half(z) - 0.01
        row = []
        for i in range(nx + 1):
            u = i / nx
            x = -hw + 2.0 * hw * u
            edge = min(u, 1.0 - u, (top - z) / top * 3.0, 1.0) if j < nz else 0.0
            # rev 2: in front of the recess's wooden back everywhere (rev 1
            # sank behind it at the edges and read as a blob), bulging more.
            depth = 0.16 + 0.13 * _lump(x, z, 1.3)
            y = -0.2 + max(0.02, depth) * min(1.0, 0.35 + edge * 3.0)
            row.append(rock.verts.new((x, y, z)))
        rows.append(row)
    for j in range(nz):
        for i in range(nx):
            # Winding so the faces look out of the recess (+Y).
            rock.faces.new((rows[j][i], rows[j + 1][i], rows[j + 1][i + 1], rows[j][i + 1]))
    mesh_object("stack_rock_breach__rock", rock, ["cave_rock"], r, recalc=False)
    # Loose bricks still in place round the edge of the breach.
    bricks = bmesh.new()
    for (x, z) in ((-1.42, 0.35), (-1.38, 0.62), (1.4, 0.2), (1.42, 0.48), (-1.4, 1.5), (1.37, 1.7),
                   (-1.25, 2.55), (1.18, 2.8), (-1.36, 0.08), (1.3, 1.12)):
        w = 0.22 if abs(x) > 1.3 else 0.2
        sx = 1.0 if x > 0 else -1.0
        x0 = x - w * 0.5 * sx
        add_box(bricks, min(x0, x + w * 0.5 * sx), max(x0, x + w * 0.5 * sx), -0.3, -0.06, z, z + 0.09)
    mesh_object("stack_rock_breach__bricks", bricks, ["brick"], r)


def _puddle(bm, n, rad, seed, z, cx=0.0, cy=0.0, squash=0.65):
    """A flat, irregular blob of n points round (cx, cy) at height z (faces up)."""
    pts = []
    for i in range(n):
        a = 2.0 * math.pi * i / n
        k = 1.0 + 0.22 * math.sin(3 * a + seed) + 0.12 * math.sin(5 * a - 2 * seed)
        pts.append(bm.verts.new((cx + rad * k * math.cos(a), cy + rad * squash * k * math.sin(a), z)))
    bm.faces.new(pts)


def stack_puddle(seed, rad):
    def build(r):
        """A shallow pool of seep water on the floor with a darker wet ring
        round it (part 3, your note: drips and small pools here and there).
        No collision: you walk through it. A StackDrips node (added by the
        wrapper scene) drops water into it from the vault."""
        stain = bmesh.new()
        _puddle(stain, 20, rad * 1.35, seed + 0.7, 0.004)
        mesh_object("stack_puddle__stain", stain, ["wet_stain"], r, recalc=False)
        water = bmesh.new()
        _puddle(water, 20, rad, seed, 0.009)
        mesh_object("stack_puddle__water", water, ["puddle"], r, recalc=False)
    return build


# --- part 4: landmarks and the signs of neglect ------------------------------------

def _poly(bm, pts, y0, y1):
    """Closed prism of an XZ outline (any winding) between y0 and y1."""
    area = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in range(len(pts)))
    add_prism(bm, pts if area > 0 else list(reversed(pts)), 0.0, 0.0, y0, y1)


def _edge(side, z0, z1, n=5):
    """Points down the recess's edge on one side (side -1 left, +1 right)."""
    return [(side * recess_half(z0 + (z1 - z0) * i / n), z0 + (z1 - z0) * i / n) for i in range(n + 1)]


NICHE_W = 0.6
NICHE_RECT = 0.42                     # straight sides of a niche below its arch
NICHE_ARCH = arch_outline(NICHE_W, 0.0)[2:-2]     # the pointed top, left to right
NICHE_H = NICHE_RECT + max(v for (_u, v) in NICHE_ARCH) + 0.03
TAG_ROWS = [(0.45, (-0.85, 0.0, 0.85)), (1.4, (-0.85, 0.0, 0.85)), (2.35, (0.0,))]
TAG_FRONT, TAG_BACK = 0.04, -0.24


def stack_taghcheh(r):
    """A landmark recess: a lime-plastered wall of taghcheh, small pointed
    niches in rows (three, three, one), holding jars, a lamp and a few books
    (stacks rework part 4: landmark bays you can find your way by). Fills the
    shelf recess (x -1.5..1.5, up into the arch); the face stands 0.04 proud
    of the recess back's line, the niches 0.28 deep."""
    face = bmesh.new()
    top = 1.9 + math.sqrt(1.8 ** 2 - 0.3 ** 2) - 0.02
    add_box(face, -1.49, 1.49, TAG_BACK - 0.03, TAG_BACK, 0.0, 1.9)                 # the niches' back
    _poly(face, _edge(-1, 1.9, top, 8) + list(reversed(_edge(1, 1.9, top, 8))), TAG_BACK - 0.03, TAG_BACK)
    z = 0.0
    for (b, cols) in TAG_ROWS:
        # The solid band under the row, then the piers between its niches
        # and the spandrel over each niche's arch.
        _poly(face, _edge(-1, z, b) + list(reversed(_edge(1, z, b))), TAG_BACK, TAG_FRONT)
        t = b + NICHE_H
        edges = [-9.0] + [x for c in cols for x in (c - NICHE_W / 2, c + NICHE_W / 2)] + [9.0]
        for i in range(0, len(edges), 2):
            x0, x1 = edges[i], edges[i + 1]
            left = _edge(-1, b, t) if x0 < -5 else [(x0, b), (x0, t)]
            right = _edge(1, b, t) if x1 > 5 else [(x1, b), (x1, t)]
            _poly(face, left + list(reversed(right)), TAG_BACK, TAG_FRONT)
        for c in cols:
            x0 = c - NICHE_W / 2
            s = b + NICHE_RECT
            pts = [(x0, t), (x0 + NICHE_W, t), (x0 + NICHE_W, s)]
            pts += [(x0 + u, s + v) for (u, v) in reversed(NICHE_ARCH)]
            pts += [(x0, s)]
            _poly(face, pts, TAG_BACK, TAG_FRONT)
        z = t
    _poly(face, _edge(-1, z, top, 8) + list(reversed(_edge(1, z, top, 8))), TAG_BACK, TAG_FRONT)
    mesh_object("stack_taghcheh__face", face, ["persian_plaster_lime"], r)
    # A tile band framing the niches, at the top of the plinth.
    trim = bmesh.new()
    add_box(trim, -1.49, 1.49, TAG_FRONT, TAG_FRONT + 0.015, 0.36, 0.42)
    mesh_object("stack_taghcheh__trim", trim, ["persian_tile"], r)
    # What the niches hold: jars, a stack of books, a small oil lamp.
    jars = bmesh.new()
    books = bmesh.new()
    lamp = bmesh.new()
    y = (TAG_BACK + TAG_FRONT) / 2
    for (b, cols) in TAG_ROWS:
        for k, c in enumerate(cols):
            pick = (int(b * 10) + k) % 3
            if pick == 0:
                lathe_at(jars, [(0.0, 0.0), (0.06, 0.0), (0.09, 0.08), (0.08, 0.17), (0.04, 0.22), (0.045, 0.26), (0.0, 0.26)], c - 0.1, y, b)
                lathe_at(jars, [(0.0, 0.0), (0.05, 0.0), (0.07, 0.07), (0.05, 0.13), (0.03, 0.16), (0.0, 0.16)], c + 0.13, y, b)
            elif pick == 1:
                for i, (w, h) in enumerate(((0.32, 0.05), (0.3, 0.045), (0.27, 0.05), (0.24, 0.04))):
                    zz = b + sum(hh for (_w, hh) in ((0.32, 0.05), (0.3, 0.045), (0.27, 0.05), (0.24, 0.04))[:i])
                    add_box(books, c - w / 2 + 0.02 * i, c + w / 2 + 0.02 * i, y - 0.09, y + 0.09, zz, zz + h)
            else:
                lathe_at(lamp, [(0.0, 0.0), (0.05, 0.0), (0.07, 0.03), (0.04, 0.05), (0.0, 0.05)], c, y, b)
                lathe_at(jars, [(0.0, 0.0), (0.07, 0.0), (0.1, 0.12), (0.06, 0.24), (0.0, 0.24)], c + 0.16, y, b)
    mesh_object("stack_taghcheh__jars", jars, ["earthenware"], r)
    mesh_object("stack_taghcheh__books", books, ["linen"], r)
    mesh_object("stack_taghcheh__lamp", lamp, ["brass"], r)
    # rev 2: the oil lamp in the bottom middle niche is lit (a landmark you
    # see from down the gallery), one small candle's light.
    flame = bmesh.new()
    lathe_at(flame, [(0.0, 0.0), (0.018, 0.025), (0.011, 0.06), (0.0, 0.085)], 0.0, y, 0.45 + 0.05, segs=6)
    mesh_object("stack_taghcheh__flame", flame, ["emit_lantern"], r)
    marker("LIGHT_candle_one__taghcheh", r, (0.0, y + 0.12, 0.62))     # rev 3: one small flame (rev 2 blew out the niche)


WEB = [((-1, 2.15), (-1, 3.05), (-0.82, 2.55), 0.22), ((1, 2.35), (1, 2.95), (0.98, 2.62), 0.2)]


def stack_cobwebs(r):
    """Cobwebs across the upper corners of a shelf recess's arch, in front of
    the shelves (part 4: the far stacks nobody tends). Thin sagging sheets
    with a few strands, in the recess's frame (corridor +Y)."""
    sheet = bmesh.new()
    strands = bmesh.new()
    for (a, b, inner, y) in WEB:
        pa = (a[0] * recess_half(a[1]) * 0.99, y, a[1])
        pb = (b[0] * recess_half(b[1]) * 0.99, y, b[1])
        pc = (inner[0], y + 0.02, inner[1])
        mid = ((pa[0] + pb[0] + pc[0]) / 3, y + 0.05, (pa[2] + pb[2] + pc[2]) / 3 - 0.06)     # the sag
        # rev 2: threads, not a sheet (the sheet read as a solid blue
        # triangle): spokes from the hub to the anchors and between them, and
        # four sagging rings round the hub.
        anchors = [pa, pb, pc]
        anchors += [((pa[0] + pb[0]) / 2, y, (pa[2] + pb[2]) / 2), ((pb[0] + pc[0]) / 2, y, (pb[2] + pc[2]) / 2),
                    ((pc[0] + pa[0]) / 2, y, (pc[2] + pa[2]) / 2)]
        anchors = [anchors[0], anchors[3], anchors[1], anchors[4], anchors[2], anchors[5]]
        for p in anchors:
            add_tube(strands, [mid, p], 0.012, segs=3)
        for ring in (0.25, 0.45, 0.65, 0.85):
            pts = [(mid[0] + (p[0] - mid[0]) * ring, mid[1] + (p[1] - mid[1]) * ring - 0.01, mid[2] + (p[2] - mid[2]) * ring - 0.015 * ring)
                   for p in anchors]
            add_tube(strands, pts + [pts[0]], 0.005, segs=3)
    mesh_object("stack_cobwebs__strands", strands, ["cobweb"], r)
    del sheet


ROOTS = [(0.0, 0.0, 1.9), (0.25, 0.12, 1.2), (-0.22, -0.1, 1.5), (0.1, -0.3, 0.8), (-0.4, 0.25, 1.0),
         (0.45, -0.15, 0.6), (-0.05, 0.38, 1.3), (0.32, 0.4, 0.9), (-0.5, -0.3, 0.7), (0.6, 0.15, 1.1),
         (-0.3, 0.55, 0.5), (0.15, -0.55, 1.4)]


def stack_roots(r):
    """Roots that have found a crack in the vault and hang into the
    gallery (part 4: the far stacks are caves under the world). Origin at the
    vault crown; the roots start 0.3 above it, inside the vault, and hang down."""
    bm = bmesh.new()
    for i, (x, y, length) in enumerate(ROOTS):
        pts = []
        n = 6
        for k in range(n + 1):
            t = k / n
            sway = 0.06 * math.sin(3.0 * t + i) * t
            pts.append((x + sway + 0.04 * t * math.cos(i), y + sway * 0.7, 0.3 - (length + 0.3) * t))
        add_tube(bm, pts[:4], 0.06 if i == 0 else 0.035, segs=6)     # rev 2: thicker (rev 1 read as wires)
        add_tube(bm, pts[3:], 0.035 if i == 0 else 0.02, segs=5)
        if length > 1.0:     # a side rootlet
            p = pts[4]
            add_tube(bm, [p, (p[0] + 0.12, p[1] - 0.05, p[2] - 0.25), (p[0] + 0.15, p[1] - 0.04, p[2] - 0.5)], 0.012, segs=3)
    mesh_object("stack_roots__roots", bm, ["camp_root"], r)


MODULES = [
    ("M_stack_sconce", props("brass,light,wall"), stack_sconce),
    ("M_stack_torch", props("iron,wood,light,wall"), stack_torch),
    ("M_stack_candles", props("brass,wax,light,floor"), stack_candles),
    ("M_stack_candles_spent", props("brass,wax,floor"), stack_candles_spent),
    ("M_stack_lamp_stool", props("wood,brass,light,floor"), stack_lamp_stool),
    ("M_stack_glowcaps", props("plant,fungus,light,floor"), stack_glowcaps),
    ("M_stack_rock_breach", props("rock,brick,recess"), stack_rock_breach),
    ("M_stack_puddle_a", props("water,floor"), stack_puddle(0.4, 0.8)),
    ("M_stack_puddle_b", props("water,floor"), stack_puddle(2.1, 0.55)),
    ("M_stack_taghcheh", props("plaster,tile,recess,landmark"), stack_taghcheh),
    ("M_stack_cobwebs", props("web,recess"), stack_cobwebs),
    ("M_stack_roots", props("root,ceiling"), stack_roots),
]


def main():
    if os.path.exists(BLEND):
        bpy.ops.wm.open_mainfile(filepath=BLEND)
    else:
        bpy.ops.wm.read_factory_settings(use_empty=True)
    added = []
    for i, (name, p, build) in enumerate(MODULES):
        if bpy.data.objects.get(name) is None:
            build(module(name, ((i % 6) * 2.0, 0.0, 0.0), p))
            added.append(name)
    REBUILD = [("M_stack_sconce", 4), ("M_stack_candles", 3), ("M_stack_torch", 2), ("M_stack_rock_breach", 2), ("M_stack_puddle_a", 2), ("M_stack_puddle_b", 2), ("M_stack_taghcheh", 3), ("M_stack_cobwebs", 2), ("M_stack_roots", 2)]     # rev 2 moved the lights out; rev 3 back by the pier (walk 1: the glare is wanted, the reach is not); sconce rev 4 re-imports the dimmer profile (walk 4)
    added += ["%s (rebuilt rev %d)" % (n, v) for (n, v) in REBUILD if rebuild(n, v, MODULES)]
    if not added:
        print("kit_add_r02: all modules already present; nothing to do.")
        return
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("kit_add_r02: added %s" % ", ".join(added))


main()
