"""Adds the R01 Reading Room modules to art_src/kit/kit_walls.blend
(ENVIRONMENT_PLAN.md phase 1, step 1).

  blender --background --factory-startup --python tools/kit_add_r01.py

Additive: opens the hand-edited .blend, adds only the modules that are not in
it yet, and saves. Modules already in the file (including ones you edited by
hand) are never touched, so re-running is safe. After the first run, edit the
new modules in Blender like any other. Then run tools/export_kit.bat.

New modules (laid out on a row at Blender Y = -24 for viewing):
  vault_hall_12m     cell 3x1: pointed barrel vault over a 12 m hall, tiled
                     crown and a transverse rib at the bay boundary. Place it
                     one storey up on two-storey walls (springs at 8 m).
  wall_gable_12m     edge, 3 bays: closes the vault end above the wall top.
  wall_iwan_12m      edge, 3 bays x 2 storeys: 6 m pointed iwan, 3 m deep,
                     tile-lined, mosaic frame, four blind niches, back shelves
                     with a recess_library socket.
  stair_gallery_8m   edge, 2 bays: masonry stair along a wall, up one storey to
                     the gallery slab lane (0.3-1.6 m from the wall).
  post_pier_corbel   post: pier with corbels under the gallery slab.
  table_reading      free: 1.4 x 4.4 m reading table with seat anchors.
  lantern_cluster    free: chandelier (one big, four small lanterns) on a chain
                     up into a 12 m hall vault; carries one light.
  rug_runner         free: three rugs end to end down the middle of the hall.
"""
import math
import os
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit_blender import (H, T, add_box, add_plan_prism, add_prism, arch_outline,  # noqa: E402
                         arch_ring, cut, marker, mesh_object, module)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(ROOT, "art_src", "kit", "kit_walls.blend")
ROW_Y = -24.0
HALL = 12.0      # hall width: three bays
HALL_K = 0.58    # vault pointedness (atlas R01)


def props(shape, size, edge, tags, weight=1.0):
    return {"kit_shape": shape, "kit_family": "walls", "size_cells": size,
            "edge": edge, "tags": tags, "weight": weight}


def vault_hall(r):
    n = 16
    inner = [(T + u, H + v) for (u, v) in arch_outline(HALL - 2 * T, 0.0, HALL_K, n)[1:-1]]
    outer = [(u, H + v) for (u, v) in arch_outline(HALL, 0.0, HALL_K, n)[1:-1]]
    bm = bmesh.new()
    # Tiled panel at the crown (atlas: turquoise and ochre tile crown).
    arch_ring(bm, inner, outer, 0.0, 4.0, lambda i, m: 1 if abs(i - (m - 1) / 2.0) < 3.0 else 0)
    mesh_object("vault_hall_12m__body-col", bm, ["vault_plaster", "tile"], r)
    # Transverse rib on the bay boundary, sunk 3 cm into the shell.
    rib_in = [(T + 0.25 + u, H + v) for (u, v) in arch_outline(HALL - 2 * T - 0.5, 0.0, HALL_K, n)[1:-1]]
    rib_out = [(x, z + 0.03) for (x, z) in inner]
    bm = bmesh.new()
    arch_ring(bm, rib_in, rib_out, -0.15, 0.15)
    mesh_object("vault_hall_12m__rib", bm, ["arch_stone"], r)


def gable_12m(r):
    bm = bmesh.new()
    add_prism(bm, arch_outline(HALL, 0.0, HALL_K, 16)[1:-1], 0.0, H, -T, T, 0)
    mesh_object("wall_gable_12m__body-col", bm, ["brick"], r)


def iwan(r):
    depth = 3.0
    bm = bmesh.new()
    add_plan_prism(bm, [(0, -T), (2.4, -T), (2.4, -depth - T), (HALL - 2.4, -depth - T),
                        (HALL - 2.4, -T), (HALL, -T), (HALL, T), (0, T)], 0.0, 2 * H, 0)
    body = mesh_object("wall_iwan_12m__body-col", bm, ["brick"], r)
    bm = bmesh.new()
    add_prism(bm, arch_outline(6.0, 4.0, HALL_K, 12), 3.0, -0.01, -depth, T + 0.2)
    cut(body, mesh_object("cutter", bm, ["tile"], r))
    # Blind niches flanking the iwan, lower and upper storey.
    for x in (0.7, HALL - 2.1):
        for (z, spring) in ((0.6, 1.6), (4.6, 1.4)):
            bm = bmesh.new()
            add_prism(bm, arch_outline(1.4, spring, 0.6, 8), x, z, T - 0.18, T + 0.2)
            cut(body, mesh_object("cutter", bm, ["tile"], r))
    # Mosaic frame (pishtaq) proud of the face.
    bm = bmesh.new()
    add_box(bm, 2.5, 2.9, T, T + 0.06, 0.0, 7.95)
    add_box(bm, HALL - 2.9, HALL - 2.5, T, T + 0.06, 0.0, 7.95)
    add_box(bm, 2.9, HALL - 2.9, T, T + 0.06, 7.55, 7.95)
    mesh_object("wall_iwan_12m__frame", bm, ["mosaic"], r)
    # Alcove floor (the cell floor stops at the wall line).
    bm = bmesh.new()
    add_box(bm, 3.0, 9.0, -depth, 0.0, -0.2, 0.0)
    mesh_object("wall_iwan_12m__floor-col", bm, ["floor_stone"], r)
    # Back shelves: same board layout as the shelf bay, so recess_library fits.
    sy = -depth + 0.25
    bm = bmesh.new()
    for z in (0.12, 0.54, 0.96, 1.38, 1.80):
        add_box(bm, 4.52, 7.48, sy - 0.25, sy + 0.22, z, z + 0.05)
    for x in (4.44, 7.48):
        add_box(bm, x, x + 0.08, sy - 0.25, sy + 0.22, 0.0, 1.9)
    mesh_object("wall_iwan_12m__shelves", bm, ["wood"], r)
    marker("SOCKET_recess_fill__iwan", r, (6.0, sy, 0.0), {"socket_set": "recess_library"})
    marker("ANCHOR_study__iwan", r, (6.0, -1.2, 0.0))


def stair(r):
    steps, run, top, y0, y1 = 20, 8.0, H + 0.15, T, 1.6
    rise, tread = top / steps, run / steps
    bm = bmesh.new()
    for i in range(steps):
        add_box(bm, i * tread, (i + 1) * tread, y0, y1, 0.0, (i + 1) * rise)
    mesh_object("stair_gallery_8m__steps", bm, ["arch_stone"], r)
    # Walkable ramp through the middle of the treads (collision only).
    bm = bmesh.new()
    add_prism(bm, [(-tread / 2, 0.0), (run - tread / 2, top), (run, top), (run, 0.0)], 0.0, 0.0, y0, y1)
    mesh_object("stair_gallery_8m__ramp-colonly", bm, ["arch_stone"], r)
    # Balustrade on the open side: posts and a sloped handrail.
    bm = bmesh.new()
    x = tread / 2
    while x < run:
        z = (math.floor(x / tread) + 1) * rise
        add_box(bm, x - 0.03, x + 0.03, y1 - 0.1, y1 - 0.04, z, z + 0.9)
        x += 0.8
    a = [bm.verts.new(p) for p in ((0, y1 - 0.12, rise + 0.86), (0, y1 - 0.02, rise + 0.86),
                                   (0, y1 - 0.02, rise + 0.94), (0, y1 - 0.12, rise + 0.94))]
    b = [bm.verts.new((run, v.co.y, v.co.z + top - rise)) for v in a]
    bm.faces.new(list(reversed(a)))
    bm.faces.new(b)
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((a[i], a[j], b[j], b[i]))
    mesh_object("stair_gallery_8m__rail-col", bm, ["wood"], r)
    marker("SNAP_stair_foot__g", r, (0.0, (y0 + y1) / 2, 0.0), {"snap_kind": "stair_foot"})
    marker("SNAP_stair_head__g", r, (run, (y0 + y1) / 2, top), {"snap_kind": "stair_head"})


def pier_corbel(r):
    bm = bmesh.new()
    add_box(bm, -0.48, 0.48, -0.48, 0.48, 0.0, 0.3)
    add_box(bm, -0.4, 0.4, -0.4, 0.4, 0.3, H - 0.3)
    add_box(bm, -0.5, 0.5, -0.5, 0.5, H - 0.3, H)
    mesh_object("post_pier_corbel__body-col", bm, ["arch_stone"], r)
    bm = bmesh.new()
    for (sx, sy) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        for (a, b, z0) in ((0.4, 0.65, 3.35), (0.65, 0.85, 3.6)):
            if sx:
                x0, x1 = sorted((sx * a, sx * b))
                add_box(bm, x0, x1, -0.25, 0.25, z0, 3.85)
            else:
                y0, y1 = sorted((sy * a, sy * b))
                add_box(bm, -0.25, 0.25, y0, y1, z0, 3.85)
    mesh_object("post_pier_corbel__corbels", bm, ["arch_stone"], r)


def table(r):
    bm = bmesh.new()
    add_box(bm, -0.7, 0.7, -2.2, 2.2, 0.72, 0.78)
    for sx in (-1, 1):
        for sy in (-1, 1):
            add_box(bm, sx * 0.58 - 0.05, sx * 0.58 + 0.05, sy * 2.05 - 0.05, sy * 2.05 + 0.05, 0.0, 0.72)
        add_box(bm, sx * 0.58 - 0.03, sx * 0.58 + 0.03, -2.0, 2.0, 0.12, 0.2)
    add_box(bm, -0.55, 0.55, -0.03, 0.03, 0.12, 0.2)
    mesh_object("table_reading__body-col", bm, ["wood"], r)
    for sx in (-1, 1):
        for y in (-1.4, 0.0, 1.4):
            marker("ANCHOR_seat__t%d%d" % (sx + 1, int(y * 10) + 20), r, (sx * 1.05, y, 0.0))


def lantern(bm, cx, cy, z0, half, height):
    """Brass lantern frame (mat 0) around a glowing body (mat 1)."""
    p = half * 0.8
    for (sx, sy) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        add_box(bm, cx + sx * p - 0.02, cx + sx * p + 0.02, cy + sy * p - 0.02, cy + sy * p + 0.02, z0, z0 + height)
    add_box(bm, cx - half, cx + half, cy - half, cy + half, z0 - 0.05, z0 + 0.01)
    add_box(bm, cx - half, cx + half, cy - half, cy + half, z0 + height - 0.01, z0 + height + 0.05)
    add_box(bm, cx - half * 0.55, cx + half * 0.55, cy - half * 0.55, cy + half * 0.55, z0 + 0.05, z0 + height - 0.05, 1)


def lantern_cluster(r):
    crown = 14.6     # intrados crown of vault_hall_12m placed one storey up
    bm = bmesh.new()
    lantern(bm, 0.0, 0.0, 5.5, 0.26, 0.65)
    add_box(bm, -0.025, 0.025, -0.025, 0.025, 6.2, 6.4)
    for k in range(4):
        a = k * math.pi / 2
        cx, cy = math.cos(a) * 0.6, math.sin(a) * 0.6
        lantern(bm, cx, cy, 5.25, 0.1, 0.3)
        add_box(bm, cx - 0.01, cx + 0.01, cy - 0.01, cy + 0.01, 5.6, 6.35)
        add_box(bm, min(0.0, cx) - 0.02, max(0.0, cx) + 0.02, min(0.0, cy) - 0.02, max(0.0, cy) + 0.02, 6.33, 6.38)
    mesh_object("lantern_cluster__body", bm, ["brass", "emit_lantern"], r)
    bm = bmesh.new()
    add_box(bm, -0.02, 0.02, -0.02, 0.02, 6.38, crown + 0.2)
    mesh_object("lantern_cluster__chain", bm, ["iron"], r)
    marker("LIGHT_chandelier__cluster", r, (0.0, 0.0, 5.8))


def rug_runner(r):
    """Three rugs end to end; the rug pixel map is UV-mapped (140 x 102 px at
    32 px/m = 4.375 x 3.19 m), long side along Y."""
    w, l, gap = 102 / 32.0, 140 / 32.0, 0.12
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    for c in (-(l + gap), 0.0, l + gap):
        x0, y0 = -w / 2, c - l / 2
        vs = [bm.verts.new(p) for p in ((x0, y0, 0.012), (x0 + w, y0, 0.012), (x0 + w, y0 + l, 0.012), (x0, y0 + l, 0.012))]
        f = bm.faces.new(vs)
        for loop in f.loops:
            loop[uv].uv = ((loop.vert.co.y - y0) / l, (loop.vert.co.x - x0) / w)
    mesh_object("rug_runner__rugs", bm, ["rug"], r, recalc=False)   # open quads: keep the authored up normal


MODULES = [
    ("M_vault_hall_12m", props("cell", [3, 1, 1], "", "plaster,tile,ceiling,hall_12m"), vault_hall),
    ("M_wall_gable_12m", props("edge", [3, 1, 0], "gable", "brick,structure,ceiling,hall_12m"), gable_12m),
    ("M_wall_iwan_12m", props("edge", [3, 2, 0], "iwan", "brick,tile,structure,landmark,hall_12m"), iwan),
    ("M_stair_gallery_8m", props("edge", [2, 1, 0], "stair", "stone,vertical"), stair),
    ("M_post_pier_corbel", props("post", [0, 1, 0], "", "stone,structure,gallery"), pier_corbel),
    ("M_table_reading", props("free", [0, 1, 0], "", "wood,furniture"), table),
    ("M_lantern_cluster", props("free", [0, 4, 0], "", "brass,light,hall_12m"), lantern_cluster),
    ("M_rug_runner", props("free", [0, 0, 0], "", "cloth,floor"), rug_runner),
]


def main():
    if not os.path.exists(BLEND):
        print("kit_add_r01: %s not found; run kit_seed_walls.py first." % BLEND)
        sys.exit(1)
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    added = []
    x = 0.0
    for (name, p, build) in MODULES:
        if bpy.data.objects.get(name) is None:
            build(module(name, (x, ROW_Y, 0.0), p))
            added.append(name)
        x += 16.0
    if not added:
        print("kit_add_r01: all modules already present; nothing to do.")
        return
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("kit_add_r01: added %s" % ", ".join(added))


main()
