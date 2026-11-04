"""Seeds the R03 Hypostyle Stacks modules into art_src/kit/kit_hall.blend
(phase-5-design.md 5.6.2 and 5.6.5, step 1).

  blender --background --factory-startup --python tools/kit_add_r03.py

Creates kit_hall.blend if it doesn't exist, then adds only the modules that
are not in it yet. Modules already in the file (including ones you edited by
hand) are never touched, so re-running is safe. Then run tools/export_kit.bat.

The hall's heights: column capitals at 4.0 m (the walls' top), arcade arches
springing there with their crowns at 5.8 m, a band of wall over the
perimeter up to 6.2 m, and a small dome on every bay from 6.2 m to 7.9 m.

New modules (laid out on a row at Blender Y = -40 for viewing):
  post_column_twisted   post: sandstone column with a twisted shaft, base and
                        capital, 0-4 m; a plain box for collision.
  post_hall_pier        post: brick pier at a wall corner of the hall, 0-6.2 m.
  post_hall_pier_cap    post: the pier's top only (4-6.2 m), over a corner
                        where the host room's own pier stands.
  arcade_arch_4m        edge: the spandrel between two columns, 4-6.2 m, with
                        a pointed arch cut from below.
  wall_hall_band_4m     edge: the wall over the hall's perimeter, 4-6.2 m, a
                        cornice at 4 m and a tile band under the domes.
  dome_cell_4m_a / _b   cell: a ceiling slab at 6.2 m with a dome over a
                        3.5 m round opening; _a tiled, _b plaster.
  oculus_cell_4m        cell: the dome with its crown open, and a cold light.
  lantern_dome          free: a lantern 3-3.6 m up on a chain from a dome's
                        crown; carries its light and a lamp_state socket.
  case_freestanding_4m  free (dressing): a double-sided bookcase 3 m long,
                        2.2 m tall, centred in a cell; a case_library socket
                        on each face.
  landmark_plinth       free (dressing): a round step at the hall's centre
                        with a hall_landmark socket (great lamp, reading tree,
                        catalogue desk).
  landmark_great_lamp   free (dressing): a 3.7 m brass lamp stand.
  landmark_catalogue_desk
                        free (dressing): a ring of catalogue cabinets round a
                        librarian's spot (ANCHOR_librarian), with a desk lamp.
"""
import math
import os
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit_blender import (T, add_box, add_lathe, add_ngon_prism, add_tube, add_obox, add_plan_prism, add_prism, arch_outline, cut, rebuild, wall_body,  # noqa: E402
                         marker, mesh_object, module)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(ROOT, "art_src", "kit", "kit_hall.blend")
ROW_Y = -40.0
CAP = 4.0          # column capitals and the walls' top
BAND_TOP = 6.2     # spandrels, perimeter band, dome springing
DOME_R = 1.75      # inner radius of a dome's opening
DOME_CROWN = 7.9   # dome intrados crown
LAMP_SOCKET = {"socket_set": "lamp_state", "socket_mode": "state"}


def props(shape, size, edge, tags, family="walls", weight=1.0):
    return {"kit_shape": shape, "kit_family": family, "size_cells": size,
            "edge": edge, "tags": tags, "weight": weight}


def star_prism(bm, z0, z1, r_out, r_in, points, twist, mat=0):
    """A fluted shaft segment: a star outline of `points` ridges, turned by `twist`."""
    n = points * 2
    pts = [((r_out if i % 2 == 0 else r_in) * math.cos(twist + math.pi * i / points),
            (r_out if i % 2 == 0 else r_in) * math.sin(twist + math.pi * i / points)) for i in range(n)]
    a = [bm.verts.new((x, y, z0)) for (x, y) in pts]
    b = [bm.verts.new((x, y, z1)) for (x, y) in pts]
    bm.faces.new(list(reversed(a))).material_index = mat
    bm.faces.new(b).material_index = mat
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i])).material_index = mat


def revolve_loop(bm, loop, cx, cy, segs, mat=0):
    """A closed profile loop [(radius, z), ...] revolved round (cx, cy): a closed
    shell with a hole where the loop never reaches radius 0 (domes, rings)."""
    rings = [[bm.verts.new((cx + r * math.cos(2 * math.pi * i / segs), cy + r * math.sin(2 * math.pi * i / segs), z))
              for i in range(segs)] for (r, z) in loop]
    for k in range(len(rings)):
        a, b = rings[k], rings[(k + 1) % len(rings)]
        for i in range(segs):
            j = (i + 1) % segs
            f = bm.faces.new((a[i], a[j], b[j], b[i]))
            f.material_index = mat
            f.smooth = True


def dome_loop(crown_hole):
    """Dome shell profile: inner surface up from the opening, outer back down."""
    n = 8
    inner, outer = [], []
    for i in range(n + 1):
        t = (math.pi / 2) * i / n
        inner.append((max(DOME_R * math.cos(t), crown_hole), BAND_TOP + (DOME_CROWN - BAND_TOP) * math.sin(t)))
        outer.append((max((DOME_R + 0.18) * math.cos(t), crown_hole), BAND_TOP + 0.18 + (DOME_CROWN - BAND_TOP) * math.sin(t)))
    return inner + list(reversed(outer))


def slab_with_hole(bm, z0, z1, mat=0):
    """The 4 x 4 m ceiling slab with a round hole for the dome (a manifold
    ring between the cell's square and the circle)."""
    segs = 32
    inner_t, inner_b, outer_t, outer_b = [], [], [], []
    for i in range(segs):
        a = 2 * math.pi * i / segs
        c, s = math.cos(a), math.sin(a)
        k = 2.0 / max(abs(c), abs(s))
        for (lst, r, z) in ((inner_b, DOME_R, z0), (inner_t, DOME_R, z1)):
            lst.append(bm.verts.new((2.0 + r * c, 2.0 + r * s, z)))
        for (lst, z) in ((outer_b, z0), (outer_t, z1)):
            lst.append(bm.verts.new((2.0 + k * c, 2.0 + k * s, z)))
    for i in range(segs):
        j = (i + 1) % segs
        for f in ((inner_t[i], outer_t[i], outer_t[j], inner_t[j]),       # top
                  (inner_b[i], inner_b[j], outer_b[j], outer_b[i]),       # underside
                  (outer_b[i], outer_b[j], outer_t[j], outer_t[i]),       # square edge
                  (inner_b[i], inner_t[i], inner_t[j], inner_b[j])):      # hole wall
            bm.faces.new(f).material_index = mat


# --- modules ------------------------------------------------------------------

def column_twisted(r):
    bm = bmesh.new()
    add_ngon_prism(bm, 8, 0.46, 0.0, 0.16)
    add_ngon_prism(bm, 8, 0.38, 0.16, 0.45)
    # rev 3 (your look review): 8 flutes a third of a turn up the shaft, so the
    # spiral reads from across the hall; shallower and in fewer drums than
    # rev 2, which looked busy and jagged up close.
    steps = 10
    for k in range(steps):
        z0 = 0.45 + (3.55 - 0.45) * k / steps
        z1 = 0.45 + (3.55 - 0.45) * (k + 1) / steps
        star_prism(bm, z0, z1, 0.28, 0.21, 8, k * math.radians(12.0))
    add_ngon_prism(bm, 8, 0.32, 3.55, 3.7)
    add_box(bm, -0.36, 0.36, -0.36, 0.36, 3.7, 3.82)
    add_box(bm, -0.42, 0.42, -0.42, 0.42, 3.82, CAP)
    mesh_object("post_column_twisted__body", bm, ["arch_stone"], r)
    bm = bmesh.new()
    add_box(bm, -0.3, 0.3, -0.3, 0.3, 0.0, CAP)
    mesh_object("post_column_twisted__shaft-colonly", bm, ["arch_stone"], r)
    column_wainscot(r)


def hall_pier(r):
    bm = bmesh.new()
    add_box(bm, -0.35, 0.35, -0.35, 0.35, 0.0, 3.8)
    add_box(bm, -0.35, 0.35, -0.35, 0.35, 4.0, BAND_TOP)
    mesh_object("post_hall_pier__body-col", bm, ["brick"], r)
    bm = bmesh.new()
    add_box(bm, -0.42, 0.42, -0.42, 0.42, 3.8, CAP)
    mesh_object("post_hall_pier__capital", bm, ["arch_stone"], r)
    pier_wainscot(r)


def hall_pier_cap(r):
    bm = bmesh.new()
    add_box(bm, -0.35, 0.35, -0.35, 0.35, CAP, BAND_TOP)
    mesh_object("post_hall_pier_cap__body-col", bm, ["brick"], r)


def arcade_arch(r):
    bm = bmesh.new()
    add_box(bm, 0.0, 4.0, -0.25, 0.25, CAP, BAND_TOP)
    body = mesh_object("arcade_arch_4m__body-col", bm, ["brick"], r)
    bm = bmesh.new()
    add_prism(bm, arch_outline(3.3, 0.1, 0.55, 10), 0.35, CAP - 0.1, -0.4, 0.4)
    cutter = mesh_object("cutter", bm, ["arch_stone"], r)
    cut(body, cutter)
    arch_ornament(r)


def hall_band(r):
    bm = bmesh.new()
    add_box(bm, 0.0, 4.0, -T, T + 0.03, CAP, BAND_TOP - 0.3)
    mesh_object("wall_hall_band_4m__body-col", bm, ["brick"], r)
    bm = bmesh.new()
    add_box(bm, 0.0, 4.0, -T, T + 0.03, BAND_TOP - 0.3, BAND_TOP)
    mesh_object("wall_hall_band_4m__tiles", bm, ["tile_hall"], r)
    bm = bmesh.new()
    add_box(bm, 0.0, 4.0, T + 0.03, T + 0.14, CAP, CAP + 0.14)
    mesh_object("wall_hall_band_4m__cornice", bm, ["arch_stone"], r)
    band_frieze(r)


def dome(r, mat, hole=0.02, name="dome_cell_4m", band=False):
    bm = bmesh.new()
    slab_with_hole(bm, BAND_TOP, BAND_TOP + 0.2)
    mesh_object(name + "__slab-col", bm, ["vault_plaster"], r)
    bm = bmesh.new()
    revolve_loop(bm, dome_loop(hole), 2.0, 2.0, 24)
    mesh_object(name + "__dome", bm, [mat], r)
    if band:
        # A ring of tile round the dome's foot, 1.5 cm proud of its inner face.
        n, top = 4, 0.42
        ri = DOME_R - 0.015
        inner = [(ri * math.cos(t), BAND_TOP + (DOME_CROWN - BAND_TOP) * math.sin(t)) for t in (top * i / n for i in range(n + 1))]
        outer = [((ri + 0.01) * math.cos(t), z) for ((_r, z), t) in zip(inner, (top * i / n for i in range(n + 1)))]
        bm = bmesh.new()
        revolve_loop(bm, inner + list(reversed(outer)), 2.0, 2.0, 24)
        mesh_object(name + "__band", bm, ["tile_hall"], r)
    if name in PAINTED:
        dome_paint(r, name, hole, band)


def dome_a(r):
    dome(r, "tile_hall", name="dome_cell_4m_a")


def dome_b(r):
    # rev 2 (your look review): paler plaster, and a tile band at the foot.
    dome(r, "dome_plaster", name="dome_cell_4m_b", band=True)


def oculus(r):
    dome(r, "tile_hall", hole=0.55, name="oculus_cell_4m")
    marker("LIGHT_cold__oculus", r, (2.0, 2.0, DOME_CROWN - 0.4))


def lantern_box(bm, glass, z0, half, height):
    p = half * 0.8
    for (sx, sy) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        add_box(bm, sx * p - 0.02, sx * p + 0.02, sy * p - 0.02, sy * p + 0.02, z0, z0 + height)
    for (za, zb) in ((z0 - 0.05, z0 + 0.01), (z0 + height - 0.01, z0 + height + 0.05)):
        add_box(bm, -half, half, -half, -half + 0.05, za, zb)
        add_box(bm, -half, half, half - 0.05, half, za, zb)
        add_box(bm, -half, -half + 0.05, -half + 0.05, half - 0.05, za, zb)
        add_box(bm, half - 0.05, half, -half + 0.05, half - 0.05, za, zb)
    add_box(glass, -half * 0.55, half * 0.55, -half * 0.55, half * 0.55, z0 + 0.05, z0 + height - 0.05)


def lantern_dome(r):
    bm = bmesh.new()
    glass = bmesh.new()
    lantern_box(bm, glass, 3.0, 0.2, 0.6)
    mesh_object("lantern_dome__body", bm, ["brass"], r)
    mesh_object("lantern_dome__glass", glass, ["emit_lantern"], r)
    bm = bmesh.new()
    add_box(bm, -0.015, 0.015, -0.015, 0.015, 3.65, DOME_CROWN + 0.1)
    mesh_object("lantern_dome__chain", bm, ["iron"], r)
    marker("LIGHT_lantern__dome", r, (0.0, 0.0, 3.3))
    marker("SOCKET_lamp_state__dome", r, (0.0, 0.0, 3.3), LAMP_SOCKET)


def case(r):
    """Centred in a cell (X and Y 0..4), long side along X, faces +Y and -Y."""
    x0, x1, y0, y1, top = 0.5, 3.5, 1.65, 2.35, 2.2
    bm = bmesh.new()
    add_box(bm, x0, x0 + 0.04, y0, y1, 0.0, top)          # ends
    add_box(bm, x1 - 0.04, x1, y0, y1, 0.0, top)
    add_box(bm, x0, x1, y0, y1, top - 0.06, top)           # top
    add_box(bm, x0 + 0.04, x1 - 0.04, 1.98, 2.02, 0.0, top - 0.06)   # divider
    add_box(bm, x0 + 0.04, x1 - 0.04, y0 + 0.02, y1 - 0.02, 0.0, 0.12)   # plinth
    for z in (0.54, 0.96, 1.38, 1.80):
        add_box(bm, x0 + 0.04, x1 - 0.04, y0, y1, z, z + 0.05)
    mesh_object("case_freestanding_4m__body-col", bm, ["wood"], r)
    marker("SOCKET_case_library__a", r, (2.0, 2.0, 0.0), {"socket_set": "case_library"})
    marker("SOCKET_case_library__b", r, (2.0, 2.0, 0.0), {"socket_set": "case_library"}).rotation_euler = (0.0, 0.0, math.pi)


def plinth(r):
    bm = bmesh.new()
    add_ngon_prism(bm, 12, 1.7, 0.0, 0.12)
    add_ngon_prism(bm, 12, 1.45, 0.12, 0.24)
    mesh_object("landmark_plinth__body-col", bm, ["arch_stone"], r)
    marker("SOCKET_hall_landmark__centre", r, (0.0, 0.0, 0.24), {"socket_set": "hall_landmark"})


def great_lamp(r):
    bm = bmesh.new()
    add_ngon_prism(bm, 8, 0.55, 0.0, 0.18)
    add_ngon_prism(bm, 8, 0.32, 0.18, 0.4)
    add_ngon_prism(bm, 8, 0.09, 0.4, 2.55)
    add_ngon_prism(bm, 8, 0.2, 1.2, 1.3)
    add_ngon_prism(bm, 8, 0.38, 2.55, 2.65)
    glass = bmesh.new()
    lantern_box(bm, glass, 2.7, 0.45, 1.0)
    add_ngon_prism(bm, 8, 0.3, 3.75, 3.85)
    add_ngon_prism(bm, 8, 0.12, 3.85, 4.1)
    mesh_object("landmark_great_lamp__body-col", bm, ["brass"], r)
    mesh_object("landmark_great_lamp__glass", glass, ["emit_redfire"], r)     # rev 2: red fire, as every lamp in the hall (hall rework step 1)
    marker("LIGHT_chandelier__great", r, (0.0, 0.0, 3.2), {"color": HALL_RED})


def catalogue_desk(r):
    bm = bmesh.new()
    n = 8
    for i in range(n):
        if i == 6:
            continue           # the way in
        a = 2 * math.pi * (i + 0.5) / n
        cx, cy = 1.25 * math.cos(a), 1.25 * math.sin(a)
        rot = a + math.pi / 2
        from mathutils import Euler, Vector
        m = Euler((0.0, 0.0, rot), "XYZ").to_matrix()
        for (hz0, hz1, hw, hd) in ((0.0, 0.95, 0.5, 0.3), (0.95, 1.0, 0.55, 0.36)):
            vs = [bm.verts.new(Vector((cx, cy, 0.0)) + m @ Vector((sx * hw, sy * hd, z)))
                  for (sx, sy, z) in ((-1, -1, hz0), (1, -1, hz0), (1, 1, hz0), (-1, 1, hz0),
                                      (-1, -1, hz1), (1, -1, hz1), (1, 1, hz1), (-1, 1, hz1))]
            for f in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
                bm.faces.new([vs[k] for k in f])
    mesh_object("landmark_catalogue_desk__counter-col", bm, ["wood"], r)
    bm = bmesh.new()
    add_ngon_prism(bm, 8, 0.12, 1.0, 1.05, cx=0.9, cy=0.0)
    add_ngon_prism(bm, 8, 0.03, 1.05, 1.35, cx=0.9, cy=0.0)
    glass = bmesh.new()
    add_ngon_prism(glass, 8, 0.07, 1.35, 1.5, cx=0.9, cy=0.0)
    mesh_object("landmark_catalogue_desk__lamp", bm, ["brass"], r)
    mesh_object("landmark_catalogue_desk__glass", glass, ["emit_redfire"], r)     # rev 2: red fire
    marker("LIGHT_lantern__desk", r, (0.9, 0.0, 1.45), {"color": HALL_RED})
    marker("ANCHOR_librarian__desk", r, (0.0, 0.0, 0.0))


# --- step 2: the big hall -------------------------------------------------------

def lantern_at(bm, glass, cx, cy, z0, half, height):
    """lantern_box moved off the axis to (cx, cy)."""
    nb, ng = len(bm.verts), len(glass.verts)
    lantern_box(bm, glass, z0, half, height)
    for (b, n) in ((bm, nb), (glass, ng)):
        b.verts.ensure_lookup_table()
        bmesh.ops.translate(b, verts=b.verts[n:], vec=(cx, cy, 0.0))


def lantern_dome_cluster(r):
    """A big lantern with three small ones round it on a brass crown, on one
    chain from the dome's crown; one light for the four (light budget)."""
    bm = bmesh.new()
    glass = bmesh.new()
    lantern_box(bm, glass, 2.9, 0.22, 0.65)
    for i in range(3):
        a = 2 * math.pi * i / 3 + math.pi / 6
        cx, cy = 0.55 * math.cos(a), 0.55 * math.sin(a)
        lantern_at(bm, glass, cx, cy, 3.1, 0.13, 0.42)
        add_box(bm, cx - 0.012, cx + 0.012, cy - 0.012, cy + 0.012, 3.57, 3.72)
    add_ngon_prism(bm, 12, 0.62, 3.72, 3.76)
    add_ngon_prism(bm, 12, 0.5, 3.76, 3.8)
    mesh_object("lantern_dome_cluster__body", bm, ["brass"], r)
    mesh_object("lantern_dome_cluster__glass", glass, ["emit_lantern"], r)
    bm = bmesh.new()
    add_box(bm, -0.015, 0.015, -0.015, 0.015, 3.6, DOME_CROWN + 0.1)
    mesh_object("lantern_dome_cluster__chain", bm, ["iron"], r)
    marker("LIGHT_cluster__dome", r, (0.0, 0.0, 3.25))
    marker("SOCKET_lamp_state__cluster", r, (0.0, 0.0, 3.25), LAMP_SOCKET)


def dome_fallen(r):
    """A bay whose dome has fallen: the slab's ring, a broken stub of the
    dome's foot, and the rough brick shaft it left, closed at 9.6 m."""
    import random
    rng = random.Random(17)
    bm = bmesh.new()
    slab_with_hole(bm, BAND_TOP, BAND_TOP + 0.2)
    mesh_object("dome_cell_4m_fallen__slab-col", bm, ["vault_plaster"], r)
    bm = bmesh.new()
    segs = 24
    for i in range(segs):
        a0, a1 = 2 * math.pi * i / segs, 2 * math.pi * (i + 1) / segs
        h = 0.2 + 0.7 * rng.random() ** 1.5
        ring = [(2.0 + rad * math.cos(a), 2.0 + rad * math.sin(a))
                for (rad, a) in ((DOME_R, a0), (DOME_R, a1), (DOME_R + 0.18, a1), (DOME_R + 0.18, a0))]
        add_plan_prism(bm, list(reversed(ring)), BAND_TOP + 0.2, BAND_TOP + 0.2 + h)
    mesh_object("dome_cell_4m_fallen__stub", bm, ["tile_hall"], r)
    bm = bmesh.new()
    top = 9.6
    w = 0.12
    add_box(bm, 0.05, 3.95, 0.05, 0.05 + w, BAND_TOP + 0.2, top)
    add_box(bm, 0.05, 3.95, 3.95 - w, 3.95, BAND_TOP + 0.2, top)
    add_box(bm, 0.05, 0.05 + w, 0.05 + w, 3.95 - w, BAND_TOP + 0.2, top)
    add_box(bm, 3.95 - w, 3.95, 0.05 + w, 3.95 - w, BAND_TOP + 0.2, top)
    add_box(bm, 0.05, 3.95, 0.05, 3.95, top, top + 0.2)
    mesh_object("dome_cell_4m_fallen__shaft", bm, ["brick"], r)


# --- hall rework (room rework, the Hypostyle Stacks) ---------------------------
# Step 1, your note: a red carpet on the floor, a red tint as if light scatters
# off it, the lanterns gone; daylight shafts, dim lamps and a few red-fire
# Moroccan lanterns.

SUN_TILT = math.radians(10.0)      # every shaft leans the same way (+X): one sun
SUN_LIFT = 5.2                     # the spot sits this far over the crown, along the beam
SKY_TOP = 9.6                      # the light tube's top over the dome
# Your note: every lamp in the hall burns red like the Moroccan lanterns; only
# daylight differs, a slightly yellow sun.
HALL_RED = [1.0, 0.54, 0.34]     # rev 3: less red overall (your walk)
SUN_YELLOW = [1.0, 0.91, 0.68]


def floor_carpet(r):
    """The hall's floor bay: the stone slab and a square carpet over it, wall to
    wall between the columns (their bases hide its corners)."""
    bm = bmesh.new()
    add_box(bm, 0, 4, 0, 4, -0.2, 0.0)
    mesh_object("floor_carpet_4m__body-col", bm, ["floor_stone"], r)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    s = 116 / 32.0
    x0 = 2.0 - s / 2
    vs = [bm.verts.new(p) for p in ((x0, x0, 0.012), (x0 + s, x0, 0.012), (x0 + s, x0 + s, 0.012), (x0, x0 + s, 0.012))]
    f = bm.faces.new(vs)
    for loop in f.loops:
        loop[uv].uv = ((loop.vert.co.x - x0) / s, (loop.vert.co.y - x0) / s)
    mesh_object("floor_carpet_4m__rug", bm, ["rug_hall_bay"], r, recalc=False)


def dome_sun(r, tilt=SUN_TILT, name="dome_sun_4m"):
    """A dome open to the sky: a brick tube over its crown to a disc of daylight,
    a narrow sunbeam leaning through it onto the carpet in a column of haze, and
    a little red light thrown back up off the carpet where it lands."""
    dome(r, "tile_hall", hole=0.55, name=name, band=True)
    bm = bmesh.new()
    revolve_loop(bm, [(0.55, DOME_CROWN - 0.1), (0.55, SKY_TOP), (0.8, SKY_TOP), (0.8, DOME_CROWN - 0.1)], 2.0, 2.0, 16)
    mesh_object(name + "__tube", bm, ["brick"], r)
    sky = bmesh.new()
    vs = [sky.verts.new((2.0 + 0.6 * math.cos(2 * math.pi * i / 16), 2.0 + 0.6 * math.sin(2 * math.pi * i / 16), SKY_TOP - 0.05)) for i in range(16)]
    sky.faces.new(list(reversed(vs)))
    mesh_object(name + "__sky", sky, ["emit_sky_day"], r, recalc=False)
    sx, cz = math.sin(tilt), math.cos(tilt)
    floor_hit = 2.0 + DOME_CROWN * sx / cz           # where the beam's axis meets the floor (x)
    half = 0.55 * (SUN_LIFT + DOME_CROWN / cz) / SUN_LIFT    # the beam's radius there
    spot = marker("LIGHT_shaft__sun", r, (2.0 - SUN_LIFT * sx, 2.0, DOME_CROWN + SUN_LIFT * cz),
                  {"range": SUN_LIFT + DOME_CROWN / cz + 2.0, "spot_angle": math.degrees(math.atan(0.55 / SUN_LIFT)),
                   "energy": 30.0, "color": SUN_YELLOW})     # rev 2: a clearer pool on the carpet; rev 3: a yellow sun (your note)
    spot.rotation_euler = (0.0, -tilt, 0.0)
    haze = marker("FOG_haze__sun", r, ((2.0 + floor_hit) / 2, 2.0, DOME_CROWN / 2),
                  {"fog_size": [half * 1.6, half * 1.6, DOME_CROWN / cz], "density": 0.03,
                   "albedo": [1.0, 0.94, 0.78], "emission": [0.62, 0.5, 0.36], "emission_energy": 0.03})     # rev 4: warmer, not olive
    haze.rotation_euler = (0.0, -tilt, 0.0)
    marker("LIGHT_bounce__carpet", r, (floor_hit, 2.0, 0.9), {"range": 6.0, "energy": 0.45, "color": [1.0, 0.42, 0.3]})


def chain(bm, z0):
    add_box(bm, -0.012, 0.012, -0.012, 0.012, z0, DOME_CROWN + 0.1)


def lantern_oil(r):
    """A small brass oil lamp low on a chain from a dome: a dim warm pool."""
    bm = bmesh.new()
    add_lathe(bm, [(0.0, 2.9), (0.09, 2.92), (0.13, 2.98), (0.12, 3.02), (0.04, 3.04), (0.0, 3.04)], segs=8)
    add_lathe(bm, [(0.0, 3.16), (0.1, 3.16), (0.06, 3.22), (0.015, 3.3), (0.0, 3.3)], segs=8)
    for i in range(3):
        a = 2 * math.pi * i / 3
        add_tube(bm, [(0.11 * math.cos(a), 0.11 * math.sin(a), 3.0), (0.0, 0.0, 3.3)], 0.006, segs=3)
    chain(bm, 3.3)
    mesh_object("lantern_oil__body", bm, ["brass"], r)
    glass = bmesh.new()
    add_lathe(glass, [(0.0, 3.03), (0.05, 3.04), (0.06, 3.09), (0.03, 3.15), (0.0, 3.16)], segs=8)
    mesh_object("lantern_oil__flame", glass, ["emit_redfire"], r)     # rev 2: red fire (your note)
    marker("LIGHT_lamp_dim__oil", r, (0.0, 0.0, 3.0), {"color": HALL_RED})
    marker("SOCKET_lamp_state__oil", r, (0.0, 0.0, 3.0), LAMP_SOCKET)


MOROCCAN_GLASS = [(0.0, 2.56), (0.1, 2.6), (0.19, 2.72), (0.23, 2.88), (0.2, 3.03), (0.12, 3.13), (0.0, 3.16)]


def lantern_moroccan(r):
    """A pierced-brass Moroccan lantern with red glass, hung low on a long chain:
    eight brass ribs over an octagonal glass bulb, a crown and a finial."""
    glass = bmesh.new()
    add_lathe(glass, MOROCCAN_GLASS, segs=8)
    mesh_object("lantern_moroccan__glass", glass, ["emit_redfire"], r)
    bm = bmesh.new()
    add_lathe(bm, [(0.0, 2.36), (0.025, 2.38), (0.05, 2.47), (0.12, 2.56), (0.13, 2.6), (0.0, 2.6)], segs=8)
    add_lathe(bm, [(0.0, 3.1), (0.15, 3.1), (0.17, 3.14), (0.11, 3.24), (0.05, 3.34), (0.02, 3.44), (0.0, 3.5)], segs=8)
    for i in range(8):
        a = 2 * math.pi * (i + 0.5) / 8
        add_tube(bm, [((rr * 1.06 + 0.004) * math.cos(a), (rr * 1.06 + 0.004) * math.sin(a), z) for (rr, z) in MOROCCAN_GLASS[1:-1]], 0.011, segs=3)
    for z in (2.74, 2.88, 3.02):
        rr = 0.235 if z == 2.88 else 0.205
        add_lathe(bm, [(rr - 0.03, z - 0.012), (rr + 0.012, z - 0.012), (rr + 0.012, z + 0.012), (rr - 0.03, z + 0.012)], segs=8)
    chain(bm, 3.5)
    mesh_object("lantern_moroccan__body", bm, ["brass"], r)
    marker("LIGHT_redfire__moroccan", r, (0.0, 0.0, 2.86))
    marker("SOCKET_lamp_state__moroccan", r, (0.0, 0.0, 2.86), LAMP_SOCKET)


# Step 2, the grand landmark: a hauz (an octagonal pool) under the centre dome,
# its sunbeam straight down onto the water, and a takht (a raised reading
# platform) beside it.

HAUZ_IN = 1.36      # the basin's inner radius (octagon corners)
HAUZ_OUT = 1.7
HAUZ_TOP = 0.45
HAUZ_WATER = 0.36


def landmark_hauz(r):
    """The hall's landmark: an octagonal pool with a stone rim to sit on, red
    and gold tile under clear water, and a small stone fountain in the middle.
    Centred on the module origin (the centre bay's middle)."""
    bm = bmesh.new()
    revolve_loop(bm, [(HAUZ_IN, 0.0), (HAUZ_IN, HAUZ_TOP), (HAUZ_OUT, HAUZ_TOP), (HAUZ_OUT, 0.0)], 0.0, 0.0, 8)
    mesh_object("landmark_hauz__rim-col", bm, ["arch_stone"], r)
    bm = bmesh.new()      # the coping, a lip proud of the rim both ways
    revolve_loop(bm, [(HAUZ_IN - 0.05, HAUZ_TOP), (HAUZ_IN - 0.05, HAUZ_TOP + 0.07), (HAUZ_OUT + 0.06, HAUZ_TOP + 0.07), (HAUZ_OUT + 0.06, HAUZ_TOP)], 0.0, 0.0, 8)
    mesh_object("landmark_hauz__coping", bm, ["persian_stone"], r)
    bm = bmesh.new()
    vs = [bm.verts.new((HAUZ_IN * math.cos(2 * math.pi * i / 8), HAUZ_IN * math.sin(2 * math.pi * i / 8), 0.06)) for i in range(8)]
    bm.faces.new(vs)
    mesh_object("landmark_hauz__floor", bm, ["tile_hall"], r)
    bm = bmesh.new()
    vs = [bm.verts.new(((HAUZ_IN + 0.01) * math.cos(2 * math.pi * i / 8), (HAUZ_IN + 0.01) * math.sin(2 * math.pi * i / 8), HAUZ_WATER)) for i in range(8)]
    bm.faces.new(vs)
    mesh_object("landmark_hauz__water", bm, ["hauz_water"], r)
    bm = bmesh.new()      # the fountain: a stone cup on a short shaft
    add_lathe(bm, [(0.0, 0.06), (0.26, 0.06), (0.26, 0.16), (0.12, 0.2), (0.09, 0.5), (0.24, 0.56), (0.27, 0.64),
                   (0.2, 0.62), (0.0, 0.62)], segs=8)
    mesh_object("landmark_hauz__fountain", bm, ["arch_stone"], r)
    bm = bmesh.new()
    add_lathe(bm, [(0.0, 0.6), (0.035, 0.6), (0.025, 0.74), (0.0, 0.78)], segs=6)
    mesh_object("landmark_hauz__spout", bm, ["brass"], r)


def landmark_takht(r):
    """A takht: a raised wooden platform 3 x 2.4 m, 0.48 m high, with a low rail
    round its back and sides, a carpet, cushions against the rail, a rahl with
    an open book and a small red-glass lamp. Its open side (Blender +Y) faces
    the pool; a step leads up there."""
    w, d, h = 1.5, 1.2, 0.48
    bm = bmesh.new()
    add_box(bm, -w, w, -d, d, h - 0.08, h)                      # the deck
    add_box(bm, -w + 0.08, w - 0.08, -d + 0.08, d - 0.08, 0.14, h - 0.08)   # the apron
    for sx in (-1, 0, 1):
        for sy in (-1, 1):
            x = sx * (w - 0.1)
            y = sy * (d - 0.1)
            add_box(bm, x - 0.07, x + 0.07, y - 0.07, y + 0.07, 0.0, 0.14)
    add_box(bm, -0.7, 0.7, d, d + 0.32, 0.0, 0.22)              # the step
    for (x0, x1, y0, y1) in ((-w, w, -d, -d + 0.06), (-w, -w + 0.06, -d, d), (w - 0.06, w, -d, d)):
        add_box(bm, x0, x1, y0, y1, h + 0.32, h + 0.38)         # rail
        n = max(2, int(round(max(x1 - x0, y1 - y0) / 0.3)))
        for k in range(n + 1):
            t = k / n
            x = x0 + (x1 - x0) * t if x1 - x0 > 0.1 else (x0 + x1) / 2
            y = y0 + (y1 - y0) * t if y1 - y0 > 0.1 else (y0 + y1) / 2
            add_box(bm, x - 0.025, x + 0.025, y - 0.025, y + 0.025, h, h + 0.32)
    mesh_object("landmark_takht__frame", bm, ["persian_wood"], r)
    bm = bmesh.new()
    add_box(bm, -w, w, -d, d, 0.0, h)
    add_box(bm, -0.7, 0.7, d, d + 0.32, 0.0, 0.22)
    mesh_object("landmark_takht__col-colonly", bm, ["persian_wood"], r)
    bm = bmesh.new()                                             # the carpet, its long side along X
    uv = bm.loops.layers.uv.new("UVMap")
    cw, cd = 2.7, 2.0
    vs = [bm.verts.new((x, y, h + 0.012)) for (x, y) in ((-cw / 2, -cd / 2), (cw / 2, -cd / 2), (cw / 2, cd / 2), (-cw / 2, cd / 2))]
    f = bm.faces.new(vs)
    for loop in f.loops:
        loop[uv].uv = ((loop.vert.co.x + cw / 2) / cw, (loop.vert.co.y + cd / 2) / cd)
    mesh_object("landmark_takht__rug", bm, ["rug_medallion_small"], r, recalc=False)
    bm = bmesh.new()                                             # bolsters along the rail, leaning back
    for x in (-0.95, 0.0, 0.95):
        add_obox(bm, (x, -d + 0.22, h + 0.24), (0.8, 0.16, 0.42), (math.radians(-14), 0.0, 0.0))
    for (x, y) in ((-w + 0.24, -0.2), (w - 0.24, -0.2)):
        add_obox(bm, (x, y, h + 0.2), (0.16, 0.7, 0.36), (0.0, math.radians(12 if x > 0 else -12), 0.0))
    mesh_object("landmark_takht__bolsters", bm, ["cushion_termeh"], r)
    bm = bmesh.new()                                             # floor cushions to sit on
    for x in (-0.65, 0.65):
        add_box(bm, x - 0.32, x + 0.32, -0.55, 0.05, h + 0.012, h + 0.11)
    mesh_object("landmark_takht__cushions", bm, ["cushion_ikat"], r)
    stand, books = bmesh.new(), bmesh.new()
    for s in (-1, 1):                                            # a rahl (book stand), the book open toward the pool
        add_obox(stand, (0.0, 0.35 + s * 0.06, h + 0.1), (0.34, 0.015, 0.24), (math.radians(-s * 38), 0.0, 0.0))
    for s in (-1, 1):
        add_obox(books, (0.0, 0.35 + s * 0.1, h + 0.2), (0.28, 0.17, 0.02), (math.radians(s * 35), 0.0, 0.0), 0)
        add_obox(books, (0.0, 0.35 + s * 0.11, h + 0.19), (0.3, 0.19, 0.008), (math.radians(s * 35), 0.0, 0.0), 1)
    for (k, (x, y)) in enumerate(((1.05, 0.55), (1.1, 0.25))):  # a stack of closed books at the front corner
        add_obox(books, (x, y, h + 0.04), (0.32, 0.24, 0.07), (0.0, 0.0, math.radians(8 * k)), 1)
        add_obox(books, (x, y, h + 0.1), (0.28, 0.2, 0.05), (0.0, 0.0, math.radians(-10 + 8 * k)), 1)
    mesh_object("landmark_takht__rahl", stand, ["persian_wood"], r)
    mesh_object("landmark_takht__books", books, ["pages", "book_leather"], r)
    x, y, z = -1.15, 0.6, h                                      # the lamp, front corner
    bm = bmesh.new()
    add_lathe(bm, [(0.0, z), (0.09, z), (0.1, z + 0.02), (0.04, z + 0.05), (0.03, z + 0.16), (0.11, z + 0.2),
                   (0.12, z + 0.23), (0.0, z + 0.23)], cx=x, cy=y, segs=8)
    add_lathe(bm, [(0.0, z + 0.46), (0.09, z + 0.46), (0.05, z + 0.52), (0.0, z + 0.58)], cx=x, cy=y, segs=8)
    for k in range(4):
        a = (k + 0.5) * math.pi / 2
        add_box(bm, x + math.cos(a) * 0.09 - 0.008, x + math.cos(a) * 0.09 + 0.008,
                y + math.sin(a) * 0.09 - 0.008, y + math.sin(a) * 0.09 + 0.008, z + 0.23, z + 0.46)
    mesh_object("landmark_takht__lamp", bm, ["brass"], r)
    bm = bmesh.new()
    add_lathe(bm, [(0.0, z + 0.23), (0.075, z + 0.25), (0.08, z + 0.36), (0.06, z + 0.44), (0.0, z + 0.46)], cx=x, cy=y, segs=8)
    mesh_object("landmark_takht__glass", bm, ["emit_redfire"], r)
    marker("LIGHT_lamp_dim__takht", r, (x, y, z + 0.34), {"color": HALL_RED, "range": 5.0})
    marker("SOCKET_lamp_state__takht", r, (x, y, z + 0.34), LAMP_SOCKET)


def dome_sun_centre(r):
    """The landmark's dome: as dome_sun_4m, the beam straight down onto the pool."""
    dome_sun(r, tilt=0.0, name="dome_sun_4m_centre")


# Step 3, scholars at work: a reading nook, a book cart and a sorting table,
# each filling one bay off the aisles (centred on the module origin, inside
# +-1.6 m so the columns at the bay's corners stay clear).

import random as _random


def book_stack(bm, x, y, z, n, rng, yaw=0.0):
    """n closed books piled at (x, y, z), each a little turned."""
    for i in range(n):
        w, d, t = rng.uniform(0.2, 0.32), rng.uniform(0.15, 0.24), rng.uniform(0.035, 0.07)
        add_obox(bm, (x, y, z + t / 2), (w, d, t), (0.0, 0.0, yaw + rng.uniform(-0.3, 0.3)))
        z += t
    return z


def books_row(bm, x0, x1, y, z, rng, lean=0.0, depth=0.18):
    """Books standing on a shelf from x0 to x1 (spines toward -Y)."""
    x = x0
    while x < x1 - 0.03:
        t = rng.uniform(0.03, 0.06)
        h = rng.uniform(0.18, 0.28)
        add_obox(bm, (x + t / 2, y, z + h / 2), (t, depth, h), (lean, 0.0, 0.0))
        x += t + 0.004


def wheel(bm, cx, cy, cz, radius, width, segs=12):
    """A wheel turning about Y."""
    for (y0, y1) in ((cy - width / 2, cy + width / 2),):
        a = [bm.verts.new((cx + radius * math.cos(2 * math.pi * i / segs), y0, cz + radius * math.sin(2 * math.pi * i / segs))) for i in range(segs)]
        b = [bm.verts.new((cx + radius * math.cos(2 * math.pi * i / segs), y1, cz + radius * math.sin(2 * math.pi * i / segs))) for i in range(segs)]
        bm.faces.new(a)
        bm.faces.new(list(reversed(b)))
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((a[j], a[i], b[i], b[j]))


def red_lamp(r, prefix, x, y, z):
    """A small brass lamp with red glass and no light of its own (the hall's
    dim lamps light the bay; your walk: every lamp here burns red)."""
    bm = bmesh.new()
    add_lathe(bm, [(0.0, z), (0.07, z), (0.075, z + 0.015), (0.03, z + 0.04), (0.025, z + 0.1), (0.06, z + 0.12), (0.0, z + 0.12)], cx=x, cy=y, segs=8)
    add_lathe(bm, [(0.0, z + 0.3), (0.06, z + 0.3), (0.03, z + 0.34), (0.0, z + 0.36)], cx=x, cy=y, segs=8)
    mesh_object(prefix + "__lamp", bm, ["brass"], r)
    bm = bmesh.new()
    add_lathe(bm, [(0.0, z + 0.12), (0.055, z + 0.14), (0.06, z + 0.22), (0.045, z + 0.29), (0.0, z + 0.3)], cx=x, cy=y, segs=8)
    mesh_object(prefix + "__glass", bm, ["emit_redfire"], r)


def hall_reading_nook(r):
    """A scholar's reading spot on the floor: a kilim, a low table with a rahl
    and an open book, cushions round it, books piled to hand, a red lamp."""
    rng = _random.Random(31)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    cw, cd = 2.5, 1.75
    vs = [bm.verts.new((x, y, 0.024)) for (x, y) in ((-cw / 2, -cd / 2), (cw / 2, -cd / 2), (cw / 2, cd / 2), (-cw / 2, cd / 2))]
    f = bm.faces.new(vs)
    for loop in f.loops:
        loop[uv].uv = ((loop.vert.co.x + cw / 2) / cw, (loop.vert.co.y + cd / 2) / cd)
    mesh_object("hall_reading_nook__rug", bm, ["rug_kilim_small"], r, recalc=False)
    bm = bmesh.new()
    add_box(bm, -0.55, 0.55, -0.3, 0.3, 0.3, 0.34)
    add_box(bm, -0.5, 0.5, -0.25, 0.25, 0.24, 0.3)
    for sx in (-1, 1):
        for sy in (-1, 1):
            add_box(bm, sx * 0.47 - 0.04, sx * 0.47 + 0.04, sy * 0.22 - 0.04, sy * 0.22 + 0.04, 0.024, 0.24)
    mesh_object("hall_reading_nook__table", bm, ["persian_wood"], r)
    bm = bmesh.new()
    add_box(bm, -0.55, 0.55, -0.3, 0.3, 0.0, 0.34)
    mesh_object("hall_reading_nook__col-colonly", bm, ["persian_wood"], r)
    stand, books = bmesh.new(), bmesh.new()
    for s in (-1, 1):
        add_obox(stand, (0.0, s * 0.06, 0.44), (0.3, 0.015, 0.24), (math.radians(-s * 38), 0.0, 0.0))
    for s in (-1, 1):
        add_obox(books, (0.0, s * 0.1, 0.54), (0.26, 0.17, 0.02), (math.radians(s * 35), 0.0, 0.0), 0)
        add_obox(books, (0.0, s * 0.11, 0.53), (0.28, 0.19, 0.008), (math.radians(s * 35), 0.0, 0.0), 1)
    mesh_object("hall_reading_nook__rahl", stand, ["persian_wood"], r)
    mesh_object("hall_reading_nook__open", books, ["pages", "book_leather"], r)
    bm = bmesh.new()
    book_stack(bm, 0.38, 0.05, 0.34, 3, rng)
    book_stack(bm, 1.0, 0.55, 0.024, 5, rng, 0.4)
    book_stack(bm, 1.05, 0.2, 0.024, 3, rng, -0.2)
    book_stack(bm, -1.05, -0.6, 0.024, 4, rng, 0.9)
    mesh_object("hall_reading_nook__books", bm, ["book_leather"], r)
    bm = bmesh.new()
    for (x, y, sx, sy) in ((0.0, -0.62, 0.62, 0.5), (0.0, 0.62, 0.62, 0.5), (-0.9, 0.05, 0.45, 0.6)):
        add_box(bm, x - sx / 2, x + sx / 2, y - sy / 2, y + sy / 2, 0.024, 0.14)
    mesh_object("hall_reading_nook__cushions", bm, ["cushion_termeh"], r)
    bm = bmesh.new()
    add_obox(bm, (0.0, -0.95, 0.24), (0.7, 0.16, 0.34), (math.radians(-12), 0.0, 0.0))
    mesh_object("hall_reading_nook__bolster", bm, ["cushion_ikat"], r)
    bm = bmesh.new()                                     # a brass tray with a tea glass
    add_lathe(bm, [(0.0, 0.024), (0.2, 0.024), (0.21, 0.05), (0.19, 0.05), (0.0, 0.035)], cx=-0.95, cy=0.6, segs=12)
    add_lathe(bm, [(0.0, 0.05), (0.03, 0.05), (0.035, 0.13), (0.0, 0.13)], cx=-0.9, cy=0.62, segs=6)
    mesh_object("hall_reading_nook__tray", bm, ["brass"], r)
    red_lamp(r, "hall_reading_nook", -0.42, 0.12, 0.34)


def hall_book_cart(r):
    """A librarian's book cart: two wheels, an A-frame of sloped shelves full of
    books on both faces, a handle; a few books waiting on the floor by it."""
    rng = _random.Random(47)
    bm = bmesh.new()
    add_box(bm, -0.75, 0.75, -0.32, 0.32, 0.36, 0.42)            # the bed
    for sx in (-1, 1):
        add_box(bm, sx * 0.7 - 0.03, sx * 0.7 + 0.03, -0.03, 0.03, 0.42, 1.25)    # A-frame ends
        for sy in (-1, 1):
            add_obox(bm, (sx * 0.7, sy * 0.17, 0.82), (0.05, 0.05, 0.85), (math.radians(sy * 22), 0.0, 0.0))
    add_box(bm, -0.72, 0.72, -0.025, 0.025, 1.18, 1.24)          # ridge
    for sy in (-1, 1):                                           # two sloped shelves each side
        for (z, off) in ((0.48, 0.27), (0.85, 0.14)):
            add_obox(bm, (0.0, sy * off, z), (1.36, 0.22, 0.02), (math.radians(-sy * 8), 0.0, 0.0))
    add_box(bm, 0.75, 1.2, -0.3, -0.26, 0.4, 0.44)                # the handle
    add_box(bm, 0.75, 1.2, 0.26, 0.3, 0.4, 0.44)
    add_box(bm, 1.16, 1.22, -0.3, 0.3, 0.4, 0.46)
    add_box(bm, -0.7, -0.64, -0.3, 0.3, 0.0, 0.36)                # the rest at the back
    mesh_object("hall_book_cart__frame", bm, ["persian_wood"], r)
    bm = bmesh.new()
    for sy in (-1, 1):
        wheel(bm, 0.35, sy * 0.38, 0.3, 0.3, 0.06)
    add_box(bm, 0.33, 0.37, -0.42, 0.42, 0.28, 0.32)              # axle
    mesh_object("hall_book_cart__wheels", bm, ["iron"], r)
    bm = bmesh.new()
    add_box(bm, -0.75, 1.22, -0.45, 0.45, 0.0, 1.25)
    mesh_object("hall_book_cart__col-colonly", bm, ["persian_wood"], r)
    bm = bmesh.new()
    for sy in (-1, 1):
        for (z, off) in ((0.49, 0.22), (0.86, 0.1)):
            books_row(bm, -0.62, 0.62, sy * off, z, rng, lean=math.radians(-sy * 8), depth=0.16)
    book_stack(bm, -1.1, 0.45, 0.0, 4, rng, 0.3)
    book_stack(bm, -1.15, 0.05, 0.0, 6, rng, -0.5)
    book_stack(bm, 0.2, 0.75, 0.0, 2, rng, 1.1)
    mesh_object("hall_book_cart__books", bm, ["book_leather"], r)


def hall_sorting_table(r):
    """Where the scholars sort what comes up from the stacks: a long table piled
    with books, an open ledger, an inkwell and scrolls, two stools, and a crate
    of books waiting beside it."""
    rng = _random.Random(59)
    h = 0.8
    bm = bmesh.new()
    add_box(bm, -1.2, 1.2, -0.45, 0.45, h - 0.05, h)
    for sx in (-1, 1):
        for sy in (-1, 1):
            add_box(bm, sx * 1.1 - 0.05, sx * 1.1 + 0.05, sy * 0.36 - 0.05, sy * 0.36 + 0.05, 0.0, h - 0.05)
        add_box(bm, sx * 1.1 - 0.03, sx * 1.1 + 0.03, -0.36, 0.36, 0.18, 0.24)
    add_box(bm, -1.1, 1.1, -0.03, 0.03, 0.18, 0.24)               # stretcher
    for x in (-0.5, 0.6):                                         # stools on the -Y side
        add_ngon_prism(bm, 8, 0.2, 0.42, 0.47, cx=x, cy=-0.75)
        for k in range(3):
            a = 2 * math.pi * k / 3
            add_box(bm, x + 0.13 * math.cos(a) - 0.02, x + 0.13 * math.cos(a) + 0.02, -0.75 + 0.13 * math.sin(a) - 0.02, -0.75 + 0.13 * math.sin(a) + 0.02, 0.0, 0.42)
    add_box(bm, 1.3, 1.9, -0.3, 0.3, 0.0, 0.04)                   # the crate
    for (x0, x1, y0, y1) in ((1.3, 1.9, -0.3, -0.27), (1.3, 1.9, 0.27, 0.3), (1.3, 1.33, -0.3, 0.3), (1.87, 1.9, -0.3, 0.3)):
        add_box(bm, x0, x1, y0, y1, 0.0, 0.42)
    mesh_object("hall_sorting_table__wood", bm, ["persian_wood"], r)
    bm = bmesh.new()
    add_box(bm, -1.2, 1.2, -0.45, 0.45, 0.0, h)
    add_box(bm, 1.3, 1.9, -0.3, 0.3, 0.0, 0.42)
    mesh_object("hall_sorting_table__col-colonly", bm, ["persian_wood"], r)
    bm = bmesh.new()
    for (x, y, n) in ((-1.0, 0.2, 5), (-0.65, 0.25, 3), (0.95, 0.15, 6), (0.65, -0.25, 2), (0.3, 0.3, 4)):
        book_stack(bm, x, y, h, n, rng)
    books_row(bm, 1.36, 1.84, 0.0, 0.04, rng, depth=0.5)          # in the crate, spines up
    book_stack(bm, -1.55, 0.35, 0.0, 5, rng, 0.6)
    book_stack(bm, -1.5, -0.1, 0.0, 3, rng, -0.3)
    mesh_object("hall_sorting_table__books", bm, ["book_leather"], r)
    paper = bmesh.new()
    add_obox(paper, (-0.15, -0.12, h + 0.015), (0.5, 0.36, 0.02), (0.0, 0.0, math.radians(-6)))   # the ledger, open
    for (x, y, a) in ((0.2, -0.3, 10), (0.4, -0.22, -25), (-0.45, -0.32, 70)):
        ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
        add_tube(paper, [(x - 0.17 * ca, y - 0.17 * sa, h + 0.025), (x + 0.17 * ca, y + 0.17 * sa, h + 0.025)], 0.022, segs=6)
    mesh_object("hall_sorting_table__papers", paper, ["pages"], r)
    bm = bmesh.new()
    add_lathe(bm, [(0.0, h), (0.045, h), (0.05, h + 0.04), (0.02, h + 0.06), (0.0, h + 0.06)], cx=0.15, cy=0.05, segs=8)
    add_tube(bm, [(0.16, 0.05, h + 0.05), (0.22, 0.12, h + 0.22)], 0.004, segs=3)     # a reed pen in it
    mesh_object("hall_sorting_table__inkwell", bm, ["brass"], r)
    red_lamp(r, "hall_sorting_table", -0.95, -0.25, h)


# Step 4, ornament: kashi tile wainscots on the columns and piers, a tile frame
# round every arch with a geometric frieze over it (and along the walls'
# band), gilt ribs and a star medallion painted in the domes. The gilt and the
# lacquer glow faintly so the ceiling reads in the dim hall; the frieze is lit only by the lamps.
# Every piece is added to the modules already in kit_hall.blend (ORNAMENT in
# main), so nothing built by hand there is lost.

PAINTED = ("dome_cell_4m_a", "dome_cell_4m_b", "dome_sun_4m", "dome_sun_4m_centre")
FRIEZE = (5.92, 6.18)        # the arcades' frieze, over the arch frame's crown (5.9)


def face_toward(bm, verts, want, mat=0, uv=None, uvs=None):
    """A face over `verts` turned to face `want`; UVs by vertex if given."""
    from mathutils import Vector
    f = bm.faces.new(verts)
    f.material_index = mat
    f.normal_update()
    if f.normal.dot(Vector(want)) < 0:
        f.normal_flip()
    if uv is not None:
        for loop in f.loops:
            loop[uv].uv = uvs[loop.vert]
    return f


def frieze(bm, uv, x0, x1, y, z0, z1, side):
    """A frieze panel in the plane y, facing +y (side 1) or -y (side -1),
    the texture read left to right from that side."""
    vs = [bm.verts.new(p) for p in ((x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1))]
    uvs = {}
    for v in vs:
        u = (x1 - v.co.x) / (x1 - x0) if side > 0 else (v.co.x - x0) / (x1 - x0)
        uvs[v] = (u, (v.co.z - z0) / (z1 - z0))
    face_toward(bm, vs, (0.0, side, 0.0), 0, uv, uvs)


def column_wainscot(r):
    """A tiled octagonal pedestal up to 1.13 m, gilt fillets and a stone cap:
    the column's spiral starts over it."""
    bm = bmesh.new()
    add_ngon_prism(bm, 8, 0.40, 0.16, 1.05, mat=0)
    add_ngon_prism(bm, 8, 0.44, 1.05, 1.13, mat=1)
    for z in (0.2, 0.97):
        add_ngon_prism(bm, 8, 0.408, z, z + 0.03, mat=2)
    mesh_object("post_column_twisted__wainscot", bm, ["tile_hall", "arch_stone", "hall_gild"], r)
    bm = bmesh.new()
    add_ngon_prism(bm, 8, 0.40, 0.0, 1.13)
    mesh_object("post_column_twisted__pedestal-colonly", bm, ["arch_stone"], r)


def pier_wainscot(r):
    """The wall piers' dado: stone plinth, tile, a gilt fillet, stone cap."""
    bm = bmesh.new()
    add_box(bm, -0.39, 0.39, -0.39, 0.39, 0.0, 0.12, mat=1)
    add_box(bm, -0.365, 0.365, -0.365, 0.365, 0.12, 1.05, mat=0)
    add_box(bm, -0.372, 0.372, -0.372, 0.372, 0.96, 0.99, mat=2)
    add_box(bm, -0.39, 0.39, -0.39, 0.39, 1.05, 1.12, mat=1)
    mesh_object("post_hall_pier__wainscot", bm, ["tile_hall", "arch_stone", "hall_gild"], r)


def arch_ornament(r):
    """A band of tile round the arch on both faces (an archivolt), and the
    frieze over its crown on both faces."""
    span, k, w, x0, zs = 3.3, 0.55, 0.09, 0.35, CAP
    rr = span * k
    mid = x0 + span / 2
    ta = math.acos((span / 2 - rr) / rr)
    def arch_ring(a, b):
        """The band between a and b metres outside the arch, foot to foot (an XZ outline)."""
        n = 10
        def side(o):
            pts = [(x0 + rr + (rr + o) * math.cos(t), zs + (rr + o) * math.sin(t))
                   for t in (math.pi + (ta - math.pi) * i / n for i in range(n + 1))]
            pts[-1] = (mid, zs + math.sqrt((rr + o) ** 2 - (span / 2 - rr) ** 2))
            return pts + [(2 * mid - x, z) for (x, z) in reversed(pts[:-1])]
        return side(b) + list(reversed(side(a)))
    bm = bmesh.new()
    for (y0, y1) in ((0.25, 0.262), (-0.262, -0.25)):
        add_prism(bm, arch_ring(0.0, w), 0.0, 0.0, y0, y1)
    mesh_object("arcade_arch_4m__archivolt", bm, ["tile_hall"], r)
    bm = bmesh.new()       # rev 2: gilt lines along both its edges, so the frame reads in the dim
    for (a, b) in ((0.0, 0.02), (w - 0.02, w)):
        for (y0, y1) in ((0.262, 0.266), (-0.266, -0.262)):
            add_prism(bm, arch_ring(a, b), 0.0, 0.0, y0, y1)
    mesh_object("arcade_arch_4m__gilt", bm, ["hall_gild"], r)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    for s in (1, -1):
        frieze(bm, uv, 0.0, 4.0, s * 0.254, FRIEZE[0], FRIEZE[1], s)
    mesh_object("arcade_arch_4m__frieze", bm, ["hall_frieze"], r, recalc=False)


def band_frieze(r):
    """The frieze along the hall's walls, on the band's inner face."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    frieze(bm, uv, 0.0, 4.0, T + 0.034, 5.5, 5.78, 1)
    mesh_object("wall_hall_band_4m__frieze", bm, ["hall_frieze"], r, recalc=False)


def dome_paint(r, name, hole, band):
    """Painted in the dome: twelve gilt ribs from the foot (or the tile band)
    to the crown, and at the crown a gilt twelve-point star with a lacquer-red
    star and a gilt boss in it; an open dome gets a gilt ring round its eye."""
    prof = dome_loop(hole)[:9]                  # the inner face, foot to crown
    def seg_normal(i):                          # the inward normal of chord i
        (r0, z0), (r1, z1) = prof[i], prof[i + 1]
        dr, dz = r1 - r0, z1 - z0
        l = math.hypot(dr, dz)
        return (-dz / l, dr / l)
    def vert_normal(i):
        ns = [seg_normal(j) for j in (i - 1, i) if 0 <= j < len(prof) - 1]
        a, b = sum(n[0] for n in ns), sum(n[1] for n in ns)
        l = math.hypot(a, b)
        return (a / l, b / l)
    def surf_z(rho):
        for i in range(len(prof) - 1):
            (r0, z0), (r1, z1) = prof[i], prof[i + 1]
            if r1 <= rho <= r0 and r0 > r1:
                return z0 + (z1 - z0) * (r0 - rho) / (r0 - r1)
        return prof[-1][1]
    def at(rho, phi, z):
        return (2.0 + rho * math.cos(phi), 2.0 + rho * math.sin(phi), z)
    bm = bmesh.new()
    d = 0.012
    k0, k1 = (3 if band else 1), 6
    for j in range(12):                         # the ribs
        phi = j * math.pi / 6
        rows = []
        for k in range(k0, k1 + 1):
            nr, nz = vert_normal(k)
            rho, z = prof[k][0] + nr * d, prof[k][1] + nz * d
            hw = 0.022 / rho
            rows.append(([bm.verts.new(at(rho, phi - hw, z)), bm.verts.new(at(rho, phi + hw, z))], (math.cos(phi) * nr, math.sin(phi) * nr, nz)))
        for (a, wa), (b, _wb) in zip(rows, rows[1:]):
            face_toward(bm, [a[0], a[1], b[1], b[0]], wa, 0)
    if hole < 0.1:                              # the crown medallion
        for (ro, ri, off, rot, mat, pts) in ((0.62, 0.42, 0.016, 0.0, 0, 12), (0.42, 0.32, 0.05, math.pi / 12, 1, 12),
                                             (0.1, 0.1, 0.065, 0.0, 0, 8)):   # rev 3: clear of the gold star's flat fan
            c = bm.verts.new((2.0, 2.0, surf_z(0.0) - off))
            ring = []
            for i in range(pts * 2):
                rho = ro if i % 2 == 0 else ri
                ring.append(bm.verts.new(at(rho, rot + math.pi * i / pts, surf_z(rho) - off)))
            for i in range(len(ring)):
                face_toward(bm, [c, ring[i], ring[(i + 1) % len(ring)]], (0.0, 0.0, -1.0), mat)
    else:                                       # a gilt ring round the eye
        rows = []
        for k in (6, 7):
            nr, nz = vert_normal(k)
            rows.append(([bm.verts.new(at(prof[k][0] + nr * d, i * math.pi / 12, prof[k][1] + nz * d)) for i in range(24)], nr, nz))
        (a, nr, nz), (b, _r, _z) = rows
        for i in range(24):
            phi = (i + 0.5) * math.pi / 12
            face_toward(bm, [a[i], a[(i + 1) % 24], b[(i + 1) % 24], b[i]], (math.cos(phi) * nr, math.sin(phi) * nr, nz), 0)
    mesh_object(name + "__paint", bm, ["hall_gild", "hall_lacquer"], r, recalc=False)


ORNAMENT = [   # (module, revision, the pieces it adds, builder); a higher revision remakes them
    ("M_post_column_twisted", 1, ["post_column_twisted__wainscot", "post_column_twisted__pedestal-colonly"], column_wainscot),
    ("M_post_hall_pier", 1, ["post_hall_pier__wainscot"], pier_wainscot),
    ("M_arcade_arch_4m", 3, ["arcade_arch_4m__archivolt", "arcade_arch_4m__gilt", "arcade_arch_4m__frieze"], arch_ornament),   # rev 2: gilt edges; rev 3: the geometric frieze (your note)
    ("M_wall_hall_band_4m", 2, ["wall_hall_band_4m__frieze"], band_frieze)] + [   # band rev 2: the geometric frieze
    ("M_" + n, 3, [n + "__paint"], (lambda n, h, b: lambda r: dome_paint(r, n, h, b))(n, h, b))   # rev 2: a fuller red star; rev 3: in front of the gold
    for (n, h, b) in (("dome_cell_4m_a", 0.02, False), ("dome_cell_4m_b", 0.02, True), ("dome_sun_4m", 0.55, True), ("dome_sun_4m_centre", 0.55, True))]


def rubble_heap(r):
    """Centred in a cell (X and Y 0..4): the fallen dome as a heap of masonry,
    brick and tile, 1.2 m high. Its collision is one box, so nobody climbs it."""
    import random
    rng = random.Random(23)
    bm = bmesh.new()
    add_lathe(bm, [(1.55, 0.0), (1.3, 0.3), (0.95, 0.65), (0.5, 0.95), (0.0, 1.1)], cx=2.0, cy=2.0, segs=10)
    for _ in range(26):
        t, d = rng.uniform(0, 2 * math.pi), 1.45 * math.sqrt(rng.random())
        z = 1.1 * (1.0 - d / 1.55) ** 1.2
        size = (rng.uniform(0.25, 0.6), rng.uniform(0.2, 0.45), rng.uniform(0.15, 0.3))
        add_obox(bm, (2.0 + d * math.cos(t), 2.0 + d * math.sin(t), z), size,
                 (rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), rng.uniform(0, math.pi)))
    mesh_object("rubble_heap_4m__stone", bm, ["arch_stone"], r)
    bm = bmesh.new()
    for _ in range(40):
        t, d = rng.uniform(0, 2 * math.pi), 1.7 * math.sqrt(rng.random())
        z = max(0.04, 1.1 * max(0.0, 1.0 - d / 1.55) ** 1.2)
        add_obox(bm, (2.0 + d * math.cos(t), 2.0 + d * math.sin(t), z), (0.23, 0.11, 0.07),
                 (rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), rng.uniform(0, math.pi)))
    mesh_object("rubble_heap_4m__bricks", bm, ["brick"], r)
    bm = bmesh.new()
    for _ in range(18):
        t, d = rng.uniform(0, 2 * math.pi), 1.6 * math.sqrt(rng.random())
        z = max(0.02, 1.1 * max(0.0, 1.0 - d / 1.55) ** 1.2) + 0.03
        add_obox(bm, (2.0 + d * math.cos(t), 2.0 + d * math.sin(t), z), (rng.uniform(0.25, 0.5), rng.uniform(0.2, 0.4), 0.035),
                 (rng.uniform(-0.7, 0.7), rng.uniform(-0.7, 0.7), rng.uniform(0, math.pi)))
    mesh_object("rubble_heap_4m__tiles", bm, ["tile_hall"], r)
    bm = bmesh.new()
    add_box(bm, 0.5, 3.5, 0.5, 3.5, 0.0, 1.2)
    mesh_object("rubble_heap_4m__block-colonly", bm, ["arch_stone"], r)


# --- step 3: the Cistern Archive (R11) --------------------------------------------
# The water's surface is 0.4 m below the hall's floor; a shallow bay's floor
# 0.9 m down (you wade), a deep bay's 2 m down (you can't go in).
WATER = -0.4
SHALLOW = -0.9
DEEP = -2.0
FOOT = -2.2        # bottom of everything that stands in the water


def water_quad(r, name, x0=0.0, x1=4.0, y0=0.0, y1=4.0):
    bm = bmesh.new()
    vs = [bm.verts.new((x, y, WATER)) for (x, y) in ((x0, y0), (x1, y0), (x1, y1), (x0, y1))]
    bm.faces.new(vs)
    mesh_object(name, bm, ["cistern_water"], r)


def basin(r):
    """A shallow bay: a stone floor 0.9 m down under the water; you wade here."""
    bm = bmesh.new()
    add_box(bm, 0.0, 4.0, 0.0, 4.0, SHALLOW - 0.2, SHALLOW)
    mesh_object("basin_cell_4m__floor-col", bm, ["floor_stone"], r)
    water_quad(r, "basin_cell_4m__water")


def basin_deep(r):
    """A deep bay: its floor 2 m down, lined with brick up to the shallows'
    floor, and a wall nobody sees that only the player meets (wade_stop)."""
    bm = bmesh.new()
    add_box(bm, 0.0, 4.0, 0.0, 4.0, DEEP - 0.2, DEEP)
    for (x0, x1, y0, y1) in ((0.0, 4.0, 0.0, 0.12), (0.0, 4.0, 3.88, 4.0), (0.0, 0.12, 0.12, 3.88), (3.88, 4.0, 0.12, 3.88)):
        add_box(bm, x0, x1, y0, y1, DEEP, SHALLOW)
    mesh_object("basin_cell_4m_deep__pit-col", bm, ["brick"], r)
    water_quad(r, "basin_cell_4m_deep__water")
    bm = bmesh.new()
    add_box(bm, 0.0, 4.0, 0.0, 4.0, SHALLOW, 2.6)
    mesh_object("basin_cell_4m_deep__wade_stop-colonly", bm, ["brick"], r)


def causeway(r):
    """A stone path 1.6 m wide along the cell (Y) at the floor's level, its sides
    sloping into the shallows (37 degrees: you can wade in and climb out;
    rev 3: 42 degrees, from a 2 m path, was too steep to climb at the lip)."""
    bm = bmesh.new()
    add_box(bm, 1.2, 2.8, 0.0, 4.0, FOOT, 0.0)
    # Each side: the slope's cross-section (X, Z) run along the cell's Y.
    add_prism(bm, [(1.2, 0.0), (0.0, SHALLOW), (0.0, FOOT), (1.2, FOOT)], 0.0, 0.0, 0.0, 4.0)
    add_prism(bm, [(2.8, 0.0), (2.8, FOOT), (4.0, FOOT), (4.0, SHALLOW)], 0.0, 0.0, 0.0, 4.0)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh_object("causeway_cell_4m__body-col", bm, ["floor_stone"], r)
    water_quad(r, "causeway_cell_4m__water_w", 0.0, 1.2)
    water_quad(r, "causeway_cell_4m__water_e", 2.8, 4.0)


def quay(r):
    """A whole bay at the floor's level, built up from the water (the
    causeway's ends, its junctions, and a door's bay)."""
    bm = bmesh.new()
    add_box(bm, 0.0, 4.0, 0.0, 4.0, FOOT, 0.0)
    mesh_object("causeway_cell_4m_quay__body-col", bm, ["floor_stone"], r)


def basin_edge(r):
    """The wall below the floor along a water bay's edge, down to the bed."""
    bm = bmesh.new()
    add_box(bm, 0.0, 4.0, -T, T, FOOT, 0.0)
    mesh_object("basin_edge_4m__body-col", bm, ["brick"], r)


def pier_brick(r):
    """A square brick pier standing in the water, up to the arches at 4 m."""
    bm = bmesh.new()
    add_box(bm, -0.32, 0.32, -0.32, 0.32, FOOT, 3.8)
    mesh_object("post_pier_brick__body-col", bm, ["brick"], r)
    bm = bmesh.new()
    add_box(bm, -0.4, 0.4, -0.4, 0.4, 3.8, CAP)
    add_box(bm, -0.38, 0.38, -0.38, 0.38, WATER - 0.05, WATER + 0.25)
    mesh_object("post_pier_brick__courses", bm, ["arch_stone"], r)


def dome_brick(r):
    dome(r, "brick", name="dome_cell_4m_brick")


def platform(r):
    """Centred in a cell: a timber deck on piles above the water, crates of
    books on it. One box of collision: nobody climbs onto it."""
    import random
    rng = random.Random(31)
    bm = bmesh.new()
    add_box(bm, 0.55, 3.45, 0.55, 3.45, -0.08, 0.05)
    for (x, y) in ((0.7, 0.7), (3.3, 0.7), (3.3, 3.3), (0.7, 3.3), (2.0, 0.7), (2.0, 3.3)):
        add_box(bm, x - 0.09, x + 0.09, y - 0.09, y + 0.09, FOOT, -0.08)
    for (cx, cy, s, h) in ((1.2, 1.2, 0.7, 0.6), (1.25, 1.2, 0.55, 0.5), (2.6, 1.3, 0.75, 0.65), (2.7, 2.7, 0.7, 0.55), (1.3, 2.7, 0.6, 0.5)):
        z0 = 0.05 if h != 0.5 or cx > 1.24 else 0.65
        add_box(bm, cx - s / 2, cx + s / 2, cy - s / 2, cy + s / 2, z0, z0 + h)
    mesh_object("platform_cell_4m__timber", bm, ["wood"], r)
    bm = bmesh.new()
    for (cx, cy) in ((1.2, 1.2), (2.6, 1.3), (2.7, 2.7)):
        for k in range(rng.randint(2, 4)):
            w = rng.uniform(0.18, 0.3)
            add_obox(bm, (cx + rng.uniform(-0.15, 0.15), cy + rng.uniform(-0.15, 0.15), 0.7 + 0.06 * k + (0.6 if cx < 1.3 else 0.0)),
                     (w, w * 0.7, 0.05), (0.0, 0.0, rng.uniform(0, math.pi)))
    mesh_object("platform_cell_4m__books", bm, ["book_leather"], r)
    bm = bmesh.new()
    add_box(bm, 0.5, 3.5, 0.5, 3.5, FOOT, 1.4)
    mesh_object("platform_cell_4m__block-colonly", bm, ["wood"], r)


def vault_door(r):
    """The far wall's sealed bronze door, under a 3 m arch. Rev 2 (room rework
    step 5, your word: no lanterns in the cistern): in place of the two
    lanterns, glowing vines climb the jambs and meet over the arch, pods
    along them and strands hanging into the opening (on the room side,
    Blender +Y)."""
    body = wall_body("wall_vault_door_4m__body-col", r)
    bm = bmesh.new()
    add_prism(bm, arch_outline(3.0, 1.9, 0.6, 10), 0.5, -0.01, -T - 0.1, T + 0.1)
    cutter = mesh_object("cutter", bm, ["brick"], r)
    cut(body, cutter)
    bm = bmesh.new()
    add_prism(bm, arch_outline(3.0, 1.9, 0.6, 10), 0.5, 0.0, -0.08, 0.08)
    for x in (1.0, 1.5, 2.5, 3.0):
        add_box(bm, x - 0.04, x + 0.04, 0.08, 0.12, 0.1, 2.2)       # bands across the leaves
    add_box(bm, 1.98, 2.02, 0.08, 0.14, 0.0, 2.85)                    # the seam
    mesh_object("wall_vault_door_4m__door-col", bm, ["brass"], r)
    vines, pods = bmesh.new(), bmesh.new()
    y = T + 0.05
    for side in (-1, 1):
        x0 = 2.0 + side * 1.75           # up the jamb beside the arch
        climb = [(x0 + 0.06 * math.sin(k * 1.7), y, 0.05 + k * 0.32) for k in range(10)]
        top = climb[-1]
        over = [(top[0] - side * 0.3 * k, y, top[2] + 0.12 * math.sin(k * 0.6)) for k in range(1, 6)]
        path = climb + over
        add_tube(vines, path, 0.035, segs=5)
        for k, (px, py, pz) in enumerate(path):
            if k % 2 == 1:
                R = 0.06 + 0.03 * ((k * 7) % 3) / 2.0
                add_lathe(pods, [(0.0, pz - R * 1.5), (R, pz - R * 0.6), (R * 0.75, pz + R * 0.2), (0.0, pz + R * 0.4)],
                          px, py + 0.05, segs=6)
        for j, (sx, length) in enumerate(((top[0] - side * 0.45, 0.7), (top[0] - side * 0.95, 0.45), (top[0] - side * 1.35, 0.3))):
            sz = top[2] + 0.1
            strand = [(sx, y + 0.03, sz - length * t / 3) for t in range(4)]
            add_tube(vines, strand, [0.016, 0.013, 0.01, 0.008], segs=4)
            (ex, ey, ez) = strand[-1]
            add_lathe(pods, [(0.0, ez - 0.1), (0.05, ez - 0.05), (0.04, ez), (0.0, ez + 0.02)], ex, ey, segs=6)
        marker("LIGHT_fungus__door_%s" % ("l" if side < 0 else "r"), r, (x0, T + 0.4, 2.0), {"range": 4.5, "energy": 0.8})
    mesh_object("wall_vault_door_4m__vines", vines, ["camp_root"], r)
    mesh_object("wall_vault_door_4m__pods", pods, ["emit_fungus"], r)


# --- step 4: the Light-Well Stair (R09), rev 2: a cone ----------------------------
# The shaft is a cone (your design, 2026-10-23; concept: previews/p5_cone_idea/v5):
# its wall leans in CONE_S m per metre up, from a floor radius of 10 or 12 m to
# an oculus CONE_RT across. A stair cut CONE_DEPTH into the wall climbs a storey
# (4 m) every three-quarters of a turn, so each floor's doorway faces another
# side (W, N, E, S, ...). Each storey's stair starts with a flat landing (the
# doorway's, or a niche's) and climbs CONE_RISERS steps of 0.2 m, with a ramp
# for collision over the step nosings (the player climbs slopes, not steps).
# Along the stair's open edge a stone ledge carries a low parapet and columns
# under the wall that leans over the stair; in the back wall, between the
# columns, niches hold a cone_niche socket (books, a tile panel, a sealed door,
# or plain brick on the upper floors).
#
# Pieces (FREE, origin on the shaft's axis at the piece's floor; angle 0, the
# landing, on the room's +Z, Blender -Y; angles run toward +X like RingGrammar's
# SIDE_TURN):
#   cone_c<r>_exit / _closed   one storey's stair and the wall over it: the
#                       wall from this storey's treads up to the treads one turn
#                       above, from the landing to the next storey's landing;
#                       <r> is the wall's radius at its floor (x10). _exit has the
#                       doorway and passage at the landing, _closed a niche.
#   cone_cap<R0>_<L>    the top storey's landing (always a doorway), the stair's
#                       end, and the cone over it to the oculus, for floor radius
#                       R0 and L levels.
#   cone_base<R0>       the floor, the pool and the wall below the first turn.
#   cone_lantern        a lantern hung from the stair's ceiling.
#   cone_passage_2m     2 m of passage from the cone's outer face to the room's edge.
# GDScript twin (the same formulas): scripts/gen/ring_grammar.gd.
STOREY = 4.0
CONE_S = 0.375        # the wall leans in this much per metre up (1.5 m a storey)
CONE_W = 3.6          # wall thickness, measured level
CONE_DEPTH = 1.0      # the stair's cut into the wall
CONE_HEAD = 2.6       # its headroom over each tread
CONE_RISERS = 20      # steps per storey (0.2 m each)
CONE_RT = 2.5         # the oculus's radius
CONE_LEDGE = 0.8      # the stone ledge's reach into the shaft
CONE_PARAPET = 0.85
CONE_COL_R = 0.11       # rev 6 chunks / rev 14 caps (your walk of step 6): columns stand on the parapet
CONE_PAR_W = 0.36       # the parapet's thickness (0.2 before): the columns' bases fit on it
CONE_BAY = 4.8        # stair length between columns
NICHE_D = 0.55        # niche depth (the socket sits 0.25 in front of its back)
SUN_FLOOR = 3.6     # the sun's pool across the floor, about (rev 8 caps: 4 m before; 7 m at rev 9-10, too wide on your walk; rev 11 4.8); rev 15: 3.6, three quarters (your walk)
SUN_GOLD = [1.0, 0.97, 0.78]       # a green-gold daylight after your reference (rev 12), whiter at rev 13 (your note)
LEAF_FILL = [0.86, 0.94, 0.76]     # its bounce off the garden
TURN = 1.5 * math.pi  # angle per storey
CONE_SIZES = ((12.0, (3, 4, 5)), (10.0, (3, 4)))   # floor radius, level counts
EPS = 0.0015          # half the width of a riser in a sweep (radians)


def polar(r, t):
    """Blender (x, y) of radius r at angle t (radians; 0 = Blender -Y)."""
    return (r * math.sin(t), -r * math.cos(t))


def c_face(r, z):
    """The cone's inner face at height z over a storey whose face is r at 0."""
    return r - CONE_S * z


def c_hb(r):
    """Half the landing's angle (3.6 m of stair at the walk)."""
    return 1.8 / max(r + 0.5, 2.0)     # (clamped for the virtual storeys over the top)


def c_span(r):
    """(start, end) angles of the climb from a storey with radius r."""
    return c_hb(r), TURN - c_hb(r - 1.5)


def c_risers(r):
    a, b = c_span(r)
    return [a + (i + 0.5) * (b - a) / CONE_RISERS for i in range(CONE_RISERS)]


def c_bays(r):
    a, b = c_span(r)
    return max(3, int(round((b - a) * (r + 0.3) / CONE_BAY)))


def c_storey(r0, phi):
    """(storey j, angle within it) of unwrapped angle phi over a piece whose
    storey 0 has radius r0 (storey j: r0 - 1.5 j)."""
    j = 0
    while phi >= TURN * (j + 1) - c_hb(r0 - 1.5 * (j + 1)):
        j += 1
    while phi < TURN * j - c_hb(r0 - 1.5 * j):
        j -= 1
    return j, phi - TURN * j


def c_tread(r0, phi):
    """The tread's height at unwrapped angle phi (risers counted)."""
    j, p = c_storey(r0, phi)
    n = sum(1 for a in c_risers(r0 - 1.5 * j) if a <= p)
    return STOREY * j + 0.2 * n


def c_line(r0, phi):
    """A smooth height through the climb (landing to landing, straight): the
    walk's edges (the cut's back wall, the guide, the ramp's sides) follow the
    cone's face at this height, so they don't jog 7.5 cm at every riser."""
    j, p = c_storey(r0, phi)
    a, b = c_span(r0 - 1.5 * j)
    return STOREY * j + STOREY * min(max((p - a) / (b - a), 0.0), 1.0)


def c_edge(r0, phi):
    """The cone's face at the walk, smooth (see c_line)."""
    return c_face(r0, c_line(r0, phi))


def c_ramp(r0, phi):
    """The collision ramp's height: 2 cm over the step nosings (storey 0's
    climb), from half a step out on the landing (0.02 up) to the last nosing
    (4.02), so the capsule never meets a step's edge."""
    a, b = c_span(r0)
    return 0.2 * ((phi - a) / ((b - a) / CONE_RISERS) + 0.5) + 0.02


def c_breaks(r0, a, b):
    """Riser angles of every storey between a and b (unwrapped)."""
    out = []
    for j in range(-2, 9):
        for x in c_risers(r0 - 1.5 * j):
            x += TURN * j
            if a < x < b:
                out.append(x)
    return out


def c_samples(r0, a, b, shift=(0.0,)):
    """Sweep angles from a to b: every 0.02 rad, and both sides of each riser
    (of the treads, and of the treads one turn above when shift has 2 pi)."""
    pts = [a + (b - a) * i / max(1, int((b - a) / 0.02)) for i in range(max(1, int((b - a) / 0.02)) + 1)]
    for s in shift:
        for x in c_breaks(r0, a + s, b + s):
            pts += [x - s - EPS, x - s + EPS]
    pts = sorted(p for p in pts if a <= p <= b)
    out = []
    for p in pts:
        if not out or p - out[-1] > 1e-5:
            out.append(p)
    return out


def c_even(a, b, step=0.04):
    """Even sweep angles from a to b: for the smooth collision (ramp, guide),
    whose hairline slivers at each riser caught the capsule (your walk)."""
    n = max(1, int(math.ceil((b - a) / step)))
    return [a + (b - a) * i / n for i in range(n + 1)]


def sweep(bm, phis, section, mat=0):
    """A closed solid swept round the axis: section(phi) -> [(r, z), ...]
    (the same number of points at every angle, counter-clockwise in r-z)."""
    rings = []
    for p in phis:
        rings.append([bm.verts.new((*polar(r, p), z)) for (r, z) in section(p)])
    n = len(rings[0])
    for i in range(len(rings) - 1):
        a, b = rings[i], rings[i + 1]
        for k in range(n):
            kk = (k + 1) % n
            bm.faces.new((a[k], a[kk], b[kk], b[k])).material_index = mat
    bm.faces.new(rings[0]).material_index = mat
    bm.faces.new(list(reversed(rings[-1]))).material_index = mat


def groove_section(r0, zt_fn):
    """The wall over a tread: from the stair's cut (its floor is the wall below)
    out to the outer face, up to zt, and back down the inner face to the
    stair's ceiling."""
    def section(p):
        zb = c_tread(r0, p)
        zt = zt_fn(p)
        rb = c_face(r0, zb)
        back = c_edge(r0, p) + CONE_DEPTH     # the cut's back wall: smooth
        return [(back, zb), (rb + CONE_W, zb), (c_face(r0, zt) + CONE_W, zt), (c_face(r0, zt), zt),
                (c_face(r0, zb + CONE_HEAD), zb + CONE_HEAD), (back, zb + CONE_HEAD)]
    return section


def solid_section(r0, zb_fn, zt_fn):
    def section(p):
        zb, zt = zb_fn(p), zt_fn(p)
        return [(c_face(r0, zb), zb), (c_face(r0, zb) + CONE_W, zb), (c_face(r0, zt) + CONE_W, zt), (c_face(r0, zt), zt)]
    return section


def tangent_prism(bm, outline, t, r_back, v0, v1, z0):
    """An XZ outline (x 0..w) centred on the tangent at angle t, extruded from
    v0 to v1 outward of radius r_back, its foot at z0 (niche and door cutters)."""
    w = max(u for (u, _v) in outline)
    o = (math.sin(t), -math.cos(t))
    tg = (math.cos(t), math.sin(t))
    rings = []
    for v in (v0, v1):
        ring = []
        for (u, zz) in outline:
            uu = u - w / 2
            ring.append(bm.verts.new((o[0] * (r_back + v) + tg[0] * uu, o[1] * (r_back + v) + tg[1] * uu, z0 + zz)))
        rings.append(ring)
    a, b = rings
    bm.faces.new(a)
    bm.faces.new(list(reversed(b)))
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))


def stair_edge(r, root, a, b, tag, parapet_from=0.0, newel=False):
    """The ledge, the parapet (where the tread is at least parapet_from up),
    the columns (at the bays' ends between a and b) and the collision ramp of
    a storey with radius r, between angles a and b. Your walk of step 6: the
    columns stood half on the walk and half in the parapet and caught you; now
    they stand on a thicker parapet, whose smooth inner face is the walk's
    edge, and `newel` puts a post where the parapet starts."""
    phis = c_samples(r, a, b)
    bm = bmesh.new()
    sweep(bm, phis, lambda p: [(c_face(r, c_tread(r, p)) - CONE_LEDGE, c_tread(r, p) - 0.25),
                               (c_face(r, c_tread(r, p)) + 0.12, c_tread(r, p) - 0.25),
                               (c_face(r, c_tread(r, p)) + 0.12, c_tread(r, p)),
                               (c_face(r, c_tread(r, p)) - CONE_LEDGE, c_tread(r, p))])
    mesh_object("cone_%s__ledge-col" % tag, bm, ["arch_stone"], root)
    pa = [p for p in phis if c_tread(r, p) >= parapet_from]
    if len(pa) > 1:
        bm = bmesh.new()
        sweep(bm, pa, lambda p: [(c_face(r, c_tread(r, p)) - CONE_LEDGE, c_tread(r, p)),
                                 (c_face(r, c_tread(r, p)) - CONE_LEDGE + CONE_PAR_W, c_tread(r, p)),
                                 (c_face(r, c_tread(r, p)) - CONE_LEDGE + CONE_PAR_W, c_tread(r, p) + CONE_PARAPET),
                                 (c_face(r, c_tread(r, p)) - CONE_LEDGE, c_tread(r, p) + CONE_PARAPET)])
        mesh_object("cone_%s__parapet" % tag, bm, ["arch_stone"], root)
        # The walk's inner edge: the parapet's whole footprint, smooth (the
        # parapet itself jogs at each riser), up past the columns: you slide
        # along it, and there is no strip of ledge outside it to get onto.
        g = CONE_LEDGE - CONE_PAR_W
        bm = bmesh.new()
        sweep(bm, c_even(pa[0], pa[-1]), lambda p: [(c_edge(r, p) - CONE_LEDGE, c_line(r, p) - 0.3),
                                                    (c_edge(r, p) - g, c_line(r, p) - 0.3),
                                                    (c_edge(r, p) - g, c_line(r, p) + 2.3),
                                                    (c_edge(r, p) - CONE_LEDGE, c_line(r, p) + 2.3)])
        mesh_object("cone_%s__guide-colonly" % tag, bm, ["arch_stone"], root)
    # Columns at the bays' ends, each on the middle of its step.
    s0, s1 = c_span(r)
    nb = c_bays(r)
    bm = bmesh.new()
    for i in range(nb + 1):
        t = s0 + (s1 - s0) * i / nb
        if not (a - 1e-6 <= t <= b + 1e-6):
            continue
        rs = [s0] + c_risers(r) + [s1]
        for k in range(len(rs) - 1):
            if rs[k] <= t <= rs[k + 1]:
                t = min(max((rs[k] + rs[k + 1]) / 2, a + 0.01), b - 0.01)
                break
        z = c_tread(r, t)
        if z < parapet_from:
            continue
        x, y = polar(c_face(r, z) - CONE_LEDGE + CONE_PAR_W / 2, t)     # on the parapet's middle
        zp = z + CONE_PARAPET
        add_lathe(bm, [(CONE_COL_R + 0.05, zp - 0.02), (CONE_COL_R + 0.05, zp + 0.12), (CONE_COL_R, zp + 0.18),
                       (CONE_COL_R, z + CONE_HEAD - 0.3), (CONE_COL_R + 0.06, z + CONE_HEAD - 0.2),
                       (CONE_COL_R + 0.06, z + CONE_HEAD + 0.05)], x, y, segs=12)
    if newel and len(pa) > 1:     # a post where the parapet starts
        t = pa[0] + 0.12 / r
        z = c_tread(r, pa[0])
        x, y = polar(c_face(r, z) - CONE_LEDGE + CONE_PAR_W / 2, t)
        add_lathe(bm, [(0.2, z - 0.02), (0.2, z + 1.0), (0.24, z + 1.06), (0.24, z + 1.14), (0.12, z + 1.24), (0.0, z + 1.3)], x, y, segs=12)
    if bm.verts:
        mesh_object("cone_%s__columns" % tag, bm, ["arch_stone"], root)
    else:
        bm.free()
    # The ramp the player walks on, over the nosings (climb only).
    half = (s1 - s0) / CONE_RISERS / 2
    ra, rb_ = s0 - half, min(b, s1 - half)     # from half a step out on the landing (the floor's too)
    if rb_ > ra:
        bm = bmesh.new()
        sweep(bm, c_even(ra, rb_), lambda p: [(c_edge(r, p) - 0.3, c_ramp(r, p) - 0.1),
                                                    (c_edge(r, p) + CONE_DEPTH - 0.02, c_ramp(r, p) - 0.1),
                                                    (c_edge(r, p) + CONE_DEPTH - 0.02, c_ramp(r, p)),
                                                    (c_edge(r, p) - 0.3, c_ramp(r, p))])
        mesh_object("cone_%s__ramp-colonly" % tag, bm, ["arch_stone"], root)


def door_cutter(bm, r):
    tangent_prism(bm, arch_outline(2.2, 1.9), 0.0, c_face(r, 0.0) + CONE_DEPTH, -0.3, CONE_W - CONE_DEPTH + 0.8, -0.05)


# Rev 7 chunks (your walk of step 6): the tall arched niches cut up through
# the stair's ceiling (2.6 m over the tread) and sat level in a sloping wall.
# Now, on the reading storeys (floor radius 12 and 10, the bottom two), a
# bookcase let into the back wall on every full tread, level on its tread, so
# the cases step up with the stair; higher up, small arched taghcheh at varied
# heights (one, two or none a tread). Each holds a socket at its back, facing
# the shaft (Blender +Y): cone_bookcase or cone_cubby.
READING_R = (12.0, 10.5, 10.0, 8.5)
CASE_W, CASE_H, CASE_D, CASE_SILL = 1.6, 2.0, 0.45, 0.22
CUBBY_D = 0.4


def stair_wall_slots(r, root, tag, cutters, exit_door, glass=None):
    reading = any(abs(r - x) < 1e-6 for x in READING_R)
    s0, s1 = c_span(r)
    rs = [s0] + c_risers(r) + [s1]
    spots = [(k, (rs[k] + rs[k + 1]) / 2) for k in range(1, len(rs) - 2)]
    if not exit_door:
        spots = [(0, 0.0)] + spots     # the landing's back wall
    n = 0
    for (k, t) in spots:
        z = c_tread(r, t)
        rb = c_edge(r, t) + CONE_DEPTH
        if reading:
            # Chunks rev 10 (the route gate): where the case spans a riser (the
            # small cone's tight second storey) it sits clear of the higher step.
            hw = (CASE_W / 2 + 0.15) / rb
            top = max(c_tread(r, t - hw), c_tread(r, t + hw))
            slots = [(0.0, [(0.0, 0.0), (0.0, CASE_H), (CASE_W, CASE_H), (CASE_W, 0.0)], CASE_D, max(z + CASE_SILL, top + 0.16), "cone_bookcase")]
        elif k % 3 == 0:
            slots = [(s * 0.42, arch_outline(0.6, 0.55), CUBBY_D, z + 1.05, "cone_cubby") for s in (-1, 1)]
        elif k % 3 == 1:
            slots = [(0.0, arch_outline(0.8, 0.7), CUBBY_D, z + 0.8, "cone_cubby")]
        else:
            slots = []
        for (off, outline, depth, sill, kind) in slots:
            tt = t + off / rb
            tangent_prism(cutters, outline, tt, rb, -0.3, depth, sill)
            if kind == "cone_cubby" and glass is not None:
                orosi_pane(glass, outline, tt, rb + depth - 0.006, sill)
            o = marker("SOCKET_%s__%s_%d" % (kind, tag, n), root, (*polar(rb + depth, tt), sill), {"socket_set": kind})
            o.rotation_euler = (0.0, 0.0, tt)
            n += 1


def orosi_pane(bm, outline, t, r_back, z0):
    """Coloured glass (emit_orosi) filling a taghcheh's arch at radius r_back,
    its UVs the outline's box (your walk of step 6: orosi backs that glow)."""
    w = max(u for (u, _v) in outline)
    h = max(v for (_u, v) in outline)
    uv = bm.loops.layers.uv.verify()
    o = (math.sin(t), -math.cos(t))
    tg = (math.cos(t), math.sin(t))
    vs = [bm.verts.new((o[0] * r_back + tg[0] * (u - w / 2), o[1] * r_back + tg[1] * (u - w / 2), z0 + zz)) for (u, zz) in outline]
    f = bm.faces.new(vs)
    for loop, (u, zz) in zip(f.loops, outline):
        loop[uv].uv = (u / w, zz / h)


def cone_chunk(r, exit_door):
    """One storey: the wall from its treads to the treads one turn above, from
    its landing to the next storey's, with the cut, niches and stair edge."""
    a, b = -c_hb(r), TURN - c_hb(r - 1.5)
    tag = "c%d_%s" % (round(r * 10), "exit" if exit_door else "closed")

    def build(root):
        bm = bmesh.new()
        sweep(bm, c_samples(r, a, b, (0.0, 2 * math.pi)), groove_section(r, lambda p: c_tread(r, p + 2 * math.pi)))
        body = mesh_object("cone_%s__wall-col" % tag, bm, ["brick"], root)
        cutters = bmesh.new()
        glass = bmesh.new()
        stair_wall_slots(r, root, tag, cutters, exit_door, glass)
        if exit_door:
            door_cutter(cutters, r)
        cutter = mesh_object("cutter", cutters, ["brick"], root)
        cut(body, cutter)
        if glass.faces:
            mesh_object("cone_%s__orosi" % tag, glass, ["emit_orosi_soft"], root, recalc=False)   # half the Gorge window glow
        # Storey 0 starts on the floor: no ledge or parapet on its landing.
        floor = any(abs(r - s) < 1e-6 for (s, _l) in CONE_SIZES)
        stair_edge(r, root, c_hb(r) if floor else a, b, tag, 0.0, newel=floor)     # rev 6: the parapet from the stair's foot (your walk)
    return build


def cone_cap(R0, L):
    r = R0 - 1.5 * (L - 1)
    z_oc = (r - CONE_RT) / CONE_S
    hb = c_hb(r)

    def build(root):
        tag = "cap%d_%d" % (round(R0 * 10), L)
        bm = bmesh.new()
        sweep(bm, c_samples(r, -hb, hb), groove_section(r, lambda p: z_oc))
        body = mesh_object("cone_%s__landing-col" % tag, bm, ["brick"], root)
        cutters = bmesh.new()
        door_cutter(cutters, r)
        cut(body, mesh_object("cutter", cutters, ["brick"], root))
        bm = bmesh.new()
        sweep(bm, c_samples(r, hb, 2 * math.pi - hb), solid_section(r, lambda p: c_tread(r, p), lambda p: z_oc))
        mesh_object("cone_%s__wall-col" % tag, bm, ["brick"], root)
        stair_edge(r, root, -hb, hb, tag)
        sky = bmesh.new()
        vs = [sky.verts.new((*polar(CONE_RT + 0.1, 2 * math.pi * i / 32), z_oc + 0.02)) for i in range(32)]
        sky.faces.new(list(reversed(vs)))
        mesh_object("cone_%s__sky" % tag, sky, ["emit_glass_cool"], root, recalc=False)
        marker("LIGHT_cold__oculus", root, (0.0, 0.0, z_oc - 0.6), {"color": [0.93, 0.98, 0.84]})
        # Sunlight down the shaft (your review): a spot far over the oculus, its
        # beam the oculus's width at the top and ~4 m across on the floor, seen in
        # a column of haze; a fill halfway down for the light it bounces.
        total = STOREY * (L - 1) + z_oc
        lift = (CONE_RT - 0.2) * total / (SUN_FLOOR - CONE_RT + 0.2)
        marker("LIGHT_shaft__oculus", root, (0.0, 0.0, z_oc + lift),
               {"range": total + lift + 2.0, "spot_angle": math.degrees(math.atan((SUN_FLOOR - CONE_RT + 0.2) / total)), "energy": 40.0, "color": SUN_GOLD})     # rev 9: much brighter, a sunlit floor (room rework step 6)
        marker("FOG_haze__shaft", root, (0.0, 0.0, z_oc - total / 2.0), {"fog_size": [3.45, 3.45, total], "density": 0.035, "albedo": [0.95, 0.97, 0.85], "emission": [0.66, 0.68, 0.45], "emission_energy": 0.04})     # rev 11: narrower; rev 12 green-gold (your walk); rev 15: 75% (your walk)
        marker("LIGHT_bounce__mid", root, (0.0, 0.0, z_oc - total / 2.0), {"range": 12.0, "energy": 0.3, "color": LEAF_FILL})     # rev 7: less fill, more contrast
    return build


def cone_base(R0):
    hb = c_hb(R0)

    def build(root):
        tag = "base%d" % round(R0 * 10)
        bm = bmesh.new()
        sweep(bm, c_samples(R0, -hb, 2 * math.pi - hb), solid_section(R0, lambda p: -0.3, lambda p: max(c_tread(R0, p), 0.0)))
        mesh_object("cone_%s__wall-col" % tag, bm, ["brick"], root)
        bm = bmesh.new()
        add_ngon_prism(bm, 64, R0 + 0.15, -0.3, 0.0)
        mesh_object("cone_%s__floor-col" % tag, bm, ["floor_stone"], root)
        bm = bmesh.new()
        for k in range(16):
            a0 = 2 * math.pi * k / 16
            polar_block(bm, 1.6, 2.0, a0, a0 + 2 * math.pi / 16, 0.0, 0.45, steps=1)
        mesh_object("cone_%s__curb-col" % tag, bm, ["arch_stone"], root)
        bm = bmesh.new()
        vs = [bm.verts.new((*polar(1.62, 2 * math.pi * i / 24), 0.3)) for i in range(24)]
        bm.faces.new(list(reversed(vs)))
        mesh_object("cone_%s__water" % tag, bm, ["cistern_water"], root, recalc=False)
        marker("LIGHT_bounce__floor", root, (0.0, 0.0, 2.5), {"range": R0 + 4.0, "color": LEAF_FILL})     # the sunlit floor's bounce (rev 8: green-gold)
    return build


def polar_block(bm, r0, r1, a0, a1, z0, z1, steps=3, rise=0.0, mat=0):
    """A closed block between radii r0 < r1 and angles a0 < a1, from z0 to z1."""
    ring = []
    for i in range(steps + 1):
        t = a0 + (a1 - a0) * i / steps
        dz = rise * i / steps
        ring.append([bm.verts.new((*polar(r, t), z + dz)) for (r, z) in ((r0, z0), (r1, z0), (r1, z1), (r0, z1))])
    for i in range(steps):
        a, b = ring[i], ring[i + 1]
        for j in range(4):
            jj = (j + 1) % 4
            bm.faces.new((a[j], a[jj], b[jj], b[j])).material_index = mat
    bm.faces.new(ring[0]).material_index = mat
    bm.faces.new(list(reversed(ring[-1]))).material_index = mat


def cone_lantern(root):
    bm = bmesh.new()
    glass = bmesh.new()
    lantern_at(bm, glass, 0.0, 0.0, 2.05, 0.15, 0.45)     # over the head (the capsule is 1.8 m)
    add_box(bm, -0.02, 0.02, -0.02, 0.02, 2.5, CONE_HEAD + 0.05)
    mesh_object("cone_lantern__body", bm, ["brass"], root)
    mesh_object("cone_lantern__glass", glass, ["emit_lantern"], root)
    # Rev 3 (room rework step 6): dimmer, so the daylight down the shaft leads.
    marker("LIGHT_lantern__cone", root, (0.0, 0.0, 2.25), {"energy": 0.6, "range": 5.0})
    marker("SOCKET_lamp_state__cone", root, (0.0, 0.0, 2.25), LAMP_SOCKET)


def cone_passage(length):
    """`length` m of passage running out along -Y (the room's +Z) from the origin."""
    tag = "cone_passage_%s" % ("2m" if length == 2.0 else "05m")

    def build(root):
        bm = bmesh.new()
        add_box(bm, -1.6, 1.6, -length, 0.0, -0.3, 0.0)
        mesh_object(tag + "__floor-col", bm, ["floor_stone"], root)
        bm = bmesh.new()
        for (x0, x1) in ((-1.6, -1.2), (1.2, 1.6)):
            add_box(bm, x0, x1, -length, 0.0, 0.0, 3.3)
        add_box(bm, -1.6, 1.6, -length, 0.0, 3.3, 3.7)
        mesh_object(tag + "__walls-col", bm, ["brick"], root)
    return build


def recess_plain_cone(root):
    """Plain brick filling a niche flush with the stair's back wall (the upper
    floors' niches)."""
    bm = bmesh.new()
    add_prism(bm, arch_outline(3.0, 1.9), -1.5, 0.0, -0.27, 0.3)
    mesh_object("recess_plain_cone__infill-col", bm, ["brick"], root)


def cone_modules():
    out = []
    tag = "brick,cone,lightwell"
    seen = set()
    for (R0, levels) in CONE_SIZES:
        L = max(levels)
        for j in range(L - 1):
            r = R0 - 1.5 * j
            for exit_door in ((True,) if j == 0 else (True, False)):
                name = "M_cone_c%d_%s" % (round(r * 10), "exit" if exit_door else "closed")
                if name not in seen:
                    seen.add(name)
                    out.append((name, props("free", [0, 1, 0], "", tag), cone_chunk(r, exit_door)))
        for n in levels:
            out.append(("M_cone_cap%d_%d" % (round(R0 * 10), n), props("free", [0, 1, 0], "", tag + ",light"), cone_cap(R0, n)))
        out.append(("M_cone_base%d" % round(R0 * 10), props("free", [0, 0, 0], "", tag), cone_base(R0)))
    out += [
        ("M_cone_lantern", props("free", [0, 1, 0], "", "brass,light,lightwell"), cone_lantern),
        ("M_cone_passage_2m", props("free", [0, 1, 0], "", tag), cone_passage(2.0)),
        ("M_cone_passage_05m", props("free", [0, 1, 0], "", tag), cone_passage(0.5)),
        ("M_recess_plain_cone", props("free", [1, 1, 0], "", "brick,lightwell", family="dressing"), recess_plain_cone),
    ]
    return out


# Step 4's first light-well (wooden galleries and ramps), replaced by the cone
# after your review: removed from the .blend when found.
RETIRED = ["M_ring%d_%s" % (R, p) for R in (8, 12) for p in
           ("wall", "wall_exit", "gallery", "gallery_landing", "stair", "stair_landing", "stair_end", "lantern", "floor", "cap")]


MODULES = [
    ("M_post_column_twisted", props("post", [0, 1, 0], "", "stone,column,hall"), column_twisted),
    ("M_post_hall_pier", props("post", [0, 2, 0], "", "brick,structure,hall"), hall_pier),
    ("M_post_hall_pier_cap", props("post", [0, 1, 0], "", "brick,structure,hall"), hall_pier_cap),
    ("M_arcade_arch_4m", props("edge", [1, 1, 0], "open", "brick,arch,hall"), arcade_arch),
    ("M_wall_hall_band_4m", props("edge", [1, 1, 0], "solid", "brick,structure,hall"), hall_band),
    ("M_dome_cell_4m_a", props("cell", [1, 1, 1], "", "tile,dome,hall"), dome_a),
    ("M_dome_cell_4m_b", props("cell", [1, 1, 1], "", "plaster,dome,hall"), dome_b),
    ("M_oculus_cell_4m", props("cell", [1, 1, 1], "", "tile,dome,light,hall"), oculus),
    ("M_lantern_dome", props("free", [0, 1, 0], "", "brass,light,hall"), lantern_dome),
    ("M_case_freestanding_4m", props("free", [1, 0, 1], "", "wood,storage,hall", family="dressing"), case),
    ("M_landmark_plinth", props("free", [1, 0, 1], "", "stone,landmark,hall", family="dressing"), plinth),
    ("M_landmark_great_lamp", dict(props("free", [0, 1, 0], "", "brass,light,landmark", family="dressing"), kit_rev=3), great_lamp),
    ("M_landmark_catalogue_desk", dict(props("free", [1, 0, 1], "", "wood,landmark", family="dressing"), kit_rev=3), catalogue_desk),
    # Step 2: the big hall.
    ("M_lantern_dome_cluster", props("free", [0, 1, 0], "", "brass,light,hall"), lantern_dome_cluster),
    ("M_dome_cell_4m_fallen", props("cell", [1, 1, 1], "", "tile,dome,ruin,hall"), dome_fallen),
    ("M_rubble_heap_4m", props("free", [1, 0, 1], "", "stone,debris,hall", family="dressing"), rubble_heap),
    # Step 3: the Cistern Archive.
    ("M_basin_cell_4m", props("cell", [1, 0, 1], "", "stone,water,cistern"), basin),
    ("M_basin_cell_4m_deep", props("cell", [1, 0, 1], "", "brick,water,deep,cistern"), basin_deep),
    ("M_causeway_cell_4m", props("cell", [1, 0, 1], "", "stone,causeway,cistern"), causeway),
    ("M_causeway_cell_4m_quay", props("cell", [1, 0, 1], "", "stone,causeway,cistern"), quay),
    ("M_basin_edge_4m", props("edge", [1, 0, 0], "solid", "brick,water,cistern"), basin_edge),
    ("M_post_pier_brick", props("post", [0, 1, 0], "", "brick,structure,cistern"), pier_brick),
    ("M_dome_cell_4m_brick", props("cell", [1, 1, 1], "", "brick,dome,cistern"), dome_brick),
    ("M_platform_cell_4m", props("free", [1, 0, 1], "", "wood,storage,cistern", family="dressing"), platform),
    ("M_wall_vault_door_4m", dict(props("edge", [1, 1, 0], "solid", "brass,door,light,fungus,cistern"), kit_rev=2), vault_door),
    # The hall rework, step 1: carpet, sun domes, dim lamps, red lanterns.
    ("M_floor_carpet_4m", props("cell", [1, 0, 1], "", "stone,cloth,floor,hall"), floor_carpet),
    ("M_dome_sun_4m", dict(props("cell", [1, 1, 1], "", "tile,dome,light,hall"), kit_rev=4), dome_sun),
    ("M_lantern_oil", dict(props("free", [0, 1, 0], "", "brass,light,hall"), kit_rev=5), lantern_oil),
    ("M_lantern_moroccan", dict(props("free", [0, 1, 0], "", "brass,light,hall"), kit_rev=2), lantern_moroccan),
    # Step 2: the grand landmark.
    ("M_landmark_hauz", props("free", [1, 0, 1], "", "stone,water,landmark,hall", family="dressing"), landmark_hauz),
    ("M_landmark_takht", props("free", [1, 0, 1], "", "wood,cloth,light,landmark,hall", family="dressing"), landmark_takht),
    ("M_dome_sun_4m_centre", props("cell", [1, 1, 1], "", "tile,dome,light,hall"), dome_sun_centre),
    # Step 3: scholars at work.
    ("M_hall_reading_nook", props("free", [1, 0, 1], "", "wood,cloth,books,scholar,hall", family="dressing"), hall_reading_nook),
    ("M_hall_book_cart", props("free", [1, 0, 1], "", "wood,books,scholar,hall", family="dressing"), hall_book_cart),
    ("M_hall_sorting_table", props("free", [1, 0, 1], "", "wood,books,scholar,hall", family="dressing"), hall_sorting_table),
] + cone_modules() + [
]

# Script-made modules remade in place at a new revision (kit_blender.rebuild):
# hand edits to them are lost, so only list ones nobody has changed in Blender.
REBUILD = [("M_post_column_twisted", 3), ("M_dome_cell_4m_b", 2),
           ("M_basin_cell_4m", 2), ("M_basin_cell_4m_deep", 2), ("M_causeway_cell_4m", 3),   # rev 2: the cistern's own water; causeway rev 3: gentler sides
           ("M_cone_lantern", 3),   # rev 2: the lantern over the head; rev 3: dimmer (room rework step 6)
           ("M_wall_vault_door_4m", 2), ("M_dome_sun_4m", 4), ("M_lantern_oil", 5),
           ("M_landmark_great_lamp", 3), ("M_landmark_catalogue_desk", 3), ("M_lantern_moroccan", 2)] + [   # rev 2: glowing vines, no lanterns (room rework step 5)
    (n, 9 if n.startswith("M_cone_base") else 15 if n.startswith("M_cone_cap") else 10) for (n, _p, _b) in cone_modules() if n.startswith(("M_cone_c", "M_cone_cap", "M_cone_base"))]   # rev 2: smooth collision, the light shaft; rev 3: the floor's ramp; rev 4: smooth walk edges, softer bounce; rev 5: even collision sweeps; rev 6: the fills between; rev 7: the floor fill reaches the first turn; chunks rev 6 / caps rev 14: columns on a thicker parapet, its footprint the walk edge (your walk); chunks rev 7: stepped bookcases and taghcheh in place of the tall niches; chunks rev 8 / caps rev 15: orosi glass backs, a narrower beam; chunks rev 9: softer glass; chunks rev 10: cases clear of the step above


def main():
    if os.path.exists(BLEND):
        bpy.ops.wm.open_mainfile(filepath=BLEND)
    else:
        bpy.ops.wm.read_factory_settings(use_empty=True)
    retired = [n for n in RETIRED if bpy.data.objects.get(n) is not None]
    for n in retired:
        root = bpy.data.objects[n]
        for ob in reversed([root] + list(root.children_recursive)):
            bpy.data.objects.remove(ob, do_unlink=True)
    added = []
    x = 0.0
    for (name, p, build) in MODULES:
        if bpy.data.objects.get(name) is None:
            build(module(name, (x, ROW_Y, 0.0), p))
            added.append(name)
        x += 40.0 if name.startswith("M_cone") else 8.0
    rebuilt = ["%s (rev %d)" % (n, v) for (n, v) in REBUILD if rebuild(n, v, MODULES)]
    ornamented = []
    for (mod, rev, pieces, build) in ORNAMENT:      # step 4: added to the modules already built
        root = bpy.data.objects.get(mod)
        if root is None or int(root.get("orn_rev", 0)) >= rev:
            continue
        for n in pieces:
            ob = bpy.data.objects.get(n)
            if ob is not None:
                bpy.data.objects.remove(ob, do_unlink=True)
        build(root)
        root["orn_rev"] = rev
        ornamented.append("%s (rev %d)" % (mod, rev))
    if not added and not rebuilt and not retired and not ornamented:
        print("kit_add_r03: everything already present; nothing to do.")
        return
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("kit_add_r03: added %s; rebuilt %s; removed %s; ornamented %s" % (", ".join(added) or "nothing", ", ".join(rebuilt) or "nothing", ", ".join(retired) or "nothing", ", ".join(ornamented) or "nothing"))


main()
