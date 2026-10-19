"""One-time seed for art_src/kit/kit_walls.blend (ENVIRONMENT_PLAN.md phase 0).

  blender --background --factory-startup --python tools/kit_seed_walls.py [-- --force]

Creates the starter wall-family modules so the export/import pipeline has
something to chew on. After the first run the .blend is the source of truth:
edit it by hand in Blender and do NOT re-run this (it refuses to overwrite
unless --force is given).

Conventions: see tools/kit_blender.py (shared helpers).
"""
import os
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit_blender import (H, T, add_box, add_prism, arch_outline, cut, marker,  # noqa: E402
                         mesh_object, wall_body)
from kit_blender import module as _module  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art_src", "kit", "kit_walls.blend")


LAMP_SOCKET = {"socket_set": "lamp_state", "socket_mode": "state"}


def module(name, slot, props):
    return _module(name, (slot * 7.0, 0.0, 0.0), props)


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)

    # 1. Plain wall bay ---------------------------------------------------------
    r = module("M_wall_plain_4m", 0, {"kit_shape": "edge", "kit_family": "walls",
               "size_cells": [1, 1, 0], "edge": "solid", "tags": "brick,structure", "weight": 3.0})
    wall_body("wall_plain_4m__body-col", r)
    marker("SOCKET_seam_debris__plain", r, (0.85, T, 0.0), {"socket_set": "seam_debris", "socket_mode": "edge_scatter",
           "scatter_count": [2, 5], "scatter_spacing": 0.45, "edge_length": 2.3, "edge_depth": 0.25,
           "settle": 1, "settle_max_drop": 0.3})

    # 2. Shelf-recess bay -------------------------------------------------------
    r = module("M_wall_shelfbay_4m", 1, {"kit_shape": "edge", "kit_family": "walls",
               "size_cells": [1, 1, 0], "edge": "recess", "tags": "brick,structure,storage", "weight": 8.0})
    body = wall_body("wall_shelfbay_4m__body-col", r, y0=-T - 0.25)
    bm = bmesh.new()
    add_prism(bm, arch_outline(3.0, 1.9), 0.5, 0.0, -0.25, T + 0.2)
    cutter = mesh_object("cutter", bm, ["wood"], r)
    cut(body, cutter)
    # Boards and books both come from the recess socket (kit/sockets/recess_library.tres).
    marker("SOCKET_recess_fill__shelfbay", r, (2.0, 0.0, 0.0), {"socket_set": "recess_library"})
    marker("ANCHOR_browse__shelfbay", r, (2.0, 1.2, 0.0))

    # 3. Arch opening (3 m) -----------------------------------------------------
    r = module("M_wall_arch_3m", 2, {"kit_shape": "edge", "kit_family": "walls",
               "size_cells": [1, 1, 0], "edge": "opening_3m", "tags": "brick,structure,passage", "weight": 2.0})
    body = wall_body("wall_arch_3m__body-col", r)
    bm = bmesh.new()
    add_prism(bm, arch_outline(3.0, 1.8), 0.5, -0.01, -T - 0.2, T + 0.2)
    cutter = mesh_object("cutter", bm, ["arch_stone"], r)
    cut(body, cutter)
    marker("SNAP_door__arch3", r, (2.0, 0.0, 0.0), {"snap_kind": "door"})

    # 4. Corner / junction pier -------------------------------------------------
    r = module("M_post_pier", 3, {"kit_shape": "post", "kit_family": "walls",
               "size_cells": [0, 1, 0], "edge": "", "tags": "stone,structure", "weight": 1.0})
    bm = bmesh.new()
    add_box(bm, -0.48, 0.48, -0.48, 0.48, 0.0, 0.3)
    add_box(bm, -0.4, 0.4, -0.4, 0.4, 0.3, H - 0.3)
    add_box(bm, -0.5, 0.5, -0.5, 0.5, H - 0.3, H)
    mesh_object("post_pier__body-col", bm, ["arch_stone"], r)

    # 5. Floor cell -------------------------------------------------------------
    r = module("M_floor_4m", 4, {"kit_shape": "cell", "kit_family": "walls",
               "size_cells": [1, 0, 1], "edge": "", "tags": "stone,floor", "weight": 1.0})
    bm = bmesh.new()
    add_box(bm, 0, 4, 0, 4, -0.2, 0.0)
    mesh_object("floor_4m__body-col", bm, ["floor_stone"], r)

    # 6. Pointed barrel-vault bay (spans X, runs along Y, sits on wall tops) -----
    r = module("M_vault_bay_4m", 5, {"kit_shape": "cell", "kit_family": "walls",
               "size_cells": [1, 1, 1], "edge": "", "tags": "plaster,ceiling", "weight": 1.0})
    inner = [(T + u, H + v) for (u, v) in arch_outline(4 - 2 * T, 0.0, 0.6, 10)[1:-1]]
    outer = [(u, H + v) for (u, v) in arch_outline(4.0, 0.0, 0.6, 10)[1:-1]]
    bm = bmesh.new()
    rings = []
    for y in (0.0, 4.0):
        rings.append(([bm.verts.new((x, y, z)) for (x, z) in inner],
                      [bm.verts.new((x, y, z)) for (x, z) in outer]))
    (i0, o0), (i1, o1) = rings
    n = len(inner)
    for i in range(n - 1):
        bm.faces.new((i0[i], i0[i + 1], i1[i + 1], i1[i])).smooth = True    # intrados
        bm.faces.new((o0[i], o1[i], o1[i + 1], o0[i + 1])).smooth = True    # extrados
        bm.faces.new((i0[i], o0[i], o0[i + 1], i0[i + 1]))     # front cap
        bm.faces.new((i1[i], i1[i + 1], o1[i + 1], o1[i]))     # back cap
    for (a, b) in ((0, 0), (n - 1, n - 1)):                     # springing strips
        bm.faces.new((i0[a], i1[a], o1[b], o0[b]))
    mesh_object("vault_bay_4m__body-col", bm, ["vault_plaster"], r)

    # 7. Gallery slab with balustrade (edge, upper level) -----------------------
    r = module("M_gallery_slab_4m", 6, {"kit_shape": "edge", "kit_family": "walls",
               "size_cells": [1, 1, 0], "edge": "gallery", "tags": "wood,vertical", "weight": 1.0})
    bm = bmesh.new()
    add_box(bm, 0, 4, T, 1.6, H - 0.15, H + 0.15, 0)
    mesh_object("gallery_slab_4m__slab-col", bm, ["wood"], r)
    bm = bmesh.new()
    x = 0.05
    while x < 4.0:
        add_box(bm, x, x + 0.06, 1.48, 1.54, H + 0.15, H + 0.95)
        x += 0.5
    add_box(bm, 0, 4, 1.46, 1.56, H + 0.92, H + 1.0)
    mesh_object("gallery_slab_4m__rail-col", bm, ["wood"], r)
    marker("ANCHOR_lookout__gallery", r, (2.0, 1.0, H + 0.15))

    # 7b. Vault gable: fills the pointed end of a vault bay above the wall top --
    r = module("M_wall_gable_4m", 8, {"kit_shape": "edge", "kit_family": "walls",
               "size_cells": [1, 1, 0], "edge": "gable", "tags": "brick,structure,ceiling", "weight": 1.0})
    bm = bmesh.new()
    gable = [(u, v) for (u, v) in arch_outline(4.0, 0.0, 0.6, 10)][1:-1]
    add_prism(bm, gable, 0.0, H, -T, T, 0)
    mesh_object("wall_gable_4m__body-col", bm, ["brick"], r)

    # 8. Hanging lantern (free dressing, carries its light) ---------------------
    r = module("M_lantern_hanging", 7, {"kit_shape": "free", "kit_family": "walls",
               "size_cells": [0, 1, 0], "edge": "", "tags": "brass,light", "weight": 1.0})
    bm = bmesh.new()
    for (sx, sy) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        add_box(bm, sx * 0.14 - 0.02, sx * 0.14 + 0.02, sy * 0.14 - 0.02, sy * 0.14 + 0.02, 2.55, 3.05, 0)
    add_box(bm, -0.18, 0.18, -0.18, 0.18, 2.5, 2.56, 0)
    add_box(bm, -0.18, 0.18, -0.18, 0.18, 3.04, 3.1, 0)
    add_box(bm, -0.015, 0.015, -0.015, 0.015, 3.1, H, 0)
    add_box(bm, -0.1, 0.1, -0.1, 0.1, 2.6, 2.98, 1)
    mesh_object("lantern_hanging__body", bm, ["brass", "emit_lantern"], r)
    marker("LIGHT_lantern__hanging", r, (0.0, 0.0, 2.8))
    marker("SOCKET_lamp_state__hanging", r, (0.0, 0.0, 2.8), LAMP_SOCKET)


def main():
    force = "--force" in sys.argv
    if os.path.exists(OUT) and not force:
        print("kit_seed_walls: %s exists; edit it in Blender instead (or pass --force)." % OUT)
        return
    build()
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=OUT)
    print("kit_seed_walls: wrote", OUT)


main()
