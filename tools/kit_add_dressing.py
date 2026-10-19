"""Creates or extends art_src/kit/kit_dressing.blend: socket candidates and
small props (ENVIRONMENT_PLAN.md phase 1 step 3), family "dressing".

  blender --background --factory-startup --python tools/kit_add_dressing.py

Additive like kit_add_r01.py: creates the .blend if it is missing, adds only
modules that are not in it yet, and never touches existing ones, so it is
safe to re-run after hand edits. Then run tools/export_kit.bat.

Every module's origin is the socket it fills (Blender axes; Godot -Z = +Y):
  recess_*     a shelf-bay recess socket: recess centre, floor level, wall
               centre line. The recess back is y = -0.25, the room is +Y.
  iwan_*       the iwan centrepiece socket (alcove floor, ~1.8 m from the back).
  prop_*       a table-top SCATTER socket: the table surface (z = 0).
"""
import math
import os
import random
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit_blender import (add_box, add_lathe, add_ngon_prism, add_obox, add_prism, rebuild,  # noqa: E402
                         arch_outline, mesh_object, module)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(ROOT, "art_src", "kit", "kit_dressing.blend")
BOARDS = (0.12, 0.54, 0.96, 1.38, 1.80)     # board bottoms, as M_wall_shelfbay_4m had
BACK, FRONT = -0.25, 0.22                   # board depth (recess back to front)


def props(tags, size=(0, 0, 0)):
    return {"kit_shape": "free", "kit_family": "dressing", "size_cells": list(size),
            "edge": "", "tags": tags, "weight": 1.0}


# --- recess candidates --------------------------------------------------------

def recess_shelves(r):
    bm = bmesh.new()
    for z in BOARDS:
        add_box(bm, -1.48, 1.48, BACK, FRONT, z, z + 0.05)
    mesh_object("recess_shelves__boards", bm, ["wood"], r)


def recess_shelves_broken(r):
    bm = bmesh.new()
    for z in (BOARDS[0], BOARDS[3], BOARDS[4]):
        add_box(bm, -1.48, 1.48, BACK, FRONT, z, z + 0.05)
    # One board dropped at its left end, one snapped and lying on the floor.
    add_obox(bm, (0.05, -0.02, 0.78), (2.9, 0.47, 0.05), (0.0, math.radians(9.5), 0.0))
    mesh_object("recess_shelves_broken__boards", bm, ["wood"], r)
    # rev 3: the two boards on the floor are separate "__spill" meshes (b moved
    # 0.15 m out so it lies in front of the wall face), so ShelfFill
    # can rest each on whatever is below (a gallery slab, a stair, the floor).
    # rev 2: centre 0.95 -> 0.82, so the board stays inside the 3 m opening.
    for (name, centre, size, rot) in (
            ("a", (-0.55, 0.45, 0.03), (1.7, 0.45, 0.05), (0.0, 0.0, math.radians(28))),
            ("b", (0.82, 0.4, 0.09), (1.2, 0.45, 0.05), (math.radians(8), 0.0, math.radians(-12)))):
        bm = bmesh.new()
        add_obox(bm, centre, size, rot)
        mesh_object("recess_shelves_broken__spill_" + name, bm, ["wood"], r)


def recess_tile_panel(r):
    bm = bmesh.new()
    add_prism(bm, arch_outline(2.9, 1.45, 0.6, 8), -1.45, 0.45, BACK, BACK + 0.04)
    mesh_object("recess_tile_panel__panel", bm, ["tile"], r)
    bm = bmesh.new()
    add_box(bm, -1.5, 1.5, BACK, 0.2, 0.0, 0.45)
    mesh_object("recess_tile_panel__bench-col", bm, ["arch_stone"], r)


def recess_sealed_door(r):
    bm = bmesh.new()      # brick infill across the whole recess arch
    add_prism(bm, arch_outline(3.0, 1.9, 0.6, 8), -1.5, 0.0, BACK, BACK + 0.1)
    mesh_object("recess_sealed_door__infill-col", bm, ["brick"], r)
    bm = bmesh.new()
    add_prism(bm, arch_outline(1.9, 1.5, 0.6, 8), -0.95, 0.0, BACK + 0.1, BACK + 0.15)
    mesh_object("recess_sealed_door__frame", bm, ["arch_stone"], r)
    bm = bmesh.new()
    add_prism(bm, arch_outline(1.5, 1.35, 0.6, 8), -0.75, 0.0, BACK + 0.15, BACK + 0.21)
    mesh_object("recess_sealed_door__door", bm, ["wood"], r)
    bm = bmesh.new()
    for z in (0.35, 1.0, 1.6):
        add_box(bm, -0.72, 0.72, BACK + 0.21, BACK + 0.23, z, z + 0.06)
    add_box(bm, 0.45, 0.53, BACK + 0.21, BACK + 0.26, 0.92, 1.0)       # ring plate
    # Planks nailed across: the door is sealed.
    add_obox(bm, (0.0, BACK + 0.27, 0.95), (1.9, 0.04, 0.16), (0.0, math.radians(24), 0.0), 1)
    add_obox(bm, (0.0, BACK + 0.31, 1.15), (1.9, 0.04, 0.16), (0.0, math.radians(-19), 0.0), 1)
    mesh_object("recess_sealed_door__iron", bm, ["iron", "wood"], r)


# --- iwan centrepieces ----------------------------------------------------------

def iwan_lectern(r):
    bm = bmesh.new()
    add_box(bm, -0.32, 0.32, -0.26, 0.26, 0.0, 0.08)
    add_box(bm, -0.05, 0.05, -0.05, 0.05, 0.08, 0.98)
    add_obox(bm, (0.0, 0.03, 1.05), (0.62, 0.46, 0.04), (math.radians(-22), 0.0, 0.0))
    add_obox(bm, (0.0, 0.2, 0.99), (0.6, 0.03, 0.06), (math.radians(-22), 0.0, 0.0))     # book ledge
    mesh_object("iwan_lectern__stand", bm, ["wood"], r)
    bm = bmesh.new()     # open book: leather cover, two page blocks
    add_obox(bm, (0.0, 0.03, 1.08), (0.5, 0.36, 0.012), (math.radians(-22), 0.0, 0.0), 0)
    for sx in (-1, 1):
        add_obox(bm, (sx * 0.12, 0.03, 1.1), (0.23, 0.33, 0.03), (math.radians(-22), math.radians(sx * -6), 0.0), 1)
    mesh_object("iwan_lectern__book", bm, ["book_leather", "pages"], r)
    bm = bmesh.new()
    add_box(bm, -0.36, 0.36, -0.3, 0.3, 0.0, 1.1)
    mesh_object("iwan_lectern__col-colonly", bm, ["wood"], r)
    bm = bmesh.new()     # small rug (rug map is UV-mapped, 140 x 102 px at 32 px/m)
    uv = bm.loops.layers.uv.new("UVMap")
    w, l = 102 / 32.0, 140 / 32.0
    vs = [bm.verts.new(p) for p in ((-l / 2, -w / 2, 0.012), (l / 2, -w / 2, 0.012), (l / 2, w / 2, 0.012), (-l / 2, w / 2, 0.012))]
    f = bm.faces.new(vs)
    for loop in f.loops:
        loop[uv].uv = ((loop.vert.co.x + l / 2) / l, (loop.vert.co.y + w / 2) / w)
    mesh_object("iwan_lectern__rug", bm, ["rug"], r, recalc=False)


def iwan_tree(r):
    rng = random.Random(41)
    bm = bmesh.new()
    add_ngon_prism(bm, 8, 0.95, 0.0, 0.55, mat=0)
    mesh_object("iwan_tree__planter-col", bm, ["tile"], r)
    bm = bmesh.new()
    for i in range(8):     # rim stones
        a0, a1 = 2 * math.pi * i / 8, 2 * math.pi * (i + 1) / 8
        cx, cy = 0.95 * math.cos((a0 + a1) / 2), 0.95 * math.sin((a0 + a1) / 2)
        add_obox(bm, (cx, cy, 0.6), (0.2, 0.78, 0.1), (0.0, 0.0, (a0 + a1) / 2))
    mesh_object("iwan_tree__rim", bm, ["arch_stone"], r)
    bm = bmesh.new()
    add_ngon_prism(bm, 8, 0.82, 0.55, 0.6, mat=0)
    mesh_object("iwan_tree__soil", bm, ["soil"], r)
    bm = bmesh.new()       # trunk and three limbs
    add_lathe(bm, [(0.16, 0.55), (0.12, 1.3), (0.09, 2.0), (0.0, 2.25)], segs=8)
    mesh_object("iwan_tree__trunk", bm, ["bark"], r)
    # Limbs as rotated boxes (simpler than rotating lathes in bmesh).
    bm = bmesh.new()
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.4
        add_obox(bm, (0.28 * math.cos(a), 0.28 * math.sin(a), 1.75), (0.07, 0.07, 0.8),
                 (math.radians(-38) * math.sin(a), math.radians(38) * math.cos(a), 0.0))
    mesh_object("iwan_tree__limbs", bm, ["bark"], r)
    bm = bmesh.new()       # canopy: leaf cards in an ellipsoid
    uv = bm.loops.layers.uv.new("UVMap")
    for _ in range(360):
        while True:
            p = (rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))
            if p[0] ** 2 + p[1] ** 2 + p[2] ** 2 <= 1.0:
                break
        c = (p[0] * 1.15, p[1] * 1.15, 2.55 + p[2] * 0.7)
        yaw, pitch, s = rng.uniform(0, math.tau), rng.uniform(-0.9, 0.9), rng.uniform(0.16, 0.24)
        ux, uy = math.cos(yaw) * s, math.sin(yaw) * s
        up = (math.sin(pitch) * -math.sin(yaw) * s, math.sin(pitch) * math.cos(yaw) * s, math.cos(pitch) * s)
        corners = [(c[0] - ux - up[0], c[1] - uy - up[1], c[2] - up[2]), (c[0] + ux - up[0], c[1] + uy - up[1], c[2] - up[2]),
                   (c[0] + ux + up[0], c[1] + uy + up[1], c[2] + up[2]), (c[0] - ux + up[0], c[1] - uy + up[1], c[2] + up[2])]
        f = bm.faces.new([bm.verts.new(v) for v in corners])
        for loop, t in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
            loop[uv].uv = t
    mesh_object("iwan_tree__leaves", bm, ["tree_leaf"], r, recalc=False)
    bm = bmesh.new()
    for _ in range(9):
        a, d = rng.uniform(0, math.tau), rng.uniform(0.5, 1.05)
        z = 2.0 + rng.uniform(0.0, 0.5)
        add_lathe(bm, [(0.0, z - 0.05), (0.05, z - 0.03), (0.055, z), (0.04, z + 0.035), (0.0, z + 0.05)],
                  cx=d * math.cos(a), cy=d * math.sin(a), segs=6)
    mesh_object("iwan_tree__fruit", bm, ["pomegranate"], r)


def iwan_fountain(r):
    bm = bmesh.new()
    add_ngon_prism(bm, 8, 1.15, 0.0, 0.5)
    mesh_object("iwan_fountain__basin-col", bm, ["tile"], r)
    bm = bmesh.new()
    for i in range(8):
        a0, a1 = 2 * math.pi * i / 8, 2 * math.pi * (i + 1) / 8
        cx, cy = 1.1 * math.cos((a0 + a1) / 2), 1.1 * math.sin((a0 + a1) / 2)
        add_obox(bm, (cx, cy, 0.55), (0.24, 0.92, 0.1), (0.0, 0.0, (a0 + a1) / 2))
    add_lathe(bm, [(0.16, 0.5), (0.12, 0.6), (0.1, 0.95), (0.36, 1.0), (0.38, 1.08), (0.0, 1.08)], segs=12)
    add_lathe(bm, [(0.05, 1.08), (0.04, 1.3), (0.0, 1.36)], segs=8)
    mesh_object("iwan_fountain__stone", bm, ["arch_stone"], r)
    bm = bmesh.new()
    add_ngon_prism(bm, 8, 1.0, 0.5, 0.52)
    add_lathe(bm, [(0.33, 1.08), (0.33, 1.1), (0.0, 1.1)], segs=12)
    mesh_object("iwan_fountain__water", bm, ["water"], r)


# --- seam debris (wall-base EDGE_SCATTER, weathering slice item 1) -------------
# Origin on the floor; pieces sit on z = 0 (sunk 1 cm so they never float).

def debris_rubble(r):
    rng = random.Random(23)
    bm = bmesh.new()
    for _ in range(6):
        s = rng.uniform(0.05, 0.14)
        add_obox(bm, (rng.uniform(-0.2, 0.2), rng.uniform(-0.12, 0.12), s * 0.35 - 0.01), (s, s * rng.uniform(0.6, 1.0), s * 0.7),
                 (rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), rng.uniform(0, math.tau)))
    mesh_object("debris_rubble__chips", bm, ["arch_stone"], r)


def debris_brick(r):
    bm = bmesh.new()
    add_obox(bm, (0.0, 0.0, 0.025), (0.23, 0.11, 0.07), (0.0, math.radians(6), math.radians(20)))
    add_obox(bm, (0.17, 0.09, 0.02), (0.11, 0.1, 0.06), (math.radians(-8), 0.0, math.radians(-35)))
    mesh_object("debris_brick__bricks", bm, ["brick"], r)


# --- table props (origin = table top) -----------------------------------------------

def prop_book_stack(r):
    rng = random.Random(7)
    bm = bmesh.new()
    z = 0.0
    for k in range(4):
        t = rng.uniform(0.04, 0.07)
        add_obox(bm, (rng.uniform(-0.02, 0.02), rng.uniform(-0.02, 0.02), z + t / 2),
                 (rng.uniform(0.2, 0.27), rng.uniform(0.28, 0.34), t), (0.0, 0.0, rng.uniform(-0.25, 0.25)))
        z += t
    mesh_object("prop_book_stack__books", bm, ["book_leather"], r)


def prop_book_open(r):
    bm = bmesh.new()
    add_box(bm, -0.25, 0.25, -0.17, 0.17, 0.0, 0.012, 0)
    for sx in (-1, 1):
        add_obox(bm, (sx * 0.12, 0.0, 0.025), (0.23, 0.32, 0.025), (0.0, math.radians(sx * -5), 0.0), 1)
    mesh_object("prop_book_open__book", bm, ["book_leather", "pages"], r)


def prop_pot(r):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    add_lathe(bm, [(0.0, 0.0), (0.07, 0.0), (0.11, 0.08), (0.12, 0.15), (0.08, 0.24), (0.06, 0.27),
                   (0.075, 0.3), (0.0, 0.3)], segs=12, uv=uv)
    mesh_object("prop_pot__body", bm, ["earthenware"], r)


def prop_oil_lamp(r):
    bm = bmesh.new()
    add_lathe(bm, [(0.0, 0.0), (0.06, 0.0), (0.08, 0.03), (0.05, 0.05), (0.0, 0.05)], segs=10)
    add_box(bm, 0.06, 0.13, -0.015, 0.015, 0.035, 0.05)
    mesh_object("prop_oil_lamp__body", bm, ["brass"], r)
    bm = bmesh.new()
    add_lathe(bm, [(0.0, 0.05), (0.012, 0.06), (0.008, 0.09), (0.0, 0.1)], cx=0.12, segs=6)
    mesh_object("prop_oil_lamp__flame", bm, ["emit_lantern"], r)


def prop_scroll(r):
    bm = bmesh.new()
    add_lathe(bm, [(0.0, -0.17), (0.035, -0.17), (0.035, 0.17), (0.0, 0.17)], segs=8)
    for v in bm.verts:     # lay it on its side along X
        v.co.x, v.co.z = v.co.z, v.co.x + 0.035
    mesh_object("prop_scroll__paper", bm, ["linen"], r)
    bm = bmesh.new()
    for sx in (-1, 1):
        add_box(bm, sx * 0.17 - 0.015, sx * 0.17 + 0.015, -0.02, 0.02, 0.015, 0.055)
    mesh_object("prop_scroll__rods", bm, ["wood"], r)


def prop_inkwell(r):
    bm = bmesh.new()
    add_lathe(bm, [(0.0, 0.0), (0.045, 0.0), (0.05, 0.05), (0.025, 0.07), (0.02, 0.08), (0.0, 0.08)], segs=8)
    mesh_object("prop_inkwell__pot", bm, ["iron"], r)
    bm = bmesh.new()
    add_obox(bm, (0.03, 0.0, 0.15), (0.012, 0.03, 0.24), (0.0, math.radians(18), 0.0))
    mesh_object("prop_inkwell__quill", bm, ["linen"], r)


MODULES = [
    ("M_recess_shelves", props("wood,storage,recess"), recess_shelves),
    ("M_recess_shelves_broken", dict(props("wood,storage,recess,ruin"), kit_rev=3), recess_shelves_broken),
    ("M_recess_tile_panel", props("tile,recess"), recess_tile_panel),
    ("M_recess_sealed_door", props("brick,wood,recess,door"), recess_sealed_door),
    ("M_iwan_lectern", props("wood,iwan,centrepiece"), iwan_lectern),
    ("M_iwan_tree", props("tree,iwan,centrepiece"), iwan_tree),
    ("M_iwan_fountain", props("stone,water,iwan,centrepiece"), iwan_fountain),
    ("M_debris_rubble", props("stone,debris,seam"), debris_rubble),
    ("M_debris_brick", props("brick,debris,seam"), debris_brick),
    ("M_prop_book_stack", props("books,table_prop"), prop_book_stack),
    ("M_prop_book_open", props("books,table_prop"), prop_book_open),
    ("M_prop_pot", props("earthenware,table_prop"), prop_pot),
    ("M_prop_oil_lamp", props("brass,light,table_prop"), prop_oil_lamp),
    ("M_prop_scroll", props("linen,table_prop"), prop_scroll),
    ("M_prop_inkwell", props("iron,table_prop"), prop_inkwell),
]


def main():
    if os.path.exists(BLEND):
        bpy.ops.wm.open_mainfile(filepath=BLEND)
    else:
        bpy.ops.wm.read_factory_settings(use_empty=True)
    added = []
    for i, (name, p, build) in enumerate(MODULES):
        if bpy.data.objects.get(name) is None:
            build(module(name, ((i % 7) * 4.0, (i // 7) * 5.0, 0.0), p))
            added.append(name)
    REBUILD = [("M_recess_shelves_broken", 3)]   # rev 3: floor boards split out as __spill
    added += ["%s (rebuilt rev %d)" % (n, v) for (n, v) in REBUILD if rebuild(n, v, MODULES)]
    if not added:
        print("kit_add_dressing: all modules already present; nothing to do.")
        return
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("kit_add_dressing: added %s" % ", ".join(added))


main()
