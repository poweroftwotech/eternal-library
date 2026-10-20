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
  prop_vase_floor(_broken) the floor under the vase's centre (a hand-placed WorldProp).
  stair_steps_* a stair_style(_r) socket: the middle of a stair_gallery_8m(_r) footprint
               (floor level, lane centre); the stair rises along +X.
  gallery_wood_*, gallery_masonry_* a gallery_style_* socket at its gallery module's origin
               (wall line, floor level; the slab lane is y 0.3..1.6).
  gallery_column(_corner) a gallery_support(_corner) socket: the column centre
               (floor level); the wall the arch reaches is -Y.
  growth_*    a growth socket (polish B): on the face the ivy clings to, room +Y.
               arch: the arch centre at floor level; cornice: the springing line;
               parapet: the coping top centre line (pitched on a stair).
"""
import math
import os
import random
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit_blender import (add_box, add_card, add_lathe, add_ngon_prism, add_obox, add_prism, add_tube, rebuild,  # noqa: E402
                         H, T, arch_outline, arch_ring, marker, mesh_object, module)

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
    # rev 5 (polish B item 6): roots push through a crack in the recess back and
    # creep down over the boards; the runs over the floor boards are part of
    # those boards' meshes (second material), so they settle with them.
    rng = random.Random(107)
    roots = bmesh.new()
    crack = (rng.uniform(-0.3, 0.3), BACK + 0.012, 2.9)
    root_clump(roots, rng, crack)
    spill = {}
    for (name, centre, size, rot) in (
            ("a", (-0.55, 0.45, 0.03), (1.7, 0.45, 0.05), (0.0, 0.0, math.radians(28))),
            ("b", (0.82, 0.4, 0.09), (1.2, 0.45, 0.05), (math.radians(8), 0.0, math.radians(-12)))):
        bm = bmesh.new()
        add_obox(bm, centre, size, rot)
        spill[name] = (bm, centre, size, rot)
    for (x, board, tip) in ((-0.75, "a", (0.05, 0.8)), (0.55, "b", (1.3, 0.55))):   # tips along each board
        # Down the back wall, over the top board, down the front of the shelves.
        drop = [crack, (crack[0] * 0.6 + x * 0.4, BACK + 0.015, 2.35), (x, BACK + 0.015, 1.92),
                (x + 0.05, 0.0, BOARDS[4] + 0.07), (x + 0.08, FRONT + 0.03, BOARDS[4] + 0.06),
                (x + 0.1, FRONT + 0.035, BOARDS[4] - 0.05), (x + 0.04, FRONT + 0.04, 1.1),
                (x + 0.1, FRONT + 0.04, 0.45), (x + 0.06, FRONT + 0.045, 0.12), (x + 0.1, FRONT + 0.06, 0.025)]
        drop = wander(rng, drop)
        add_tube(roots, drop, taper(len(drop), 0.05, 0.03), 6)
        # Out of the recess and over the floor board to a thin tip.
        bm, centre, size, rot = spill[board]
        start = drop[-1]
        run = [(start[0] + (tip[0] - start[0]) * t, start[1] + (tip[1] - start[1]) * t, 0.0) for t in (i / 9 for i in range(10))]
        run = [(px + rng.uniform(-0.04, 0.04) * (0 < i < 9), py, board_top(px, py, centre, size, rot) + 0.024)
               for i, (px, py, _z) in enumerate(run)]
        add_tube(bm, [start] + run[1:], taper(len(run), 0.03, 0.008), 6, mat=1)
    for (name, (bm, _c, _s, _r)) in spill.items():
        mesh_object("recess_shelves_broken__spill_" + name, bm, ["wood", "bark"], r)
    # A third root creeps along the dropped board, downhill, and off its low end.
    along = [crack, (crack[0] - 0.4, BACK + 0.015, 2.3), (-0.95, BACK + 0.015, 1.92),
             (-1.0, FRONT + 0.035, BOARDS[4] + 0.03), (-1.02, FRONT + 0.04, BOARDS[4] - 0.08), (-1.0, 0.12, 1.15)]
    along += [(xx, 0.05 + 0.04 * math.sin(xx * 3.0), dropped_top(xx) + 0.035) for xx in (-0.95 + 0.25 * i for i in range(9))]
    along += [(1.3, FRONT + 0.05, dropped_top(1.3) - 0.06), (1.32, FRONT + 0.06, 0.3), (1.28, 0.1, 0.02), (1.1, -0.05, 0.015)]
    along = wander(rng, along)
    add_tube(roots, along, taper(len(along), 0.045, 0.01), 6)
    mesh_object("recess_shelves_broken__roots", roots, ["bark"], r)


DROPPED = ((0.05, -0.02, 0.78), 0.05, math.radians(9.5))   # the dropped board: centre, thickness, tilt about Y


def dropped_top(x):
    """Top of the dropped board above recess x (it falls toward +X)."""
    (cx, _cy, cz), t, a = DROPPED
    return cz - (x - cx) * math.tan(a) + t / 2 / math.cos(a)


def board_top(x, y, centre, size, rot):
    """Top surface height of an add_obox board at (x, y), or the floor (0) off it."""
    from mathutils import Euler, Vector
    m = Euler(rot, "XYZ").to_matrix()
    local = m.transposed() @ (Vector((x, y, centre[2])) - Vector(centre))
    if abs(local.x) > size[0] / 2 or abs(local.y) > size[1] / 2:
        return 0.0
    n = m @ Vector((0.0, 0.0, 1.0))
    top = Vector(centre) + n * (size[2] / 2)
    return top.z - (n.x * (x - top.x) + n.y * (y - top.y)) / n.z


def wander(rng, path, step=0.1, amp=0.025):
    """Subdivide a path to about `step` and jitter the inner points along the wall
    (x), so a root reads gnarled rather than straight; the ends stay put."""
    from mathutils import Vector
    out = [path[0]]
    for a, b in zip(path, path[1:]):
        n = max(1, round((Vector(b) - Vector(a)).length / step))
        for j in range(1, n + 1):
            t = j / n
            out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t))
    return [out[0]] + [(x + rng.uniform(-amp, amp), y, z) for (x, y, z) in out[1:-1]] + [out[-1]]


def taper(n, r0, r1):
    return [r0 + (r1 - r0) * i / max(n - 1, 1) for i in range(n)]


def root_clump(bm, rng, crack):
    """Gnarled root stubs bursting from a crack in the recess back, spread on the wall."""
    for k in range(6):
        a = k * math.tau / 6 + rng.uniform(-0.3, 0.3)
        reach = rng.uniform(0.18, 0.42)
        path = [crack]
        for j in range(1, 4):
            f = reach * j / 3
            path.append((crack[0] + math.cos(a) * f + rng.uniform(-0.03, 0.03), crack[1] + 0.004 * j,
                         crack[2] + math.sin(a) * f * 0.8 + rng.uniform(-0.03, 0.03)))
        add_tube(bm, path, taper(4, 0.065, 0.015), 6)


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


# --- plants (weathering slice item 2) ----------------------------------------
# Cards use the swaying foliage materials (kit_foliage.gdshader). Seam plants
# have their origin on the floor; ivy hangs from a gallery rail top.

def plant_crack_tuft(r):
    rng = random.Random(31)
    bm = bmesh.new()
    add_obox(bm, (0.0, 0.0, 0.004), (0.55, 0.035, 0.012), (0.0, 0.0, 0.0))
    mesh_object("plant_crack_tuft__moss", bm, ["moss"], r)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    for _ in range(11):
        s = rng.uniform(0.6, 1.1)
        add_card(bm, uv, (rng.uniform(-0.26, 0.26), rng.uniform(-0.02, 0.02), 0.0), 0.05 * s, 0.13 * s,
                 rng.uniform(0, math.tau), rng.uniform(-0.35, 0.35))
    mesh_object("plant_crack_tuft__blades", bm, ["leaf"], r, recalc=False)


def plant_moss_cushion(r):
    rng = random.Random(37)
    bm = bmesh.new()
    for _ in range(3):
        rad, h = rng.uniform(0.09, 0.17), rng.uniform(0.04, 0.07)
        add_lathe(bm, [(0.0, -0.005), (rad, -0.005), (rad * 0.85, h * 0.6), (rad * 0.45, h), (0.0, h * 1.02)],
                  cx=rng.uniform(-0.12, 0.12), cy=rng.uniform(-0.08, 0.08), segs=8)
    mesh_object("plant_moss_cushion__moss", bm, ["moss"], r)


def plant_fern(r):
    rng = random.Random(41)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    for k in range(6):
        add_card(bm, uv, (0.0, 0.0, 0.0), 0.12, rng.uniform(0.28, 0.38), k * math.tau / 7 + rng.uniform(-0.2, 0.2),
                 math.radians(rng.uniform(45, 62)))
    mesh_object("plant_fern__fronds", bm, ["fern"], r, recalc=False)


def plant_ivy_hang(r):
    """Origin on the rail top centre line; the room is +Y (Godot -Z). A few leaves
    drape over the rail and strands hang 0.12 m out, clear of the slab edge."""
    rng = random.Random(43)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    for i in range(3):     # draped over the rail top, lying flat
        add_card(bm, uv, (rng.uniform(-0.2, 0.2), -0.06, 0.012), 0.14, 0.2, math.radians(rng.uniform(-20, 20)), math.radians(-90))
    for _ in range(rng.randint(3, 5)):
        x, length = rng.uniform(-0.22, 0.22), rng.uniform(0.6, 1.15)
        z = 0.0
        while z > -length:
            add_card(bm, uv, (x + rng.uniform(-0.03, 0.03), 0.12, z - 0.14), 0.14, 0.14, rng.uniform(-0.5, 0.5), rng.uniform(-0.3, 0.3))
            z -= rng.uniform(0.09, 0.13)
    mesh_object("plant_ivy_hang__leaves", bm, ["ivy_leaf"], r, recalc=False)


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


# --- floor vase and its shards (phase 3 slice 1; origin = floor under its centre) ----
# Not socket candidates: R01 places the vase by hand as a WorldProp
# (props/vase_floor.tscn). The broken module holds the same vase cut into
# shards in their assembled places, so the shards spawn exactly where the
# vase stood. Each shard is a closed shell (outer and inner surface), so a
# convex hull per shard is a fair collider.
VASE = [(0.0, 0.0), (0.13, 0.0), (0.15, 0.03), (0.2, 0.14), (0.25, 0.3), (0.26, 0.42),
        (0.23, 0.56), (0.15, 0.7), (0.1, 0.78), (0.1, 0.84), (0.14, 0.9), (0.0, 0.9)]
VASE_WALL = 0.018


def prop_vase_floor(r):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    add_lathe(bm, VASE, segs=16, uv=uv)
    mesh_object("prop_vase_floor__body", bm, ["earthenware"], r)


def vase_shard(bm, uv, k0, k1, a0, a1, steps=4):
    """A piece of the vase wall between profile points k0..k1 and the angle
    bounds a0(k)..a1(k) (functions of the ring, so cuts wander), as a closed
    shell VASE_WALL thick. With a1 - a0 = full turn it is a closed band."""
    z0, z1 = VASE[0][1], VASE[-1][1]
    full = abs((a1(k0) - a0(k0)) - 2 * math.pi) < 1e-6
    n = steps * (4 if full else 1)
    outer, inner = [], []
    for k in range(k0, k1 + 1):
        r, z = VASE[k]
        ri = max(r - VASE_WALL, 0.02)
        lo, hi = a0(k), a1(k)
        cols = range(n) if full else range(n + 1)
        outer.append([bm.verts.new((r * math.cos(lo + (hi - lo) * i / n), r * math.sin(lo + (hi - lo) * i / n), z)) for i in cols])
        inner.append([bm.verts.new((ri * math.cos(lo + (hi - lo) * i / n), ri * math.sin(lo + (hi - lo) * i / n), z + (VASE_WALL if k == 0 else 0.0))) for i in cols])
    m = len(outer[0])
    span = range(m) if full else range(m - 1)

    def quad(vs, row, col):
        f = bm.faces.new(vs)
        for loop, (c, kk) in zip(f.loops, ((col, row), (col + 1, row), (col + 1, row + 1), (col, row + 1))):
            loop[uv].uv = ((a0(k0) + (a1(k0) - a0(k0)) * c / n) / (2 * math.pi), (VASE[k0 + kk][1] - z0) / (z1 - z0))
    for j in range(len(outer) - 1):
        for i in span:
            i2 = (i + 1) % m
            quad((outer[j][i], outer[j][i2], outer[j + 1][i2], outer[j + 1][i]), j, i)
            quad((inner[j][i], inner[j + 1][i], inner[j + 1][i2], inner[j][i2]), j, i)
    for (row, flip) in ((0, True), (len(outer) - 1, False)):    # rims (bottom, top)
        for i in span:
            i2 = (i + 1) % m
            vs = (outer[row][i], inner[row][i], inner[row][i2], outer[row][i2])
            bm.faces.new(tuple(reversed(vs)) if flip else vs)
    if not full:                                                  # the two cut sides
        for j in range(len(outer) - 1):
            bm.faces.new((outer[j][0], outer[j + 1][0], inner[j + 1][0], inner[j][0]))
            bm.faces.new((outer[j][-1], inner[j][-1], inner[j + 1][-1], outer[j + 1][-1]))


def prop_vase_floor_broken(r):
    rng = random.Random(31)
    # Base: the foot ring up to k 2 (a floor disc closes it). Belly: k 2..6 in
    # four pieces. Shoulder and neck: k 6..11 in three. Cuts wander per ring.
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    vase_shard(bm, uv, 1, 3, lambda k: 0.0, lambda k: 2 * math.pi)
    add_ngon_prism(bm, 16, VASE[1][0] - 0.005, 0.0, VASE_WALL)
    mesh_object("prop_vase_floor_broken__shard_0", bm, ["earthenware"], r)
    count = 1
    for (k0, k1, cuts) in ((3, 6, 4), (6, 10, 3)):
        start = rng.uniform(0, 2 * math.pi)
        bounds = [start + 2 * math.pi * c / cuts + rng.uniform(-0.25, 0.25) for c in range(cuts)]
        wobble = {(c, k): rng.uniform(-0.18, 0.18) for c in range(cuts) for k in range(k0, k1 + 1)}
        for c in range(cuts):
            c2 = (c + 1) % cuts
            lo = (lambda k, c=c: bounds[c] + wobble[(c, k)])
            hi = (lambda k, c=c, c2=c2: bounds[c2] + wobble[(c2, k)] + (2 * math.pi if c2 == 0 else 0.0))
            bm = bmesh.new()
            uv = bm.loops.layers.uv.new("UVMap")
            vase_shard(bm, uv, k0, k1, lo, hi, steps=3)
            mesh_object("prop_vase_floor_broken__shard_%d" % count, bm, ["earthenware"], r)
            count += 1


# --- stair candidates (weathering item 4, polish slice A) ---------------------
# The look of stair_gallery_8m / _r is a stair_style(_r) socket. The stair
# module keeps the walkable ramp slab, the open-side rail collision and the
# snaps, so routes never depend on the look. Each look brings its own railing
# and, for masonry, the solid fill under the slab. The open side (+Y) carries
# the railing, so the reversed stair needs mirrored candidates (`_r`): a half
# turn would put the railing against the wall.
STAIR_STEPS, STAIR_RUN, STAIR_TOP = 20, 8.0, H + 0.15
STAIR_HALF = (1.6 - T) / 2      # lane half width (T to 1.6 from the wall line)
STAIR_WALL = -STAIR_HALF - T    # the wall's centre line, in socket space


def stair_x(x, reverse):
    """Stair-space x (0 = foot of a plain stair) to socket space (origin mid-run)."""
    return (STAIR_RUN - x if reverse else x) - STAIR_RUN / 2


def stair_prism(bm, outline, y0, y1, reverse):
    """add_prism for a stair-space XZ outline, mirrored for the reversed stair."""
    pts = [(stair_x(u, reverse), v) for (u, v) in outline]
    if reverse:
        pts.reverse()
    add_prism(bm, pts, 0.0, 0.0, y0, y1)


def stair_box(bm, x0, x1, y0, y1, z0, z1, reverse):
    a, b = sorted((stair_x(x0, reverse), stair_x(x1, reverse)))
    add_box(bm, a, b, y0, y1, z0, z1)


def stair_claim(r, name, x0, x1, z1, reverse):
    """CLAIM_ empty: while this look is picked, other sockets' items whose origin
    is in the box are cleared. It starts 0.1 m off the wall line, so it takes the
    wall-base seams (0.3 m out) but never a socket on the wall line itself: the
    gallery look socket of the slab at the stair head sits at its module origin,
    on the corner of this box (polish 1c fix)."""
    a, b = sorted((stair_x(x0, reverse), stair_x(x1, reverse)))
    y0, y1 = STAIR_WALL + 0.1, STAIR_HALF
    marker("CLAIM_" + name, r, ((a + b) / 2, (y0 + y1) / 2, z1 / 2), {"claim_size": [b - a, y1 - y0, z1]})


# Turned baluster (radius, height 0..1), the prototype gallery's profile
# (interior_pass.gd) with its radii scaled to 0.85.
BALUSTER = [(0.0, 0.0), (0.077, 0.0), (0.077, 0.12), (0.047, 0.196), (0.06, 0.543),
            (0.038, 0.783), (0.068, 0.913), (0.077, 1.0), (0.0, 1.0)]
FINIAL = [(0.0, 0.0), (0.05, 0.0), (0.03, 0.03), (0.06, 0.07), (0.065, 0.1), (0.05, 0.14), (0.0, 0.16)]


def stair_steps_masonry(r, reverse=False):
    """Solid stone steps with an open stone balustrade on the open edge, all in
    arch_stone like the steps (polish 1b): a sloped plinth 0.18 m above the
    nosing line, a turned baluster per tread, a sloped handrail 0.8-0.92 m above
    the nosings, and a capped newel with a ball finial at the foot and the head.
    The solid under the slab is collision (the stair is not walkable under)."""
    name = "stair_steps_masonry" + ("_r" if reverse else "")
    rise, tread = STAIR_TOP / STAIR_STEPS, STAIR_RUN / STAIR_STEPS
    run, top, slope = STAIR_RUN, STAIR_TOP, STAIR_TOP / STAIR_STEPS / (STAIR_RUN / STAIR_STEPS)
    inner = STAIR_HALF - 0.2       # the balustrade takes the outer 0.2 m of the lane
    bm = bmesh.new()
    for i in range(STAIR_STEPS):
        stair_box(bm, i * tread, (i + 1) * tread, -STAIR_HALF, inner, 0.0, (i + 1) * rise, reverse)
    mesh_object(name + "__steps", bm, ["arch_stone"], r)
    nosing = lambda x: rise + min(x, run - tread) * slope    # noqa: E731  (flat over the top tread)

    def band(x0, x1, lo, hi):
        """XZ outline of a band lo..hi above the nosing line, from x0 to x1 (> run - tread)."""
        return [(x0, nosing(x0) + lo), (run - tread, top + lo), (x1, top + lo),
                (x1, top + hi), (run - tread, top + hi), (x0, nosing(x0) + hi)]

    plinth, rail_lo, rail_hi = 0.18, 0.8, 0.92
    bm = bmesh.new()
    stair_prism(bm, [(0.02, 0.0), (run - 0.02, 0.0), (run - 0.02, top + plinth), (run - tread, top + plinth),
                     (0.02, nosing(0.02) + plinth)], inner, STAIR_HALF - 0.02, reverse)
    mesh_object(name + "__plinth", bm, ["arch_stone"], r)
    bm = bmesh.new()
    for i in range(1, STAIR_STEPS - 1):        # one per tread, clear of the newels
        x = i * tread + tread / 2
        z0, z1 = nosing(x) + plinth - 0.07, nosing(x) + rail_lo + 0.07    # sunk into plinth and rail
        add_lathe(bm, [(rr, z0 + t * (z1 - z0)) for (rr, t) in BALUSTER],
                  cx=stair_x(x, reverse), cy=inner + 0.09, segs=12)
    mesh_object(name + "__balusters", bm, ["arch_stone"], r)
    bm = bmesh.new()
    stair_prism(bm, band(0.25, run - 0.15, rail_lo, rail_hi), inner - 0.02, STAIR_HALF - 0.01, reverse)
    mesh_object(name + "__handrail", bm, ["arch_stone"], r)
    bm = bmesh.new()
    for (x0, x1, h) in ((0.0, 0.3, nosing(0.3) + rail_hi + 0.06), (run - 0.3, run, top + rail_hi + 0.06)):
        stair_box(bm, x0, x1, inner - 0.03, STAIR_HALF, 0.0, h, reverse)                   # shaft
        stair_box(bm, x0 - 0.025, x1 + 0.025 if x1 < run else x1, inner - 0.055, STAIR_HALF + 0.02,
                  h, h + 0.08, reverse)                                                     # cap
        add_lathe(bm, [(rr, h + 0.07 + z) for (rr, z) in FINIAL],
                  cx=stair_x((x0 + x1) / 2, reverse), cy=(inner - 0.03 + STAIR_HALF) / 2, segs=10)
    mesh_object(name + "__newels", bm, ["arch_stone"], r)
    bm = bmesh.new()
    stair_prism(bm, [(0.1, 0.0), (run - tread / 2, top - 0.1), (run, top - 0.1), (run, 0.0)],
                -STAIR_HALF, STAIR_HALF, reverse)
    mesh_object(name + "__fill-colonly", bm, ["arch_stone"], r)
    stair_claim(r, "under", 0.0, run, 0.6, reverse)      # the wall base behind it is hidden
    stair_head_claim(r, reverse)


def stair_steps_open(r, reverse=False):
    """Wooden stringer stair with open risers: two sloped stringers (8 cm thick,
    0.3 m deep, top edge 8 cm above the nosings, foot on the floor) carrying
    5 cm treads with a 3 cm nosing, and a wooden post-and-handrail balustrade.
    No collision of its own: the module's slab and rail strip are walked on, and
    the space under the high end is open."""
    name = "stair_steps_open" + ("_r" if reverse else "")
    rise, tread = STAIR_TOP / STAIR_STEPS, STAIR_RUN / STAIR_STEPS
    run, top, lip = STAIR_RUN, STAIR_TOP, 0.08
    outline = [(0.0, 0.0), (0.6, 0.0), (run, top - 0.3), (run, top + lip),
               (run - tread, top + lip), (0.0, rise + lip)]
    bm = bmesh.new()
    for (a, b) in ((-STAIR_HALF, -STAIR_HALF + 0.08), (STAIR_HALF - 0.08, STAIR_HALF)):
        stair_prism(bm, outline, a, b, reverse)
    mesh_object(name + "__stringers", bm, ["wood"], r)
    bm = bmesh.new()
    for i in range(STAIR_STEPS):
        z = (i + 1) * rise
        stair_box(bm, max(0.0, i * tread - 0.03), (i + 1) * tread, -STAIR_HALF + 0.08, STAIR_HALF - 0.08, z - 0.05, z, reverse)
    mesh_object(name + "__treads", bm, ["wood"], r)
    # Balustrade (as the stair module carried before): posts every 0.8 m and a
    # sloped handrail.
    y1 = STAIR_HALF
    bm = bmesh.new()
    x = tread / 2
    while x < run:
        z = (math.floor(x / tread) + 1) * rise
        stair_box(bm, x - 0.03, x + 0.03, y1 - 0.1, y1 - 0.04, z, z + 0.9, reverse)
        x += 0.8
    stair_prism(bm, [(0.0, rise + 0.86), (run, top + 0.86), (run, top + 0.94), (0.0, rise + 0.94)],
                y1 - 0.12, y1 - 0.02, reverse)
    mesh_object(name + "__rail", bm, ["wood"], r)
    stair_claim(r, "low_end", 0.0, 1.6, 0.8, reverse)    # too low to reach under


def stair_steps_masonry_r(r):
    stair_steps_masonry(r, True)


def stair_head_claim(r, reverse):
    """Masonry only: the column a room places under the gallery at the stair head
    (post_gallery_column, 1.4 m from the wall line) is cleared, because the solid
    stair carries the arcade's last arch (polish 1c). Covers the open half of the
    lane only, so the gallery look socket on the wall line is never claimed."""
    a, b = sorted((stair_x(STAIR_RUN - 0.2, reverse), stair_x(STAIR_RUN + 0.4, reverse)))
    marker("CLAIM_head", r, ((a + b) / 2, STAIR_HALF / 2, 0.3), {"claim_size": [b - a, STAIR_HALF, 0.8]})


def stair_steps_open_r(r):
    stair_steps_open(r, True)


# --- gallery candidates (polish 1c) -------------------------------------------
# The look of gallery_slab_4m / _open_end / _open_start / gallery_end_12m is a
# gallery_style_* socket at the module's origin (wall line, floor level; the
# room is +Y, the slab lane y T..1.6). The module keeps only the slab and rail
# collision. Wood is the old visible slab and balustrade. Masonry is a stone
# slab, the stair's stone balustrade and an arcade along the open edge between
# the column points; post_gallery_column(_corner) brings the columns and the
# arches back to the wall (gallery_support(_corner) candidates below).
GAL_Y0, GAL_Y1, GAL_TOP, GAL_SOFFIT = T, 1.6, H + 0.15, H - 0.15
COL_Y = 1.4                     # column centre line, from the wall line
SPRING = 1.85                   # abacus top: every arch springs here (capsule 1.75 m)
ARCADE_APEX, ARM_APEX = 3.55, 3.3
ABACUS = 0.32                   # abacus half width
COL_BASE = 0.24                 # column base half width: 0.74 m clear of a pier base (0.42)
RING = 0.18                     # voussoir depth
ARCADE = (COL_Y - 0.2, COL_Y + 0.2)
BAL_Y = 1.49                    # stone balustrade centre line
PLINTH_TOP, RAIL_LO, RAIL_HI = GAL_TOP + 0.15, GAL_TOP + 0.8, GAL_TOP + 0.92   # handrail top as the stair head
CORNER = 1.6 - 0.11             # corner newel centre (both lines), as the wooden newel


def wood_balustrade(bm, x0, x1):
    """Balusters every 0.5 m and a top rail between x0 and x1 (gallery_slab_4m's)."""
    x = x0 + 0.05
    while x < x1 - 0.02:
        add_box(bm, x, x + 0.06, 1.48, 1.54, H + 0.15, H + 0.95)
        x += 0.5
    add_box(bm, x0, x1, 1.46, 1.56, H + 0.92, H + 1.0)


def gallery_wood(r, name, slab, rail, newels=()):
    """The wooden look, as the modules carried it before (visual only)."""
    bm = bmesh.new()
    add_box(bm, slab[0], slab[1], GAL_Y0, GAL_Y1, H - 0.15, H + 0.15)
    mesh_object(name + "__slab", bm, ["wood"], r)
    bm = bmesh.new()
    wood_balustrade(bm, rail[0], rail[1])
    for x in newels:
        add_box(bm, x - 0.06, x + 0.06, 1.45, 1.57, H + 0.15, H + 1.06)
    mesh_object(name + "__rail", bm, ["wood"], r)


def intrados(x0, x1, z0, apex, n=8):
    """Arch curve from (x0, z0) up and over to (x1, z0), its crown near `apex`:
    round when the span is wide enough, pointed up to k = 0.75, beyond that a
    k = 0.75 arch stilted on vertical sides (arch_outline's construction)."""
    s, rise = x1 - x0, apex - z0
    k, stilt = min(max(0.25 + (rise / s) ** 2, 0.5), 0.75), 0.0
    if 0.25 + (rise / s) ** 2 > 0.75:
        stilt = rise - s * math.sqrt(0.5)
    rr = s * k
    left = [(x0, z0)] + ([(x0, z0 + stilt)] if stilt > 0 else [])
    left += [(x0 + u, z0 + stilt + math.sqrt(max(0.0, rr * rr - (u - rr) ** 2)))
             for u in (s / 2 * i / n for i in range(1, n + 1))]
    return left + [(x0 + x1 - u, v) for (u, v) in reversed(left[:-1])]


def offset(pts, d):
    """Offset an arch curve away from its opening by d (negative: into it)."""
    out = []
    for i, (x, z) in enumerate(pts):
        a, b = pts[max(i - 1, 0)], pts[min(i + 1, len(pts) - 1)]
        tx, tz = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(tx, tz)
        out.append((x - tz / ln * d, z + tx / ln * d))
    return out


def arch_span(bm_wall, bm_ring, xa, x0, x1, xb, y0, y1, apex):
    """One arch in the XZ plane, extruded y0..y1: a solid wall from xa to xb
    between the springing and the slab soffit with the opening x0..x1 cut out,
    and a voussoir ring standing 2 cm proud of both faces."""
    curve = intrados(x0, x1, SPRING, apex)
    add_prism(bm_wall, [(xa, SPRING)] + curve + [(xb, SPRING), (xb, GAL_SOFFIT), (xa, GAL_SOFFIT)], 0.0, 0.0, y0, y1)
    arch_ring(bm_ring, offset(curve, -0.01), offset(curve, RING), y0 - 0.02, y1 + 0.02, smooth=False)


def stone_balustrade(bm_plinth, bm_bal, bm_rail, x0, x1):
    """The stair's stone balustrade, level, on the gallery edge from x0 to x1:
    balusters on the 0.4 m grid (x = 0.2 + 0.4 k), so runs line up across modules."""
    add_box(bm_plinth, x0, x1, BAL_Y - 0.09, BAL_Y + 0.09, GAL_TOP - 0.01, PLINTH_TOP)
    add_box(bm_rail, x0, x1, BAL_Y - 0.11, BAL_Y + 0.1, RAIL_LO, RAIL_HI)
    k = math.ceil((x0 + 0.1 - 0.2) / 0.4)
    while 0.2 + 0.4 * k < x1 - 0.1:
        z0, z1 = PLINTH_TOP - 0.07, RAIL_LO + 0.07
        add_lathe(bm_bal, [(rr, z0 + t * (z1 - z0)) for (rr, t) in BALUSTER], cx=0.2 + 0.4 * k, cy=BAL_Y, segs=12)
        k += 1


def stone_newel(bm, x, y):
    """Corner newel swallowing the meeting rail ends: shaft, cap, ball finial."""
    h = RAIL_HI + 0.06
    add_box(bm, x - 0.14, x + 0.14, y - 0.14, y + 0.14, GAL_TOP - 0.01, h)
    add_box(bm, x - 0.17, x + 0.17, y - 0.17, y + 0.17, h, h + 0.08)
    add_lathe(bm, [(rr, h + 0.07 + z) for (rr, z) in FINIAL], cx=x, cy=y, segs=10)


def gallery_masonry(r, name, slab, rail, cols, cornice, newels=()):
    """Stone slab, stone balustrade on `rail` (x0, x1), an arcade between the
    column centres `cols` on the COL_Y line, and a cornice along the open edge."""
    bm = bmesh.new()
    add_box(bm, slab[0], slab[1], GAL_Y0, GAL_Y1, GAL_SOFFIT, GAL_TOP)
    mesh_object(name + "__slab", bm, ["floor_stone"], r)
    bm = bmesh.new()
    add_box(bm, cornice[0], cornice[1], GAL_Y1 - 0.05, GAL_Y1 + 0.06, GAL_SOFFIT - 0.08, GAL_SOFFIT + 0.07)
    mesh_object(name + "__cornice", bm, ["arch_stone"], r)
    bp, bb, br = bmesh.new(), bmesh.new(), bmesh.new()
    stone_balustrade(bp, bb, br, rail[0], rail[1])
    for (x, y) in newels:
        stone_newel(br, x, y)
    mesh_object(name + "__plinth", bp, ["arch_stone"], r)
    mesh_object(name + "__balusters", bb, ["arch_stone"], r)
    mesh_object(name + "__handrail", br, ["arch_stone"], r)
    bw, bv = bmesh.new(), bmesh.new()
    for (a, b) in zip(cols, cols[1:]):
        arch_span(bw, bv, a, a + ABACUS, b - ABACUS, b, ARCADE[0], ARCADE[1], ARCADE_APEX)
    mesh_object(name + "__spandrels-col", bw, ["brick"], r)
    mesh_object(name + "__voussoirs", bv, ["arch_stone"], r)


def gallery_wood_slab(r):
    gallery_wood(r, "gallery_wood_slab", (0.0, 4.0), (0.0, 4.0))


def gallery_masonry_slab(r):
    gallery_masonry(r, "gallery_masonry_slab", (0.0, 4.0), (0.0, 4.0), (0.0, 4.0), (0.0, 4.0))


def gallery_wood_open_end(r):
    gallery_wood(r, "gallery_wood_open_end", (0.0, 4.0), (0.0, 4.0 - GAL_Y1 + 0.04))


def gallery_masonry_open_end(r):
    """The corner square (x 2.4..4) opens onto the end-wall gallery; the corner
    column stands at x 4 - COL_Y and gallery_end_12m owns the corner newel."""
    gallery_masonry(r, "gallery_masonry_open_end", (0.0, 4.0), (0.0, 4.0 - CORNER), (0.0, 4.0 - COL_Y),
                    (0.0, 4.0 - GAL_Y1 + 0.05))


def gallery_wood_open_start(r):
    gallery_wood(r, "gallery_wood_open_start", (0.0, 4.0), (GAL_Y1 - 0.04, 4.0))


def gallery_masonry_open_start(r):
    gallery_masonry(r, "gallery_masonry_open_start", (0.0, 4.0), (CORNER, 4.0), (COL_Y, 4.0),
                    (GAL_Y1 - 0.05, 4.0))


HALL = 12.0


def gallery_wood_end(r):
    x0, x1 = GAL_Y1, HALL - GAL_Y1
    gallery_wood(r, "gallery_wood_end", (x0, x1), (x0 - 0.04, x1 + 0.04), (x0 - 0.09, x1 + 0.09))


def gallery_masonry_end(r):
    """Columns at both corners and either side of the 3 m entrance arch (x 4, 8)."""
    gallery_masonry(r, "gallery_masonry_end", (GAL_Y1, HALL - GAL_Y1), (CORNER, HALL - CORNER),
                    (COL_Y, 4.0, 8.0, HALL - COL_Y), (GAL_Y1 + 0.06, HALL - GAL_Y1 - 0.06),
                    ((CORNER, CORNER), (HALL - CORNER, CORNER)))


# Supports: a post_gallery_column(_corner) socket at the column point (floor
# level). The wall is -Y, COL_Y away.
def stone_column(bm):
    """Square base, turned shaft, flared capital, abacus (top at SPRING)."""
    add_box(bm, -COL_BASE, COL_BASE, -COL_BASE, COL_BASE, 0.0, 0.22)
    add_lathe(bm, [(0.0, 0.22), (0.23, 0.22), (0.23, 0.28), (0.19, 0.36), (0.17, 0.44), (0.16, 1.44), (0.2, 1.47),
                   (0.2, 1.52), (0.17, 1.55), (0.3, 1.72), (0.0, 1.72)], segs=12)
    add_box(bm, -ABACUS, ABACUS, -ABACUS, ABACUS, 1.72, SPRING)


def wall_arm(bm_wall, bm_ring, bm_respond, half, angle):
    """Arch from the column to the wall face (COL_Y - T away), springing from the
    abacus and from a two-tier respond corbel on the wall, stilted to ARM_APEX.
    Built along +X, then turned by `angle` about Z (-90: toward -Y)."""
    length = COL_Y - T
    marks = [len(bm.verts) for bm in (bm_wall, bm_ring, bm_respond)]
    arch_span(bm_wall, bm_ring, 0.0, ABACUS, length - 0.25, length + 0.05, -half, half, ARM_APEX)
    add_box(bm_respond, length - 0.25, length + 0.05, -half - 0.03, half + 0.03, SPRING - 0.13, SPRING)
    add_box(bm_respond, length - 0.15, length + 0.05, -half + 0.03, half - 0.03, SPRING - 0.4, SPRING - 0.13)
    c, s = math.cos(math.radians(angle)), math.sin(math.radians(angle))
    for bm, start in zip((bm_wall, bm_ring, bm_respond), marks):
        bm.verts.ensure_lookup_table()
        for i in range(start, len(bm.verts)):
            v = bm.verts[i]
            v.co.x, v.co.y = v.co.x * c - v.co.y * s, v.co.x * s + v.co.y * c


def gallery_support(r, name, arms, half):
    bm = bmesh.new()
    stone_column(bm)
    mesh_object(name + "__column-col", bm, ["arch_stone"], r)
    bw, bv, bc = bmesh.new(), bmesh.new(), bmesh.new()
    for angle in arms:
        wall_arm(bw, bv, bc, half, angle)
    mesh_object(name + "__spandrels-col", bw, ["brick"], r)
    mesh_object(name + "__voussoirs", bv, ["arch_stone"], r)
    mesh_object(name + "__responds", bc, ["arch_stone"], r)


def gallery_column(r):
    """One transverse arch to the wall, 0.6 m thick: it buries the wall pier's
    corbel (post_pier_corbel) where there is one."""
    gallery_support(r, "gallery_column", (-90,), 0.3)


def gallery_column_corner(r):
    """One arch to the -Y wall (the end wall), continuing the side arcade's line.
    The -X wall is a side wall with a recess beside the corner, so an arch there
    would land in the recess mouth; post_gallery_column_corner_r turns this
    socket so the arch reaches the end wall on the other side too."""
    gallery_support(r, "gallery_column_corner", (-90,), 0.2)


# --- growth (polish slice B item 5) ------------------------------------------
# Built like the prototype's arch_head_ivy, pier_ivy and clinging vine()
# (scripts/arch_pass.gd, interior_pass.gd): a thin vine tube tracing the stone,
# dense ivy leaf clumps, and long hanging strands. Leaves are ivy_leaf cards
# (swaying kit_foliage material); the vine is a static tube. Every growth
# candidate's origin is on the face it clings to; the room is +Y.
LEAF = (0.15, 0.17)     # ivy card, as the prototype's (0.16 x 0.2) arch ivy
VINE_R = 0.011


def leaf(bm, uv, rng, p, scale=1.0, flat=False):
    """One ivy card centred near p, roughly parallel to the wall (or lying flat)."""
    w, h = LEAF[0] * scale, LEAF[1] * scale
    if flat:
        add_card(bm, uv, (p[0], p[1] - h / 2, p[2]), w, h, rng.uniform(-0.6, 0.6), math.radians(-90))
    else:
        add_card(bm, uv, (p[0], p[1], p[2] - h / 2), w, h, rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5))


def clump(bm, uv, rng, centre, n, rx, rz, zmax=99.0):
    """A dense ivy clump: n cards in an ellipse rx x rz on the wall, 0-0.12 m out."""
    for _ in range(n):
        z = min(centre[2] + rng.uniform(-rz, rz * 0.8), zmax - LEAF[1] / 2)
        leaf(bm, uv, rng, (centre[0] + rng.uniform(-rx, rx), centre[1] + rng.uniform(0.0, 0.12), z))


def strand(bm, uv, rng, top, length, zmin=-99.0):
    """Leaves hanging from `top` in a slightly drifting line, down to `length`."""
    x, drift, z = top[0], rng.uniform(-0.05, 0.05), top[2]
    while z > max(top[2] - length, zmin):
        leaf(bm, uv, rng, (x + rng.uniform(-0.04, 0.04), top[1] + rng.uniform(-0.02, 0.04), z - 0.04), 0.9)
        x += drift * 0.1
        z -= rng.uniform(0.1, 0.13)


def clinging(bm_vine, bm_leaf, uv, rng, path, per_m=14, spread=0.14, zmax=99.0):
    """A vine tube along path (on the wall) with leaves along it, none above zmax."""
    from mathutils import Vector
    add_tube(bm_vine, path, VINE_R, 5)
    for a, b in zip(path, path[1:]):
        n = max(1, round((Vector(b) - Vector(a)).length * per_m))
        for j in range(n):
            t = (j + rng.random()) / n
            p = [a[i] + (b[i] - a[i]) * t for i in range(3)]
            leaf(bm_leaf, uv, rng, (p[0] + rng.uniform(-spread, spread), p[1] + rng.uniform(0.0, 0.08),
                                    min(p[2] + rng.uniform(-spread, spread * 0.8), zmax - LEAF[1] / 2)))


def arch_point(span, spring, k, off, t, side):
    """A point (x, z) on an arch_outline arch centred on x = 0, offset `off` out
    from the intrados: t = 0 at the springing, 1 at the crown; side -1 left, 1 right."""
    r = span * k
    cx = r - span / 2                 # the left arc's centre (right of centre if pointed)
    rr = r + off
    end = math.acos(max(-1.0, min(1.0, -cx / rr)))
    a = math.pi + t * (end - math.pi)
    x = cx + rr * math.cos(a)
    return (x if side < 0 else -x, spring + rr * math.sin(a))


def arch_growth(r, name, span, spring, k, heavy, face, zmax, strand_floor, seed):
    """Ivy over an arch: vines along the extrados, clumps near the apex and strands
    hanging into the opening. `face`: how far out the wall face (or frame) is.
    Nothing grows above zmax; strands stop at strand_floor."""
    rng = random.Random(seed)
    bv, bl = bmesh.new(), bmesh.new()
    uv = bl.loops.layers.uv.new("UVMap")
    y = face + 0.015
    s = span / 3.0                    # counts and reach scale with the arch
    sides = (-1, 1) if heavy else (rng.choice((-1, 1)),)
    for side in sides:
        t0 = 0.4                    # clear of the piers either side
        path = [arch_point(span, spring, k, 0.14, t0 + (1.0 - t0) * i / 10, side) for i in range(11)]
        if not heavy:                  # a light vine runs a little way past the crown
            path += [arch_point(span, spring, k, 0.14, 1.0 - 0.3 * i / 4, -side) for i in range(1, 5)]
        path = [(x, y, min(z, zmax - 0.03)) for (x, z) in path]
        clinging(bv, bl, uv, rng, path, 12 if heavy else 8, 0.1 * s ** 0.5, zmax)
    for side in (-1, 1):              # clumps along the head, densest at the crown
        n = round((10 if heavy else (3 if side in sides else 1)) * s)
        for i in range(n):
            t = 0.5 + 0.5 * (i + rng.random()) / n
            (x, z) = arch_point(span, spring, k, 0.2, t, side)
            clump(bl, uv, rng, (x, face, z), rng.randint(6, 9) if heavy else rng.randint(4, 6), 0.2 * s ** 0.5, 0.2, zmax)
    for side in (-1, 1):              # strands into the opening
        m = round((7 if heavy else 2) * s)
        for i in range(m):
            t = 0.5 + 0.47 * i / max(m - 1, 1) + rng.uniform(-0.03, 0.03) if heavy else rng.uniform(0.7, 0.97)
            (x, z) = arch_point(span, spring, k, 0.0, t, side)
            strand(bl, uv, rng, (x, face + 0.05, min(z, zmax) - 0.02),
                   rng.uniform(0.25, 1.1 if heavy else 0.6) * s ** 0.5, strand_floor)
    mesh_object(name + "__vine", bv, ["vine"], r)
    mesh_object(name + "__leaves", bl, ["ivy_leaf"], r, recalc=False)


# wall_arch_3m: 3 m opening, springs at 1.8 m, k 0.6. The lower-storey arches sit
# under a gallery slab (soffit 3.85 m), so nothing grows above 3.8 m; strands
# stop at 2.2 m, clear of a head in the doorway.
def growth_arch_3m_light(r):
    arch_growth(r, "growth_arch_3m_light", 3.0, 1.8, 0.6, False, 0.0, 3.8, 2.2, 61)


def growth_arch_3m_heavy(r):
    arch_growth(r, "growth_arch_3m_heavy", 3.0, 1.8, 0.6, True, 0.0, 3.8, 2.2, 67)


# The iwan arch: 6 m, springs at 4 m, k 0.58, in front of the 6 cm mosaic frame;
# the gable starts at 8 m.
def growth_arch_iwan_light(r):
    arch_growth(r, "growth_arch_iwan_light", 6.0, 4.0, 0.58, False, 0.07, 7.95, 4.3, 71)


def growth_arch_iwan_heavy(r):
    arch_growth(r, "growth_arch_iwan_heavy", 6.0, 4.0, 0.58, True, 0.07, 7.95, 4.3, 73)


def cornice_curtain(r, name, strands, lengths, seed):
    """Ivy curtain from the springing line (origin) down the wall face: a vine
    along the line, a clump on it and strands about 0.36 m apart."""
    rng = random.Random(seed)
    bv, bl = bmesh.new(), bmesh.new()
    uv = bl.loops.layers.uv.new("UVMap")
    half = 0.18 * strands
    clinging(bv, bl, uv, rng, [(-half, 0.02, -0.04), (0.0, 0.025, 0.02), (half, 0.02, -0.03)], 10, 0.1)
    clump(bl, uv, rng, (0.0, 0.0, -0.05), 6 + 2 * strands, half, 0.12)
    for i in range(strands):
        x = -half + 2 * half * (i + 0.5) / strands + rng.uniform(-0.06, 0.06)
        strand(bl, uv, rng, (x, 0.06, -0.05), rng.uniform(*lengths))
    mesh_object(name + "__vine", bv, ["vine"], r)
    mesh_object(name + "__leaves", bl, ["ivy_leaf"], r, recalc=False)


def growth_cornice_short(r):
    cornice_curtain(r, "growth_cornice_short", 3, (0.4, 1.1), 79)


def growth_cornice_long(r):
    cornice_curtain(r, "growth_cornice_long", 4, (0.9, 2.3), 83)


STAIR_PITCH = math.atan(STAIR_TOP / STAIR_RUN)   # the masonry handrail's slope


def parapet_strands(r, name, pitch, seed):
    """Strands from a crack in a stone coping (origin: coping top, centre line),
    over the hall-side edge and down the open face. On a stair the socket is
    pitched by -pitch about its Y axis; the strands are built level and turned
    back by `pitch`, so they hang plumb. The leaves in the crack lie on the coping."""
    from mathutils import Matrix
    rng = random.Random(seed)
    bl = bmesh.new()
    uv = bl.loops.layers.uv.new("UVMap")
    for _ in range(rng.randint(2, 4)):
        x = rng.uniform(-0.25, 0.25)
        leaf(bl, uv, rng, (x, 0.13, -0.02), 0.9)                     # over the edge
        strand(bl, uv, rng, (x, 0.2, -0.1), rng.uniform(0.4, 1.2) if pitch else rng.uniform(0.8, 2.4))
    m = Matrix.Rotation(pitch, 3, "Y")
    for v in bl.verts:
        v.co = m @ v.co
    for _ in range(4):
        leaf(bl, uv, rng, (rng.uniform(-0.2, 0.2), rng.uniform(-0.04, 0.06), 0.012), 0.9, flat=True)
    mesh_object(name + "__leaves", bl, ["ivy_leaf"], r, recalc=False)


def growth_parapet_strands(r):
    parapet_strands(r, "growth_parapet_strands", 0.0, 89)


def growth_parapet_stair(r):
    """For stair_gallery_8m (rises along +X): its socket is turned -STAIR_PITCH about Y."""
    parapet_strands(r, "growth_parapet_stair", STAIR_PITCH, 97)


def growth_parapet_stair_r(r):
    """For stair_gallery_8m_r (falls along +X): its socket is turned +STAIR_PITCH about Y."""
    parapet_strands(r, "growth_parapet_stair_r", -STAIR_PITCH, 101)


MODULES = [
    ("M_recess_shelves", props("wood,storage,recess"), recess_shelves),
    ("M_recess_shelves_broken", dict(props("wood,storage,recess,ruin"), kit_rev=5), recess_shelves_broken),
    ("M_recess_tile_panel", props("tile,recess"), recess_tile_panel),
    ("M_recess_sealed_door", props("brick,wood,recess,door"), recess_sealed_door),
    ("M_iwan_lectern", props("wood,iwan,centrepiece"), iwan_lectern),
    ("M_iwan_tree", props("tree,iwan,centrepiece"), iwan_tree),
    ("M_iwan_fountain", props("stone,water,iwan,centrepiece"), iwan_fountain),
    ("M_debris_rubble", props("stone,debris,seam"), debris_rubble),
    ("M_debris_brick", props("brick,debris,seam"), debris_brick),
    ("M_plant_crack_tuft", props("plant,moss,seam"), plant_crack_tuft),
    ("M_plant_moss_cushion", props("plant,moss,seam"), plant_moss_cushion),
    ("M_plant_fern", props("plant,seam"), plant_fern),
    ("M_plant_ivy_hang", props("plant,ivy,rail"), plant_ivy_hang),
    ("M_prop_book_stack", props("books,table_prop"), prop_book_stack),
    ("M_prop_book_open", props("books,table_prop"), prop_book_open),
    ("M_prop_pot", props("earthenware,table_prop"), prop_pot),
    ("M_prop_oil_lamp", props("brass,light,table_prop"), prop_oil_lamp),
    ("M_prop_scroll", props("linen,table_prop"), prop_scroll),
    ("M_prop_inkwell", props("iron,table_prop"), prop_inkwell),
    # Phase 3 slice 1: a breakable floor vase (WorldProp) and its shards.
    ("M_prop_vase_floor", props("earthenware,floor_prop,breakable"), prop_vase_floor),
    ("M_prop_vase_floor_broken", props("earthenware,shards"), prop_vase_floor_broken),
    ("M_stair_steps_masonry", dict(props("stone,stair"), kit_rev=6), stair_steps_masonry),
    ("M_stair_steps_open", dict(props("wood,stair"), kit_rev=3), stair_steps_open),
    ("M_stair_steps_masonry_r", dict(props("stone,stair"), kit_rev=6), stair_steps_masonry_r),
    ("M_stair_steps_open_r", dict(props("wood,stair"), kit_rev=3), stair_steps_open_r),
    # Polish 1c: gallery looks and column supports.
    ("M_gallery_wood_slab", props("wood,gallery"), gallery_wood_slab),
    ("M_gallery_masonry_slab", props("stone,brick,gallery"), gallery_masonry_slab),
    ("M_gallery_wood_open_end", props("wood,gallery"), gallery_wood_open_end),
    ("M_gallery_masonry_open_end", props("stone,brick,gallery"), gallery_masonry_open_end),
    ("M_gallery_wood_open_start", props("wood,gallery"), gallery_wood_open_start),
    ("M_gallery_masonry_open_start", props("stone,brick,gallery"), gallery_masonry_open_start),
    ("M_gallery_wood_end", props("wood,gallery"), gallery_wood_end),
    ("M_gallery_masonry_end", props("stone,brick,gallery"), gallery_masonry_end),
    ("M_gallery_column", dict(props("stone,brick,gallery,structure"), kit_rev=2), gallery_column),
    ("M_gallery_column_corner", dict(props("stone,brick,gallery,structure"), kit_rev=2), gallery_column_corner),
    # Polish B item 5: growth over arches, from the vault springing and on stone copings.
    ("M_growth_arch_3m_light", props("plant,ivy,arch"), growth_arch_3m_light),
    ("M_growth_arch_3m_heavy", props("plant,ivy,arch"), growth_arch_3m_heavy),
    ("M_growth_arch_iwan_light", props("plant,ivy,arch"), growth_arch_iwan_light),
    ("M_growth_arch_iwan_heavy", props("plant,ivy,arch"), growth_arch_iwan_heavy),
    ("M_growth_cornice_short", props("plant,ivy,cornice"), growth_cornice_short),
    ("M_growth_cornice_long", props("plant,ivy,cornice"), growth_cornice_long),
    ("M_growth_parapet_strands", props("plant,ivy,parapet"), growth_parapet_strands),
    ("M_growth_parapet_stair", props("plant,ivy,parapet"), growth_parapet_stair),
    ("M_growth_parapet_stair_r", props("plant,ivy,parapet"), growth_parapet_stair_r),
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
    REBUILD = [("M_recess_shelves_broken", 5),   # rev 3: floor boards split out as __spill; rev 5: roots (polish B)
               ("M_stair_steps_masonry", 6), ("M_stair_steps_open", 3),   # rev 2: railings, fill, claims (polish A)
               ("M_stair_steps_masonry_r", 6), ("M_stair_steps_open_r", 3),   # 1b balustrade, 1c head claim; rev 6/3: claims start off the wall line
               ("M_gallery_column", 2), ("M_gallery_column_corner", 2)]   # rev 2: slimmer plinth; the corner keeps one arch
    added += ["%s (rebuilt rev %d)" % (n, v) for (n, v) in REBUILD if rebuild(n, v, MODULES)]
    if not added:
        print("kit_add_dressing: all modules already present; nothing to do.")
        return
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("kit_add_dressing: added %s" % ", ".join(added))


main()
