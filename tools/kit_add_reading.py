"""Adds the Reading Room's furniture and carpets to art_src/kit/kit_dressing.blend
(room rework, step 1: your walk of 2026-11-02 asked for furniture that says
"reading" and keeps the doorways clear, lamps on the furniture in place of the
lower hanging lanterns, and carpets that change with the seed).

  blender --background --factory-startup --python tools/kit_add_reading.py

Additive like kit_add_dressing.py: adds only modules that are not in the file
yet and never touches existing ones, so it is safe to re-run after hand edits.
Then run tools/export_kit.bat kit_dressing.blend.

Furniture (family "dressing", origin on the floor; the front of a seat faces +Y,
which is Godot -Z):
  reading_table     1.5 x 0.8 m table, long side along X; a lamp at the -X end,
                    a table_props_small scatter on the +X half.
  reading_chair     wooden chair with a slatted back.
  reading_armchair  low upholstered armchair (wool cushions on a wooden frame).
  side_table        octagonal side table on a turned post, top at 0.62 m, a lamp on it.
  table_lamp        the lamp by itself (a brass oil lamp with a glass chimney and
                    a "desk" light), for a floor or a ledge on the grid.
  low_table         low carved table (0.36 m) for floor seating; a lamp, table_props_small.
The lamps are part of the tables: free kit pieces sit on the 0.5 m grid at
0.5 m heights, so a lamp can't stand on a table top as a piece of its own.
  floor_cushion     a square striped cushion.
Carpets: rug_<design>_<shape>, one pixel map per design and size
(tools/pixel_materials_ext.gd -- rugs). Shapes, long side along Y:
  runner  three 4.375 x 3.19 m rugs end to end (as rug_runner)
  grand   one 6 x 3.5 m rug (fits between the reading tables' chairs)
  small   one 2.5 x 1.75 m rug
"""
import math
import os
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit_blender import add_box, add_lathe, add_ngon_prism, add_obox, marker, mesh_object, module, rebuild  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(ROOT, "art_src", "kit", "kit_dressing.blend")
ROW_Y = 40.0     # laid out past kit_add_dressing.py's rows
DESIGNS = ("kilim", "herati", "medallion", "gabbeh", "garden")
RUG_PX = {"runner": (140, 102), "grand": (192, 112), "small": (80, 56)}     # (long, short) texels at 32 px/m


def props(tags, size=(0, 0, 0)):
    return {"kit_shape": "free", "kit_family": "dressing", "size_cells": list(size),
            "edge": "", "tags": tags, "weight": 1.0}


def table_socket(extent, count=(1, 3)):
    return {"socket_set": "table_props_small", "socket_mode": "scatter", "scatter_count": list(count),
            "scatter_extent": list(extent), "scatter_spacing": 0.3}


# --- furniture ----------------------------------------------------------------

def lamp_into(r, prefix, x, y, z):
    """A brass oil lamp with a glass chimney standing at (x, y, z), with its
    "desk" light. Part of the table it stands on: a free kit piece sits on the
    0.5 m grid, so a lamp can't be placed on a table top by itself."""
    bm = bmesh.new()
    add_lathe(bm, [(0.0, z), (0.075, z), (0.08, z + 0.015), (0.03, z + 0.04), (0.025, z + 0.09), (0.06, z + 0.11),
                   (0.065, z + 0.13), (0.0, z + 0.13)], cx=x, cy=y, segs=10)
    add_lathe(bm, [(0.05, z + 0.3), (0.055, z + 0.31), (0.03, z + 0.33), (0.0, z + 0.34)], cx=x, cy=y, segs=10)   # chimney cap
    for k in range(3):
        a = k * 2 * math.pi / 3
        add_box(bm, x + math.cos(a) * 0.05 - 0.006, x + math.cos(a) * 0.05 + 0.006,
                y + math.sin(a) * 0.05 - 0.006, y + math.sin(a) * 0.05 + 0.006, z + 0.13, z + 0.3)   # gallery rods
    mesh_object(prefix + "__lamp", bm, ["brass"], r)
    bm = bmesh.new()
    add_lathe(bm, [(0.0, z + 0.135), (0.035, z + 0.15), (0.042, z + 0.2), (0.03, z + 0.27), (0.024, z + 0.3), (0.0, z + 0.3)],
              cx=x, cy=y, segs=10)
    mesh_object(prefix + "__glass", bm, ["emit_lantern"], r)
    marker("LIGHT_desk__" + prefix, r, (x, y, z + 0.22))


def reading_table(r):
    bm = bmesh.new()
    add_box(bm, -0.75, 0.75, -0.4, 0.4, 0.74, 0.78)                  # top
    add_box(bm, -0.66, 0.66, -0.33, 0.33, 0.64, 0.74)                # apron
    for sx in (-1, 1):
        for sy in (-1, 1):
            add_box(bm, sx * 0.64 - 0.04, sx * 0.64 + 0.04, sy * 0.31 - 0.04, sy * 0.31 + 0.04, 0.0, 0.64)
        add_box(bm, sx * 0.64 - 0.025, sx * 0.64 + 0.025, -0.3, 0.3, 0.1, 0.16)
    add_box(bm, -0.62, 0.62, -0.025, 0.025, 0.1, 0.16)               # stretcher
    mesh_object("reading_table__body-col", bm, ["wood"], r)
    for sy in (-1, 1):
        marker("ANCHOR_seat__t%d" % (sy + 1), r, (0.0, sy * 0.75, 0.0))
    marker("SOCKET_table_props__table", r, (0.22, 0.0, 0.78), table_socket((0.36, 0.22)))
    lamp_into(r, "reading_table", -0.5, 0.12, 0.78)


def reading_chair(r):
    bm = bmesh.new()
    add_box(bm, -0.22, 0.22, -0.21, 0.21, 0.42, 0.46)                # seat
    for sx in (-1, 1):
        add_box(bm, sx * 0.19 - 0.025, sx * 0.19 + 0.025, 0.16, 0.21, 0.0, 0.42)        # front legs
        add_box(bm, sx * 0.19 - 0.025, sx * 0.19 + 0.025, -0.21, -0.16, 0.0, 0.98)      # back posts
        add_box(bm, sx * 0.19 - 0.015, sx * 0.19 + 0.015, -0.18, 0.18, 0.12, 0.16)      # side stretchers
    for z in (0.62, 0.76, 0.9):
        add_box(bm, -0.17, 0.17, -0.2, -0.17, z, z + 0.06)           # back slats
    mesh_object("reading_chair__body", bm, ["wood"], r)
    bm = bmesh.new()
    add_box(bm, -0.22, 0.22, -0.21, 0.21, 0.0, 0.46)
    mesh_object("reading_chair__col-colonly", bm, ["wood"], r)


def reading_armchair(r):
    bm = bmesh.new()
    add_box(bm, -0.38, 0.38, -0.36, 0.36, 0.08, 0.2)                 # base
    for sx in (-1, 1):
        for sy in (-1, 1):
            add_box(bm, sx * 0.34 - 0.04, sx * 0.34 + 0.04, sy * 0.32 - 0.04, sy * 0.32 + 0.04, 0.0, 0.08)
        add_box(bm, sx * 0.38 - 0.08, sx * 0.38, -0.36, 0.32, 0.2, 0.58)               # arm sides
        add_box(bm, sx * 0.38 - 0.09, sx * 0.38 + 0.01, -0.37, 0.34, 0.58, 0.62)       # arm rests
    add_box(bm, -0.38, 0.38, -0.36, -0.28, 0.2, 0.9)                 # back frame
    mesh_object("reading_armchair__frame", bm, ["wood"], r)
    bm = bmesh.new()
    add_box(bm, -0.3, 0.3, -0.28, 0.34, 0.2, 0.36)                   # seat cushion
    add_obox(bm, (0.0, -0.21, 0.6), (0.58, 0.12, 0.5), (math.radians(-10), 0.0, 0.0))  # back cushion
    mesh_object("reading_armchair__cushions", bm, ["cloth"], r)
    bm = bmesh.new()
    add_box(bm, -0.38, 0.38, -0.36, 0.34, 0.0, 0.6)
    mesh_object("reading_armchair__col-colonly", bm, ["wood"], r)


def side_table(r):
    bm = bmesh.new()
    add_ngon_prism(bm, 8, 0.3, 0.58, 0.62)
    add_ngon_prism(bm, 8, 0.26, 0.55, 0.58)
    add_lathe(bm, [(0.2, 0.0), (0.2, 0.04), (0.08, 0.07), (0.04, 0.12), (0.05, 0.3), (0.035, 0.48), (0.07, 0.55), (0.0, 0.55)], segs=8)
    mesh_object("side_table__body", bm, ["wood"], r)
    bm = bmesh.new()
    add_box(bm, -0.24, 0.24, -0.24, 0.24, 0.0, 0.62)
    mesh_object("side_table__col-colonly", bm, ["wood"], r)
    lamp_into(r, "side_table", 0.0, 0.0, 0.62)


def table_lamp(r):
    lamp_into(r, "table_lamp", 0.0, 0.0, 0.0)


def low_table(r):
    bm = bmesh.new()
    add_box(bm, -0.5, 0.5, -0.35, 0.35, 0.32, 0.36)                  # top
    add_box(bm, -0.44, 0.44, -0.29, 0.29, 0.22, 0.32)                # carved apron
    for sx in (-1, 1):
        for sy in (-1, 1):
            add_box(bm, sx * 0.42 - 0.05, sx * 0.42 + 0.05, sy * 0.27 - 0.05, sy * 0.27 + 0.05, 0.0, 0.22)
    mesh_object("low_table__body-col", bm, ["wood"], r)
    marker("SOCKET_table_props__table", r, (0.12, 0.0, 0.36), table_socket((0.24, 0.2), (1, 2)))
    lamp_into(r, "low_table", -0.36, 0.0, 0.36)


def floor_cushion(r):
    bm = bmesh.new()
    add_box(bm, -0.3, 0.3, -0.3, 0.3, 0.0, 0.1)
    add_box(bm, -0.27, 0.27, -0.27, 0.27, 0.1, 0.14)
    mesh_object("floor_cushion__body", bm, ["cushion_termeh"], r)


# --- Persian floor seating (your note after step 1: in place of the chairs) -----

def add_bolster(bm, a, b, radius, segs=8):
    """Closed round bolster from point a to point b (axis horizontal)."""
    from mathutils import Vector
    a, b = Vector(a), Vector(b)
    axis = (b - a).normalized()
    side = axis.cross(Vector((0.0, 0.0, 1.0))).normalized()
    up = side.cross(axis)
    rings = [[bm.verts.new(c + (side * math.cos(2 * math.pi * i / segs) + up * math.sin(2 * math.pi * i / segs)) * radius)
              for i in range(segs)] for c in (a, b)]
    for i in range(segs):
        j = (i + 1) % segs
        bm.faces.new((rings[0][i], rings[0][j], rings[1][j], rings[1][i]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[1])


def floor_seat(r):
    """A toshak (1.6 x 0.6 m floor mattress) in termeh, two poshti (back
    cushions) in ikat leaning at its back (-Y), a round bolster at the +X end.
    Facing +Y like the other seats. No collision: you step over it."""
    bm = bmesh.new()
    add_box(bm, -0.8, 0.8, -0.3, 0.3, 0.0, 0.07)
    add_box(bm, -0.77, 0.77, -0.27, 0.27, 0.07, 0.1)
    mesh_object("floor_seat__toshak", bm, ["cushion_termeh"], r)
    bm = bmesh.new()
    for x in (-0.38, 0.3):
        add_obox(bm, (x, -0.2, 0.32), (0.62, 0.16, 0.46), (math.radians(-14), 0.0, 0.0))
    mesh_object("floor_seat__poshti", bm, ["cushion_ikat"], r)
    bm = bmesh.new()
    add_bolster(bm, (0.68, -0.22, 0.2), (0.68, 0.22, 0.2), 0.1)
    mesh_object("floor_seat__bolster", bm, ["cushion_kilim"], r)


def pouf(r):
    """A round kilim pouf (ottoman), 0.36 m high. No collision."""
    bm = bmesh.new()
    add_lathe(bm, [(0.0, 0.0), (0.2, 0.0), (0.26, 0.05), (0.28, 0.18), (0.26, 0.31), (0.2, 0.36), (0.0, 0.37)], segs=12)
    mesh_object("pouf__body", bm, ["cushion_kilim"], r)


def rahl(bm, books, x, y, z):
    """A rahl, the folding book stand: two boards crossed in an X, an open
    book in the V. Long side along X; the book opens toward +Y and -Y, the
    sides of the table you sit at."""
    for s in (-1, 1):
        add_obox(bm, (x, y + s * 0.06, z + 0.1), (0.3, 0.015, 0.24), (math.radians(-s * 38), 0.0, 0.0))
    for s in (-1, 1):
        add_obox(books, (x, y + s * 0.1, z + 0.2), (0.26, 0.17, 0.02), (math.radians(s * 35), 0.0, 0.0), 0)
        add_obox(books, (x, y + s * 0.11, z + 0.19), (0.28, 0.19, 0.008), (math.radians(s * 35), 0.0, 0.0), 1)


def low_reading_table(r):
    """A low reading table (1.2 x 0.6 m, 0.34 m) for sitting on the floor, long
    side along X: a lamp at the -X end, a rahl with an open book in the middle,
    a table_props_small scatter at the +X end."""
    bm = bmesh.new()
    add_box(bm, -0.6, 0.6, -0.3, 0.3, 0.3, 0.34)
    add_box(bm, -0.54, 0.54, -0.24, 0.24, 0.24, 0.3)
    for sx in (-1, 1):
        for sy in (-1, 1):
            add_box(bm, sx * 0.52 - 0.04, sx * 0.52 + 0.04, sy * 0.22 - 0.04, sy * 0.22 + 0.04, 0.0, 0.24)
    mesh_object("low_reading_table__body-col", bm, ["wood"], r)
    stand, books = bmesh.new(), bmesh.new()
    rahl(stand, books, 0.05, 0.0, 0.34)
    mesh_object("low_reading_table__rahl", stand, ["wood"], r)
    mesh_object("low_reading_table__book", books, ["pages", "book_leather"], r)
    lamp_into(r, "low_reading_table", -0.45, 0.08, 0.34)
    marker("SOCKET_table_props__table", r, (0.42, 0.0, 0.34), table_socket((0.12, 0.2), (1, 2)))


def tray_table(r):
    """A brass tray (sini) on a folding wooden stand, 0.42 m, a lamp on it."""
    bm = bmesh.new()
    for s in (-1, 1):
        add_obox(bm, (0.0, s * 0.12, 0.19), (0.04, 0.03, 0.44), (math.radians(s * 22), 0.0, 0.0))
        add_obox(bm, (s * 0.12, 0.0, 0.19), (0.03, 0.04, 0.44), (0.0, math.radians(s * -22), 0.0))
    mesh_object("tray_table__stand", bm, ["wood"], r)
    bm = bmesh.new()
    add_lathe(bm, [(0.0, 0.38), (0.3, 0.38), (0.31, 0.42), (0.28, 0.42), (0.27, 0.395), (0.0, 0.395)], segs=16)
    mesh_object("tray_table__tray", bm, ["brass"], r)
    bm = bmesh.new()
    add_box(bm, -0.24, 0.24, -0.24, 0.24, 0.0, 0.42)
    mesh_object("tray_table__col-colonly", bm, ["wood"], r)
    lamp_into(r, "tray_table", 0.08, 0.06, 0.395)


# --- carpets ------------------------------------------------------------------

def rug_quad(bm, uv, cx, cy, long_m, short_m):
    """One rug, long side along Y, its map stretched over it (u along Y)."""
    x0, y0 = cx - short_m / 2, cy - long_m / 2
    vs = [bm.verts.new(p) for p in ((x0, y0, 0.012), (x0 + short_m, y0, 0.012),
                                    (x0 + short_m, y0 + long_m, 0.012), (x0, y0 + long_m, 0.012))]
    f = bm.faces.new(vs)
    for loop in f.loops:
        loop[uv].uv = ((loop.vert.co.y - y0) / long_m, (loop.vert.co.x - x0) / short_m)


def rug(design, shape):
    def build(r):
        px_long, px_short = RUG_PX[shape]
        long_m, short_m = px_long / 32.0, px_short / 32.0
        bm = bmesh.new()
        uv = bm.loops.layers.uv.new("UVMap")
        centres = (-(long_m + 0.12), 0.0, long_m + 0.12) if shape == "runner" else (0.0,)
        for c in centres:
            rug_quad(bm, uv, 0.0, c, long_m, short_m)
        mesh_object("rug_%s_%s__rug" % (design, shape), bm, ["rug_%s_%s" % (design, shape)], r, recalc=False)
    return build


MODULES = [
    ("M_reading_table", dict(props("wood,furniture,light,reading"), kit_rev=3), reading_table),
    ("M_reading_chair", props("wood,furniture,seat,reading"), reading_chair),
    ("M_reading_armchair", props("wood,cloth,furniture,seat,reading"), reading_armchair),
    ("M_side_table", dict(props("wood,furniture,light,reading"), kit_rev=2), side_table),
    ("M_table_lamp", props("brass,light,table_prop,reading"), table_lamp),
    ("M_low_table", dict(props("wood,furniture,light,reading"), kit_rev=3), low_table),
    ("M_floor_cushion", dict(props("cloth,furniture,seat,reading"), kit_rev=2), floor_cushion),
    ("M_floor_seat", props("cloth,furniture,seat,reading"), floor_seat),
    ("M_pouf", props("cloth,furniture,seat,reading"), pouf),
    ("M_low_reading_table", dict(props("wood,furniture,light,reading"), kit_rev=2), low_reading_table),
    ("M_tray_table", props("brass,wood,furniture,light,reading"), tray_table),
] + [("M_rug_%s_%s" % (d, s), dict(props("cloth,floor,rug,reading"), kit_rev=2 if s == "grand" else 1), rug(d, s))
     for s in ("runner", "grand", "small") for d in DESIGNS]

# Script-made modules whose layout changed: rebuilt in place when the root's
# "kit_rev" is below the rev listed. Only for modules nobody has edited by hand.
# rev 2: table_props_small, grand rugs 7 x 4.5 -> 6 x 3.5 m; rev 3 (the side
# table's 2): the lamp is part of the table (free pieces stay on the 0.5 m grid);
# the floor cushion's 2: termeh cloth; the low reading table's 2: the rahl
# turned to face its seats.
REBUILD = [("M_reading_table", 3), ("M_low_table", 3), ("M_side_table", 2), ("M_floor_cushion", 2),
           ("M_low_reading_table", 2)] + \
          [("M_rug_%s_grand" % d, 2) for d in DESIGNS]


def main():
    if not os.path.exists(BLEND):
        print("kit_add_reading: %s not found; run kit_add_dressing.py first." % BLEND)
        sys.exit(1)
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    added = []
    for i, (name, p, build) in enumerate(MODULES):
        if bpy.data.objects.get(name) is None:
            build(module(name, ((i % 7) * 8.0, ROW_Y + (i // 7) * 8.0, 0.0), p))
            added.append(name)
    added += ["%s (rebuilt rev %d)" % (n, v) for (n, v) in REBUILD if rebuild(n, v, MODULES)]
    if not added:
        print("kit_add_reading: all modules already present; nothing to do.")
        return
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("kit_add_reading: added %s" % ", ".join(added))


main()
