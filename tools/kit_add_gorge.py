"""Seeds the gorge's architecture into art_src/kit/kit_gorge.blend
(phase-6-design.md 5.7.2 and 5.7.10, step 1).

  blender --background --factory-startup --python tools/kit_add_gorge.py

Creates kit_gorge.blend if it doesn't exist, then adds only the modules that
are not in it yet. Modules already in the file (including ones you edited by
hand) are never touched, so re-running is safe. Then run tools/export_kit.bat.

The gorge was built by code (scripts/vista.gd); these pieces are modelled to
its shapes, fitted to the kit's 4 m bay and 4 m storey: a facade bay is one
storey tall (today's bays ran 4.3-4.6 m, so the arches and stacks are a
little shorter), a tier is 2 or 3 storeys (today 8.3-11.7 m). Materials are
the gorge's own, copied from the camp into kit/materials/gorge_*.tres by
tools/gorge_materials.gd.

A face piece's frame (Blender): X 0..4 along the tier's face, the face at
Y = 0, the tier behind it (+Y), its ornament out over the gorge (-Y); Z up
from the storey's floor. GorgeGrammar places it like an edge module on the
tier cell's outward side (CellGrid.edge_transform).

New modules (laid out on a row at Blender Y = -120 for viewing):
  gorge_wall_4m / _aged / _clean
                     edge: one storey of tier wall, the weathered ashlar in
                     its three ages (picked per tier, as today)
  gorge_bay_window / _balcony / _doorway
                     edge: a pointed arch frame round a lit lattice window;
                     with a balcony slab and balusters; a tall doorway with
                     a step (a figure stands in some, a separate piece)
  gorge_bay_stack_window (+ _near)
                     edge: books behind a deep-set window
                     (where nothing in front of a stack can be stood on)
  gorge_soffit       cell: a tier's underside where it overhangs the tier
                     below
  gorge_bay_stack / _stack_ladder (+ _near)
                     edge: a framed book stack under a cornice; with a
                     rolling ladder; _near: the candle-lit books of the
                     stacks within 110 m of the overlook
  gorge_bay_panel    edge: a faience panel under a stone lintel
  gorge_pier / _streaked
                     edge: the slim projecting support at the left end of a
                     face (X = 0), one storey; rain-stained
  gorge_deck         cell: the faience deck on a tier's exposed top
  gorge_deck_edge / _streaked / _mossy
                     edge: the deck's 2.2 m overhang: faience slab, gold
                     band, gold rails, two balusters (lamps are separate)
  gorge_crown_edge / _worn / _broken
                     edge: the top tier's overhang with stepped merlons
                     (a capless and a repaired one; one lost)
  gorge_deck_corner / gorge_crown_corner
                     post: the overhang's square at an outside corner
  gorge_figure       free: the seated reader (a scale marker)
  gorge_cypress_5 / _6 / _8
                     free: lathed cypress, 5, 6.3 and 7.6 m
  gorge_pavilion_4 / _8
                     free: four gold posts under a tented roof, 4.3 and 7.5 m
  gorge_banner_0 / _1 / _2
                     free: a tapestry hanging below a deck edge
  gorge_lamp / gorge_lamp_big
                     free: the small glowing lamp box (0.14 and 0.3 m)
  gorge_wall_4m_faience
                     edge: the sanctum's tier wall (gorge_pier stone)
  gorge_tower_wall_stone / _window_stone
                     edge: the same in clean stone (most storeys; faience in bands)
  gorge_tower_wall / _window
                     edge: a Persian tower's storey; with a lit window
  gorge_tower_band   edge: the faience course over a gold band, every two
                     storeys
  gorge_tower_crown / _corner
                     edge / post: the tower's 1.1 m crown with merlons
  gorge_carpet       free: a carpet hung down a tower's face (4.5 x 6.5 m)
  aqueduct_upper_12m / aqueduct_lower_12m
                     cell, 3 bays: the aqueduct's round-arch tiers (12 and
                     20 m tall, a faience course over the lower one), in a
                     frame along the aqueduct, hanging below Z = 0
  aqueduct_pier_20m  post: a plain pier, stacked into the mist
  aqueduct_deck_12m  cell: the deck, its faience course, gold rails and
                     balusters
  aqueduct_landing   free: the round faience landing at each end
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit_blender import (add_box, add_card, add_lathe, add_ngon_prism, add_prism, marker, mesh_object, module, rebuild)  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(ROOT, "art_src", "kit", "kit_gorge.blend")
ROW_Y = -120.0
H = 4.0            # storey
OVER = 2.2         # a deck's overhang past the tier face
DECK_TOP = 0.15    # the deck's top over the tier's top (today: -0.5 .. +0.15)


def props(shape, size, edge, tags, family="walls", weight=1.0):
    return {"kit_shape": shape, "kit_family": family, "size_cells": size,
            "edge": edge, "tags": tags, "weight": weight}


def solid(name, root, mats, build):
    bm = bmesh.new()
    build(bm)
    return mesh_object(name, bm, mats, root)


def pointed(half, spring, rise, n=12):
    """A pointed arch's outline in the XZ plane, centred on X = 0, from the
    left foot round to the right foot (vista.gd's pointed_top)."""
    centre = (half * half - rise * rise) / (2 * half)
    cr = half - centre
    angle = math.atan2(rise, -centre)
    pts = [(-half, 0.0), (-half, spring)]
    for i in range(1, n):
        t = 1 - abs(2 * i / n - 1)
        side = -1.0 if i < n / 2 else 1.0
        pts.append((side * (centre + cr * math.cos(angle * t)), spring + cr * math.sin(angle * t)))
    pts += [(half, spring), (half, 0.0)]
    return pts


def arch_frame(root, name, z0):
    """vista.gd's arch frame (arcade_outline): a pointed ring 0.43 deep out
    from the face, outer 3.3 m wide, inner 2.74, as pointed as today's (rise
    2.05 over a 1.65 half span), springing lower to fit a storey."""
    ring = pointed(1.65, 1.55, 2.05) + list(reversed(pointed(1.37, 1.55, 1.78)))
    solid(name + "__frame", root, ["gorge_sandstone"], lambda bm: add_prism(bm, ring, 2.0, z0, -0.52, -0.09))


def window_card(root, name, cx, z0, width, height, y=-0.06):
    """A lit lattice window: a quad facing out (-Y), its map's top at the top."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    add_card(bm, uv, (cx, y, z0), width, height, yaw=0.0)     # it faces -Y: out over the gorge
    mesh_object(name + "__glow", bm, ["gorge_window"], root, recalc=False)


# --- tier walls ----------------------------------------------------------------------

def wall(material):
    def build(r):
        solid(r.name[2:] + "__body", r, [material], lambda bm: add_box(bm, 0.0, 4.0, 0.0, 0.5, 0.0, H))
    return build


# --- facade bays ---------------------------------------------------------------------

BASE = 0.2         # a bay's foot over the storey floor


SILL = 0.58       # a window's sill top over the bay's foot
# Rev 5 windows (walked: the plain ring read too simple, and windows and
# balconies with nothing behind them didn't say how anyone used them): a
# pointed opening in a faience-panelled rectangular frame (an alfiz), a stone
# border and arch ring round it, a sill on brackets, a hood over it; the
# opening set back in the ring's depth.
OPEN = (1.25, 1.55, 1.45)      # the opening's half width, spring and rise over z0
FRAME_HALF = 1.75
FRAME_TOP = 3.45


def front_box(bm, x0, x1, y0, y1, z0, z1):
    """add_box without its back face (at y1, against the wall: never seen;
    thousands of facade bays, so their triangles count)."""
    vs = [bm.verts.new(v) for v in (
        (x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
        (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1))]
    for f in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (3, 0, 4, 7)):
        bm.faces.new([vs[i] for i in f])


def front_prism(bm, outline, x_off, z_off, y0, y1):
    """add_prism without its back cap (at y1, against the wall)."""
    a = [bm.verts.new((x_off + u, y0, z_off + v)) for (u, v) in outline]
    b = [bm.verts.new((x_off + u, y1, z_off + v)) for (u, v) in outline]
    bm.faces.new(a)
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))


def arch(half, spring, rise, foot, n=6):
    """A pointed arch's outline (XZ, centred on X = 0) from its left foot at
    `foot` round to its right foot."""
    pts = pointed(half, spring, rise, n)
    return [(-half, foot)] + pts[1:-1] + [(half, foot)]


def surround(root, name, z0, opening, foot, depth, proud=0.0):
    """The frame round an opening (half, spring, rise; its bottom at `foot`),
    the ring `depth` deep (its inner faces are the opening's reveal), the
    whole frame stood `proud` further out from the wall (filled back to it).
    The panel's opening follows the ring's outer edge (walked: on its inner
    edge, the two faces under the arch fought)."""
    half, spring, rise = opening
    inner = arch(half, spring, rise, foot)
    outer = arch(half + 0.16, spring, rise + 0.16, foot)
    bottom = foot - 0.12
    # Its outer edges stop inside the stone border (rev 9: flush with the
    # border's outer faces, the two fought down the frame's sides).
    e, top = FRAME_HALF - 0.08, FRAME_TOP - 0.08
    bottom_in = bottom + 0.03
    panel = [(-e, bottom_in), (-e, top), (e, top), (e, bottom_in)] \
        + [(x, z if z > foot else bottom_in) for (x, z) in reversed(arch(half + 0.17, spring, rise + 0.17, foot))]
    solid(name + "__panel", root, ["gorge_faience"], lambda bm: front_prism(bm, panel, 2.0, z0, -0.22 - proud, -0.02))

    def stone(bm):
        front_prism(bm, outer + list(reversed(inner)), 2.0, z0, -depth - proud, -0.02)
        for x0 in (-FRAME_HALF, FRAME_HALF - 0.16):
            front_box(bm, 2.0 + x0, 2.0 + x0 + 0.16, -0.32 - proud, -0.02, z0 + bottom, z0 + FRAME_TOP)
        front_box(bm, 2.0 - FRAME_HALF, 2.0 + FRAME_HALF, -0.32 - proud, -0.02, z0 + FRAME_TOP - 0.16, z0 + FRAME_TOP)
        front_box(bm, 2.0 - FRAME_HALF - 0.1, 2.0 + FRAME_HALF + 0.1, -0.46 - proud, -0.02, z0 + FRAME_TOP, z0 + FRAME_TOP + 0.14)   # hood
    solid(name + "__frame", root, ["gorge_sandstone"], stone)


def sill(root, name, z0, proud=0.0, brackets=True):
    def build(bm):
        front_box(bm, 2.0 - FRAME_HALF, 2.0 + FRAME_HALF, -0.48 - proud, -0.02, z0 + SILL - 0.14, z0 + SILL)
        for x in ((2.0 - 1.2, 2.0 + 1.2) if brackets else ()):
            front_box(bm, x - 0.12, x + 0.12, -0.4 - proud, -0.02, z0 + SILL - 0.5, z0 + SILL - 0.14)
    solid(name + "__sill", root, ["gorge_sandstone"], build)


def glow(root, name, z0, opening, foot):
    half, spring, rise = opening
    bm = bmesh.new()
    verts = [bm.verts.new((2.0 + x, -0.04, z0 + z)) for (x, z) in reversed(arch(half, spring, rise, foot))]
    bm.faces.new(verts)
    mesh_object(name + "__glow", bm, ["gorge_window_glow"], root, recalc=False)


def lattice(root, name, z0, opening, foot, y, w=0.08):
    """Wooden bars across an opening: a mullion from its foot to its crown and
    a transom at its spring, each meeting the frame."""
    half, spring, rise = opening

    def bars(bm):
        front_box(bm, 2.0 - w / 2, 2.0 + w / 2, y - w, y, z0 + foot, z0 + spring + rise)
        front_box(bm, 2.0 - half, 2.0 + half, y - w, y, z0 + spring, z0 + spring + w)
    solid(name + "__bars", root, ["gorge_wood"], bars)


def bay_window(r):
    """Rev 5: a lit window in its frame, no balcony."""
    surround(r, "gorge_bay_window", BASE, OPEN, SILL, 0.36)
    sill(r, "gorge_bay_window", BASE)
    glow(r, "gorge_bay_window", BASE, OPEN, SILL)
    lattice(r, "gorge_bay_window", BASE, OPEN, SILL, -0.14)


DOOR = (0.95, 2.35, 1.0)       # a patio door's half width, spring and rise over z0
DOOR_FOOT = 0.45               # the balcony's floor over z0


def bay_balcony(r):
    """Rev 6: a balcony with a patio door onto it (walked: a balcony before a
    window said nothing of how anyone came out onto it): a pair of glazed
    doors, shut (rev 8, walked: shut by default), wood below and barred
    lamplit glass above, a lit fanlight over them; the balcony on two
    brackets, balusters round its open sides, a gold rail."""
    name = "gorge_bay_balcony"
    surround(r, name, BASE, DOOR, DOOR_FOOT, 0.36)
    glow(r, name, BASE, DOOR, DOOR_FOOT)
    half, spring, rise = DOOR

    def wood(bm):
        y0, y1 = -0.24, -0.16
        front_box(bm, 2.0 - half, 2.0 + half, y0, y1, BASE + spring, BASE + spring + 0.08)    # the fanlight's transom
        add_box(bm, 1.96, 2.04, y0, y1, BASE + spring, BASE + spring + rise)
        front_box(bm, 2.0 - half, 2.0 + half, y0, y1, BASE + DOOR_FOOT, BASE + DOOR_FOOT + 0.9)   # the leaves' wooden lower halves
        for x in (2.0 - half, 1.96, 2.0 + half - 0.08):                                       # stiles: the jambs' and the meeting one
            front_box(bm, x, x + 0.08, y0, y1, BASE + DOOR_FOOT + 0.9, BASE + spring)
        for x in (2.0 - half / 2, 2.0 + half / 2):                                            # a glazing bar in each leaf
            front_box(bm, x - 0.025, x + 0.025, y0 + 0.02, y1, BASE + DOOR_FOOT + 0.9, BASE + spring)
        front_box(bm, 2.0 - half, 2.0 + half, y0 + 0.02, y1, BASE + DOOR_FOOT + 1.6, BASE + DOOR_FOOT + 1.65)
    solid(name + "__door", r, ["gorge_wood"], wood)

    def slab(bm):
        front_box(bm, 0.3, 3.7, -1.6, -0.02, BASE + DOOR_FOOT - 0.2, BASE + DOOR_FOOT)
        for x in (0.75, 3.25):
            front_box(bm, x - 0.14, x + 0.14, -1.2, -0.02, BASE + DOOR_FOOT - 0.6, BASE + DOOR_FOOT - 0.2)
        for k in range(5):
            x = 0.6 + k * 0.7
            add_box(bm, x - 0.06, x + 0.06, -1.54, -1.42, BASE + DOOR_FOOT, BASE + DOOR_FOOT + 0.85)
        for x in (0.36, 3.64):
            for y in (-1.1, -0.55):
                add_box(bm, x - 0.06, x + 0.06, y - 0.06, y + 0.06, BASE + DOOR_FOOT, BASE + DOOR_FOOT + 0.85)
    solid(name + "__slab", r, ["gorge_sandstone"], slab)

    def rails(bm):
        add_box(bm, 0.3, 3.7, -1.56, -1.4, BASE + DOOR_FOOT + 0.85, BASE + DOOR_FOOT + 0.95)
        for x in (0.3, 3.58):
            front_box(bm, x, x + 0.12, -1.56, -0.02, BASE + DOOR_FOOT + 0.85, BASE + DOOR_FOOT + 0.95)
    solid(name + "__rail", r, ["gorge_gold"], rails)


STACK_PROUD = 0.35     # a stack window's frame stands this much further out


def bay_stack_window(near=False):
    """Books behind a window, for a stack with nothing in front of it to stand
    on (walked: a stack on a bare wall, or on a balcony nobody could reach,
    didn't say how its books were read): the window's frame stood out from
    the wall (rev 3, walked: the books sat too close behind the window), so
    the stack is 0.9 m back from the light glazing bars at the frame's front."""
    def build(r):
        name = r.name[2:]
        surround(r, name, BASE, OPEN, SILL, 0.55, STACK_PROUD)
        sill(r, name, BASE, STACK_PROUD, brackets=False)
        half, spring, rise = OPEN
        solid(name + "__books", r, ["gorge_stacks_near" if near else "gorge_stacks"],
              lambda bm: front_box(bm, 2.0 - half, 2.0 + half, -0.05, 0.05, BASE + SILL, BASE + spring + rise))
        lattice(r, name, BASE, OPEN, SILL, -0.82, 0.05)
    return build


DOOR_OPEN = (1.15, 2.0, 1.0)   # a pishtaq's door: half width, spring and rise over BASE
PISHTAQ_TOP = 3.35             # its frame's top over BASE (the cornice over it)


def pishtaq(r, name, back, place=None):
    """Rev 4 (fly-mode walk, 2026-10-26: "a proper arch with pishtaq and
    door"): a stone frame round a tiled field, the pointed arch's ring in it,
    a cornice over all; in the arch a pair of wooden doors with iron bands, a
    lit fanlight over them, a step before them. `back`: its own back plate, to
    stand proud of a face (a gallery's door, gorge_door_pishtaq), not on a wall."""
    half, spring, rise = DOOR_OPEN
    inner = arch(half, spring, rise, 0.0)
    outer = arch(half + 0.2, spring, rise + 0.2, 0.0)
    e = 1.62
    field = [(-e, 0.0), (-e, PISHTAQ_TOP), (e, PISHTAQ_TOP), (e, 0.0)] + list(reversed(outer))
    solid(name + "__field", r, ["gorge_faience"], lambda bm: front_prism(bm, field, 2.0, BASE, -0.3, -0.05))

    def stone(bm):
        front_prism(bm, outer + list(reversed(inner)), 2.0, BASE, -0.42, -0.05)          # the arch's ring
        for x0 in (0.2, 3.62):
            front_box(bm, x0, x0 + 0.18, -0.45, -0.05, 0.0, BASE + PISHTAQ_TOP + 0.25)   # the frame's sides
        front_box(bm, 0.2, 3.8, -0.45, -0.05, BASE + PISHTAQ_TOP, BASE + PISHTAQ_TOP + 0.25)
        front_box(bm, 0.1, 3.9, -0.6, -0.05, BASE + PISHTAQ_TOP + 0.25, BASE + PISHTAQ_TOP + 0.4)   # cornice
        front_box(bm, 0.4, 3.6, -1.09, -0.05, 0.0, BASE + 0.1)                           # step
        if back:
            add_box(bm, 0.1, 3.9, -0.05, 0.0, 0.0, BASE + PISHTAQ_TOP + 0.4)
    solid(name + "__frame", r, ["gorge_sandstone"], stone)

    def doors(bm):
        front_box(bm, 2.0 - half, 2.0 + half, -0.12, -0.05, BASE, BASE + spring)
        front_box(bm, 1.98, 2.02, -0.15, -0.12, BASE, BASE + spring)                     # where the leaves meet
        front_box(bm, 2.0 - half, 2.0 + half, -0.15, -0.08, BASE + spring, BASE + spring + 0.08)   # transom
    solid(name + "__doors", r, ["gorge_wood"], doors)
    solid(name + "__bands", r, ["gorge_brass"], lambda bm: [front_box(bm, 2.0 - half, 2.0 + half, -0.14, -0.12, BASE + z, BASE + z + 0.06) for z in (0.45, 1.5)])
    bm = bmesh.new()
    fan = pointed(half, spring, rise, 6)[1:-1]
    bm.faces.new([bm.verts.new((2.0 + x, -0.08, BASE + z)) for (x, z) in reversed(fan)])
    mesh_object(name + "__glow", bm, ["gorge_window_glow"], r, recalc=False)
    if place is not None:
        for o in [c for c in r.children if c.name.startswith(name + "__")]:
            if o.type == "MESH":
                o.data.transform(place)
            else:
                o.location = place @ o.location
    marker("ANCHOR_figure__door", r, (2.0, -0.34, BASE + 0.1))


def bay_doorway(r):
    pishtaq(r, "gorge_bay_doorway", False)


def door_pishtaq(r):
    pishtaq(r, "gorge_door_pishtaq", True)


def bay_stack(ladder, near=False):
    def build(r):
        name = r.name[2:]
        solid(name + "__books", r, ["gorge_stacks_near" if near else "gorge_stacks"], lambda bm: add_box(bm, 0.55, 3.45, -0.03, 0.09, BASE, BASE + 3.4))

        def frames(bm):
            for side in (-1, 1):
                x = 2.0 + side * 1.6
                add_box(bm, x - 0.16, x + 0.16, -0.34, 0.16, 0.0, BASE + 3.5)
            add_box(bm, 0.225, 3.775, -0.365, 0.185, BASE + 3.4, BASE + 3.65)     # lintel
            add_box(bm, 0.1, 3.9, -0.45, 0.27, BASE + 3.65, BASE + 3.8)           # cornice
        solid(name + "__frames", r, ["gorge_sandstone"], frames)
        if ladder:
            def rungs(bm):
                for side in (-1, 1):
                    x = 2.55 + side * 0.22
                    add_box(bm, x - 0.03, x + 0.03, -0.22, -0.16, BASE, BASE + 3.4)
                for k in range(7):
                    z = BASE + 0.35 + k * 0.45
                    add_box(bm, 2.33, 2.77, -0.215, -0.165, z, z + 0.05)
            solid(name + "__ladder", r, ["gorge_wood"], rungs)
    return build


# --- flush bays (phase 6 step 6) ---------------------------------------------------
# Walked in fly mode (2026-10-26): the bays' frames stood 0.5 to 0.9 m out from
# the wall and up close read as boxes stuck on it. These sit in an opening
# through their wall (gorge_wall_*_arch, _rect: the wall's own stone, its back
# closed RECESS in): the frame only a few centimetres proud, the window's glow,
# the stacks and their lattice set back into the wall, as into a room.
RECESS = 0.42      # the opening's depth (the wall is 0.5 thick)
STACK_OPEN = (0.55, 3.45, 3.4)     # a stack's rectangular opening: x0, x1, height over BASE


def wall_open(material, shape):
    """A tier wall with a bay's opening through it: `arch` (OPEN, its foot at
    the sill) or `rect` (STACK_OPEN), closed at the back by a plate."""
    def build(r):
        def body(bm):
            if shape == "arch":
                half, spring, rise = OPEN
                foot = BASE + SILL
                x0, x1, top = 2.0 - half, 2.0 + half, BASE + spring + rise
                add_box(bm, 0.0, 4.0, 0.0, 0.5, 0.0, foot)
                add_box(bm, 0.0, x0, 0.0, 0.5, foot, H)
                add_box(bm, x1, 4.0, 0.0, 0.5, foot, H)
                crown = pointed(half, spring, rise, 6)[1:-1] + [(half, H - BASE), (-half, H - BASE)]
                add_prism(bm, crown, 2.0, BASE, 0.0, 0.5)
            else:
                x0, x1, height = STACK_OPEN
                foot, top = BASE, BASE + height
                add_box(bm, 0.0, 4.0, 0.0, 0.5, 0.0, foot)
                add_box(bm, 0.0, x0, 0.0, 0.5, foot, H)
                add_box(bm, x1, 4.0, 0.0, 0.5, foot, H)
                add_box(bm, x0, x1, 0.0, 0.5, top, H)
            add_box(bm, x0, x1, RECESS, 0.5, foot, top)     # the back plate
        solid(r.name[2:] + "__body", r, [material], body)
    return build


def flush_surround(root, name, opening, foot):
    """surround()'s alfiz, border, ring and hood, a few centimetres proud of
    the wall round its opening (the wall's reveal is the ring's depth)."""
    half, spring, rise = opening
    inner = arch(half, spring, rise, foot)
    outer = arch(half + 0.16, spring, rise + 0.16, foot)
    bottom = foot - 0.12
    e, top = FRAME_HALF - 0.08, FRAME_TOP - 0.08
    bottom_in = bottom + 0.03
    panel = [(-e, bottom_in), (-e, top), (e, top), (e, bottom_in)] \
        + [(x, z if z > foot else bottom_in) for (x, z) in reversed(arch(half + 0.17, spring, rise + 0.17, foot))]
    solid(name + "__panel", root, ["gorge_faience"], lambda bm: front_prism(bm, panel, 2.0, BASE, -0.03, 0.0))

    def stone(bm):
        front_prism(bm, outer + list(reversed(inner)), 2.0, BASE, -0.07, 0.0)
        for x0 in (-FRAME_HALF, FRAME_HALF - 0.16):
            front_box(bm, 2.0 + x0, 2.0 + x0 + 0.16, -0.06, 0.0, BASE + bottom, BASE + FRAME_TOP)
        front_box(bm, 2.0 - FRAME_HALF, 2.0 + FRAME_HALF, -0.06, 0.0, BASE + FRAME_TOP - 0.16, BASE + FRAME_TOP)
        front_box(bm, 2.0 - FRAME_HALF - 0.1, 2.0 + FRAME_HALF + 0.1, -0.16, 0.0, BASE + FRAME_TOP, BASE + FRAME_TOP + 0.12)   # hood
        front_box(bm, 2.0 - FRAME_HALF, 2.0 + FRAME_HALF, -0.14, 0.0, BASE + SILL - 0.12, BASE + SILL)                     # sill
    solid(name + "__frame", root, ["gorge_sandstone"], stone)


def bay_window_flush(r):
    name = r.name[2:]
    flush_surround(r, name, OPEN, SILL)
    half, spring, rise = OPEN
    bm = bmesh.new()
    bm.faces.new([bm.verts.new((2.0 + x, RECESS - 0.02, BASE + z)) for (x, z) in reversed(arch(half, spring, rise, SILL))])
    mesh_object(name + "__glow", bm, ["gorge_window_glow"], r, recalc=False)
    lattice(r, name, BASE, OPEN, SILL, 0.14)


def bay_stack_window_flush(near=False):
    def build(r):
        name = r.name[2:]
        flush_surround(r, name, OPEN, SILL)
        half, spring, rise = OPEN
        solid(name + "__books", r, ["gorge_stacks_near" if near else "gorge_stacks"],
              lambda bm: front_box(bm, 2.0 - half, 2.0 + half, RECESS - 0.06, RECESS, BASE + SILL, BASE + spring + rise))
        lattice(r, name, BASE, OPEN, SILL, 0.06, 0.05)
    return build


def bay_stack_flush(ladder, near=False):
    def build(r):
        name = r.name[2:]
        x0, x1, height = STACK_OPEN
        solid(name + "__books", r, ["gorge_stacks_near" if near else "gorge_stacks"],
              lambda bm: front_box(bm, x0, x1, RECESS - 0.06, RECESS, BASE, BASE + height))

        def frames(bm):
            for side in (-1, 1):
                x = 2.0 + side * 1.6
                front_box(bm, x - 0.16, x + 0.16, -0.06, 0.0, 0.0, BASE + height + 0.1)
            front_box(bm, 0.225, 3.775, -0.08, 0.0, BASE + height, BASE + height + 0.25)     # lintel
            front_box(bm, 0.1, 3.9, -0.18, 0.0, BASE + height + 0.25, BASE + height + 0.4)   # cornice
        solid(name + "__frames", r, ["gorge_sandstone"], frames)
        if ladder:
            def rungs(bm):
                for side in (-1, 1):
                    x = 2.55 + side * 0.22
                    add_box(bm, x - 0.03, x + 0.03, 0.12, 0.18, BASE, BASE + height)
                for k in range(7):
                    z = BASE + 0.35 + k * 0.45
                    add_box(bm, 2.33, 2.77, 0.125, 0.175, z, z + 0.05)
            solid(name + "__ladder", r, ["gorge_wood"], rungs)
    return build


def soffit(r):
    """The underside of a tier where it overhangs the one below (walked, from
    under them the tiers were open shells)."""
    solid("gorge_soffit__slab", r, ["gorge_stone"], lambda bm: add_box(bm, 0.0, 4.0, 0.0, 4.0, 0.0, 0.3))


def bay_panel(r):
    solid("gorge_bay_panel__tiles", r, ["gorge_faience"], lambda bm: add_box(bm, 0.55, 3.45, -0.14, -0.04, BASE + 0.05, BASE + 3.35))
    solid("gorge_bay_panel__lintel", r, ["gorge_sandstone"], lambda bm: add_box(bm, 0.35, 3.65, -0.29, 0.11, BASE + 3.35, BASE + 3.57))


# --- piers, decks and edges ----------------------------------------------------------

def pier(streaked):
    def build(r):
        name = r.name[2:]
        solid(name + "__body", r, ["gorge_pier"], lambda bm: add_box(bm, -0.21, 0.21, -0.535, 0.115, 0.0, H))
        if streaked:
            solid(name + "__streak", r, ["gorge_grime"], lambda bm: add_box(bm, -0.16, 0.16, -0.555, -0.535, H - 3.2, H))
    return build


PAVING = 0.07     # rev 2: decks are walked on: a stone top over the faience slab (its sides stay tiled)


def paved(name, r, x0, x1, y0, y1):
    """A deck slab: faience to just under the top, stone paving on it."""
    solid(name + "__slab", r, ["gorge_faience"], lambda bm: add_box(bm, x0, x1, y0, y1, DECK_TOP - 0.65, DECK_TOP - PAVING))
    solid(name + "__paving", r, ["gorge_sandstone"], lambda bm: add_box(bm, x0, x1, y0, y1, DECK_TOP - PAVING, DECK_TOP))


def deck(r):
    paved("gorge_deck", r, 0.0, 4.0, 0.0, 4.0)


def overhang(bm_name, r, crowned, length=4.0):
    """The overhang's slab and the gold band under its lip."""
    paved(bm_name, r, 0.0, length, -OVER, 0.0)
    solid(bm_name + "__band", r, ["gorge_gold"], lambda bm: add_box(bm, 0.0, length, -OVER - 0.02, -OVER + 0.18, DECK_TOP - 0.98, DECK_TOP - 0.78))


## Inner corners (fly-mode walk, 2026-10-26). Where a face ends against the next
## face round an inside corner (_inner), its overhang stops where that face's
## overhang begins (4 - OVER): the paving isn't doubled. The face starting
## there (_inner_start) keeps its paving (it fills the corner square) but its
## rail starts OVER in, where the other's ends: the two rails meet in an L
## instead of crossing. A one-bay face with inside corners at both ends:
## _inner_both, no rail of its own.
INNER = 4.0 - OVER


def deck_edge(variant, length=4.0, rail_from=0.0):
    def build(r):
        name = r.name[2:]
        overhang(name, r, False, length)
        if rail_from >= length:
            return

        def rails(bm):
            add_box(bm, rail_from, length, -OVER - 0.05, -OVER + 0.05, 1.15 - 0.055, 1.15 + 0.055)
            add_box(bm, rail_from, length, -OVER - 0.08, -OVER + 0.08, -0.2 - 0.09, -0.2 + 0.09)
        solid(name + "__rails", r, ["gorge_gold"], rails)

        def balusters(bm):
            for x in (x for x in (1.0, 3.0) if rail_from < x < length):
                add_box(bm, x - 0.085, x + 0.085, -OVER - 0.085, -OVER + 0.085, DECK_TOP, 1.1)
        solid(name + "__balusters", r, ["gorge_sandstone"], balusters)
        if variant == "streaked":
            def streaks(bm):
                for (x, w) in ((0.9, 0.5), (2.6, 0.7)):
                    add_box(bm, x - w / 2, x + w / 2, -OVER - 0.05, -OVER - 0.02, DECK_TOP - 1.33, DECK_TOP - 0.35)
            solid(name + "__streaks", r, ["gorge_grime"], streaks)
        if variant == "mossy":
            solid(name + "__moss", r, ["gorge_moss"], lambda bm: add_box(bm, 0.4, 3.6, -OVER + 0.1, -OVER + 0.4, DECK_TOP, DECK_TOP + 0.06))
    return build


def merlon(bm, x, steps):
    for step in range(steps):
        w = 0.95 - step * 0.3
        z = DECK_TOP + 0.2 + step * 0.42
        add_box(bm, x - w / 2, x + w / 2, -OVER - 0.21, -OVER + 0.21, z - 0.21, z + 0.21)


def crown_edge(variant, length=4.0, rail_from=0.0):
    def build(r):
        name = r.name[2:]
        overhang(name, r, True, length)
        xs = (0.67, 2.0, 3.33) if length >= 4.0 and rail_from == 0.0 else ((rail_from + length) / 2, length, length)     # an inner corner's: one merlon (the others filtered out)
        steps = {"": (3, 3, 3), "worn": (2, 3, 3), "broken": (3, 0, 3)}[variant]
        solid(name + "__merlons", r, ["gorge_sandstone"], lambda bm: [merlon(bm, x, s) for (x, s) in zip(xs, steps) if s > 0 and rail_from < x < length])
        if variant == "worn":
            solid(name + "__repair", r, ["gorge_repair"], lambda bm: merlon(bm, 3.33 + 0.0, 1))
    return build


def corner(crowned):
    def build(r):
        name = r.name[2:]
        paved(name, r, -OVER, 0.0, -OVER, 0.0)
        if crowned:
            solid(name + "__merlon", r, ["gorge_sandstone"], lambda bm: merlon(bm, -OVER + 0.6, 3))
        else:
            # Rev 3: the rails round both open sides, a stone post at the corner and
            # a baluster on each (rev 1-2 railed one side: walked, the other
            # read as missing).
            def rails(bm):
                for z in (1.15, -0.2):
                    h = 0.055 if z > 0 else 0.09
                    add_box(bm, -OVER - 0.05, -OVER + 0.05, -OVER - 0.05, 0.0, z - h, z + h)
                    add_box(bm, -OVER - 0.05, 0.0, -OVER - 0.05, -OVER + 0.05, z - h, z + h)
            solid(name + "__rails", r, ["gorge_gold"], rails)

            def posts(bm):
                add_box(bm, -OVER - 0.12, -OVER + 0.12, -OVER - 0.12, -OVER + 0.12, DECK_TOP, 1.25)
                for (x, y) in ((-OVER, -OVER / 2), (-OVER / 2, -OVER)):
                    add_box(bm, x - 0.085, x + 0.085, y - 0.085, y + 0.085, DECK_TOP, 1.1)
            solid(name + "__posts", r, ["gorge_sandstone"], posts)
    return build


# --- terrace dressing ----------------------------------------------------------------

def figure(r):
    solid("gorge_figure__robe", r, ["gorge_cloth"], lambda bm: add_lathe(bm, [(0.37, 0.075), (0.22, 1.325)], segs=7))
    solid("gorge_figure__head", r, ["gorge_sandstone"],
          lambda bm: add_lathe(bm, [(0.0, 1.31), (0.13, 1.36), (0.19, 1.5), (0.13, 1.64), (0.0, 1.69)], segs=8))


CYPRESS = [(0.0, 0.0), (0.32, 0.15), (0.62, 1.2), (0.6, 2.6), (0.42, 3.9), (0.18, 4.8), (0.0, 5.2)]


def cypress(height):
    def build(r):
        s = height / 5.2
        solid(r.name[2:] + "__tree", r, ["gorge_cypress"], lambda bm: add_lathe(bm, [(u * s, v * s) for (u, v) in CYPRESS], segs=7))
    return build


def lamp_box(bm, size, z):
    add_box(bm, -size / 2, size / 2, -size / 2, size / 2, z - size * 0.8, z + size * 0.8)


def pavilion(size):
    def build(r):
        name = r.name[2:]

        def posts(bm):
            for sx in (-1, 1):
                for sy in (-1, 1):
                    add_lathe(bm, [(0.12, 0.0), (0.12, 3.6)], cx=sx * size * 0.45, cy=sy * size * 0.45, segs=6)
        solid(name + "__posts", r, ["gorge_gold"], posts)
        roof = [(0.0, 3.2), (size * 0.72, 3.2), (size * 0.62, 3.5), (size * 0.3, 3.9), (0.0, 5.0)]

        def tent(bm):
            add_lathe(bm, roof, segs=4)
            bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 4, 3, "Z"))
        solid(name + "__roof", r, ["gorge_tapestry_0"], tent)
        solid(name + "__lamp", r, ["gorge_lamp"], lambda bm: lamp_box(bm, 0.3, 3.0))
    return build


def banner(i):
    def build(r):
        bm = bmesh.new()
        uv = bm.loops.layers.uv.new("UVMap")
        add_card(bm, uv, (0.0, 0.0, -3.3), 2.0, 3.3)     # facing -Y, out over the gorge
        mesh_object(r.name[2:] + "__cloth", bm, ["gorge_tapestry_%d" % i], r, recalc=False)
    return build


def lamp(size):
    def build(r):
        solid(r.name[2:] + "__glow", r, ["gorge_lamp"], lambda bm: lamp_box(bm, size, 0.0))
    return build


# --- Persian towers (vista.gd persian_tower) ------------------------------------------

def tower_wall(window, material="gorge_pier"):
    """A tower's storey of wall (stone variants: all-faience towers read as too
    busy up close, so most storeys are stone and the faience comes in bands)."""
    def build(r):
        name = r.name[2:]
        solid(name + "__body", r, [material], lambda bm: add_box(bm, 0.0, 4.0, 0.0, 0.5, 0.0, H))
        if window:
            window_card(r, name, 2.0, 0.85, 0.9, 2.3)
    return build


def tower_band(r):
    """A faience course over a gold band at the storey's top (every two storeys)."""
    solid("gorge_tower_band__course", r, ["gorge_faience"], lambda bm: add_box(bm, 0.0, 4.0, -0.22, 0.0, H - 0.5, H))
    solid("gorge_tower_band__gold", r, ["gorge_gold"], lambda bm: add_box(bm, 0.0, 4.0, -0.3, 0.0, H - 0.68, H - 0.52))


def tower_crown(r):
    """The tower's crown: a 1.1 m faience overhang with stepped merlons."""
    solid("gorge_tower_crown__slab", r, ["gorge_faience"], lambda bm: add_box(bm, 0.0, 4.0, -1.1, 0.0, 0.0, 0.6))

    def merlons(bm):
        for x in (0.67, 2.0, 3.33):
            for step in range(3):
                w = 0.95 - step * 0.3
                z = 0.6 + 0.2 + step * 0.42
                add_box(bm, x - w / 2, x + w / 2, -1.1 - 0.21 + 0.3, -1.1 + 0.21 + 0.3, z - 0.21, z + 0.21)
    solid("gorge_tower_crown__merlons", r, ["gorge_sandstone"], merlons)


def tower_crown_corner(r):
    solid("gorge_tower_crown_corner__slab", r, ["gorge_faience"], lambda bm: add_box(bm, -1.1, 0.0, -1.1, 0.0, 0.0, 0.6))


def carpet(r):
    """A carpet hung down a tower's face from its top (4.5 x 6.5 m)."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    add_card(bm, uv, (0.0, 0.0, -6.5), 4.5, 6.5)     # facing -Y
    mesh_object("gorge_carpet__cloth", bm, ["gorge_carpet"], r, recalc=False)


# --- aqueducts (vista.gd bridge, arch_bay) ----------------------------------------------
# A bay's frame: X 0..12 along the aqueduct, Y across it (centred), Z up; the
# arcade hangs below Z = 0 (the deck's underside line).

SPAN = 12.0


def arcade_bay(height, pier):
    """vista.gd's arch_bay: piers at both ends, a round arch between them,
    springing 1.4 m + the arch's radius below the top, solid above."""
    r = SPAN * 0.5 - pier
    spring = -1.4 - r
    pts = [(0.0, -height), (pier, -height), (pier, spring)]
    for i in range(1, 24):
        u = i / 24.0
        pts.append((SPAN * 0.5 - math.cos(math.pi * u) * r, spring + math.sin(math.pi * u) * r))
    pts += [(SPAN - pier, spring), (SPAN - pier, -height), (SPAN, -height), (SPAN, 0.0), (0.0, 0.0)]
    return pts


def aqueduct_upper(r):
    outline = arcade_bay(12.0, 1.2)
    solid("aqueduct_upper_12m__arcade", r, ["gorge_sandstone"], lambda bm: add_prism(bm, outline, 0.0, 0.0, -1.6, 1.6))


def aqueduct_lower(r):
    solid("aqueduct_lower_12m__course", r, ["gorge_faience"], lambda bm: add_box(bm, 0.0, SPAN, -1.9, 1.9, -0.6, 0.0))
    outline = arcade_bay(20.0, 1.5)
    solid("aqueduct_lower_12m__arcade", r, ["gorge_sandstone"], lambda bm: add_prism(bm, outline, 0.0, -0.6, -1.4, 1.4))


def aqueduct_pier(r):
    solid("aqueduct_pier_20m__body", r, ["gorge_background"], lambda bm: add_box(bm, -1.56, 1.56, -1.4, 1.4, -20.0, 0.0))


def aqueduct_deck(r):
    """The deck: a 0.8 m slab 4 m wide, a faience course under it, gold rails
    and balusters every 2.4 m along both sides (lamps are separate)."""
    solid("aqueduct_deck_12m__slab", r, ["gorge_sandstone"], lambda bm: add_box(bm, 0.0, SPAN, -2.0, 2.0, -0.4, 0.4))
    solid("aqueduct_deck_12m__course", r, ["gorge_faience"], lambda bm: add_box(bm, 0.0, SPAN, -2.1, 2.1, -1.0, -0.4))

    def rails(bm):
        for side in (-1, 1):
            add_box(bm, 0.0, SPAN, side * 2.0 - 0.06, side * 2.0 + 0.06, 1.1, 1.2)
    solid("aqueduct_deck_12m__rails", r, ["gorge_gold"], rails)

    def balusters(bm):
        for side in (-1, 1):
            for k in range(5):
                x = 1.2 + k * 2.4
                add_box(bm, x - 0.085, x + 0.085, side * 2.0 - 0.085, side * 2.0 + 0.085, 0.4, 1.1)
    solid("aqueduct_deck_12m__balusters", r, ["gorge_sandstone"], balusters)


def aqueduct_landing(r):
    solid("aqueduct_landing__slab", r, ["gorge_faience"],
          lambda bm: add_ngon_prism(bm, 12, 4.3, -0.6, -PAVING))
    solid("aqueduct_landing__paving", r, ["gorge_sandstone"],
          lambda bm: add_ngon_prism(bm, 12, 4.3, -PAVING, 0.0))


## An aqueduct's end (fly-mode walk, 2026-10-26: the decks ran into the banks'
## walls): a gatehouse facing back along the deck, its door a pishtaq; the
## deck arrives on its landing (X along the deck, -X toward it; the gatehouse
## behind, +X, set into the bank).
def aqueduct_gate(r):
    name = "aqueduct_gate"
    solid(name + "__landing", r, ["gorge_sandstone"], lambda bm: add_box(bm, -3.0, 0.0, -2.6, 2.6, -0.6, 0.0))
    solid(name + "__fascia", r, ["gorge_faience"], lambda bm: add_box(bm, -3.05, 0.0, -2.65, 2.65, -1.3, -0.6))

    def house(bm):
        add_box(bm, 0.0, 6.0, -3.2, 3.2, -1.3, 6.4)                 # the block, back into the bank
        add_box(bm, -0.25, 6.0, -3.4, 3.4, 6.4, 6.75)               # its cornice
        for y in (-3.0, 2.6):
            add_box(bm, -0.3, 0.3, y, y + 0.4, 0.0, 6.4)            # corner piers
    solid(name + "__house", r, ["gorge_stone_clean"], house)
    # The door on the block's face (x 0), facing -X: the pishtaq's frame (built
    # along X 0..4 facing -Y) turned a quarter and centred on the deck.
    pishtaq(r, name + "_door", False, Matrix.Translation((0.0, 2.0, 0.0)) @ Matrix.Rotation(-math.pi / 2, 4, "Z"))


def wall_faience(r):
    solid("gorge_wall_4m_faience__body", r, ["gorge_pier"], lambda bm: add_box(bm, 0.0, 4.0, 0.0, 0.5, 0.0, H))



MODULES = [
    ("M_gorge_wall_4m", props("edge", [1, 1, 0], "solid", "scenery,stone,gorge,wall"), wall("gorge_stone")),
    ("M_gorge_wall_4m_aged", props("edge", [1, 1, 0], "solid", "scenery,stone,gorge,wall"), wall("gorge_stone_aged")),
    ("M_gorge_wall_4m_clean", props("edge", [1, 1, 0], "solid", "scenery,stone,gorge,wall"), wall("gorge_stone_clean")),
    ("M_gorge_bay_window", props("edge", [1, 1, 0], "none", "scenery,gorge,facade,window"), bay_window),
    ("M_gorge_bay_balcony", props("edge", [1, 1, 0], "none", "scenery,gorge,facade,window"), bay_balcony),
    ("M_gorge_bay_doorway", props("edge", [1, 1, 0], "none", "scenery,gorge,facade,door"), bay_doorway),
    ("M_gorge_bay_stack", props("edge", [1, 1, 0], "none", "scenery,gorge,facade,books"), bay_stack(False)),
    ("M_gorge_bay_stack_ladder", props("edge", [1, 1, 0], "none", "scenery,gorge,facade,books"), bay_stack(True)),
    ("M_gorge_bay_stack_near", props("edge", [1, 1, 0], "none", "scenery,gorge,facade,books"), bay_stack(False, True)),
    ("M_gorge_bay_stack_ladder_near", props("edge", [1, 1, 0], "none", "scenery,gorge,facade,books"), bay_stack(True, True)),
    ("M_gorge_bay_panel", props("edge", [1, 1, 0], "none", "scenery,gorge,facade,tile"), bay_panel),
    ("M_gorge_bay_stack_window", props("edge", [1, 1, 0], "none", "scenery,gorge,facade,books,window"), bay_stack_window()),
    ("M_gorge_bay_stack_window_near", props("edge", [1, 1, 0], "none", "scenery,gorge,facade,books,window"), bay_stack_window(True)),
    ("M_gorge_soffit", props("cell", [1, 0, 1], "", "scenery,gorge,deck"), soffit),
    ("M_gorge_pier", props("edge", [1, 1, 0], "none", "scenery,gorge,pier"), pier(False)),
    ("M_gorge_pier_streaked", props("edge", [1, 1, 0], "none", "scenery,gorge,pier"), pier(True)),
    ("M_gorge_deck", props("cell", [1, 0, 1], "", "scenery,gorge,deck"), deck),
    ("M_gorge_deck_edge", props("edge", [1, 0, 0], "none", "scenery,gorge,deck,rail"), deck_edge("")),
    ("M_gorge_deck_edge_streaked", props("edge", [1, 0, 0], "none", "scenery,gorge,deck,rail"), deck_edge("streaked")),
    ("M_gorge_deck_edge_mossy", props("edge", [1, 0, 0], "none", "scenery,gorge,deck,rail"), deck_edge("mossy")),
    ("M_gorge_crown_edge", props("edge", [1, 0, 0], "none", "scenery,gorge,crown"), crown_edge("")),
    ("M_gorge_crown_edge_worn", props("edge", [1, 0, 0], "none", "scenery,gorge,crown"), crown_edge("worn")),
    ("M_gorge_crown_edge_broken", props("edge", [1, 0, 0], "none", "scenery,gorge,crown"), crown_edge("broken")),
    ("M_gorge_deck_edge_inner", props("edge", [1, 0, 0], "none", "scenery,gorge,deck,rail"), deck_edge("", INNER)),
    ("M_gorge_crown_edge_inner", props("edge", [1, 0, 0], "none", "scenery,gorge,crown"), crown_edge("", INNER)),
    ("M_gorge_deck_edge_inner_start", props("edge", [1, 0, 0], "none", "scenery,gorge,deck,rail"), deck_edge("", 4.0, OVER)),
    ("M_gorge_crown_edge_inner_start", props("edge", [1, 0, 0], "none", "scenery,gorge,crown"), crown_edge("", 4.0, OVER)),
    ("M_gorge_deck_edge_inner_both", props("edge", [1, 0, 0], "none", "scenery,gorge,deck"), deck_edge("", INNER, INNER)),
    ("M_gorge_crown_edge_inner_both", props("edge", [1, 0, 0], "none", "scenery,gorge,crown"), crown_edge("", INNER, INNER)),
    ("M_gorge_deck_corner", props("post", [0, 0, 0], "", "scenery,gorge,deck"), corner(False)),
    ("M_gorge_crown_corner", props("post", [0, 0, 0], "", "scenery,gorge,crown"), corner(True)),
    ("M_gorge_figure", props("free", [0, 0, 0], "", "scenery,gorge,figure", family="dressing"), figure),
    ("M_gorge_cypress_5", props("free", [0, 1, 0], "", "scenery,gorge,plant", family="dressing"), cypress(5.0)),
    ("M_gorge_cypress_6", props("free", [0, 2, 0], "", "scenery,gorge,plant", family="dressing"), cypress(6.3)),
    ("M_gorge_cypress_8", props("free", [0, 2, 0], "", "scenery,gorge,plant", family="dressing"), cypress(7.6)),
    ("M_gorge_pavilion_4", props("free", [1, 1, 1], "", "scenery,gorge,pavilion,light", family="dressing"), pavilion(4.3)),
    ("M_gorge_pavilion_8", props("free", [2, 1, 2], "", "scenery,gorge,pavilion,light", family="dressing"), pavilion(7.5)),
    ("M_gorge_banner_0", props("free", [0, 1, 0], "", "scenery,gorge,cloth", family="dressing"), banner(0)),
    ("M_gorge_banner_1", props("free", [0, 1, 0], "", "scenery,gorge,cloth", family="dressing"), banner(1)),
    ("M_gorge_banner_2", props("free", [0, 1, 0], "", "scenery,gorge,cloth", family="dressing"), banner(2)),
    ("M_gorge_lamp", props("free", [0, 0, 0], "", "scenery,gorge,lamp", family="dressing"), lamp(0.14)),
    ("M_gorge_lamp_big", props("free", [0, 0, 0], "", "scenery,gorge,lamp", family="dressing"), lamp(0.3)),
    ("M_gorge_wall_4m_faience", props("edge", [1, 1, 0], "solid", "scenery,stone,gorge,wall"), wall_faience),
    # Flush bays in openings through their walls (phase 6 step 6, fly-mode walk).
    *[("M_%s_%s" % (wall_name, shape), props("edge", [1, 1, 0], "solid", "scenery,stone,gorge,wall"), wall_open(mat, shape))
      for (wall_name, mat) in (("gorge_wall_4m", "gorge_stone"), ("gorge_wall_4m_aged", "gorge_stone_aged"),
                               ("gorge_wall_4m_clean", "gorge_stone_clean"), ("gorge_wall_4m_faience", "gorge_pier"))
      for shape in ("arch", "rect")],
    ("M_gorge_door_pishtaq", props("edge", [1, 1, 0], "none", "scenery,gorge,facade,door"), door_pishtaq),
    ("M_gorge_bay_window_flush", props("edge", [1, 1, 0], "none", "scenery,gorge,facade,window,light"), bay_window_flush),
    ("M_gorge_bay_stack_window_flush", props("edge", [1, 1, 0], "none", "scenery,gorge,facade,books,window"), bay_stack_window_flush()),
    ("M_gorge_bay_stack_window_flush_near", props("edge", [1, 1, 0], "none", "scenery,gorge,facade,books,window"), bay_stack_window_flush(True)),
    ("M_gorge_bay_stack_flush", props("edge", [1, 1, 0], "none", "scenery,gorge,facade,books"), bay_stack_flush(False)),
    ("M_gorge_bay_stack_flush_near", props("edge", [1, 1, 0], "none", "scenery,gorge,facade,books"), bay_stack_flush(False, True)),
    ("M_gorge_bay_stack_ladder_flush", props("edge", [1, 1, 0], "none", "scenery,gorge,facade,books"), bay_stack_flush(True)),
    ("M_gorge_bay_stack_ladder_flush_near", props("edge", [1, 1, 0], "none", "scenery,gorge,facade,books"), bay_stack_flush(True, True)),
    ("M_gorge_tower_wall", props("edge", [1, 1, 0], "solid", "scenery,gorge,tower"), tower_wall(False)),
    ("M_gorge_tower_window", props("edge", [1, 1, 0], "solid", "scenery,gorge,tower,window"), tower_wall(True)),
    ("M_gorge_tower_wall_stone", props("edge", [1, 1, 0], "solid", "scenery,gorge,tower"), tower_wall(False, "gorge_stone_clean")),
    ("M_gorge_tower_window_stone", props("edge", [1, 1, 0], "solid", "scenery,gorge,tower,window"), tower_wall(True, "gorge_stone_clean")),
    ("M_gorge_tower_band", props("edge", [1, 1, 0], "none", "scenery,gorge,tower"), tower_band),
    ("M_gorge_tower_crown", props("edge", [1, 0, 0], "none", "scenery,gorge,tower,crown"), tower_crown),
    ("M_gorge_tower_crown_corner", props("post", [0, 0, 0], "", "scenery,gorge,tower,crown"), tower_crown_corner),
    ("M_gorge_carpet", props("free", [1, 2, 0], "", "scenery,gorge,cloth", family="dressing"), carpet),
    ("M_aqueduct_upper_12m", props("cell", [3, 3, 1], "", "scenery,gorge,aqueduct"), aqueduct_upper),
    ("M_aqueduct_lower_12m", props("cell", [3, 5, 1], "", "scenery,gorge,aqueduct"), aqueduct_lower),
    ("M_aqueduct_pier_20m", props("post", [0, 5, 0], "", "scenery,gorge,aqueduct"), aqueduct_pier),
    ("M_aqueduct_deck_12m", props("cell", [3, 0, 1], "", "scenery,gorge,aqueduct,rail"), aqueduct_deck),
    ("M_aqueduct_gate", props("free", [2, 2, 2], "", "scenery,gorge,aqueduct,door", family="dressing"), aqueduct_gate),
    ("M_aqueduct_landing", props("free", [2, 0, 2], "", "scenery,gorge,aqueduct", family="dressing"), aqueduct_landing),
]

REBUILD = [("M_gorge_bay_window", 9), ("M_gorge_bay_balcony", 10), ("M_gorge_bay_doorway", 4),
           ("M_gorge_bay_stack_window", 5), ("M_gorge_bay_stack_window_near", 5)]   # rev 2: pointed arches; rev 3: the glow fits inside the arch; window 4, balcony 5: lit edge to edge, bars; window 5: a framed window, balcony 6: a patio door; window 6, balcony 7, stack window 2: no faces against the wall (lighter); window 7, balcony 8, stack window 3: no z-fighting under the arch, doors shut, books further back; then lighter again (6-segment arches); then the panel inside the border (z-fighting)
# rev 2: stone paving on the decks (tile reads as a wall or ceiling, not a floor)
REBUILD += [(n, 2) for n in ("M_gorge_deck", "M_gorge_deck_edge", "M_gorge_deck_edge_streaked", "M_gorge_deck_edge_mossy",
                             "M_gorge_crown_edge", "M_gorge_crown_edge_worn", "M_gorge_crown_edge_broken",
                             "M_gorge_deck_corner", "M_gorge_crown_corner", "M_aqueduct_landing")]
REBUILD = [(n, 3 if n == "M_gorge_deck_corner" else v) for (n, v) in REBUILD]     # rev 3: railed on both open sides



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
        x += 10.0
    rebuilt = ["%s (rev %d)" % (n, v) for (n, v) in REBUILD if rebuild(n, v, MODULES)]
    # Tags added since a module was seeded; tags you added by hand stay.
    for (name, p, _b) in MODULES:
        root = bpy.data.objects.get(name)
        have = str(root.get("tags", "")).split(",") if root is not None else []
        missing = [t for t in p["tags"].split(",") if t not in have]
        if root is not None and missing:
            root["tags"] = ",".join([t for t in have if t] + missing)
            rebuilt.append("%s (tags)" % name)
    if not added and not rebuilt:
        print("kit_add_gorge: everything already present; nothing to do.")
        return
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("kit_add_gorge: added %s; rebuilt %s" % (", ".join(added) if added else "nothing", ", ".join(rebuilt) if rebuilt else "nothing"))


main()
