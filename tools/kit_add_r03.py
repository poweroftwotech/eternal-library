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
from kit_blender import (T, add_box, add_lathe, add_ngon_prism, add_obox, add_plan_prism, add_prism, arch_outline, cut, rebuild, wall_body,  # noqa: E402
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


def hall_pier(r):
    bm = bmesh.new()
    add_box(bm, -0.35, 0.35, -0.35, 0.35, 0.0, 3.8)
    add_box(bm, -0.35, 0.35, -0.35, 0.35, 4.0, BAND_TOP)
    mesh_object("post_hall_pier__body-col", bm, ["brick"], r)
    bm = bmesh.new()
    add_box(bm, -0.42, 0.42, -0.42, 0.42, 3.8, CAP)
    mesh_object("post_hall_pier__capital", bm, ["arch_stone"], r)


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


def hall_band(r):
    bm = bmesh.new()
    add_box(bm, 0.0, 4.0, -T, T + 0.03, CAP, BAND_TOP - 0.3)
    mesh_object("wall_hall_band_4m__body-col", bm, ["brick"], r)
    bm = bmesh.new()
    add_box(bm, 0.0, 4.0, -T, T + 0.03, BAND_TOP - 0.3, BAND_TOP)
    mesh_object("wall_hall_band_4m__tiles", bm, ["tile"], r)
    bm = bmesh.new()
    add_box(bm, 0.0, 4.0, T + 0.03, T + 0.14, CAP, CAP + 0.14)
    mesh_object("wall_hall_band_4m__cornice", bm, ["arch_stone"], r)


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
        mesh_object(name + "__band", bm, ["tile"], r)


def dome_a(r):
    dome(r, "tile", name="dome_cell_4m_a")


def dome_b(r):
    # rev 2 (your look review): paler plaster, and a tile band at the foot.
    dome(r, "dome_plaster", name="dome_cell_4m_b", band=True)


def oculus(r):
    dome(r, "tile", hole=0.55, name="oculus_cell_4m")
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
    mesh_object("landmark_great_lamp__glass", glass, ["emit_lantern"], r)
    marker("LIGHT_chandelier__great", r, (0.0, 0.0, 3.2))


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
    mesh_object("landmark_catalogue_desk__glass", glass, ["emit_lantern"], r)
    marker("LIGHT_lantern__desk", r, (0.9, 0.0, 1.45))
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
    mesh_object("dome_cell_4m_fallen__stub", bm, ["tile"], r)
    bm = bmesh.new()
    top = 9.6
    w = 0.12
    add_box(bm, 0.05, 3.95, 0.05, 0.05 + w, BAND_TOP + 0.2, top)
    add_box(bm, 0.05, 3.95, 3.95 - w, 3.95, BAND_TOP + 0.2, top)
    add_box(bm, 0.05, 0.05 + w, 0.05 + w, 3.95 - w, BAND_TOP + 0.2, top)
    add_box(bm, 3.95 - w, 3.95, 0.05 + w, 3.95 - w, BAND_TOP + 0.2, top)
    add_box(bm, 0.05, 3.95, 0.05, 3.95, top, top + 0.2)
    mesh_object("dome_cell_4m_fallen__shaft", bm, ["brick"], r)


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
    mesh_object("rubble_heap_4m__tiles", bm, ["tile"], r)
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
    """The far wall's sealed bronze door, under a 3 m arch, a lantern on a
    bracket each side (on the room side, Blender +Y)."""
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
    glass = bmesh.new()
    bm = bmesh.new()
    for x in (0.2, 3.8):
        lantern_at(bm, glass, x, T + 0.25, 2.3, 0.14, 0.42)
        add_box(bm, x - 0.02, x + 0.02, T, T + 0.25, 2.76, 2.8)      # bracket
    mesh_object("wall_vault_door_4m__lanterns", bm, ["brass"], r)
    mesh_object("wall_vault_door_4m__glass", glass, ["emit_lantern"], r)
    marker("LIGHT_lantern__door_l", r, (0.2, T + 0.25, 2.5))
    marker("LIGHT_lantern__door_r", r, (3.8, T + 0.25, 2.5))


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
CONE_COL_R = 0.17
CONE_BAY = 4.8        # stair length between columns
NICHE_D = 0.55        # niche depth (the socket sits 0.25 in front of its back)
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


def stair_edge(r, root, a, b, tag, parapet_from=0.0):
    """The ledge, the parapet (where the tread is at least parapet_from up),
    the columns (at the bays' ends between a and b) and the collision ramp of
    a storey with radius r, between angles a and b."""
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
                                 (c_face(r, c_tread(r, p)) - CONE_LEDGE + 0.2, c_tread(r, p)),
                                 (c_face(r, c_tread(r, p)) - CONE_LEDGE + 0.2, c_tread(r, p) + CONE_PARAPET),
                                 (c_face(r, c_tread(r, p)) - CONE_LEDGE, c_tread(r, p) + CONE_PARAPET)])
        mesh_object("cone_%s__parapet" % tag, bm, ["arch_stone"], root)
        # The walk's inner edge, smooth, 0.22 inside the wall's face: you slide
        # along it instead of catching on the parapet and the columns' bases.
        bm = bmesh.new()
        sweep(bm, c_even(pa[0], pa[-1]), lambda p: [(c_edge(r, p) - 0.32, c_line(r, p) - 0.3),
                                                    (c_edge(r, p) - 0.22, c_line(r, p) - 0.3),
                                                    (c_edge(r, p) - 0.22, c_line(r, p) + 2.3),
                                                    (c_edge(r, p) - 0.32, c_line(r, p) + 2.3)])
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
        x, y = polar(c_face(r, z) - 0.55, t)
        add_lathe(bm, [(CONE_COL_R + 0.08, z - 0.05), (CONE_COL_R + 0.08, z + 0.22), (CONE_COL_R, z + 0.3),
                       (CONE_COL_R, z + CONE_HEAD - 0.34), (CONE_COL_R + 0.12, z + CONE_HEAD - 0.24),
                       (CONE_COL_R + 0.12, z + CONE_HEAD + 0.05)], x, y, segs=12)
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
        # Niches between the columns: the climb's bays, and the landing's if no door.
        s0, s1 = c_span(r)
        nb = c_bays(r)
        mids = [s0 + (s1 - s0) * (i + 0.5) / nb for i in range(nb)]
        if not exit_door:
            mids = [0.0] + mids
        for i, t in enumerate(mids):
            rb = c_edge(r, t) + CONE_DEPTH
            reach = 1.6 / rb
            sill = max(c_tread(r, t + d * reach / 4) for d in range(-4, 5)) + 0.15
            tangent_prism(cutters, arch_outline(3.0, 1.9), t, rb, -0.3, NICHE_D, sill)
            o = marker("SOCKET_cone_niche__%s_%d" % (tag, i), root, (*polar(rb + NICHE_D - 0.25, t), sill),
                       {"socket_set": "cone_niche"})
            o.rotation_euler = (0.0, 0.0, t)
        if exit_door:
            door_cutter(cutters, r)
        cutter = mesh_object("cutter", cutters, ["brick"], root)
        cut(body, cutter)
        # Storey 0 starts on the floor: no ledge or parapet on its landing.
        floor = any(abs(r - s) < 1e-6 for (s, _l) in CONE_SIZES)
        stair_edge(r, root, c_hb(r) if floor else a, b, tag, 0.6 if floor else 0.0)
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
        marker("LIGHT_cold__oculus", root, (0.0, 0.0, z_oc - 0.6))
        # Sunlight down the shaft (your review): a spot far over the oculus, its
        # beam the oculus's width at the top and ~4 m across on the floor, seen in
        # a column of haze; a fill halfway down for the light it bounces.
        total = STOREY * (L - 1) + z_oc
        lift = (CONE_RT - 0.2) * total / (4.0 - CONE_RT + 0.2)
        marker("LIGHT_shaft__oculus", root, (0.0, 0.0, z_oc + lift),
               {"range": total + lift + 2.0, "spot_angle": math.degrees(math.atan((4.0 - CONE_RT + 0.2) / total))})
        marker("FOG_haze__shaft", root, (0.0, 0.0, z_oc - total / 2.0), {"fog_size": [6.5, 6.5, total], "density": 0.05})
        marker("LIGHT_bounce__mid", root, (0.0, 0.0, z_oc - total / 2.0), {"range": 12.0})
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
        marker("LIGHT_bounce__floor", root, (0.0, 0.0, 2.5), {"range": R0 + 4.0})     # the sunlit floor's bounce
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
    marker("LIGHT_lantern__cone", root, (0.0, 0.0, 2.25))
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
    ("M_landmark_great_lamp", props("free", [0, 1, 0], "", "brass,light,landmark", family="dressing"), great_lamp),
    ("M_landmark_catalogue_desk", props("free", [1, 0, 1], "", "wood,landmark", family="dressing"), catalogue_desk),
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
    ("M_wall_vault_door_4m", props("edge", [1, 1, 0], "solid", "brass,door,light,cistern"), vault_door),
] + cone_modules() + [
]

# Script-made modules remade in place at a new revision (kit_blender.rebuild):
# hand edits to them are lost, so only list ones nobody has changed in Blender.
REBUILD = [("M_post_column_twisted", 3), ("M_dome_cell_4m_b", 2),
           ("M_basin_cell_4m", 2), ("M_basin_cell_4m_deep", 2), ("M_causeway_cell_4m", 3),   # rev 2: the cistern's own water; causeway rev 3: gentler sides
           ("M_cone_lantern", 2)] + [   # rev 2: the lantern over the head
    (n, 7 if n.startswith("M_cone_base") else 6 if n.startswith("M_cone_cap") else 5) for (n, _p, _b) in cone_modules() if n.startswith(("M_cone_c", "M_cone_cap", "M_cone_base"))]   # rev 2: smooth collision, the light shaft; rev 3: the floor's ramp; rev 4: smooth walk edges, softer bounce; rev 5: even collision sweeps; rev 6: the fills between; rev 7: the floor fill reaches the first turn


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
    if not added and not rebuilt and not retired:
        print("kit_add_r03: everything already present; nothing to do.")
        return
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("kit_add_r03: added %s; rebuilt %s; removed %s" % (", ".join(added) or "nothing", ", ".join(rebuilt) or "nothing", ", ".join(retired) or "nothing"))


main()
