"""Seeds the R06 Domicile Quarter modules into art_src/kit/kit_quarter.blend
(phase 14 step 1, docs/environment/phase-14-approval.md).

  blender --background --factory-startup --python tools/kit_add_r06.py

Creates kit_quarter.blend if it doesn't exist, then adds only the modules
that are not in it yet (hand edits are kept), and remakes those in REBUILD.
Then run tools/export_kit.bat kit_quarter.blend.

The room (QuarterGrammar, scripts/gen/quarter_grammar.gd): narrow lanes in a
cavern. Houses are stacks of 3 m storeys, lower and narrower than the Gorge's
(Q3), standing on the lanes' cell edges.

Frame of a front (an edge piece, as a wall on the lane cell's edge): X along
the lane 0..w, the lane on +Y, Z up from the storey's floor. Its face stands
FACE proud of the cell edge, so a 4 m cell makes a 3.4 m lane; its body runs
back to BACK, so a neighbour set back shows a closed end.

  qt_g_<kind>_<tint>_<w>   ground storey: brick plinth, timber band on top
                           kinds door, lit, dark, blank
  qt_u_<kind>_<tint>_<w>   upper storey: kinds lit, dark, blank
  qt_cap_<tint>_<w>        parapet over a house's top storey
                           tints r (rose) and c (clay); widths 2 and 4
  qt_pier, qt_pier_cap     a brick corner post where a house turns a lane corner
  qt_roof                  a house's flat roof, one cell
  qt_lane, qt_lane_plain   one cell of lane, with a gutter or without
  qt_stair, qt_lane_high   a stair climbing one storey over two cells, and the
                           landing it reaches
  qt_gate                  the frame round a doorway in a house front
  qt_sabat                 a room bridging a lane, one cell
  qt_hauz                  the small pool at the crossing
  qt_rock_wall[_lit|_top]  the cavern's wall, one cell wide; _lit has far
                           windows, _top starts above a doorway
  qt_rock_low[_b|_top]     the same up to the entry alley's low roof
  qt_cavern                the roof over the whole block
  qt_cavern_neck_<n>       the low roof over an entry alley n cells long
  qt_badgir, qt_bath, qt_bath_portal, qt_pigeon
                           the landmarks of the Wind Tower, Bath Ring and
                           Pigeon Tower layouts
  qt_glow                  a window's or doorway's light, nothing else
  qt_door_lamp             a small lantern on a bracket by a door (an edge piece)
  qt_washing_a, _b, qt_cloth  a line of washing, and a big hung cloth, across a lane
  qt_chimney               a brick stack on a roof, smoke from it (QuarterLife)
  qt_g_home_<tint>         a ground front with a real doorway and window (step 3)
  qt_home_1, qt_home_2     the room behind it, one or two cells deep
  qt_home_leaf             the door, origin at its hinge (HomeDoor swings it)
  qt_home_hides            a hunter's wall: stretched hides, pelts, a bow
  qt_home_note             a note left out (HomeNote reads it)
  qt_fig_*                 the people: stand, jar, sit, read, stir, mend (step 4)
  qt_rags                  what's left of a line of washing
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit_blender import add_box, add_lathe, add_ngon_prism, add_prism, add_tube, arch_outline, arch_ring, add_card, cut, marker, mesh_object, module, rebuild

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(ROOT, "art_src", "kit", "kit_quarter.blend")
ROW_Y = -200.0
SH = 3.0               # a house storey
FACE, BACK = 0.3, -0.4
RECESS = 0.06          # how far back a window's glow or a door stands from the wall's back of its opening
ROCK, STONE, BRICK, WOOD = "cave_rock", "persian_stone", "quarter_brick", "persian_wood"
GLOW, LATTICE, LANE = "emit_window_warm", "persian_lattice", "quarter_lane"
LIME, DARK = "persian_plaster_lime", "culvert_dark"
TINTS = {"r": "quarter_plaster_rose", "c": "quarter_plaster_clay"}
ROOM_W, ROOM_D = 36.0, 32.0     # the room (QuarterGrammar.HALF, DEPTH)
ROCK_TOP = 20.0


def props(size=(0, 0, 0), tags="quarter,r06"):
    return {"kit_shape": "free", "kit_family": "walls", "size_cells": list(size), "edge": "", "tags": tags, "weight": 1.0}


def solid(name, root, mats, build, recalc=True):
    bm = bmesh.new()
    build(bm)
    return mesh_object(name, bm, mats, root, recalc)


def arch_at(bm, x, foot, span, spring, y0, y1):
    add_prism(bm, arch_outline(span, spring, 0.6, 6), x - span / 2, foot, y0, y1)


def arch_face(root, name, mat, x, foot, span, spring, y, facing=1):
    """A flat arch-shaped face at Y `y`, facing +Y (or -Y)."""
    bm = bmesh.new()
    pts = [(x - span / 2 + u, y, foot + v) for (u, v) in arch_outline(span, spring, 0.6, 6)]
    bm.faces.new([bm.verts.new(p) for p in (pts if facing > 0 else reversed(pts))])
    return mesh_object(name, bm, [mat], root, recalc=False)


def window_at(r, name, x, foot, lit):
    """A small pointed window in a wall whose face is at FACE: lamplight behind
    a lattice, or dark behind shut timber."""
    span, spring = 0.8, 0.7
    arch_face(r, name + "__glow", GLOW if lit else WOOD, x, foot, span, spring, 0.08)
    if lit:
        bm = bmesh.new()
        uv = bm.loops.layers.uv.new("UVMap")
        add_card(bm, uv, (x, 0.17, foot), span, spring + 0.5)
        mesh_object(name + "__screen", bm, [LATTICE], r, recalc=False)
    else:
        solid(name + "__shut", r, [WOOD], lambda bm: arch_at(bm, x, foot, span, spring, 0.08, 0.14))
    solid(name + "__sill", r, [STONE], lambda bm: add_box(bm, x - 0.52, x + 0.52, 0.0, FACE + 0.1, foot - 0.09, foot))


def door_at(r, name, x):
    """A small house door: studded timber set back, a brick arch round it, a
    stone step (no collision: it is low enough to walk through)."""
    span, spring = 1.1, 1.55
    solid(name + "__door", r, [WOOD], lambda bm: arch_at(bm, x, 0.0, span, spring, 0.06, 0.12))

    def studs(bm):
        for z in (0.5, 1.0, 1.5):
            for dx in (-0.36, -0.14, 0.14, 0.36):
                add_box(bm, x + dx - 0.025, x + dx + 0.025, 0.12, 0.15, z - 0.025, z + 0.025)
    solid(name + "__studs", r, ["brass"], studs)
    inner = [(x - span / 2 + u, v) for (u, v) in arch_outline(span, spring, 0.6, 6)][1:-1]
    outer = [(x - span / 2 - 0.16 + u, v) for (u, v) in arch_outline(span + 0.32, spring + 0.02, 0.6, 6)][1:-1]
    solid(name + "__arch", r, [BRICK], lambda bm: arch_ring(bm, inner, outer, 0.1, FACE + 0.05, smooth=False), recalc=False)
    solid(name + "__step", r, [STONE], lambda bm: add_box(bm, x - 0.75, x + 0.75, 0.0, FACE + 0.42, 0.0, 0.14))


def front(level, kind, tint, w):
    def build(r):
        name = r.name[2:]
        foot = 1.2 if level == "g" else 0.95
        wins = [] if kind == "blank" else {2: [1.0], 4: [1.05, 2.95]}[w]
        door = None
        if kind == "door":
            door, wins = (1.0, []) if w == 2 else (1.2, [3.0])
        body = solid(name + "__body-col", r, [TINTS[tint]], lambda bm: add_box(bm, 0.0, float(w), BACK, FACE, 0.0, SH))

        def cutter(bm):
            for x in wins:
                arch_at(bm, x, foot, 0.8, 0.7, 0.05, FACE + 0.3)
            if door is not None:
                arch_at(bm, door, -0.05, 1.1, 1.6, 0.03, FACE + 0.3)
        if wins or door is not None:
            cut(body, solid("cutter", r, [TINTS[tint]], cutter))
        for i, x in enumerate(wins):
            if kind != "blank":
                window_at(r, name + "_%d" % i, x, foot, kind != "dark" if kind != "door" else True)
        if door is not None:
            door_at(r, name, door)
        if level == "g":
            def plinth(bm):
                spans = [(0.0, float(w))] if door is None else [(0.0, door - 0.72), (door + 0.72, float(w))]
                for (a, b) in spans:
                    add_box(bm, a, b, FACE - 0.02, FACE + 0.04, 0.0, 0.48)
            solid(name + "__plinth", r, [BRICK], plinth)
            solid(name + "__band", r, [WOOD], lambda bm: add_box(bm, 0.0, float(w), FACE - 0.02, FACE + 0.05, SH - 0.13, SH))
    return build


def cap(tint, w):
    def build(r):
        name = r.name[2:]
        solid(name + "__wall-col", r, [TINTS[tint]], lambda bm: add_box(bm, 0.0, float(w), BACK + 0.2, FACE, 0.0, 0.62))
        solid(name + "__coping", r, [BRICK], lambda bm: add_box(bm, 0.0, float(w), BACK + 0.15, FACE + 0.05, 0.62, 0.72))
        solid(name + "__spout", r, [WOOD], lambda bm: add_box(bm, w / 2.0 - 0.07, w / 2.0 + 0.07, FACE, FACE + 0.42, 0.06, 0.16))
    return build


def pier(r):
    solid("qt_pier__body-col", r, [BRICK], lambda bm: add_box(bm, -0.36, 0.36, -0.36, 0.36, 0.0, SH))


def pier_cap(r):
    solid("qt_pier_cap__body", r, [BRICK], lambda bm: add_box(bm, -0.42, 0.42, -0.42, 0.42, 0.0, 0.76))


def roof(r):
    solid("qt_roof__slab-col", r, ["persian_plaster_lime"], lambda bm: add_box(bm, 0.0, 4.0, 0.0, 4.0, -0.2, 0.0))


def lane(gutter):
    def build(r):
        name = r.name[2:]
        solid(name + "__floor-col", r, [LANE], lambda bm: add_box(bm, 0.0, 4.0, 0.0, 4.0, -0.4, 0.0))
        if gutter:
            solid(name + "__gutter", r, [STONE], lambda bm: add_box(bm, 1.82, 2.18, 0.0, 4.0, -0.02, 0.012))
    return build


def stair(r):
    n, run, rise = 16, 8.0, 4.0

    def steps(bm):
        for s in range(n):
            add_box(bm, 0.0, 4.0, s * run / n, (s + 1) * run / n, -0.2, (s + 1) * rise / n)
    solid("qt_stair__steps", r, [STONE], steps)

    def ramp(bm):
        a = [bm.verts.new(p) for p in ((0, 0, -0.2), (4, 0, -0.2), (4, run, -0.2), (0, run, -0.2),
                                       (0, 0, 0.0), (4, 0, 0.0), (4, run, rise), (0, run, rise))]
        for f in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
            bm.faces.new([a[i] for i in f])
    solid("qt_stair__ramp-colonly", r, [STONE], ramp)


def lane_high(r):
    solid("qt_lane_high__body-col", r, [LANE], lambda bm: add_box(bm, 0.0, 4.0, 0.0, 4.0, -4.2, 0.0))
    solid("qt_lane_high__gutter", r, [STONE], lambda bm: add_box(bm, 1.82, 2.18, 0.0, 4.0, -0.02, 0.012))


def gate(r):
    """A wall 6 m tall round the kit's 3 m doorway (X 0.5..3.5, 3.5 m high): the
    door wall itself stands on the edge (Y +-0.3), this is the house front
    just inside it. The passage's lintel is timber."""
    def wall(bm):
        add_box(bm, 0.0, 0.5, 0.31, 0.7, 0.0, 6.0)
        add_box(bm, 3.5, 4.0, 0.31, 0.7, 0.0, 6.0)
        add_box(bm, 0.5, 3.5, 0.31, 0.7, 3.5, 6.0)
    solid("qt_gate__wall-col", r, [TINTS["r"]], wall)
    solid("qt_gate__lintel", r, [WOOD], lambda bm: add_box(bm, 0.3, 3.7, 0.68, 0.8, 3.42, 3.62))

    def jambs(bm):
        add_box(bm, 0.3, 0.55, 0.68, 0.76, 0.0, 3.42)
        add_box(bm, 3.45, 3.7, 0.68, 0.76, 0.0, 3.42)
    solid("qt_gate__jambs", r, [BRICK], jambs)


def sabat(r):
    """A room bridging a lane: the lane under a pointed arch along Y, two lit
    windows on each face, a parapet. X 0..4 across, Y 0..4 along."""
    name = "qt_sabat"
    y0, y1, top = 0.4, 3.6, 6.4
    body = solid(name + "__body-col", r, [TINTS["r"]], lambda bm: add_box(bm, -0.1, 4.1, y0, y1, 1.7, top))

    def cutter(bm):
        add_prism(bm, arch_outline(3.3, 1.8, 0.6, 8), 0.35, 0.0, -1.0, 5.0)
        for x in (1.1, 2.9):
            arch_at(bm, x, 4.2, 0.8, 0.7, y0 - 0.1, y0 + 0.24)
            arch_at(bm, x, 4.2, 0.8, 0.7, y1 - 0.24, y1 + 0.1)
    cut(body, solid("cutter", r, [TINTS["r"]], cutter))
    for i, x in enumerate((1.1, 2.9)):
        arch_face(r, name + "__glow_s%d" % i, GLOW, x, 4.2, 0.8, 0.7, y0 + 0.22, facing=-1)
        arch_face(r, name + "__glow_n%d" % i, GLOW, x, 4.2, 0.8, 0.7, y1 - 0.22, facing=1)

    def trim(bm):
        for y, d in ((y0, -1.0), (y1, 1.0)):
            a, b = sorted((y, y + d * 0.1))
            add_box(bm, -0.1, 4.1, a, b, 3.92, 4.04)
    solid(name + "__beams", r, [WOOD], trim)
    solid(name + "__roof", r, ["persian_plaster_lime"], lambda bm: add_box(bm, -0.1, 4.1, y0, y1, top, top + 0.05))

    def parapet(bm):
        add_box(bm, -0.1, 4.1, y0 - 0.05, y0 + 0.2, top, top + 0.6)
        add_box(bm, -0.1, 4.1, y1 - 0.2, y1 + 0.05, top, top + 0.6)
    solid(name + "__parapet", r, [BRICK], parapet)


def hauz(r):
    """The small pool: an eight-sided stone rim with water in it, origin at its
    centre. The rim stops you walking through."""
    body = solid("qt_hauz__rim-col", r, [STONE], lambda bm: add_ngon_prism(bm, 8, 1.95, 0.0, 0.42))
    cut(body, solid("cutter", r, [ROCK], lambda bm: add_ngon_prism(bm, 8, 1.65, 0.18, 0.6)))
    bm = bmesh.new()
    n = 8
    ph = math.pi / n
    bm.faces.new([bm.verts.new((1.72 * math.cos(ph + 2 * math.pi * i / n), 1.72 * math.sin(ph + 2 * math.pi * i / n), 0.32)) for i in range(n)])
    mesh_object("qt_hauz__water", bm, ["cistern_water"], r, recalc=False)


def rough(x, y, z, seed):
    return noise.noise((x * 0.35, y * 0.35, z * 0.35 + seed)) * 0.7 + noise.noise((x * 1.1, y * 1.1, z * 1.1 + seed + 7.0)) * 0.3


def badgir(r):
    """The wind tower: a tall brick shaft on a house, its pale head slatted on
    all four sides, a lit slit in each face below it. Origin at its foot."""
    h = 1.5
    solid("qt_badgir__shaft-col", r, [BRICK], lambda bm: add_box(bm, -h, h, -h, h, 0.0, 12.6))
    solid("qt_badgir__head", r, [LIME], lambda bm: add_box(bm, -1.75, 1.75, -1.75, 1.75, 12.6, 16.2))
    solid("qt_badgir__vents", r, [DARK], lambda bm: add_box(bm, -1.79, 1.79, -1.79, 1.79, 13.2, 15.7), recalc=True)

    def corners(bm):
        for sx in (-1, 1):
            for sy in (-1, 1):
                add_box(bm, min(sx * 1.45, sx * 1.84), max(sx * 1.45, sx * 1.84), min(sy * 1.45, sy * 1.84), max(sy * 1.45, sy * 1.84), 12.6, 16.2)
    solid("qt_badgir__corners", r, [LIME], corners)

    def fins(bm):
        for i in range(-3, 4):
            u = i * 0.4
            for s in (-1, 1):
                add_box(bm, u - 0.05, u + 0.05, min(s * 1.75, s * 1.9), max(s * 1.75, s * 1.9), 13.2, 15.7)
                add_box(bm, min(s * 1.75, s * 1.9), max(s * 1.75, s * 1.9), u - 0.05, u + 0.05, 13.2, 15.7)
    solid("qt_badgir__fins", r, [WOOD], fins)

    def crown(bm):
        add_box(bm, -1.95, 1.95, -1.95, 1.95, 16.2, 16.42)
        for i in range(-2, 3):
            u = i * 0.8 - 0.15
            for s in (-1, 1):
                add_box(bm, u, u + 0.3, min(s * 1.7, s * 1.95), max(s * 1.7, s * 1.95), 16.42, 16.9)
                add_box(bm, min(s * 1.7, s * 1.95), max(s * 1.7, s * 1.95), u, u + 0.3, 16.42, 16.9)
    solid("qt_badgir__crown", r, [BRICK], crown)

    def slits(bm):
        for s in (-1, 1):
            add_box(bm, -0.16, 0.16, min(s * 1.5, s * 1.54), max(s * 1.5, s * 1.54), 10.8, 12.0)
            add_box(bm, min(s * 1.5, s * 1.54), max(s * 1.5, s * 1.54), -0.16, 0.16, 10.8, 12.0)
    solid("qt_badgir__slits", r, [GLOW], slits)
    marker("LIGHT_home__badgir", r, (0.0, -2.2, 10.6))
    marker("LIGHT_home__badgir_head", r, (0.0, -3.0, 14.6))


def bath(r):
    """The bath-house's dome, on the roof of its block: a pale drum and dome set
    with rings of small glowing glass eyes. Origin at the roof's middle."""
    solid("qt_bath__drum", r, [LIME], lambda bm: add_ngon_prism(bm, 16, 5.35, -0.1, 1.0))
    solid("qt_bath__band", r, ["persian_tile"], lambda bm: add_ngon_prism(bm, 16, 5.45, 1.0, 1.35))
    profile = [(5.0, 1.35), (4.92, 2.1), (4.5, 3.0), (3.8, 3.8), (2.9, 4.5), (1.8, 5.0), (0.7, 5.25), (0.0, 5.3)]
    solid("qt_bath__dome", r, [LIME], lambda bm: add_lathe(bm, profile, segs=24), recalc=False)

    def eyes(bm):
        for (rad, z, n) in ((4.55, 3.0, 18), (3.55, 4.05, 14), (2.25, 4.8, 9)):
            for i in range(n):
                a = 2 * math.pi * (i + 0.5) / n
                add_lathe(bm, [(0.2, z - 0.25), (0.17, z + 0.14), (0.0, z + 0.22)], rad * math.cos(a), rad * math.sin(a), 6)
    solid("qt_bath__eyes", r, [GLOW], eyes, recalc=False)
    solid("qt_bath__lantern", r, [BRICK], lambda bm: add_lathe(bm, [(0.75, 5.15), (0.7, 5.8), (0.85, 5.9), (0.0, 6.25)], segs=8), recalc=False)
    marker("LIGHT_home__bath_s", r, (0.0, -6.0, 0.8))
    marker("LIGHT_home__bath_n", r, (0.0, 6.0, 0.8))


def bath_portal(r):
    """The bath-house's door: a tiled arch standing on the house front, one
    lane cell wide (an edge piece: X along the wall, the lane on +Y)."""
    face = FACE + 0.3
    body = solid("qt_bath_portal__body-col", r, ["persian_tile"], lambda bm: add_box(bm, -0.2, 4.2, FACE - 0.05, face, 0.0, 6.0))
    cut(body, solid("cutter", r, ["persian_tile"], lambda bm: arch_at(bm, 2.0, -0.05, 2.3, 2.5, FACE - 0.2, face + 0.2)))
    solid("qt_bath_portal__door", r, [WOOD], lambda bm: arch_at(bm, 2.0, 0.0, 2.3, 2.5, FACE - 0.04, FACE + 0.02))
    solid("qt_bath_portal__lamp", r, [GLOW], lambda bm: add_lathe(bm, [(0.0, 2.75), (0.16, 2.9), (0.16, 3.12), (0.0, 3.25)], 2.0, FACE + 0.14, 8), recalc=False)
    solid("qt_bath_portal__coping", r, [BRICK], lambda bm: add_box(bm, -0.3, 4.3, FACE - 0.05, face + 0.08, 6.0, 6.18))
    marker("LIGHT_home__portal", r, (2.0, 1.5, 3.0))


def pigeon(r):
    """The pigeon tower: a round pale tower closing a lane, rows of small dark
    nest holes, brick bands, a tiled cap. Origin at its foot."""
    wall = [(3.4, 0.0), (3.3, 2.0), (3.1, 6.0), (2.9, 10.0), (2.75, 12.4)]
    solid("qt_pigeon__body", r, [LIME], lambda bm: add_lathe(bm, wall, segs=24), recalc=False)

    def radius(z):
        for (r0, z0), (r1, z1) in zip(wall, wall[1:]):
            if z <= z1:
                return r0 + (r1 - r0) * (z - z0) / (z1 - z0)
        return wall[-1][0]

    def bands(bm):
        for z in (3.9, 7.1, 10.2):
            add_lathe(bm, [(radius(z) + 0.1, z), (radius(z) + 0.1, z + 0.2)], segs=24)
    solid("qt_pigeon__bands", r, [BRICK], bands, recalc=False)
    solid("qt_pigeon__rim", r, [BRICK], lambda bm: add_lathe(bm, [(2.75, 12.3), (3.0, 12.45), (3.0, 12.8), (2.6, 12.9)], segs=24), recalc=False)
    solid("qt_pigeon__cap", r, ["persian_dome_tile"], lambda bm: add_lathe(bm, [(2.6, 12.9), (2.0, 13.8), (1.0, 14.5), (0.0, 14.8)], segs=24), recalc=False)

    bm = bmesh.new()
    row, z = 0, 1.5
    while z < 12.0:
        if not any(abs(z - b - 0.1) < 0.3 for b in (3.9, 7.1, 10.2)):
            n = 28
            for i in range(n):
                a = 2 * math.pi * (i + 0.5 * (row % 2)) / n
                c, s = math.cos(a), math.sin(a)
                rad = radius(z) + 0.02
                tx, ty = -s * 0.11, c * 0.11
                px, py = rad * c, rad * s
                bm.faces.new([bm.verts.new(p) for p in ((px - tx, py - ty, z - 0.15), (px + tx, py + ty, z - 0.15),
                                                        (px + tx, py + ty, z + 0.15), (px - tx, py - ty, z + 0.15))])
        row += 1
        z += 0.52
    mesh_object("qt_pigeon__holes", bm, [DARK], r, recalc=False)
    solid("qt_pigeon__window", r, [GLOW], lambda bm: add_box(bm, -0.3, 0.3, -3.06, -2.9, 8.2, 9.3))
    marker("LIGHT_home__pigeon_a", r, (0.0, -3.9, 8.6))
    marker("LIGHT_home__pigeon_b", r, (0.0, -4.6, 3.2))


def rock_wall(z0, seed, windows=0, top=ROCK_TOP):
    """One cell of the cavern's wall, facing +Y: X 0..4, rough in the middle
    and flat at its ends, so any tile meets any other."""
    def build(r):
        name = r.name[2:]
        bm = bmesh.new()
        nx, nz = 6, 14
        grid = []
        for i in range(nx + 1):
            x = 4.0 * i / nx
            env = math.sin(math.pi * x / 4.0)
            col = []
            for k in range(nz + 1):
                z = z0 + (top - z0) * k / nz
                col.append(bm.verts.new((x, max(0.0, 0.25 + 0.55 * rough(x, 0.0, z, seed)) * env, z)))
            grid.append(col)
        for i in range(nx):
            for k in range(nz):
                bm.faces.new((grid[i][k], grid[i][k + 1], grid[i + 1][k + 1], grid[i + 1][k]))     # facing +Y, into the room
        for f in bm.faces:
            f.normal_update()
        mesh_object(name + "__rock", bm, [ROCK], r, recalc=False)
        if z0 < 1.0:
            solid(name + "__wall-colonly", r, [ROCK], lambda b: add_box(b, 0.0, 4.0, -0.6, 0.0, -1.0, 8.0))
        rng = random.Random(int(seed * 31.0) + 3)
        spots = [(rng.uniform(0.6, 3.4), rng.uniform(10.6, 14.5)) for _ in range(windows)]
        for i, (x, z) in enumerate(spots):
            # A far terraced house: a small lit window on a dark ledge.
            solid(name + "__ledge_%d" % i, r, ["persian_rock_dressed"], lambda b, x=x, z=z: add_box(b, x - 0.55, x + 0.55, -0.05, 0.95, z - 0.14, z - 0.04))
            solid(name + "__face_%d" % i, r, ["persian_rock_dressed"], lambda b, x=x, z=z: add_box(b, x - 0.45, x + 0.45, -0.05, 0.75, z - 0.04, z + 0.95))
            arch_face(r, name + "__far_%d" % i, GLOW, x, z + 0.14, 0.34, 0.3, 0.76)
    return build


def cavern(r):
    """The roof over the whole room, facing down: low at the walls, higher over
    the middle. Origin at the room's south-west corner."""
    bm = bmesh.new()
    nx, ny = 36, 32
    vs = []
    for i in range(nx + 1):
        x = ROOM_W * i / nx
        row = []
        for j in range(ny + 1):
            y = ROOM_D * j / ny
            dome = (math.sin(math.pi * x / ROOM_W) * math.sin(math.pi * y / ROOM_D)) ** 0.7
            row.append(bm.verts.new((x, y, 15.0 + 6.0 * dome + rough(x, y, 3.0, 5.0) * 2.2)))
        vs.append(row)
    for i in range(nx):
        for j in range(ny):
            bm.faces.new((vs[i][j], vs[i][j + 1], vs[i + 1][j + 1], vs[i + 1][j]))
    mesh_object("qt_cavern__roof", bm, [ROCK], r, recalc=False)
    # Under everything: nothing falls out if a house is flown through.
    solid("qt_cavern__floor-col", r, [ROCK], lambda b: add_box(b, 0.0, ROOM_W, 0.0, ROOM_D, -0.9, -0.5))


def cavern_neck(n):
    """The low roof over an entry alley, three cells wide, n cells long. Origin
    at its south-west corner."""
    def build(r):
        name = r.name[2:]
        bm = bmesh.new()
        nx, ny = 12, 4 * n
        vs = [[bm.verts.new((float(i), float(j), 10.0 + rough(i, j, 3.0, 9.0) * 0.5)) for j in range(ny + 1)] for i in range(nx + 1)]
        for i in range(nx):
            for j in range(ny):
                bm.faces.new((vs[i][j], vs[i][j + 1], vs[i + 1][j + 1], vs[i + 1][j]))
        mesh_object(name + "__roof", bm, [ROCK], r, recalc=False)
        solid(name + "__floor-col", r, [ROCK], lambda b: add_box(b, 0.0, 12.0, 0.0, 4.0 * n, -0.9, -0.5))
    return build


def door_lamp(r):
    """A small lantern on a bracket, on a house front (an edge piece, X at the
    bracket, the lane on +Y). The grammar puts a real light beside it."""
    solid("qt_door_lamp__arm", r, [WOOD], lambda bm: add_box(bm, -0.03, 0.03, FACE, FACE + 0.3, 2.3, 2.36))
    solid("qt_door_lamp__hood", r, ["brass"], lambda bm: add_lathe(bm, [(0.13, 2.14), (0.15, 2.17), (0.0, 2.3)], 0.0, FACE + 0.26, 6), recalc=False)
    solid("qt_door_lamp__glass", r, ["emit_lantern"], lambda bm: add_lathe(bm, [(0.05, 1.86), (0.11, 1.92), (0.11, 2.12), (0.05, 2.15)], 0.0, FACE + 0.26, 6), recalc=False)


def hung(name, r, items, line_z=4.7, sag=0.22):
    """A rope across the lane (X 0.3..3.7 at Y 2) with cloths pegged on it:
    items are (x, width, drop, atlas column). The map's v runs from 0 at the
    rope to 1 at the hem, so the wind moves the hem most."""
    def z_at(x):
        t = (x - 0.3) / 3.4
        return line_z - sag * 4.0 * t * (1.0 - t)

    def rope(bm):
        for i in range(8):
            a, b = 0.3 + 3.4 * i / 8.0, 0.3 + 3.4 * (i + 1) / 8.0
            add_box(bm, a, b, 1.985, 2.015, min(z_at(a), z_at(b)) - 0.015, max(z_at(a), z_at(b)) + 0.015)
    solid(name + "__rope", r, [WOOD], rope)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    for (x, w, drop, col) in items:
        u0, u1 = col / 4.0, (col + 1) / 4.0
        n = 3
        rows = []
        for k in range(n + 1):
            t = k / float(n)
            rows.append([bm.verts.new((x + dx, 2.0 + 0.04 * math.sin(t * 3.0 + x), z_at(x + dx) - drop * t)) for dx in (0.0, w)])
        for k in range(n):
            f = bm.faces.new((rows[k + 1][0], rows[k + 1][1], rows[k][1], rows[k][0]))
            v0, v1 = k / float(n), (k + 1) / float(n)
            for loop, t in zip(f.loops, ((u0, v1), (u1, v1), (u1, v0), (u0, v0))):
                loop[uv].uv = t
    mesh_object(name + "__cloth", bm, ["quarter_cloth"], r, recalc=False)


def washing(items):
    def build(r):
        hung(r.name[2:], r, items)
    return build


def chimney(r):
    solid("qt_chimney__stack", r, [BRICK], lambda bm: add_box(bm, -0.3, 0.3, -0.3, 0.3, -0.1, 1.0))
    solid("qt_chimney__cap", r, [STONE], lambda bm: add_box(bm, -0.38, 0.38, -0.38, 0.38, 1.0, 1.1))


def home_front(tint):
    """A ground front you can walk through: as qt_g_door, but the doorway and
    the window are cut right through the wall. Door centred on X 1.2, 1.3 wide."""
    def build(r):
        name = r.name[2:]
        body = solid(name + "__body-col", r, [TINTS[tint]], lambda bm: add_box(bm, 0.0, 4.0, BACK, FACE, 0.0, SH))

        def cutter(bm):
            arch_at(bm, 1.2, -0.05, 1.3, 1.75, BACK - 0.2, FACE + 0.3)
            arch_at(bm, 3.0, 1.2, 0.8, 0.7, BACK - 0.2, FACE + 0.3)
        cut(body, solid("cutter", r, [TINTS[tint]], cutter))
        inner = [(1.2 - 0.65 + u, v) for (u, v) in arch_outline(1.3, 1.75, 0.6, 6)][1:-1]
        outer = [(1.2 - 0.81 + u, v) for (u, v) in arch_outline(1.62, 1.77, 0.6, 6)][1:-1]
        solid(name + "__arch", r, [BRICK], lambda bm: arch_ring(bm, inner, outer, 0.1, FACE + 0.05, smooth=False), recalc=False)
        solid(name + "__step", r, [STONE], lambda bm: add_box(bm, 0.45, 1.95, 0.0, FACE + 0.42, 0.0, 0.12))
        bm = bmesh.new()
        uv = bm.loops.layers.uv.new("UVMap")
        add_card(bm, uv, (3.0, 0.0, 1.2), 0.8, 1.2)
        mesh_object(name + "__screen", bm, [LATTICE], r, recalc=False)
        solid(name + "__bars-colonly", r, [WOOD], lambda bm: add_box(bm, 2.6, 3.4, -0.02, 0.02, 1.2, 2.4))
        solid(name + "__sill", r, [STONE], lambda bm: add_box(bm, 2.48, 3.52, 0.0, FACE + 0.1, 1.11, 1.2))

        def plinth(bm):
            add_box(bm, 0.0, 0.38, FACE - 0.02, FACE + 0.04, 0.0, 0.48)
            add_box(bm, 2.02, 4.0, FACE - 0.02, FACE + 0.04, 0.0, 0.48)
        solid(name + "__plinth", r, [BRICK], plinth)
        solid(name + "__band", r, [WOOD], lambda bm: add_box(bm, 0.0, 4.0, FACE - 0.02, FACE + 0.05, SH - 0.13, SH))
    return build


def home_room(cells):
    """The room behind a home front, cells deep: X 0.42..3.58, back from the
    front's inner face to Y -d, a floor running out under the wall to the lane,
    a boarded and beamed ceiling at 2.7 m."""
    d = 4.0 * cells - 0.4

    def build(r):
        name = r.name[2:]
        solid(name + "__floor-col", r, ["quarter_lane"], lambda bm: add_box(bm, 0.3, 3.7, -d - 0.02, 0.0, -0.3, 0.0))

        def walls(bm):
            add_box(bm, 0.3, 0.42, -d - 0.02, BACK, 0.0, 2.8)
            add_box(bm, 3.58, 3.7, -d - 0.02, BACK, 0.0, 2.8)
            add_box(bm, 0.3, 3.7, -d - 0.1, -d + 0.02, 0.0, 2.8)
        solid(name + "__walls-col", r, [LIME], walls)

        def dado(bm):
            add_box(bm, 0.42, 0.44, -d + 0.02, BACK, 0.0, 0.9)
            add_box(bm, 3.56, 3.58, -d + 0.02, BACK, 0.0, 0.9)
            add_box(bm, 0.42, 3.58, -d + 0.02, -d + 0.04, 0.0, 0.9)
        solid(name + "__dado", r, ["persian_plaster"], dado)
        solid(name + "__ceiling", r, [WOOD], lambda bm: add_box(bm, 0.3, 3.7, -d - 0.02, BACK, 2.7, 2.8))

        def beams(bm):
            y = -0.9
            while y > -d + 0.2:
                add_box(bm, 0.42, 3.58, y - 0.07, y + 0.07, 2.56, 2.7)
                y -= 0.85
        solid(name + "__beams", r, [WOOD], beams)
        if cells == 2:
            # Two rooms, not a corridor: a plaster wall with an arch in it.
            wall = solid(name + "__partition-col", r, [LIME], lambda bm: add_box(bm, 0.42, 3.58, -3.9, -3.7, 0.0, 2.72))
            cut(wall, solid("cutter", r, [LIME], lambda bm: arch_at(bm, 2.0, -0.05, 1.5, 1.8, -4.1, -3.5)))
    return build


def home_leaf(r):
    """The door, its hinge at the origin, X along the leaf when shut."""
    solid("qt_home_leaf__boards", r, [WOOD], lambda bm: add_prism(bm, arch_outline(1.26, 1.74, 0.6, 6), 0.02, 0.0, -0.03, 0.03))

    def studs(bm):
        for z in (0.5, 1.1, 1.7):
            for x in (0.25, 0.65, 1.05):
                add_box(bm, x - 0.025, x + 0.025, -0.05, 0.05, z - 0.025, z + 0.025)
        add_box(bm, 1.06, 1.14, -0.07, 0.07, 1.0, 1.08)
    solid("qt_home_leaf__iron", r, ["brass"], studs)


def home_hides(r):
    """A hunter's wall (a wall piece: centred on X, its back at Y -0.25, facing
    +Y): two stretched hides on frames, pelts on a rail, a strung bow."""
    def frames(bm):
        for cx in (-0.75, 0.35):
            add_box(bm, cx - 0.5, cx - 0.44, -0.22, -0.16, 0.5, 2.15)
            add_box(bm, cx + 0.44, cx + 0.5, -0.22, -0.16, 0.5, 2.15)
            add_box(bm, cx - 0.55, cx + 0.55, -0.22, -0.16, 2.05, 2.11)
            add_box(bm, cx - 0.55, cx + 0.55, -0.22, -0.16, 0.6, 0.66)
    solid("qt_home_hides__frames", r, [WOOD], frames)

    def hides(bm):
        for cx in (-0.75, 0.35):
            outline = [(-0.36, 0.72), (-0.42, 1.2), (-0.32, 1.98), (0.0, 2.02), (0.32, 1.98), (0.42, 1.2), (0.36, 0.72), (0.0, 0.68)]
            bm.faces.new([bm.verts.new((cx + u, -0.19, v)) for (u, v) in outline])
    solid("qt_home_hides__hides", r, ["quarter_hide"], hides, recalc=False)
    bm = bmesh.new()
    add_tube(bm, [(1.15, -0.18, 0.75 + 1.3 * t) for t in (0.0, 1.0)], 0.012)
    add_tube(bm, [(1.15 + 0.2 * math.sin(math.pi * t), -0.18, 0.75 + 1.3 * t) for t in [i / 8.0 for i in range(9)]], 0.022)
    mesh_object("qt_home_hides__bow", bm, [WOOD], r)


def moved(bm, build, m):
    """Builds into bm, then moves only what was just added."""
    before = set(bm.verts)
    build(bm)
    bmesh.ops.transform(bm, matrix=m, verts=[v for v in bm.verts if v not in before])


def person(r, name, hip, lean, hands, low=False, robe="gorge_cloth", hood="persian_awning"):
    """A robed figure, facing -Y (Godot +Z): a skirt to `hip` (a low, wide one
    for someone sitting or kneeling), the body leaning `lean` radians forward,
    a hood with a shadowed face, sleeves to `hands` (two points)."""
    rb, hd, shade, hb = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    if low:
        add_lathe(rb, [(0.34, 0.0), (0.36, 0.12), (0.22, hip)], 0.0, 0.1, segs=8)
    else:
        add_lathe(rb, [(0.31, 0.0), (0.27, 0.3), (0.2, hip)], segs=8)
    body = Matrix.Translation((0.0, 0.0, hip)) @ Matrix.Rotation(lean, 4, "X")
    moved(rb, lambda bm: add_lathe(bm, [(0.2, 0.0), (0.21, 0.3), (0.18, 0.48), (0.09, 0.54)], segs=8), body)
    head = body @ Matrix.Translation((0.0, -0.04, 0.48))
    moved(hd, lambda bm: add_lathe(bm, [(0.0, 0.0), (0.18, 0.04), (0.17, 0.2), (0.12, 0.3), (0.0, 0.35)], segs=8), head)
    moved(shade, lambda bm: add_lathe(bm, [(0.0, 0.0), (0.09, 0.02), (0.09, 0.16), (0.0, 0.18)], segs=6),
          head @ Matrix.Translation((0.0, -0.09, 0.16)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
    for k, hx in enumerate((-0.19, 0.19)):
        sh = body @ Vector((hx, 0.0, 0.44))
        hp = Vector(hands[k])
        el = (sh + hp) / 2 + Vector((hx * 0.3, 0.04, -0.02))
        add_tube(rb, [tuple(sh), tuple(el), tuple(hp + Vector((0.0, 0.0, 0.05)))], [0.07, 0.06, 0.055], segs=6)
        moved(hb, lambda bm: add_lathe(bm, [(0.0, -0.045), (0.04, -0.03), (0.036, 0.04), (0.0, 0.045)], segs=5), Matrix.Translation(hp))
    mesh_object(name + "__robe", rb, [robe], r)
    mesh_object(name + "__hood", hd, [hood], r)
    mesh_object(name + "__shade", shade, [DARK], r)
    mesh_object(name + "__hands", hb, ["camp_leather"], r)
    solid(name + "-colonly", r, [STONE], lambda bm: add_box(bm, -0.3, 0.3, -0.42, 0.32, 0.0, 1.0 if low else 1.5))


def fig_stand(r):
    """At a door with folded arms, looking down the lane."""
    person(r, "qt_fig_stand", 0.92, 0.03, [(-0.08, -0.24, 1.08), (0.1, -0.24, 1.1)])


def fig_jar(r):
    """On the way home with a water jar on the hip."""
    person(r, "qt_fig_jar", 0.92, 0.06, [(0.33, -0.12, 0.98), (0.2, -0.26, 0.8)], robe="quarter_hide")
    solid("qt_fig_jar__jar", r, ["quarter_brick"], lambda bm: add_lathe(bm, [(0.05, 0.72), (0.15, 0.8), (0.17, 0.95), (0.1, 1.12), (0.06, 1.2), (0.08, 1.24)], 0.34, -0.16, segs=8), recalc=False)


def fig_sit(r):
    """Sitting on a step, hands on the knees."""
    person(r, "qt_fig_sit", 0.4, 0.08, [(-0.2, -0.38, 0.36), (0.2, -0.38, 0.36)], low=True, robe="quarter_hide")


def fig_read(r):
    """Cross-legged with an open book."""
    person(r, "qt_fig_read", 0.4, 0.3, [(-0.14, -0.42, 0.5), (0.14, -0.42, 0.5)], low=True)

    def book(bm):
        add_box(bm, -0.16, 0.0, -0.54, -0.36, 0.5, 0.53)
        add_box(bm, 0.0, 0.16, -0.54, -0.36, 0.5, 0.53)
    solid("qt_fig_read__book", r, [LIME], book)


def fig_stir(r):
    """Kneeling at the hearth, a spoon in the pot."""
    person(r, "qt_fig_stir", 0.38, 0.42, [(-0.2, -0.38, 0.4), (0.12, -0.56, 0.62)], low=True, robe="quarter_hide")
    bm = bmesh.new()
    add_tube(bm, [(0.12, -0.54, 0.66), (0.0, -0.95, 0.62)], 0.012, segs=5)
    mesh_object("qt_fig_stir__spoon", bm, [WOOD], r)


def fig_mend(r):
    """Sitting at a table, mending a snare."""
    person(r, "qt_fig_mend", 0.42, 0.34, [(-0.16, -0.46, 0.66), (0.16, -0.46, 0.66)], low=True)


def note(r):
    """Two sheets, a little apart."""
    def sheets(bm):
        add_box(bm, -0.09, 0.09, -0.125, 0.125, 0.0, 0.006)
        moved(bm, lambda b: add_box(b, -0.09, 0.09, -0.125, 0.125, 0.006, 0.012), Matrix.Translation((0.03, 0.02, 0.0)) @ Matrix.Rotation(0.3, 4, "Z"))
    solid("qt_home_note__sheets", r, [LIME], sheets)


def glow(r):
    marker("LIGHT_home__window", r, (0.0, 0.0, 0.0))


MODULES = []
for lvl, kinds in (("g", ("door", "lit", "dark", "blank")), ("u", ("lit", "dark", "blank"))):
    for k in kinds:
        for t in TINTS:
            for wd in (2, 4):
                MODULES.append(("M_qt_%s_%s_%s_%d" % (lvl, k, t, wd), props(), front(lvl, k, t, wd)))
for t in TINTS:
    for wd in (2, 4):
        MODULES.append(("M_qt_cap_%s_%d" % (t, wd), props(), cap(t, wd)))
MODULES += [
    ("M_qt_pier", props(), pier),
    ("M_qt_pier_cap", props(), pier_cap),
    ("M_qt_roof", props(), roof),
    ("M_qt_lane", props(), lane(True)),
    ("M_qt_lane_plain", props(), lane(False)),
    ("M_qt_stair", props(), stair),
    ("M_qt_lane_high", props(), lane_high),
    ("M_qt_gate", props(), gate),
    ("M_qt_sabat", props(), sabat),
    ("M_qt_hauz", props(), hauz),
    ("M_qt_rock_wall", props(), rock_wall(-1.0, 2.0)),
    ("M_qt_rock_wall_b", props(), rock_wall(-1.0, 13.0)),
    ("M_qt_rock_wall_lit", props(), rock_wall(-1.0, 7.0, 3)),
    ("M_qt_rock_wall_top", props(), rock_wall(9.4, 21.0)),
    ("M_qt_cavern", props(), cavern),
    ("M_qt_glow", props(), glow),
    ("M_qt_rock_low", props(), rock_wall(-1.0, 3.0, 0, 11.2)),
    ("M_qt_rock_low_b", props(), rock_wall(-1.0, 17.0, 0, 11.2)),
    ("M_qt_rock_low_top", props(), rock_wall(9.4, 23.0, 0, 11.2)),
    ("M_qt_cavern_neck_2", props(), cavern_neck(2)),
    ("M_qt_cavern_neck_3", props(), cavern_neck(3)),
    ("M_qt_badgir", props(), badgir),
    ("M_qt_bath", props(), bath),
    ("M_qt_bath_portal", props(), bath_portal),
    ("M_qt_pigeon", props(), pigeon),
    ("M_qt_door_lamp", props(), door_lamp),
    ("M_qt_washing_a", props(), washing([(0.5, 0.6, 0.9, 0), (1.25, 0.5, 0.75, 0), (1.9, 0.7, 1.0, 3), (2.75, 0.55, 0.8, 0)])),
    ("M_qt_washing_b", props(), washing([(0.6, 0.8, 1.05, 1), (1.6, 0.5, 0.7, 0), (2.3, 0.85, 1.1, 2)])),
    ("M_qt_cloth", props(), washing([(0.9, 2.2, 1.5, 2)])),
    ("M_qt_chimney", props(), chimney),
    ("M_qt_g_home_r", props(), home_front("r")),
    ("M_qt_g_home_c", props(), home_front("c")),
    ("M_qt_home_1", props(), home_room(1)),
    ("M_qt_home_2", props(), home_room(2)),
    ("M_qt_home_leaf", props(), home_leaf),
    ("M_qt_home_hides", props(), home_hides),
    ("M_qt_home_note", props(), note),
    ("M_qt_fig_stand", props(), fig_stand),
    ("M_qt_fig_jar", props(), fig_jar),
    ("M_qt_fig_sit", props(), fig_sit),
    ("M_qt_fig_read", props(), fig_read),
    ("M_qt_fig_stir", props(), fig_stir),
    ("M_qt_fig_mend", props(), fig_mend),
    ("M_qt_rags", props(), washing([(0.55, 0.16, 0.5, 0), (0.95, 0.3, 0.8, 3), (1.75, 0.12, 0.35, 1), (2.35, 0.22, 0.65, 2), (3.0, 0.14, 0.45, 0)])),
]

# Script-made modules remade in place at a new revision (kit_blender.rebuild).
# Rev 3: the quarter's own brick (step 2). Nobody has edited these in Blender yet.
REBUILD = [(n, {"M_qt_home_2": 4, "M_qt_home_hides": 4, "M_qt_fig_jar": 4, "M_qt_fig_sit": 4, "M_qt_fig_stir": 4}.get(n, 3)) for (n, _p, _b) in MODULES]


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
    rebuilt = ["%s (rev %d)" % (n, v) for (n, v) in REBUILD if rebuild(n, v, MODULES)]
    if not added and not rebuilt:
        print("kit_add_r06: everything already present; nothing to do.")
        return
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("kit_add_r06: added %d; rebuilt %s" % (len(added), ", ".join(rebuilt) or "nothing"))


main()
