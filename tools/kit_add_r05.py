"""Seeds the R05 Caravanserai modules into art_src/kit/kit_court.blend
(phase-5-design.md 5.6.7 and 5.6.5, step 5).

  blender --background --factory-startup --python tools/kit_add_r05.py

Creates kit_court.blend if it doesn't exist, then adds only the modules that
are not in it yet. Modules already in the file (including ones you edited by
hand) are never touched, so re-running is safe. Then run tools/export_kit.bat.

The courtyard (CourtyardGrammar, scripts/gen/courtyard_grammar.gd): a ring of
cells one bay deep round an open court, two storeys of them. Heights: the
ground storey 0-4 m, the upper 4-8 m, the roof's parapet to 8.6 m, the gate's
pishtaq to 10.4 m and the cavern's rock 12-15.5 m over the court.

A ring piece's frame (Blender): X 0..4 along the court face (8 for the
stair), Y from the court face (0) to the outer wall (4), placed like an edge
module on the cell's court side (CellGrid.edge_transform). The court face wall
is Y 0..0.5; the upper storey's loggia (the walkway) runs along Y 0.5..1.8
through every upper cell, the cell's own room behind it. A corner piece's
frame has the court's corner at its origin, X and Y along its two faces.

New modules (laid out on a row at Blender Y = -80 for viewing):
  court_cell_bay          cell: a ground cell, a pointed arch to the court, a
                          plastered barrel vault, a court_cell socket.
  court_cell_bay_upper    cell (one storey up): the loggia behind an arch with
                          a 0.9 m sill, the cell behind it (court_cell_upper
                          socket), a timber ceiling, the roof's parapet.
  court_corner_block      cell: the solid ground storey of a corner.
  court_corner_upper      cell (one storey up): the loggia turning the corner.
  court_corner_upper_stair / _r
                          cell (one storey up): the corner where a stair comes
                          up (its arm in the back lane); _r mirrored.
  court_corner_stair / _r cell, 2 bays: the stair hall beside the gate, an arch
                          from the court to its foot, two flights of 0.2 m
                          steps (a ramp over their nosings for walking) up
                          to the corner; _r mirrored (rises the other way).
  court_pishtaq_gate      cell, 2 storeys: the gate passage, a tall tiled
                          pishtaq facing the court, the doorway out (a 3 m
                          arch between piers, as the kit's doors).
  court_passage           cell: a side door's passage through the ring.
  court_floor_4m          cell: the court's paving.
  court_hearth_platform   free (dressing): the raised hearth, three steps round
                          (a ramp for walking), a carpet, a court_hearth socket
                          and eight ANCHOR_sit round it.
  court_fire_pit / court_brazier_ring / court_tannur
                          free (dressing): the hearth's three looks.
  court_well              free (dressing): the well, its frame and bucket.
  court_lantern_string    free: a rope of lanterns across the court, 20 m.
  court_loggia_lantern    free: a lantern under a loggia beam.
  court_cell_lantern      free: a lantern in a ground cell's mouth (every second one).
  court_contents_bedroll / _stable / _store / _stall / _ruin
                          free (dressing): what a cell holds; origin at the
                          foot of its back wall, reaching toward -Y (the court).
  cavern_ceiling_5x5      cell, 7 x 7 bays: the cavern's rock over the court,
                          down to the roofs at the edges.
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import noise, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit_blender import (add_box, add_lathe, add_ngon_prism, add_obox, add_prism, add_tube, arch_outline, arch_ring,  # noqa: E402
                         cut, marker, mesh_object, module, rebuild)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(ROOT, "art_src", "kit", "kit_court.blend")
ROW_Y = -80.0
H = 4.0            # storey
FACE = 0.5         # the court face wall, Y 0..FACE
LANE = (0.5, 1.8)  # the loggia and the stair's front lane
BACK = (2.1, 3.4)  # the stair's back lane
PART = 0.15        # half a partition between cells
OUTER = 3.4        # the ground storey's outer wall, Y OUTER..4
OUTER_UP = 3.6     # the upper storey's
CEIL_UP = 3.6      # the upper storey's ceiling (the roof slab's underside), over its floor
SILL = 0.9         # the upper arches' sill, over the upper floor
PARAPET = 0.6      # the roof's parapet over the roof (8 m)
LAMP_SOCKET = {"socket_set": "lamp_state", "socket_mode": "state"}


def props(shape, size, edge, tags, family="walls", weight=1.0):
    return {"kit_shape": shape, "kit_family": family, "size_cells": size,
            "edge": edge, "tags": tags, "weight": weight}


def add_prism_x(bm, outline, x0, x1, y_off=0.0, z_off=0.0, mat=0):
    """Extrude a YZ outline along X (a loggia's or a stair's cross-section)."""
    a = [bm.verts.new((x0, y_off + u, z_off + v)) for (u, v) in outline]
    b = [bm.verts.new((x1, y_off + u, z_off + v)) for (u, v) in outline]
    bm.faces.new(list(reversed(a))).material_index = mat
    bm.faces.new(b).material_index = mat
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], b[i], b[j], a[j])).material_index = mat


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


def lantern_at(bm, glass, cx, cy, z0, half, height):
    nb, ng = len(bm.verts), len(glass.verts)
    lantern_box(bm, glass, z0, half, height)
    for (b, n) in ((bm, nb), (glass, ng)):
        b.verts.ensure_lookup_table()
        bmesh.ops.translate(b, verts=b.verts[n:], vec=(cx, cy, 0.0))


def transform(bm, fn):
    """Moves every vertex by fn((x, y, z)) -> (x, y, z): mirrors for the _r
    pieces (normals are recalculated by mesh_object)."""
    for v in bm.verts:
        v.co = Vector(fn(tuple(v.co)))
    return bm


def solid(name, root, mats, build, xf=None, recalc=True):
    """A mesh from build(bm), optionally moved by xf (a mirror)."""
    bm = bmesh.new()
    build(bm)
    if xf is not None:
        transform(bm, xf)
    return mesh_object(name, bm, mats, root, recalc)


def cutter(root, build, xf=None, mat="court_plaster"):
    return solid("cutter", root, [mat], build, xf)


def pier(bm, x, y):
    """The kit's door pier (post_pier's boxes) at (x, y), so a room joined at a
    door finds its corners like any host's."""
    add_box(bm, x - 0.48, x + 0.48, y - 0.48, y + 0.48, 0.0, 0.3)
    add_box(bm, x - 0.4, x + 0.4, y - 0.4, y + 0.4, 0.3, H - 0.3)
    add_box(bm, x - 0.5, x + 0.5, y - 0.5, y + 0.5, H - 0.3, H)


def face_trim(root, name, width=4.0):
    """The ground storey's face: a tile band under a stone string course at 4 m."""
    solid(name + "__band", root, ["tile"], lambda bm: add_box(bm, 0.0, width, -0.03, 0.0, 3.5, 3.85))
    solid(name + "__course", root, ["arch_stone"], lambda bm: add_box(bm, 0.0, width, -0.1, 0.0, 3.85, 4.05))


def roof_parapet(root, name, width=4.0, z0=H):
    """The roof's parapet over the court face (z0 = the roof, the piece's top),
    merlons every metre, a tile band under the roof line."""
    def build(bm):
        add_box(bm, 0.0, width, 0.0, FACE, z0, z0 + 0.3)
        x = 0.25
        while x < width - 0.1:
            add_box(bm, x - 0.25, x + 0.25, 0.05, FACE - 0.05, z0 + 0.3, z0 + PARAPET)
            x += 1.0
    solid(name + "__parapet-col", root, ["brick"], build)
    solid(name + "__roofband", root, ["tile"], lambda bm: add_box(bm, 0.0, width, -0.03, 0.0, z0 - 0.3, z0 - 0.05))


def beams(bm, x0, x1, y0, y1, z=CEIL_UP, along_x=False):
    """Timber joists under a flat ceiling at z, every 0.5 m."""
    if along_x:
        y = y0 + 0.2
        while y < y1 - 0.1:
            add_box(bm, x0, x1, y - 0.06, y + 0.06, z - 0.15, z)
            y += 0.5
        return
    x = x0 + 0.25
    while x < x1 - 0.1:
        add_box(bm, x - 0.06, x + 0.06, y0, y1, z - 0.15, z)
        x += 0.5


# --- the ring -----------------------------------------------------------------------

def cell_bay(r):
    body = solid("court_cell_bay__body-col", r, ["brick"], lambda bm: add_box(bm, 0.0, 4.0, 0.0, 4.0, 0.0, H))
    # The cell: a round barrel along Y, springing at 1.8 m (crown 3.65).
    cut(body, cutter(r, lambda bm: add_prism(bm, arch_outline(4.0 - 2 * PART, 1.8, 0.5, 10), PART, -0.01, FACE - 0.05, OUTER)))
    cut(body, cutter(r, lambda bm: add_prism(bm, arch_outline(2.6, 1.8, 0.6, 10), 0.7, -0.01, -0.1, FACE + 0.1), mat="arch_stone"))
    solid("court_cell_bay__floor-col", r, ["floor_stone"], lambda bm: add_box(bm, 0.0, 4.0, 0.0, 4.0, -0.2, 0.0))
    bm = bmesh.new()
    arch_ring(bm, [(0.7 + u, v) for (u, v) in arch_outline(2.6, 1.8, 0.6, 10)],
              [(0.45 + u, v) for (u, v) in arch_outline(3.1, 1.8, 0.6, 10)], -0.05, 0.02)
    mesh_object("court_cell_bay__archivolt", bm, ["arch_stone"], r)
    face_trim(r, "court_cell_bay")
    marker("SOCKET_court_cell__bay", r, (2.0, OUTER, 0.0), {"socket_set": "court_cell"})
    # rev 3: the lantern in the cell's mouth is its own piece (court_cell_lantern), on
    # every second cell, so the court keeps within the light budget.


def upper_shell(r, name, room=True):
    """The upper storey's body: the loggia along X, the cell behind it (room),
    an arch to the court with a sill; floor, joists, the roof's parapet."""
    body = solid(name + "__body-col", r, ["brick"], lambda bm: add_box(bm, 0.0, 4.0, 0.0, 4.0, 0.0, H))
    cut(body, cutter(r, lambda bm: add_box(bm, -0.1, 4.1, LANE[0] - 0.05, LANE[1], -0.01, CEIL_UP)))
    if room:
        cut(body, cutter(r, lambda bm: add_prism(bm, arch_outline(4.0 - 2 * PART, 1.7, 0.5, 10), PART, -0.01, LANE[1] - 0.05, OUTER_UP)))
    cut(body, cutter(r, lambda bm: add_prism(bm, arch_outline(2.4, 1.2, 0.6, 10), 0.8, SILL, -0.1, FACE), mat="arch_stone"))
    solid(name + "__floor-col", r, ["floor_stone"], lambda bm: add_box(bm, 0.0, 4.0, LANE[0] - 0.05, OUTER_UP if room else LANE[1], 0.0, 0.05))
    solid(name + "__joists", r, ["wood"], lambda bm: beams(bm, 0.0, 4.0, LANE[0] - 0.05, LANE[1]))
    bm = bmesh.new()
    arch_ring(bm, [(0.8 + u, SILL + v) for (u, v) in arch_outline(2.4, 1.2, 0.6, 10)],
              [(0.6 + u, SILL + v) for (u, v) in arch_outline(2.8, 1.2, 0.6, 10)], -0.05, 0.02)
    mesh_object(name + "__archivolt", bm, ["arch_stone"], r)
    roof_parapet(r, name)


def cell_bay_upper(r):
    upper_shell(r, "court_cell_bay_upper")
    marker("SOCKET_court_cell_upper__bay", r, (2.0, OUTER_UP, 0.05), {"socket_set": "court_cell_upper"})


def corner_block(r):
    solid("court_corner_block__body-col", r, ["brick"], lambda bm: add_box(bm, 0.0, 4.0, 0.0, 4.0, 0.0, H))
    solid("court_corner_block__course", r, ["arch_stone"], lambda bm: add_box(bm, -0.1, 0.0, -0.1, 0.0, 3.85, 4.05))


def corner_upper(arm_b_lane, mirror=False):
    """The loggia turning a corner: arm A from the Y = 0 face (X 0.5..1.8),
    arm B from the X = 0 face in lane arm_b_lane (Y); mirror swaps X and Y."""
    tag = "court_corner_upper" + ("_stair" if arm_b_lane != LANE else "") + ("_r" if mirror else "")
    swap = (lambda p: (p[1], p[0], p[2])) if mirror else None

    def build(r):
        body = solid(tag + "__body-col", r, ["brick"], lambda bm: add_box(bm, 0.0, 4.0, 0.0, 4.0, 0.0, H))
        cut(body, cutter(r, lambda bm: add_box(bm, LANE[0] - 0.05, LANE[1], -0.1, arm_b_lane[1], -0.01, CEIL_UP), swap))
        cut(body, cutter(r, lambda bm: add_box(bm, -0.1, LANE[1], arm_b_lane[0], arm_b_lane[1], -0.01, CEIL_UP), swap))

        def floor(bm):
            add_box(bm, LANE[0] - 0.05, LANE[1], 0.0, arm_b_lane[1], 0.0, 0.05)
            add_box(bm, 0.0, LANE[0] - 0.05, arm_b_lane[0], arm_b_lane[1], 0.0, 0.05)
        solid(tag + "__floor-col", r, ["floor_stone"], floor, swap)
        solid(tag + "__joists", r, ["wood"], lambda bm: beams(bm, LANE[0] - 0.05, LANE[1], 0.0, arm_b_lane[1], along_x=True), swap)
        solid(tag + "__parapet-col", r, ["brick"], lambda bm: add_box(bm, 0.0, FACE, 0.0, FACE, H, H + PARAPET))
        solid(tag + "__roofband", r, ["tile"], lambda bm: add_box(bm, -0.03, 0.0, -0.03, 0.0, H - 0.3, H - 0.05))
    return build


def stair(mirror=False):
    """Two bays (X 0..8, X = 8 the corner) beside the gate: an arch from the
    court (X 6.25..7.75) to the foot of flight 1, which climbs the front lane
    toward the gate to a landing (2 m) at X 0.15..1.9; flight 2 climbs the
    back lane to the corner and comes out at 4 m through the end wall into
    the corner's loggia. 0.2 m steps, 0.39 m treads (27 degrees), a ramp 2 cm
    over their nosings for walking; a divider with a parapet's height over
    the upper flight; the stairwell open to the roof. mirror: X -> 8 - X."""
    tag = "court_corner_stair" + ("_r" if mirror else "")
    xf = (lambda p: (8.0 - p[0], p[1], p[2])) if mirror else None
    foot, land, t, n = 5.8, 1.9, 0.39, 10

    def build(r):
        body = solid(tag + "__body-col", r, ["brick"], lambda bm: add_box(bm, 0.0, 8.0, 0.0, 4.0, 0.0, 2 * H), xf)
        cut(body, cutter(r, lambda bm: add_box(bm, PART, 8.0 - PART, FACE - 0.05, OUTER, -0.01, 2 * H - 0.4), xf))
        cut(body, cutter(r, lambda bm: add_prism(bm, arch_outline(1.5, 1.6, 0.6, 10), 6.25, -0.01, -0.1, FACE + 0.1), xf, "arch_stone"))
        for x0 in (1.4, 4.6):
            cut(body, cutter(r, lambda bm, x0=x0: add_prism(bm, arch_outline(2.4, 1.2, 0.6, 10), x0, H + SILL, -0.1, FACE + 0.1), xf, "arch_stone"))
        cut(body, cutter(r, lambda bm: add_box(bm, 8.0 - PART - 0.05, 8.1, BACK[0], BACK[1], H - 0.01, H + 2.6), xf))
        solid(tag + "__floor-col", r, ["floor_stone"], lambda bm: add_box(bm, 0.0, 8.0, 0.0, 4.0, -0.2, 0.0), xf)

        def steps(bm):
            for i in range(n):      # flight 1: the front lane, rising toward -X
                add_box(bm, foot - t * (i + 1), foot - t * i, LANE[0] - 0.05, LANE[1], 0.0, 0.2 * (i + 1))
            add_box(bm, PART, land, LANE[0] - 0.05, BACK[1], 0.0, 2.0)          # the landing
            for j in range(n):      # flight 2: the back lane, rising toward +X, solid below
                add_box(bm, land + t * j, land + t * (j + 1), BACK[0], BACK[1], 0.0, 2.2 + 0.2 * j)
            add_box(bm, foot, 8.0 - PART, BACK[0], BACK[1], 0.0, 2 * 2.0 + 0.05)      # the top landing (the loggia floor's height), solid below
        solid(tag + "__steps-col", r, ["arch_stone"], steps, xf)
        slope = 0.2 / t
        ramp1 = [(foot + 0.22 / slope, 0.0), (foot - t * (n - 1), 2.02), (land, 2.02), (land, 0.0)]
        solid(tag + "__ramp1-colonly", r, ["arch_stone"],
              lambda bm: add_prism(bm, ramp1, 0.0, 0.0, LANE[0] - 0.05, LANE[1]), xf)
        ramp2 = [(land - 0.22 / slope, 2.0), (land + t * (n - 1), 4.02), (land + t * (n - 1), 0.0), (land - 0.22 / slope, 0.0)]
        solid(tag + "__ramp2-colonly", r, ["arch_stone"],
              lambda bm: add_prism(bm, ramp2, 0.0, 0.0, BACK[0], BACK[1]), xf)
        divider = [(land, 0.0), (8.0 - PART, 0.0), (8.0 - PART, 4.9), (land + t * (n - 1), 4.9), (land, 2.9)]
        solid(tag + "__divider-col", r, ["brick"], lambda bm: add_prism(bm, divider, 0.0, 0.0, LANE[1], BACK[0]), xf)
        solid(tag + "__divider_cap", r, ["arch_stone"],
              lambda bm: add_prism(bm, [(land, 2.9), (land + t * (n - 1), 4.9), (8.0 - PART, 4.9), (8.0 - PART, 4.97),
                                        (land + t * (n - 1), 4.97), (land, 2.97)], 0.0, 0.0, LANE[1] - 0.03, BACK[0] + 0.03), xf)
        bm = bmesh.new()
        arch_ring(bm, [(6.25 + u, v) for (u, v) in arch_outline(1.5, 1.6, 0.6, 10)],
                  [(6.0 + u, v) for (u, v) in arch_outline(2.0, 1.6, 0.6, 10)], -0.05, 0.02)
        mesh_object(tag + "__archivolt", transform(bm, xf) if xf else bm, ["arch_stone"], r)
        solid(tag + "__band", r, ["tile"], lambda bm: add_box(bm, 0.0, 8.0, -0.03, 0.0, 3.5, 3.85), xf)
        solid(tag + "__course", r, ["arch_stone"], lambda bm: add_box(bm, 0.0, 8.0, -0.1, 0.0, 3.85, 4.05), xf)

        def parapet(bm):
            add_box(bm, 0.0, 8.0, 0.0, FACE, 2 * H, 2 * H + 0.3)
            x = 0.25
            while x < 7.9:
                add_box(bm, x - 0.25, x + 0.25, 0.05, FACE - 0.05, 2 * H + 0.3, 2 * H + PARAPET)
                x += 1.0
        solid(tag + "__parapet-col", r, ["brick"], parapet, xf)
        solid(tag + "__roofband", r, ["tile"], lambda bm: add_box(bm, 0.0, 8.0, -0.03, 0.0, 2 * H - 0.3, 2 * H - 0.05), xf)
        # Lanterns: one hung over the landing, one at the top of the stair.
        bm = bmesh.new()
        glass = bmesh.new()
        lantern_at(bm, glass, 1.0, 1.95, 4.4, 0.16, 0.48)
        add_box(bm, 0.98, 1.02, 1.93, 1.97, 4.93, 2 * H - 0.4)
        lantern_at(bm, glass, 6.9, BACK[0] - 0.12, 6.1, 0.14, 0.42)
        add_box(bm, 6.88, 6.92, BACK[0] - 0.14, BACK[0] - 0.1, 6.57, 2 * H - 0.4)
        mesh_object(tag + "__lanterns", transform(bm, xf) if xf else bm, ["brass"], r)
        mesh_object(tag + "__glass", transform(glass, xf) if xf else glass, ["emit_lantern"], r)
        for (k, p) in (("landing", (1.0, 1.95, 4.65)), ("top", (6.9, BACK[0] - 0.12, 6.3))):
            q = xf(p) if xf else p
            marker("LIGHT_lantern__%s_%s" % (tag, k), r, q)
            marker("SOCKET_lamp_state__%s_%s" % (tag, k), r, q, LAMP_SOCKET)
    return build


def pishtaq_gate(r):
    """The gate cell: a passage (a pointed vault 3 m wide, 4 m high) from
    the court to the doorway out; on the court side a pishtaq 6 m wide and
    10.4 m high, 0.8 m proud of the face, its arch 6.4 m high over the
    passage, tile and mosaic, a lit grille over the passage and a lantern
    either side; the doorway out is the kit's 3 m arch between piers, its
    wall astride the cell's edge (Y 3.7..4.3) as door walls are, up to 4 m
    (over it the joining room's own band, a hall's, closes the edge). The
    upper storey is solid."""
    body = solid("court_pishtaq_gate__body-col", r, ["brick"], lambda bm: add_box(bm, 0.0, 4.0, 0.0, 3.7, 0.0, 2 * H))
    cut(body, cutter(r, lambda bm: add_prism(bm, arch_outline(3.0, 2.2, 0.6, 10), 0.5, -0.01, -0.1, 3.8)))
    wall = solid("court_pishtaq_gate__door-col", r, ["brick"], lambda bm: add_box(bm, 0.0, 4.0, 3.7, 4.3, 0.0, H))
    cut(wall, cutter(r, lambda bm: add_prism(bm, arch_outline(3.0, 1.8, 0.6, 10), 0.5, -0.01, 3.6, 4.4), mat="brick"))
    solid("court_pishtaq_gate__piers-col", r, ["arch_stone"], lambda bm: (pier(bm, 0.0, 4.0), pier(bm, 4.0, 4.0)))
    solid("court_pishtaq_gate__floor-col", r, ["floor_stone"], lambda bm: add_box(bm, 0.0, 4.0, 0.0, 4.0, -0.2, 0.0))
    frame = solid("court_pishtaq_gate__pishtaq-col", r, ["brick"], lambda bm: add_box(bm, -1.0, 5.0, -0.8, 0.0, 0.0, 10.1))
    cut(frame, cutter(r, lambda bm: add_prism(bm, arch_outline(3.0, 4.6, 0.6, 12), 0.5, -0.01, -0.9, 0.1), mat="tile"))

    def mosaic(bm):
        add_box(bm, -0.9, -0.5, -0.84, -0.8, 0.4, 9.8)
        add_box(bm, 4.5, 4.9, -0.84, -0.8, 0.4, 9.8)
        add_box(bm, -0.9, 4.9, -0.84, -0.8, 9.4, 9.8)
        add_box(bm, -0.5, 4.5, -0.84, -0.8, 7.1, 7.4)
    solid("court_pishtaq_gate__mosaic", r, ["mosaic"], mosaic)
    solid("court_pishtaq_gate__panel", r, ["tile"], lambda bm: add_box(bm, -0.5, 4.5, -0.83, -0.8, 7.4, 9.4))
    bm = bmesh.new()
    arch_ring(bm, [(0.5 + u, v) for (u, v) in arch_outline(3.0, 4.6, 0.6, 12)],
              [(0.2 + u, v) for (u, v) in arch_outline(3.6, 4.6, 0.6, 12)], -0.86, -0.78)
    mesh_object("court_pishtaq_gate__archivolt", bm, ["arch_stone"], r)
    solid("court_pishtaq_gate__cornice", r, ["arch_stone"], lambda bm: add_box(bm, -1.15, 5.15, -0.98, 0.0, 10.1, 10.4))
    # The iwan's back wall over the passage: tile, a lit grille.
    solid("court_pishtaq_gate__back", r, ["tile"], lambda bm: add_box(bm, 0.5, 3.5, -0.02, 0.0, 4.15, 6.5))
    solid("court_pishtaq_gate__grille_glow", r, ["emit_lantern"], lambda bm: add_box(bm, 1.5, 2.5, -0.04, -0.02, 4.6, 5.9))

    def grille(bm):
        for k in range(6):
            x = 1.5 + k * 0.2
            add_box(bm, x - 0.02, x + 0.02, -0.07, -0.04, 4.6, 5.9)
        for z in (4.6, 5.05, 5.45, 5.9):
            add_box(bm, 1.48, 2.52, -0.07, -0.04, z - 0.02, z + 0.02)
    solid("court_pishtaq_gate__grille", r, ["iron"], grille)
    bm = bmesh.new()
    glass = bmesh.new()
    for x in (-0.25, 4.25):          # on brackets from the pishtaq's face, either side of its arch
        lantern_at(bm, glass, x, -1.1, 2.3, 0.14, 0.42)
        add_box(bm, x - 0.02, x + 0.02, -1.1, -0.8, 2.76, 2.8)
    mesh_object("court_pishtaq_gate__lanterns", bm, ["brass"], r)
    mesh_object("court_pishtaq_gate__glass", glass, ["emit_lantern"], r)
    for (k, x) in (("l", -0.25), ("r", 4.25)):
        marker("LIGHT_lantern__gate_" + k, r, (x, -1.1, 2.5))
        marker("SOCKET_lamp_state__gate_" + k, r, (x, -1.1, 2.5), LAMP_SOCKET)


def passage(r):
    """A side door's passage: a pointed vault 3 m wide from the court to the
    doorway out (the kit's 3 m arch between piers, astride the edge)."""
    body = solid("court_passage__body-col", r, ["brick"], lambda bm: add_box(bm, 0.0, 4.0, 0.0, 3.7, 0.0, H))
    cut(body, cutter(r, lambda bm: add_prism(bm, arch_outline(3.0, 2.0, 0.6, 10), 0.5, -0.01, -0.1, 3.8)))
    wall = solid("court_passage__door-col", r, ["brick"], lambda bm: add_box(bm, 0.0, 4.0, 3.7, 4.3, 0.0, H))
    cut(wall, cutter(r, lambda bm: add_prism(bm, arch_outline(3.0, 1.8, 0.6, 10), 0.5, -0.01, 3.6, 4.4), mat="brick"))
    solid("court_passage__piers-col", r, ["arch_stone"], lambda bm: (pier(bm, 0.0, 4.0), pier(bm, 4.0, 4.0)))
    solid("court_passage__floor-col", r, ["floor_stone"], lambda bm: add_box(bm, 0.0, 4.0, 0.0, 4.0, -0.2, 0.0))
    bm = bmesh.new()
    arch_ring(bm, [(0.5 + u, v) for (u, v) in arch_outline(3.0, 2.0, 0.6, 10)],
              [(0.25 + u, v) for (u, v) in arch_outline(3.5, 2.0, 0.6, 10)], -0.05, 0.02)
    mesh_object("court_passage__archivolt", bm, ["arch_stone"], r)
    face_trim(r, "court_passage")


def court_floor(r):
    solid("court_floor_4m__paving-col", r, ["paving"], lambda bm: add_box(bm, 0.0, 4.0, 0.0, 4.0, -0.2, 0.0))


# --- the court ---------------------------------------------------------------------

def hearth_platform(r):
    """Centred on its origin: three steps of 0.15 m (7.4, 6.6, 5.8 m square),
    a carpet, cushions and packs; one ramp for collision over the nosings
    (21 degrees, from 0.4 m out from the lowest step)."""
    def tiers(bm):
        for (h, z0, z1) in ((3.7, 0.0, 0.15), (3.3, 0.15, 0.3), (2.9, 0.3, 0.45)):
            add_box(bm, -h, h, -h, h, z0, z1)
    solid("court_hearth_platform__steps", r, ["hearth_stone"], tiers)

    def ramp(bm):
        lo = [bm.verts.new((sx * 4.1, sy * 4.1, 0.0)) for (sx, sy) in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        hi = [bm.verts.new((sx * 2.9, sy * 2.9, 0.47)) for (sx, sy) in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        bm.faces.new(list(reversed(lo)))
        bm.faces.new(hi)
        for i in range(4):
            j = (i + 1) % 4
            bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
    solid("court_hearth_platform__ramp-colonly", r, ["hearth_stone"], ramp)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    vs = [bm.verts.new((x, y, 0.455)) for (x, y) in ((-2.2, -2.2), (2.2, -2.2), (2.2, 2.2), (-2.2, 2.2))]
    f = bm.faces.new(vs)
    for loop, t in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
        loop[uv].uv = t
    mesh_object("court_hearth_platform__carpet", bm, ["rug"], r, recalc=False)
    rng = random.Random(55)

    def cushions(bm):
        for k in range(8):
            a = 2 * math.pi * (k + 0.5) / 8
            add_obox(bm, (2.35 * math.cos(a), 2.35 * math.sin(a), 0.53), (0.55, 0.45, 0.16), (0.0, 0.0, a + rng.uniform(-0.2, 0.2)))
    solid("court_hearth_platform__cushions", r, ["linen"], cushions)

    def packs(bm):
        for (x, y) in ((2.5, -2.5), (-2.6, 2.4), (2.55, 2.45)):
            add_obox(bm, (x, y, 0.65), (0.6, 0.4, 0.4), (0.0, 0.0, rng.uniform(0, math.pi)))
            add_obox(bm, (x + 0.1, y - 0.05, 0.98), (0.45, 0.3, 0.26), (0.0, 0.0, rng.uniform(0, math.pi)))
    solid("court_hearth_platform__packs", r, ["book_leather"], packs)
    solid("court_hearth_platform__packs-colonly", r, ["linen"],
          lambda bm: [add_box(bm, x - 0.4, x + 0.4, y - 0.4, y + 0.4, 0.45, 1.2) for (x, y) in ((2.5, -2.5), (-2.6, 2.4), (2.55, 2.45))])
    marker("SOCKET_court_hearth__centre", r, (0.0, 0.0, 0.45), {"socket_set": "court_hearth"})
    for k in range(8):
        a = 2 * math.pi * (k + 0.5) / 8
        m = marker("ANCHOR_sit__%d" % k, r, (2.1 * math.cos(a), 2.1 * math.sin(a), 0.45))
        m.rotation_euler = (0.0, 0.0, a + math.pi / 2)
    # The hearth's glow on the cavern's rock (no shadow; the fire's own light has one).
    marker("LIGHT_cluster__glow", r, (0.0, 0.0, 8.5), {"energy": 1.6, "range": 17.0})     # rev 2: higher, brighter (the rock was black)


def fire_pit(r):
    rng = random.Random(7)

    def ring(bm):
        for k in range(11):
            a = 2 * math.pi * k / 11
            add_obox(bm, (0.68 * math.cos(a), 0.68 * math.sin(a), 0.1), (0.3, 0.22, 0.2), (0.0, 0.0, a + rng.uniform(-0.15, 0.15)))
    solid("court_fire_pit__stones", r, ["hearth_stone"], ring)
    solid("court_fire_pit__ash", r, ["char"], lambda bm: add_ngon_prism(bm, 10, 0.58, 0.0, 0.04))

    def logs(bm):
        for k in range(5):
            a = 2 * math.pi * k / 5 + 0.3
            add_obox(bm, (0.18 * math.cos(a), 0.18 * math.sin(a), 0.16), (0.75, 0.11, 0.11), (0.0, 0.35, a))
    solid("court_fire_pit__logs", r, ["wood"], logs)
    solid("court_fire_pit__embers", r, ["emit_ember"],
          lambda bm: [add_obox(bm, (rng.uniform(-0.25, 0.25), rng.uniform(-0.25, 0.25), 0.06), (0.1, 0.08, 0.05), (0, 0, rng.uniform(0, 3))) for _ in range(12)])
    solid("court_fire_pit__flame", r, ["emit_ember"], lambda bm: add_lathe(bm, [(0.0, 0.08), (0.22, 0.2), (0.12, 0.5), (0.0, 0.75)], segs=6))
    solid("court_fire_pit__block-colonly", r, ["hearth_stone"], lambda bm: add_ngon_prism(bm, 10, 0.85, 0.0, 0.7))
    marker("LIGHT_brazier__fire", r, (0.0, 0.0, 0.7))


def brazier_ring(r):
    """A wide iron brazier on three legs, a ring of hot stones round it."""
    solid("court_brazier_ring__bowl", r, ["iron"],
          lambda bm: add_lathe(bm, [(0.0, 0.55), (0.45, 0.58), (0.62, 0.82), (0.58, 0.85), (0.4, 0.66), (0.0, 0.64)], segs=12))

    def legs(bm):
        for k in range(3):
            a = 2 * math.pi * k / 3
            add_obox(bm, (0.38 * math.cos(a), 0.38 * math.sin(a), 0.3), (0.05, 0.05, 0.62), (0.25 * math.sin(a), -0.25 * math.cos(a), 0.0))
    solid("court_brazier_ring__legs", r, ["iron"], legs)
    rng = random.Random(9)
    solid("court_brazier_ring__coals", r, ["emit_ember"],
          lambda bm: [add_obox(bm, (rng.uniform(-0.35, 0.35), rng.uniform(-0.35, 0.35), 0.74), (0.12, 0.1, 0.07), (0, 0, rng.uniform(0, 3))) for _ in range(14)])

    def stones(bm):
        for k in range(9):
            a = 2 * math.pi * k / 9
            add_obox(bm, (1.0 * math.cos(a), 1.0 * math.sin(a), 0.08), (0.26, 0.2, 0.16), (0.0, 0.0, a))
    solid("court_brazier_ring__stones", r, ["hearth_stone"], stones)
    solid("court_brazier_ring__block-colonly", r, ["iron"], lambda bm: add_ngon_prism(bm, 10, 0.75, 0.0, 0.9))
    marker("LIGHT_brazier__brazier", r, (0.0, 0.0, 1.05))


def tannur(r):
    """A clay tannur oven: a dome with a glowing mouth on top and one at its
    foot, flatbreads stacked on a board."""
    solid("court_tannur__oven", r, ["earthenware"],
          lambda bm: add_lathe(bm, [(0.0, 0.0), (0.72, 0.0), (0.7, 0.4), (0.55, 0.8), (0.3, 1.0), (0.24, 1.02)], segs=14))
    solid("court_tannur__mouth", r, ["emit_ember"], lambda bm: add_ngon_prism(bm, 10, 0.22, 1.02, 1.04))
    solid("court_tannur__vent", r, ["emit_ember"], lambda bm: add_box(bm, -0.12, 0.12, -0.74, -0.71, 0.05, 0.25))
    solid("court_tannur__board", r, ["wood"], lambda bm: add_box(bm, 0.9, 1.5, -0.3, 0.3, 0.0, 0.08))
    solid("court_tannur__bread", r, ["pages"], lambda bm: [add_ngon_prism(bm, 10, 0.24, 0.08 + 0.02 * k, 0.095 + 0.02 * k, cx=1.2) for k in range(5)])
    solid("court_tannur__block-colonly", r, ["earthenware"], lambda bm: add_ngon_prism(bm, 10, 0.8, 0.0, 1.0))
    marker("LIGHT_brazier__tannur", r, (0.0, 0.0, 1.3), {"energy": 1.5})


def well(r):
    """An octagonal curb (0.8 m), still water inside, a timber frame with a
    pulley and a bucket on the rim."""
    def curb(bm):
        for k in range(8):
            a = 2 * math.pi * (k + 0.5) / 8
            add_obox(bm, (0.73 * math.cos(a), 0.73 * math.sin(a), 0.4), (0.25, 0.6, 0.8), (0.0, 0.0, a))
    solid("court_well__curb", r, ["arch_stone"], curb)
    solid("court_well__water", r, ["water"], lambda bm: add_ngon_prism(bm, 8, 0.62, 0.3, 0.32))
    solid("court_well__shaft", r, ["brick"], lambda bm: add_ngon_prism(bm, 8, 0.64, -0.2, 0.3))

    def frame(bm):
        for x in (-0.95, 0.95):
            add_box(bm, x - 0.07, x + 0.07, -0.07, 0.07, 0.0, 2.2)
        add_box(bm, -1.05, 1.05, -0.08, 0.08, 2.1, 2.25)
        add_box(bm, 1.0, 1.4, -0.25, 0.25, 0.0, 0.3)         # the bucket's stone
    solid("court_well__frame", r, ["wood"], frame)
    solid("court_well__pulley", r, ["iron"], lambda bm: (add_ngon_prism(bm, 10, 0.16, 1.9, 1.96), add_box(bm, -0.01, 0.01, -0.01, 0.01, 0.9, 1.9)))
    solid("court_well__bucket", r, ["wood"], lambda bm: add_lathe(bm, [(0.0, 0.3), (0.16, 0.3), (0.19, 0.6), (0.0, 0.58)], cx=1.2, segs=10))
    solid("court_well__block-colonly", r, ["arch_stone"], lambda bm: (add_ngon_prism(bm, 8, 0.88, 0.0, 0.85), add_box(bm, -1.05, 1.05, -0.12, 0.12, 0.0, 2.25)))


def lantern_string(r):
    """A rope across the court, X -10..10, from 7.0 m at the faces sagging to
    6.3 m; seven lanterns on it, two lights for them."""
    sag = lambda x: 7.0 - 0.7 * (1.0 - (x / 10.0) ** 2)
    solid("court_lantern_string__rope", r, ["iron"], lambda bm: add_tube(bm, [(x * 0.5, 0.0, sag(x * 0.5)) for x in range(-20, 21)], 0.015, 4))
    bm = bmesh.new()
    glass = bmesh.new()
    for k in range(7):
        x = -7.5 + 2.5 * k
        lantern_at(bm, glass, x, 0.0, sag(x) - 0.75, 0.12, 0.36)
        add_box(bm, x - 0.01, x + 0.01, -0.01, 0.01, sag(x) - 0.34, sag(x))
    mesh_object("court_lantern_string__lanterns", bm, ["brass"], r)
    mesh_object("court_lantern_string__glass", glass, ["emit_lantern"], r)
    for x in (-3.75, 3.75):
        marker("LIGHT_lantern__string_%d" % (x > 0), r, (x, 0.0, sag(x) - 0.7), {"energy": 1.7, "range": 9.5})     # rev 2: brighter (the atlas mock's warm court)


def cell_lantern(r):
    """A lantern hung from a ground cell's vault in its mouth (origin on the floor
    under it, 1.1 m in from the court face; the vault's crown is 3.65 m up)."""
    bm = bmesh.new()
    glass = bmesh.new()
    lantern_box(bm, glass, 2.3, 0.14, 0.42)
    add_box(bm, -0.015, 0.015, -0.015, 0.015, 2.77, 3.66)
    mesh_object("court_cell_lantern__body", bm, ["brass"], r)
    mesh_object("court_cell_lantern__glass", glass, ["emit_lantern"], r)
    marker("LIGHT_lantern__cell", r, (0.0, 0.0, 2.5), {"energy": 1.2, "range": 6.0})
    marker("SOCKET_lamp_state__cell", r, (0.0, 0.0, 2.5), LAMP_SOCKET)


def loggia_lantern(r):
    bm = bmesh.new()
    glass = bmesh.new()
    lantern_box(bm, glass, 2.35, 0.15, 0.45)
    add_box(bm, -0.015, 0.015, -0.015, 0.015, 2.85, CEIL_UP - 0.15)
    mesh_object("court_loggia_lantern__body", bm, ["brass"], r)
    mesh_object("court_loggia_lantern__glass", glass, ["emit_lantern"], r)
    marker("LIGHT_lantern__loggia", r, (0.0, 0.0, 2.55))
    marker("SOCKET_lamp_state__loggia", r, (0.0, 0.0, 2.55), LAMP_SOCKET)


# --- what a cell holds (origin at the foot of the back wall, toward -Y) -------------

def oil_lamp(bm, glass, x, y, z):
    add_lathe(bm, [(0.0, z), (0.07, z), (0.08, z + 0.05), (0.03, z + 0.08), (0.0, z + 0.08)], cx=x, cy=y, segs=8)
    add_box(glass, x - 0.015, x + 0.015, y - 0.015, y + 0.015, z + 0.08, z + 0.13)


def contents_bedroll(r):
    rng = random.Random(3)
    solid("court_contents_bedroll__mattress", r, ["linen"], lambda bm: (add_box(bm, -1.3, 0.6, -0.9, -0.1, 0.0, 0.12),
                                                                         add_obox(bm, (-1.1, -0.5, 0.18), (0.25, 0.7, 0.12), (0, 0, 0))))
    solid("court_contents_bedroll__blanket", r, ["cloth"], lambda bm: add_obox(bm, (0.15, -0.5, 0.15), (0.75, 0.82, 0.06), (0, 0, 0.05)))
    solid("court_contents_bedroll__roll", r, ["linen"], lambda bm: add_tube(bm, [(0.9, -0.35, 0.15), (1.6, -0.35, 0.15)], 0.15, 8))
    solid("court_contents_bedroll__packs", r, ["book_leather"], lambda bm: (add_obox(bm, (1.45, -0.9, 0.2), (0.45, 0.35, 0.4), (0, 0, 0.3)),
                                                                             add_obox(bm, (1.5, -0.88, 0.48), (0.3, 0.26, 0.16), (0, 0, 0.1))))
    solid("court_contents_bedroll__jar", r, ["earthenware"],
          lambda bm: add_lathe(bm, [(0.0, 0.0), (0.12, 0.0), (0.2, 0.25), (0.14, 0.52), (0.08, 0.6), (0.0, 0.6)], cx=-1.6, cy=-0.3, segs=10))
    bm = bmesh.new()
    glass = bmesh.new()
    oil_lamp(bm, glass, 0.75, -1.05, 0.0)
    mesh_object("court_contents_bedroll__lamp", bm, ["earthenware"], r)
    mesh_object("court_contents_bedroll__flame", glass, ["emit_lantern"], r)
    # rev 2: no light of its own (the light budget): the flame glows, the cell's lantern lights it.
    solid("court_contents_bedroll__block-colonly", r, ["linen"], lambda bm: (add_box(bm, 1.2, 1.75, -1.15, -0.65, 0.0, 0.7),
                                                                              add_box(bm, -1.8, -1.4, -0.5, -0.1, 0.0, 0.6)))
    marker("ANCHOR_sleep__bedroll", r, (-0.35, -0.5, 0.12)).rotation_euler = (0.0, 0.0, math.pi / 2 + rng.uniform(-0.05, 0.05))


def contents_stable(r):
    rng = random.Random(4)

    def manger(bm):
        add_box(bm, -1.6, 1.6, -0.62, -0.58, 0.5, 0.88)
        add_box(bm, -1.6, 1.6, -0.12, -0.08, 0.5, 0.88)
        add_box(bm, -1.6, 1.6, -0.62, -0.08, 0.48, 0.52)
        for x in (-1.6, 1.56):
            add_box(bm, x, x + 0.04, -0.62, -0.08, 0.5, 0.88)
        for x in (-1.5, 0.0, 1.45):
            add_box(bm, x - 0.04, x + 0.04, -0.6, -0.52, 0.0, 0.5)
        add_box(bm, -1.85, 1.85, -2.12, -2.06, 0.88, 0.98)             # the tether rail
        for x in (-1.82, -0.55, 0.55, 1.82):
            add_box(bm, x - 0.04, x + 0.04, -2.13, -2.05, 0.0, 0.98)
        add_lathe(bm, [(0.0, 0.0), (0.17, 0.0), (0.2, 0.35), (0.0, 0.33)], cx=1.3, cy=-1.3, segs=10)     # the bucket
    solid("court_contents_stable__timber", r, ["wood"], manger)

    def hay(bm):
        for _ in range(8):
            add_obox(bm, (rng.uniform(-1.4, 1.4), rng.uniform(-0.5, -0.2), 0.78), (0.55, 0.32, 0.18), (rng.uniform(-0.2, 0.2), 0, rng.uniform(0, 3)))
        for _ in range(10):
            add_obox(bm, (rng.uniform(-1.6, -0.9), rng.uniform(-2.0, -1.0), rng.uniform(0.15, 0.5)), (0.7, 0.55, 0.4), (rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), rng.uniform(0, 3)))
        for _ in range(9):
            add_obox(bm, (rng.uniform(-1.5, 1.5), rng.uniform(-2.2, -0.8), 0.015), (0.6, 0.5, 0.03), (0, 0, rng.uniform(0, 3)))
    solid("court_contents_stable__hay", r, ["hay"], hay)
    solid("court_contents_stable__saddle", r, ["book_leather"], lambda bm: (add_obox(bm, (1.1, -2.09, 1.02), (0.5, 0.55, 0.12), (0.0, 0.0, 0.0)),
                                                                            add_obox(bm, (1.1, -2.09, 0.82), (0.5, 0.06, 0.4), (0.0, 0.0, 0.0))))

    def block(bm):
        add_box(bm, -1.65, 1.65, -0.65, -0.05, 0.0, 0.9)
        add_box(bm, -1.75, -0.75, -2.0, -0.75, 0.0, 0.7)
        for (x0, x1) in ((-1.86, -0.5), (0.5, 1.86)):
            add_box(bm, x0, x1, -2.15, -2.03, 0.0, 1.0)
    solid("court_contents_stable__block-colonly", r, ["wood"], block)
    marker("ANCHOR_tether__stable", r, (0.0, -1.5, 0.0))


def contents_store(r):
    rng = random.Random(5)

    def sacks(bm):
        for (x, y, z, s) in ((-1.4, -0.35, 0.25, 1.0), (-0.9, -0.38, 0.24, 0.95), (-1.15, -0.4, 0.68, 0.9), (-0.4, -0.35, 0.24, 1.0), (-1.55, -0.95, 0.22, 0.9)):
            add_obox(bm, (x, y, z), (0.5 * s, 0.42 * s, 0.5 * s), (rng.uniform(-0.15, 0.15), rng.uniform(-0.15, 0.15), rng.uniform(0, 3)))
    solid("court_contents_store__sacks", r, ["linen"], sacks)

    def crates(bm):
        for (x, y, z, w) in ((0.45, -0.4, 0.0, 0.6), (1.1, -0.4, 0.0, 0.62), (0.75, -0.42, 0.6, 0.55), (1.35, -1.05, 0.0, 0.5)):
            add_obox(bm, (x, y, z + w / 2), (w, w * 0.9, w), (0, 0, rng.uniform(-0.1, 0.1)))
        add_box(bm, -1.75, 1.75, -0.32, -0.02, 1.45, 1.5)      # a shelf on the back wall
    solid("court_contents_store__crates", r, ["wood"], crates)

    def jars(bm):
        for (x, y, h) in ((-0.1, -0.95, 0.75), (0.25, -1.1, 0.6), (-0.45, -1.15, 0.55)):
            add_lathe(bm, [(0.0, 0.0), (0.13, 0.0), (0.22, h * 0.45), (0.12, h * 0.9), (0.09, h), (0.0, h)], cx=x, cy=y, segs=10)
        for k in range(6):
            add_lathe(bm, [(0.0, 1.5), (0.07, 1.5), (0.1, 1.62), (0.05, 1.75), (0.0, 1.75)], cx=-1.4 + 0.5 * k, cy=-0.17, segs=8)
    solid("court_contents_store__jars", r, ["earthenware"], jars)
    solid("court_contents_store__block-colonly", r, ["wood"], lambda bm: (add_box(bm, -1.8, 1.65, -0.7, 0.0, 0.0, 1.0),
                                                                          add_box(bm, -1.8, 1.65, -1.35, -0.7, 0.0, 0.8)))


def contents_stall(r):
    """A spice seller's: a low counter toward the court with baskets of spice,
    sacks behind, a cloth awning and a hanging lamp."""
    rng = random.Random(6)
    solid("court_contents_stall__counter", r, ["wood"], lambda bm: (add_box(bm, -1.6, 1.6, -2.15, -1.45, 0.0, 0.5),
                                                                    add_box(bm, -1.65, 1.65, -2.2, -1.4, 0.5, 0.55)))
    spices = ("earthenware", "pomegranate", "moss", "pages", "soil", "hay")
    for k, mat in enumerate(spices):
        x = -1.25 + 0.5 * k
        solid("court_contents_stall__basket_%d" % k, r, ["wood"],
              lambda bm, x=x: add_lathe(bm, [(0.0, 0.55), (0.17, 0.55), (0.2, 0.7), (0.0, 0.68)], cx=x, cy=-1.8, segs=10))
        solid("court_contents_stall__spice_%d" % k, r, [mat],
              lambda bm, x=x: add_lathe(bm, [(0.0, 0.66), (0.19, 0.69), (0.0, 0.84 + 0.04 * rng.random())], cx=x, cy=-1.8, segs=8))

    def sacks(bm):
        for (x, y) in ((-1.3, -0.4), (-0.7, -0.35), (0.6, -0.4), (1.25, -0.45), (-1.0, -0.95)):
            add_obox(bm, (x, y, 0.28), (0.5, 0.45, 0.56), (0, 0, rng.uniform(0, 3)))
    solid("court_contents_stall__sacks", r, ["linen"], sacks)
    solid("court_contents_stall__awning", r, ["cloth"], lambda bm: add_obox(bm, (0.0, -2.0, 2.25), (3.6, 0.9, 0.03), (0.35, 0.0, 0.0)))
    bm = bmesh.new()
    glass = bmesh.new()
    lantern_at(bm, glass, 0.0, -1.1, 1.85, 0.13, 0.4)
    add_box(bm, -0.01, 0.01, -1.11, -1.09, 2.3, 3.6)
    mesh_object("court_contents_stall__lamp", bm, ["brass"], r)
    mesh_object("court_contents_stall__glass", glass, ["emit_lantern"], r)
    # rev 3: no light of its own (the light budget): the lamp glows, the cell's lantern lights it.
    solid("court_contents_stall__block-colonly", r, ["wood"], lambda bm: (add_box(bm, -1.65, 1.65, -2.22, -1.38, 0.0, 0.85),
                                                                          add_box(bm, -1.6, 1.6, -0.75, -0.1, 0.0, 0.6)))
    marker("ANCHOR_merchant__stall", r, (0.0, -0.9, 0.0))


def contents_ruin(r):
    rng = random.Random(8)

    def rubble(bm):
        for _ in range(16):
            x, y = rng.uniform(-1.6, 1.6), rng.uniform(-1.3, -0.15)
            add_obox(bm, (x, y, rng.uniform(0.05, 0.5) * (1.4 - abs(x) / 2)), (rng.uniform(0.2, 0.45), rng.uniform(0.15, 0.3), rng.uniform(0.1, 0.22)),
                     (rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4), rng.uniform(0, 3)))
    solid("court_contents_ruin__rubble", r, ["brick"], rubble)
    solid("court_contents_ruin__stones", r, ["arch_stone"], lambda bm: [add_obox(bm, (rng.uniform(-1.4, 1.4), rng.uniform(-1.2, -0.3), 0.12), (0.5, 0.35, 0.24),
                                                                                 (0.1, 0.0, rng.uniform(0, 3))) for _ in range(4)])
    solid("court_contents_ruin__beam", r, ["wood"], lambda bm: add_obox(bm, (0.3, -0.7, 0.55), (2.8, 0.16, 0.16), (0.0, -0.38, 0.25)))
    solid("court_contents_ruin__shards", r, ["earthenware"], lambda bm: [add_obox(bm, (rng.uniform(-1.5, 1.5), rng.uniform(-1.5, -0.4), 0.02), (0.12, 0.08, 0.03),
                                                                                  (0.0, 0.0, rng.uniform(0, 3))) for _ in range(9)])
    solid("court_contents_ruin__block-colonly", r, ["brick"], lambda bm: add_box(bm, -1.75, 1.75, -1.4, 0.0, 0.0, 0.75))


# --- the cavern ---------------------------------------------------------------------

def cavern_ceiling(r):
    """Rock over the 7 x 7 bay footprint (X 0..28, Y 0..28): 15 m over the
    court's middle, 12 m over its faces, down to the roofs (8.05 m) at the
    outer edge; facing down. A slab of collision far above (planning)."""
    n, size, court = 28, 28.0, 10.0

    def height(x, y):
        d = max(abs(x - size / 2), abs(y - size / 2))
        if d <= 6.0:
            h = 15.0
        elif d <= court:
            h = 15.0 - 2.6 * ((d - 6.0) / (court - 6.0)) ** 1.5
        else:
            h = 12.4 - 4.35 * ((d - court) / (size / 2 - court)) ** 0.8
        rough = noise.noise((x * 0.21, y * 0.21, 3.7)) * 0.9 + noise.noise((x * 0.6, y * 0.6, 9.1)) * 0.3
        fade = min(1.0, (size / 2 - d) / 2.5)
        return h + rough * fade

    bm = bmesh.new()
    vs = [[bm.verts.new((size * i / n, size * j / n, height(size * i / n, size * j / n))) for j in range(n + 1)] for i in range(n + 1)]
    for i in range(n):
        for j in range(n):
            bm.faces.new((vs[i][j], vs[i][j + 1], vs[i + 1][j + 1], vs[i + 1][j]))     # wound to face down
    mesh_object("cavern_ceiling_5x5__rock", bm, ["cave_rock"], r, recalc=False)
    solid("cavern_ceiling_5x5__lid-colonly", r, ["cave_rock"], lambda bm: add_box(bm, 0.0, size, 0.0, size, 15.9, 16.0))


MODULES = [
    ("M_court_cell_bay", props("cell", [1, 1, 1], "", "brick,court,walled"), cell_bay),
    ("M_court_cell_bay_upper", props("cell", [1, 1, 1], "", "brick,court,upper,walled"), cell_bay_upper),
    ("M_court_corner_block", props("cell", [1, 1, 1], "", "brick,court,walled"), corner_block),
    ("M_court_corner_upper", props("cell", [1, 1, 1], "", "brick,court,upper,walled"), corner_upper(LANE)),
    ("M_court_corner_upper_stair", props("cell", [1, 1, 1], "", "brick,court,upper,walled"), corner_upper(BACK)),
    ("M_court_corner_upper_stair_r", props("cell", [1, 1, 1], "", "brick,court,upper,walled"), corner_upper(BACK, mirror=True)),
    ("M_court_corner_stair", props("cell", [2, 2, 1], "", "brick,court,vertical,light,walled"), stair()),
    ("M_court_corner_stair_r", props("cell", [2, 2, 1], "", "brick,court,vertical,light,walled"), stair(mirror=True)),
    ("M_court_pishtaq_gate", props("cell", [1, 3, 1], "", "brick,tile,court,door,light,walled"), pishtaq_gate),
    ("M_court_passage", props("cell", [1, 1, 1], "", "brick,court,door,walled"), passage),
    ("M_court_floor_4m", props("cell", [1, 0, 1], "", "stone,court"), court_floor),
    ("M_court_hearth_platform", props("free", [2, 0, 2], "", "stone,court,landmark,light", family="dressing"), hearth_platform),
    ("M_court_fire_pit", props("free", [0, 0, 0], "", "stone,fire,light", family="dressing"), fire_pit),
    ("M_court_brazier_ring", props("free", [0, 0, 0], "", "iron,fire,light", family="dressing"), brazier_ring),
    ("M_court_tannur", props("free", [0, 0, 0], "", "clay,fire,light", family="dressing"), tannur),
    ("M_court_well", props("free", [1, 0, 1], "", "stone,water,court", family="dressing"), well),
    ("M_court_lantern_string", props("free", [5, 2, 0], "", "brass,light,court"), lantern_string),
    ("M_court_loggia_lantern", props("free", [0, 1, 0], "", "brass,light,court"), loggia_lantern),
    ("M_court_cell_lantern", props("free", [0, 1, 0], "", "brass,light,court"), cell_lantern),
    ("M_court_contents_bedroll", props("free", [1, 0, 1], "", "cloth,court", family="dressing"), contents_bedroll),
    ("M_court_contents_stable", props("free", [1, 0, 1], "", "wood,court", family="dressing"), contents_stable),
    ("M_court_contents_store", props("free", [1, 0, 1], "", "wood,storage,court", family="dressing"), contents_store),
    ("M_court_contents_stall", props("free", [1, 0, 1], "", "wood,court,light", family="dressing"), contents_stall),
    ("M_court_contents_ruin", props("free", [1, 0, 1], "", "brick,debris,court", family="dressing"), contents_ruin),
    ("M_cavern_ceiling_5x5", props("cell", [7, 4, 7], "", "rock,cavern,court"), cavern_ceiling),
]


# Script-made modules remade in place at a new revision (kit_blender.rebuild):
# hand edits to them are lost, so only list ones nobody has changed in Blender.
REBUILD = [("M_court_pishtaq_gate", 2),   # rev 2: the doorway's wall up to 4 m, the passage 4 m high
           ("M_court_cell_bay", 3),       # rev 2: a lantern in the mouth; rev 3: it moved to court_cell_lantern
           ("M_court_contents_bedroll", 2),   # rev 2: no light of its own
           ("M_court_hearth_platform", 2),   # rev 2: the glow on the rock higher and brighter
           ("M_court_contents_stable", 2), ("M_court_contents_stall", 3),   # rev 2: rail and counter 1.2 m back from the arch; stall rev 3: no light of its own
           ("M_court_lantern_string", 2)]   # rev 2: brighter


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
        x += 32.0 if name.startswith("M_cavern") else 12.0
    rebuilt = ["%s (rev %d)" % (n, v) for (n, v) in REBUILD if rebuild(n, v, MODULES)]
    # Tags added since a module was seeded ("walled": the ring's pieces close
    # their own cells for Validate Room); tags you added by hand stay.
    tagged = []
    for (name, p, _b) in MODULES:
        root = bpy.data.objects.get(name)
        have = str(root.get("tags", "")).split(",") if root is not None else []
        missing = [t for t in p["tags"].split(",") if t not in have]
        if root is not None and missing:
            root["tags"] = ",".join([t for t in have if t] + missing)
            tagged.append(name)
    rebuilt += ["%s (tags)" % n for n in tagged]
    if not added and not rebuilt:
        print("kit_add_r05: everything already present; nothing to do.")
        return
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("kit_add_r05: added %s; rebuilt %s" % (", ".join(added) or "nothing", ", ".join(rebuilt) or "nothing"))


main()
