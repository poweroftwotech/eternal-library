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
from kit_blender import (T, add_box, add_ngon_prism, add_prism, arch_outline, cut,  # noqa: E402
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
    steps = 10
    for k in range(steps):
        z0 = 0.45 + (3.55 - 0.45) * k / steps
        z1 = 0.45 + (3.55 - 0.45) * (k + 1) / steps
        star_prism(bm, z0, z1, 0.27, 0.22, 6, k * math.radians(9.0))
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


def dome(r, mat, hole=0.02, name="dome_cell_4m"):
    bm = bmesh.new()
    slab_with_hole(bm, BAND_TOP, BAND_TOP + 0.2)
    mesh_object(name + "__slab-col", bm, ["vault_plaster"], r)
    bm = bmesh.new()
    revolve_loop(bm, dome_loop(hole), 2.0, 2.0, 24)
    mesh_object(name + "__dome", bm, [mat], r)


def dome_a(r):
    dome(r, "tile", name="dome_cell_4m_a")


def dome_b(r):
    dome(r, "vault_plaster", name="dome_cell_4m_b")


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
]


def main():
    if os.path.exists(BLEND):
        bpy.ops.wm.open_mainfile(filepath=BLEND)
    else:
        bpy.ops.wm.read_factory_settings(use_empty=True)
    added = []
    x = 0.0
    for (name, p, build) in MODULES:
        if bpy.data.objects.get(name) is None:
            build(module(name, (x, ROW_Y, 0.0), p))
            added.append(name)
        x += 8.0
    if not added:
        print("kit_add_r03: everything already present; nothing to do.")
        return
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("kit_add_r03: added " + ", ".join(added))


main()
