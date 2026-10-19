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
  stair_gallery_8m_r the stair mirrored: rises toward its origin (step 2b).
  gallery_slab_4m_open_end / _open_start
                     gallery slab whose rail stops 1.6 m short of the X=4 / X=0
                     end, for the corner where an end-wall gallery joins.
  gallery_end_12m    gallery along a 12 m end wall between the side lanes,
                     newel posts at both corners, wall corbels clear of a
                     central 3 m arch.
"""
import math
import os
import sys

import bmesh
from mathutils import Vector
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit_blender import (H, T, add_box, add_plan_prism, add_prism, arch_outline, rebuild,  # noqa: E402
                         arch_ring, cut, marker, mesh_object, module)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(ROOT, "art_src", "kit", "kit_walls.blend")
ROW_Y = -24.0
HALL = 12.0      # hall width: three bays
HALL_K = 0.58    # vault pointedness (atlas R01)
LAMP_SOCKET = {"socket_set": "lamp_state", "socket_mode": "state"}


def seam_socket(length):
    """Wall-base debris seam (weathering item 1): starts 0.85 m in so items (up to
    ~0.3 m across) stay clear of
    the corner piers; on the wall face; items settle or vanish if nothing is below."""
    return {"socket_set": "seam_debris", "socket_mode": "edge_scatter", "scatter_count": [2, 5],
            "scatter_spacing": 0.45, "edge_length": length, "edge_depth": 0.25, "settle": 1, "settle_max_drop": 0.3}


def wall_decals(extent, spacing):
    """Stains on a wall face (weathering item 3): 0-2 unspun decals around the
    marker; extent is [half along the wall, half up the wall]."""
    return {"socket_set": "wall_stains", "socket_mode": "scatter", "scatter_count": [0, 2],
            "scatter_extent": extent, "scatter_spacing": spacing, "scatter_spin": 0}


FLOOR_DECALS = {"socket_set": "floor_wear", "socket_mode": "scatter", "scatter_count": [0, 2],
                "scatter_extent": [0.7, 0.7], "scatter_spacing": 1.2}
SOOT = {"socket_set": "lamp_soot"}
WALL_TURN = (-math.pi / 2, 0.0, 0.0)
UP_TURN = (math.pi, 0.0, 0.0)


TABLE_SOCKET = {"socket_set": "table_props", "socket_mode": "scatter", "scatter_count": [2, 5],
                "scatter_extent": [0.5, 1.9], "scatter_spacing": 0.35}


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
    # Back wall: a recess_library socket; its candidates bring their own boards.
    sy = -depth + 0.25
    marker("SOCKET_recess_fill__iwan", r, (6.0, sy, 0.0), {"socket_set": "recess_library"})
    marker("ANCHOR_study__iwan", r, (6.0, -1.2, 0.0))
    marker("SOCKET_iwan_centre__iwan", r, (6.0, -1.2, 0.0), {"socket_set": "iwan_centre"})
    marker("SOCKET_seam_debris__iwan_l", r, (0.85, T, 0.0), seam_socket(1.3))
    marker("SOCKET_seam_debris__iwan_r", r, (HALL - 2.15, T, 0.0), seam_socket(1.2))


STAIR = (20, 8.0, H + 0.15, T, 1.6)   # steps, run, top, wall-side y, open-side y
STAIR_SOCKET = (4.0, (T + 1.6) / 2, 0.0)   # footprint middle, where stair_steps_* have their origin
SLAB = 0.3                                 # ramp slab depth, measured vertically


def stair(r, name="stair_gallery_8m", reverse=False):
    """reverse=True mirrors along X: the stair rises toward its origin, so on a
    wall it climbs the other way from the plain one (same footprint).
    The look is a stair_style socket (stair_style_r on the reversed stair:
    masonry or open wood, each with its own railing). The module keeps what
    every look shares, so routes never depend on the pick: a walkable ramp
    slab (open underneath; the masonry look fills it), an invisible rail strip
    on the open edge and the foot / head snaps. Polish slice A (rev 2)."""
    marker("SOCKET_stair_style__" + name, r, STAIR_SOCKET,
           {"socket_set": "stair_style_r" if reverse else "stair_style"})
    steps, run, top, y0, y1 = STAIR
    rise, tread = top / steps, run / steps
    slope = rise / tread
    # Walkable ramp slab through the middle of the treads (collision only).
    bm = bmesh.new()
    add_prism(bm, [(-tread / 2, 0.0), (run - tread / 2, top), (run, top), (run, top - SLAB),
                   (run - tread / 2, top - SLAB), (-tread / 2 + SLAB / slope, 0.0)], 0.0, 0.0, y0, y1)
    mesh_object(name + "__ramp-colonly", flip(bm, run, reverse), ["arch_stone"], r)
    # Rail strip on the open edge, from the slab up to handrail height (the
    # visible railing comes with the look).
    bm = bmesh.new()
    add_prism(bm, [(0.0, 0.0), (run - tread / 2, top), (run, top), (run, top + 0.94), (0.0, rise + 0.94)],
              0.0, 0.0, y1 - 0.12, y1 - 0.02)
    mesh_object(name + "__rail-colonly", flip(bm, run, reverse), ["wood"], r)
    foot, head = (run, 0.0) if reverse else (0.0, run)
    marker("SNAP_stair_foot__" + name, r, (foot, (y0 + y1) / 2, 0.0), {"snap_kind": "stair_foot"})
    marker("SNAP_stair_head__" + name, r, (head, (y0 + y1) / 2, top), {"snap_kind": "stair_head"})


def flip(bm, run, on):
    """Mirror a bmesh along X about run / 2 (normals are recalculated later)."""
    if on:
        for v in bm.verts:
            v.co.x = run - v.co.x
    return bm


def stair_reversed(r):
    stair(r, "stair_gallery_8m_r", reverse=True)


GAL_Y0, GAL_Y1 = T, 1.6          # gallery lane, as gallery_slab_4m
RAIL_Y0, RAIL_Y1 = 1.46, 1.56    # handrail band along the hall side


def balustrade(bm, x0, x1):
    """Balusters every 0.5 m and a top rail between x0 and x1 (as gallery_slab_4m)."""
    x = x0 + 0.05
    while x < x1 - 0.02:
        add_box(bm, x, x + 0.06, 1.48, 1.54, H + 0.15, H + 0.95)
        x += 0.5
    add_box(bm, x0, x1, RAIL_Y0, RAIL_Y1, H + 0.92, H + 1.0)


def newel(bm, x):
    """Corner post that swallows the meeting rail ends (no coplanar faces)."""
    add_box(bm, x - 0.06, x + 0.06, 1.45, 1.57, H + 0.15, H + 1.06)


def gallery_open(r, name, rail_x0, rail_x1):
    """gallery_slab_4m with its rail stopped 1.6 m short of one end, so the
    corner square under it opens onto an end-wall gallery."""
    bm = bmesh.new()
    add_box(bm, 0, 4, GAL_Y0, GAL_Y1, H - 0.15, H + 0.15)
    mesh_object(name + "__slab-colonly", bm, ["wood"], r)
    bm = bmesh.new()
    balustrade(bm, rail_x0, rail_x1)
    mesh_object(name + "__rail-colonly", bm, ["wood"], r)
    marker("ANCHOR_lookout__" + name, r, (2.0, 1.0, H + 0.15))


def gallery_open_end(r):
    gallery_open(r, "gallery_slab_4m_open_end", 0.0, 4.0 - GAL_Y1 + 0.04)


def gallery_open_start(r):
    gallery_open(r, "gallery_slab_4m_open_start", GAL_Y1 - 0.04, 4.0)


def gallery_end(r):
    """Gallery along a 12 m end wall, between the two side-gallery lanes. Pair
    it with gallery_slab_4m_open_end / _open_start at the corners."""
    x0, x1 = GAL_Y1, HALL - GAL_Y1
    bm = bmesh.new()
    add_box(bm, x0, x1, GAL_Y0, GAL_Y1, H - 0.15, H + 0.15)
    mesh_object("gallery_end_12m__slab-colonly", bm, ["wood"], r)
    bm = bmesh.new()
    balustrade(bm, x0 - 0.04, x1 + 0.04)
    newel(bm, x0 - 0.09)
    newel(bm, x1 + 0.09)
    mesh_object("gallery_end_12m__rail-colonly", bm, ["wood"], r)
    # Wall corbels under the slab, clear of a central 3 m arch (x 4.5-7.5).
    bm = bmesh.new()
    for x in (2.4, 3.9, 7.9, 9.4):
        add_box(bm, x - 0.15, x + 0.15, GAL_Y0, GAL_Y0 + 0.25, H - 0.55, H - 0.15)
        add_box(bm, x - 0.15, x + 0.15, GAL_Y0 + 0.25, GAL_Y0 + 0.45, H - 0.35, H - 0.15)
    mesh_object("gallery_end_12m__corbels", bm, ["arch_stone"], r)
    marker("ANCHOR_lookout__gallery_end", r, (HALL / 2, 1.0, H + 0.15))


COL_Y = 1.4    # gallery column centre line, from the wall line (polish 1c)


def gallery_column(r):
    """Column point under a gallery's open edge (polish 1c). The origin is on the
    wall line (on the grid, like a pier); the socket stands at the column centre,
    COL_Y into the room. Nothing visible of its own: the gallery_support socket
    brings the column and its arch to the wall when the gallery is masonry, and
    nothing when it is wood. The socket is an ADD_MARKERS entry (kept in sync)."""


def gallery_column_corner(r):
    """As post_gallery_column at the inner corner of an L of galleries: the origin
    is the corner of the two wall lines, the column (COL_Y, COL_Y) from it, with
    arches to both walls (-Y and -X)."""


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
    marker("SOCKET_table_props__table", r, (0.0, 0.0, 0.78), TABLE_SOCKET)


def lantern(bm, glass, cx, cy, z0, half, height):
    """Brass lantern frame (into bm) around a glowing body (into glass). The glass
    is its own mesh so it casts no shadow: a shadowed light inside it would be
    boxed in (step 4: the chandelier lit nothing)."""
    p = half * 0.8
    for (sx, sy) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        add_box(bm, cx + sx * p - 0.02, cx + sx * p + 0.02, cy + sy * p - 0.02, cy + sy * p + 0.02, z0, z0 + height)
    # Open ring caps: solid caps under a shadowed light threw a ~10 m shadow disc.
    w = 0.05
    for (za, zb) in ((z0 - 0.05, z0 + 0.01), (z0 + height - 0.01, z0 + height + 0.05)):
        add_box(bm, cx - half, cx + half, cy - half, cy - half + w, za, zb)
        add_box(bm, cx - half, cx + half, cy + half - w, cy + half, za, zb)
        add_box(bm, cx - half, cx - half + w, cy - half + w, cy + half - w, za, zb)
        add_box(bm, cx + half - w, cx + half, cy - half + w, cy + half - w, za, zb)
    add_box(glass, cx - half * 0.55, cx + half * 0.55, cy - half * 0.55, cy + half * 0.55, z0 + 0.05, z0 + height - 0.05)


def lantern_cluster(r):
    crown = 14.6     # intrados crown of vault_hall_12m placed one storey up
    bm = bmesh.new()
    glass = bmesh.new()
    lantern(bm, glass, 0.0, 0.0, 5.5, 0.26, 0.65)
    add_box(bm, -0.025, 0.025, -0.025, 0.025, 6.2, 6.4)
    for k in range(4):
        a = k * math.pi / 2
        cx, cy = math.cos(a) * 0.6, math.sin(a) * 0.6
        lantern(bm, glass, cx, cy, 5.25, 0.1, 0.3)
        add_box(bm, cx - 0.01, cx + 0.01, cy - 0.01, cy + 0.01, 5.6, 6.35)
        add_box(bm, min(0.0, cx) - 0.02, max(0.0, cx) + 0.02, min(0.0, cy) - 0.02, max(0.0, cy) + 0.02, 6.33, 6.38)
    mesh_object("lantern_cluster__body", bm, ["brass"], r)
    mesh_object("lantern_cluster__glass", glass, ["emit_lantern"], r)
    bm = bmesh.new()
    add_box(bm, -0.02, 0.02, -0.02, 0.02, 6.38, crown + 0.2)
    mesh_object("lantern_cluster__chain", bm, ["iron"], r)
    marker("LIGHT_chandelier__cluster", r, (0.0, 0.0, 5.8))
    marker("SOCKET_lamp_state__cluster", r, (0.0, 0.0, 5.8), LAMP_SOCKET)


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
    ("M_stair_gallery_8m", dict(props("edge", [2, 1, 0], "stair", "stone,vertical"), kit_rev=2), stair),
    ("M_post_pier_corbel", props("post", [0, 1, 0], "", "stone,structure,gallery"), pier_corbel),
    ("M_table_reading", props("free", [0, 1, 0], "", "wood,furniture"), table),
    ("M_lantern_cluster", dict(props("free", [0, 4, 0], "", "brass,light,hall_12m"), kit_rev=2), lantern_cluster),
    ("M_rug_runner", props("free", [0, 0, 0], "", "cloth,floor"), rug_runner),
    # Step 2b: one continuous gallery (side runs + end-wall run, stairs both ways).
    ("M_stair_gallery_8m_r", dict(props("edge", [2, 1, 0], "stair", "stone,vertical"), kit_rev=2), stair_reversed),
    ("M_gallery_slab_4m_open_end", props("edge", [1, 1, 0], "gallery", "wood,vertical,gallery_corner"), gallery_open_end),
    ("M_gallery_slab_4m_open_start", props("edge", [1, 1, 0], "gallery", "wood,vertical,gallery_corner"), gallery_open_start),
    ("M_gallery_end_12m", props("edge", [3, 1, 0], "gallery_end", "wood,vertical,hall_12m"), gallery_end),
    # Polish 1c: column points for the masonry gallery's arcade.
    ("M_post_gallery_column", props("free", [0, 1, 0], "", "stone,gallery"), gallery_column),
    ("M_post_gallery_column_corner", props("free", [0, 1, 0], "", "stone,gallery"), gallery_column_corner),
]

# Polish 1c: the gallery's visible slab and rail come from its gallery_style
# look, so the modules keep them as collision only (renamed in place: hand edits
# to the shapes survive).
GALLERIES = ["gallery_slab_4m", "gallery_slab_4m_open_end", "gallery_slab_4m_open_start", "gallery_end_12m"]
RENAME = [("%s__%s-col" % (g, part), "%s__%s-colonly" % (g, part)) for g in GALLERIES for part in ("slab", "rail")]
# Root properties kept in sync with MODULES (the column points were first made as "post").
SYNC_PROPS = [(n, {"kit_shape": p["kit_shape"], "tags": p["tags"]}) for (n, p, _b) in MODULES if n.startswith("M_post_gallery_column")]


# Step 3 upgrades for modules that already exist in a hand-edited .blend
# (fresh builds above already match). Each is idempotent.
REMOVE = ["wall_shelfbay_4m__shelves", "wall_iwan_12m__shelves",   # boards now come from recess candidates
          "stair_gallery_8m__steps", "stair_gallery_8m_r__steps"]   # steps are a stair_style socket (item 4)
# Whole modules to delete with their children (item 4: the open stair is a
# stair_style candidate now, not a module of its own).
REMOVE_MODULES = ["M_stair_gallery_8m_open", "M_stair_gallery_8m_open_r"]
# Script-owned markers to delete (module, marker name prefix). Polish B item 4:
# no vines on the gallery rails (the rail_growth set stays for reuse).
REMOVE_MARKERS = [("M_" + g, "SOCKET_rail_growth__") for g in GALLERIES]
ADD_MARKERS = [
    ("M_wall_iwan_12m", "SOCKET_iwan_centre__iwan", (6.0, -1.2, 0.0), {"socket_set": "iwan_centre"}),
    ("M_table_reading", "SOCKET_table_props__table", (0.0, 0.0, 0.78), TABLE_SOCKET),
    ("M_lantern_hanging", "SOCKET_lamp_state__hanging", (0.0, 0.0, 2.8), LAMP_SOCKET),
    ("M_lantern_cluster", "SOCKET_lamp_state__cluster", (0.0, 0.0, 5.8), LAMP_SOCKET),
    ("M_wall_plain_4m", "SOCKET_seam_debris__plain", (0.85, T, 0.0), seam_socket(2.3)),
    ("M_wall_iwan_12m", "SOCKET_seam_debris__iwan_l", (0.85, T, 0.0), seam_socket(1.3)),
    ("M_wall_iwan_12m", "SOCKET_seam_debris__iwan_r", (HALL - 2.15, T, 0.0), seam_socket(1.2)),
    # Weathering item 3 (decals). Wall sockets are turned -90 deg about X so the
    # socket's Godot Y comes out of the wall and Z points up; soot sockets half a
    # turn so Y points down and the decal projects up onto what is overhead.
    ("M_wall_plain_4m", "SOCKET_wall_stains__plain", (2.0, T, 2.0), wall_decals([0.75, 0.45], 1.0), WALL_TURN),
    ("M_wall_gable_12m", "SOCKET_wall_stains__gable", (HALL / 2, T, H + 3.4), wall_decals([2.2, 0.6], 1.4), WALL_TURN),
    ("M_floor_4m", "SOCKET_floor_wear__cell", (2.0, 2.0, 0.0), FLOOR_DECALS),
    ("M_lantern_hanging", "SOCKET_lamp_soot__hanging", (0.0, 0.0, H), SOOT, UP_TURN),   # chain top, in the slab
    ("M_lantern_cluster", "SOCKET_lamp_soot__cluster", (0.0, 0.0, 14.6), SOOT, UP_TURN),      # vault crown
    # Item 4: stair looks.
    ("M_stair_gallery_8m", "SOCKET_stair_style__stair_gallery_8m", STAIR_SOCKET, {"socket_set": "stair_style"}),
    ("M_stair_gallery_8m_r", "SOCKET_stair_style__stair_gallery_8m_r", STAIR_SOCKET, {"socket_set": "stair_style_r"}),
    # Polish 1c: gallery looks, at the module origin (the candidates share its space).
    ("M_gallery_slab_4m", "SOCKET_gallery_style__slab", (0.0, 0.0, 0.0), {"socket_set": "gallery_style_slab"}),
    ("M_gallery_slab_4m_open_end", "SOCKET_gallery_style__open_end", (0.0, 0.0, 0.0), {"socket_set": "gallery_style_open_end"}),
    ("M_gallery_slab_4m_open_start", "SOCKET_gallery_style__open_start", (0.0, 0.0, 0.0),
     {"socket_set": "gallery_style_open_start"}),
    ("M_gallery_end_12m", "SOCKET_gallery_style__end", (0.0, 0.0, 0.0), {"socket_set": "gallery_style_end"}),
    ("M_post_gallery_column", "SOCKET_gallery_support__column", (0.0, COL_Y, 0.0), {"socket_set": "gallery_support"}),
    ("M_post_gallery_column_corner", "SOCKET_gallery_support__corner", (COL_Y, COL_Y, 0.0),
     {"socket_set": "gallery_support_corner"}),
]


# Generated modules whose layout changed: rebuilt in place (same location and
# custom properties) when the root's "kit_rev" is below the listed rev. Only for modules that
# are still script-made; a hand-edited one would lose its edits, so list
# nothing here that you have changed in Blender.
REBUILD = [("M_lantern_cluster", 2),   # rev 2 (step 4): glass split from the frame, open ring caps
           ("M_stair_gallery_8m", 2), ("M_stair_gallery_8m_r", 2)]   # rev 2 (polish A): slab ramp, rail strip, railing in the look



def upgrade():
    done = ["rebuilt %s (rev %d)" % (n, v) for (n, v) in REBUILD if rebuild(n, v, MODULES)]
    for (mod, p) in SYNC_PROPS:
        root = bpy.data.objects.get(mod)
        stale = {k: v for (k, v) in p.items() if root is not None and root.get(k) != v}
        for (k, v) in stale.items():
            root[k] = v
        if stale:
            done.append("%s: synced %s" % (mod, ", ".join(stale)))
    for (old, new) in RENAME:
        ob = bpy.data.objects.get(old)
        if ob is not None and bpy.data.objects.get(new) is None:
            ob.name = new
            done.append("renamed %s -> %s" % (old, new))
    for name in REMOVE:
        ob = bpy.data.objects.get(name)
        if ob is not None:
            bpy.data.objects.remove(ob, do_unlink=True)
            done.append("removed " + name)
    for name in REMOVE_MODULES:
        ob = bpy.data.objects.get(name)
        if ob is not None:
            for child in ob.children_recursive:
                bpy.data.objects.remove(child, do_unlink=True)
            bpy.data.objects.remove(ob, do_unlink=True)
            done.append("removed module " + name)
    for (mod, prefix) in REMOVE_MARKERS:
        root = bpy.data.objects.get(mod)
        for child in ([c for c in root.children if c.name.startswith(prefix)] if root is not None else []):
            done.append("%s -= %s" % (mod, child.name))
            bpy.data.objects.remove(child, do_unlink=True)
    # Script-owned markers: added when missing, and kept in sync (position and
    # custom properties, rotation) so tuning a socket here reaches an existing .blend.
    # Entries are (module, marker, location, properties[, rotation]).
    for entry in ADD_MARKERS:
        (mod, name, loc, p) = entry[:4]
        rot = Vector(entry[4] if len(entry) > 4 else (0.0, 0.0, 0.0))
        root = bpy.data.objects.get(mod)
        if root is None:
            continue
        existing = [c for c in root.children if c.name.startswith(name)]
        if not existing:
            marker(name, root, loc, p).rotation_euler = rot
            done.append("%s += %s" % (mod, name))
            continue
        e = existing[0]
        stale = (e.location - Vector(loc)).length > 1e-4 or (Vector(e.rotation_euler) - rot).length > 1e-4 or any(
            k not in e.keys() or (list(e[k]) if hasattr(e[k], "__len__") and not isinstance(e[k], str) else e[k]) != v
            for (k, v) in p.items())
        if stale:
            e.location = loc
            e.rotation_euler = rot
            for (k, v) in p.items():
                e[k] = v
            done.append("%s: synced %s" % (mod, name))
    return done


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
    changes = ["added " + n for n in added] + upgrade()
    if not changes:
        print("kit_add_r01: everything already present; nothing to do.")
        return
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("kit_add_r01: " + "; ".join(changes))


main()
