"""Seeds the R08 Orosi Scriptorium modules into art_src/kit/kit_scriptorium.blend
(phase 17, docs/environment/phase-17-approval.md).

  blender --background --factory-startup --python tools/kit_add_r08.py

Creates kit_scriptorium.blend if it doesn't exist, then adds only the modules
that are not in it yet (hand edits are kept), and remakes those in REBUILD.
Then run tools/export_kit.bat kit_scriptorium.blend, then
`godot --headless --script res://tools/r08_glass.gd` (the glass and the light
pictures it throws, read from the imported wall), then import again.

The hall is 12 m wide (three 4 m cells) and about 6.4 m high. Wall frame
(sc_orosi_wall, sc_moss_garden): the far wall's left end at X 0, X 0..12, the
wall's room face on Y 0 looking -Y (into the hall), the garden behind it on +Y.

  sc_orosi_wall   the far wall: plaster, three tall pointed openings (the middle
                  one widest), each filled with an orosi: a wooden sash frame,
                  a transom at the arch's springing, mullions, and coloured
                  glass (emit_sc_glass_mid / _side, written by r08_glass.gd);
                  a light behind each (LIGHT_orosi), throwing a picture of its
                  window's glass across the hall (its projector, r08_glass.gd)
  sc_moss_garden  the lumen-moss garden behind the glass: a narrow rock slot
                  with glowing warm moss on its floor and back wall, a lumen
                  stone high up (where the three window lights stand), and a
                  dim warm fill so the glass glows from behind

Step 2, the hall (ScriptoriumGrammar). Edge pieces use the kit's edge frame:
X 0..4 along the wall, the wall astride Y 0 (Y -0.3..0.3), the room on +Y
(Godot -Z), floor to HEIGHT in one piece.

  sc_niche_wall_4m  cream lime plaster with niches (taqcheh): two small pointed
                    ones low down, a wide one above them, a dark wood cornice
                    under the ceiling and a wood skirting
  sc_door_wall_4m   the same wall round the kit's 3 m doorway (X 0.5..3.5),
                    a wood frame round the arch, a small niche over it
  sc_ceiling_12m    the timber ceiling over one 4 m bay of the 12 m hall:
                    dark planks at HEIGHT, three beams across (1.33 m apart).
                    Frame: X 0..12, Y 0..4 (one bay), from the hall's left wall
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit_blender import (T, add_box, add_lathe, add_obox, add_prism, add_tube, arch_outline, arch_ring, cut,  # noqa: E402
                         marker, mesh_object, module, rebuild)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(ROOT, "art_src", "kit", "kit_scriptorium.blend")
ROW_Y = -260.0
PLASTER, WOOD, ROCK = "persian_plaster_lime", "persian_wood", "cave_rock"
GLASS_MID, GLASS_SIDE = "emit_sc_glass_mid", "emit_sc_glass_side"
MOSS, LUMEN = "emit_sc_lumenmoss", "emit_lumen"

WIDTH = 12.0          # the hall's width
HEIGHT = 6.4          # its walls' height, to the timber ceiling
THICK = 0.5           # the far wall's thickness
GLASS_Y = 0.32        # the glass sits this far back in the opening
SILL = 0.35           # the openings' foot over the floor
# The three openings: (centre X, half width, springing over the sill, rise of the arch).
WINDOWS = ((2.6, 1.4, 3.0, 1.75), (6.0, 1.6, 3.2, 1.95), (9.4, 1.4, 3.0, 1.75))
# The light behind each window: this far behind the wall's room face and this high,
# aimed through the window's middle (the floor picture runs from the wall to about 7 m in).
LIGHT_BACK, LIGHT_UP = 3.6, 8.2
GARDEN_DEPTH = 4.4    # the slot behind the wall, from its back face
GARDEN_TOP = 10.0


def props(size=(3, 1, 2), tags="scriptorium,r08", shape="free", edge=""):
    return {"kit_shape": shape, "kit_family": "walls", "size_cells": list(size), "edge": edge, "tags": tags, "weight": 1.0}


def pointed(half, spring, rise, n=10):
    """A pointed arch's outline in XZ, centred on X 0, from the left foot round
    to the right foot (tools/kit_add_persian.py's pointed())."""
    centre = (half * half - rise * rise) / (2 * half)
    cr = half - centre
    angle = math.atan2(rise, -centre)
    pts = [(-half, 0.0), (-half, spring)]
    for i in range(1, n):
        t = 1 - abs(2 * i / n - 1)
        side = -1.0 if i < n / 2 else 1.0
        pts.append((side * (centre + cr * math.cos(angle * t)), spring + cr * math.sin(angle * t)))
    return pts + [(half, spring), (half, 0.0)]


def solid(name, root, mats, build, recalc=True):
    bm = bmesh.new()
    build(bm)
    return mesh_object(name, bm, mats, root, recalc)


def quad(bm, a, b, c, d, mat=0):
    bm.faces.new([bm.verts.new(p) for p in (a, b, c, d)]).material_index = mat


def wall_body(bm):
    """The plaster wall from boxes round the three openings (no booleans): below
    the sills, the piers between them, and over each arch a strip per segment.
    Both faces are kept: the garden side shows through the glass."""
    y0, y1 = 0.0, THICK
    add_box(bm, 0.0, WIDTH, y0, y1, 0.0, SILL)
    edges = [0.0]
    for (cx, half, _s, _r) in WINDOWS:
        edges += [cx - half, cx + half]
    edges.append(WIDTH)
    for i in range(0, len(edges), 2):
        add_box(bm, edges[i], edges[i + 1], y0, y1, SILL, HEIGHT)
    for (cx, half, spring, rise) in WINDOWS:
        pts = pointed(half, spring, rise)[1:-1]
        for (xa, za), (xb, zb) in zip(pts[:-1], pts[1:]):
            q = [(xa, za), (xb, zb), (xb, HEIGHT - SILL), (xa, HEIGHT - SILL)]
            a = [bm.verts.new((cx + u, y0, SILL + v)) for (u, v) in q]
            b = [bm.verts.new((cx + u, y1, SILL + v)) for (u, v) in q]
            bm.faces.new(a)
            bm.faces.new(list(reversed(b)))
            bm.faces.new((a[0], a[1], b[1], b[0]))       # the arch's soffit
            bm.faces.new((a[2], a[3], b[3], b[2]))       # the top
        # the jambs' insides are the piers' sides; the sill's top is the base box's


def frame_bars(bm, cx, half, spring, rise):
    """The orosi's wooden sash: a band round the arch, a transom at the springing,
    two mullions below it and a rail across the lower sash, a hair proud of the
    glass on the room side (the glass behind carries the fine lattice)."""
    yf0, yf1 = GLASS_Y - 0.07, GLASS_Y + 0.03
    w = 0.09
    outer = pointed(half, spring, rise)
    inner = pointed(half - w, spring, rise - w)
    arch_ring(bm, [(cx + x, SILL + z) for (x, z) in inner], [(cx + x, SILL + z) for (x, z) in outer], yf0, yf1, smooth=False)
    add_box(bm, cx - half, cx + half, yf0, yf1, SILL, SILL + w)                       # the bottom rail
    add_box(bm, cx - half, cx + half, yf0, yf1, SILL + spring - w / 2, SILL + spring + w / 2)   # the transom
    third = (2 * half) / 3
    for k in (1, 2):
        x = cx - half + third * k
        add_box(bm, x - 0.035, x + 0.035, yf0 - 0.01, yf1, SILL, SILL + spring)       # mullions
    add_box(bm, cx - half, cx + half, yf0 - 0.01, yf1, SILL + spring * 0.42 - 0.03, SILL + spring * 0.42 + 0.03)   # the sash's meeting rail
    # a sill board on the room side
    add_box(bm, cx - half - 0.12, cx + half + 0.12, -0.16, 0.02, SILL - 0.06, SILL)


def glass_face(root, name, mat, cx, half, spring, rise):
    """The glass, one flat face in the opening's outline; UV 0..1 over its bounds
    (r08_glass.gd draws the lattice and panes to the same bounds)."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    pts = pointed(half, spring, rise, n=16)
    top = spring + rise
    f = bm.faces.new([bm.verts.new((cx + x, GLASS_Y, SILL + z)) for (x, z) in pts])
    f.normal_update()
    if f.normal.y > 0.0:      # face the hall
        f.normal_flip()
    for loop in f.loops:
        co = loop.vert.co
        loop[uv].uv = ((co.x - (cx - half)) / (2 * half), (co.z - SILL) / top)
    return mesh_object(name, bm, [mat], root, recalc=False)


def orosi_wall(r):
    name = r.name[2:]
    solid(name + "__body-col", r, [PLASTER], wall_body)
    for i, (cx, half, spring, rise) in enumerate(WINDOWS):
        solid("%s__frame%d" % (name, i), r, [WOOD], lambda bm, w=(cx, half, spring, rise): frame_bars(bm, *w))
        glass_face(r, "%s__glass%d" % (name, i), GLASS_MID if i == 1 else GLASS_SIDE, cx, half, spring, rise)
        # The light: behind and over the window, aimed through its middle. A spot
        # marker shines down its -Z, so tip -Z toward the hall (-Y) and down.
        mid_z = SILL + (spring + rise) * 0.5
        drop = math.atan2(LIGHT_UP - mid_z, LIGHT_BACK)
        m = marker("LIGHT_orosi__%d" % i, r, (cx, LIGHT_BACK, LIGHT_UP),
                   {"window": i, "shadowed": 1 if i == 1 else 0})
        m.rotation_euler = (-(math.pi / 2 - drop), 0.0, 0.0)
    # The glass's own glow on the hall: a soft fill low in front of the middle
    # window (tinted to the palette by OrosiGlass.apply), so the walls and floor
    # near the glass take its colour and the hall is dim, never black.
    marker("LIGHT_orosi_bounce", r, (WIDTH / 2, -1.8, 1.3))
    # A glass collider so nothing walks into the garden (the panes are thin faces).
    solid(name + "__panes-colonly", r, [PLASTER],
          lambda bm: [add_box(bm, cx - half, cx + half, GLASS_Y - 0.02, GLASS_Y + 0.02, SILL, SILL + spring + rise)
                      for (cx, half, spring, rise) in WINDOWS])


def moss_garden(r):
    """The slot behind the wall: rock walls and floor, warm glowing moss on the
    floor and climbing the back, a lumen stone where the window lights stand."""
    name = r.name[2:]
    y0, y1 = THICK, THICK + GARDEN_DEPTH

    def rock(bm):
        add_box(bm, -0.6, WIDTH + 0.6, y0, y1 + 0.6, -0.6, 0.0)               # floor
        add_box(bm, -0.6, WIDTH + 0.6, y1, y1 + 0.6, 0.0, GARDEN_TOP)          # back
        add_box(bm, -0.6, 0.0, y0, y1, 0.0, GARDEN_TOP)                        # ends
        add_box(bm, WIDTH, WIDTH + 0.6, y0, y1, 0.0, GARDEN_TOP)
        add_box(bm, -0.6, WIDTH + 0.6, y0 - 0.0, y1 + 0.6, GARDEN_TOP, GARDEN_TOP + 0.6)   # the slot's roof
        add_box(bm, -0.6, WIDTH + 0.6, y0, y0 + 0.01, HEIGHT, GARDEN_TOP)      # over the wall: the garden is closed
    solid(name + "__rock", r, [ROCK], rock)

    def moss(bm):
        # Low mounds along the floor, and a mat up the back wall, in loose bands.
        x = 0.2
        k = 0
        while x < WIDTH - 0.4:
            w = 0.9 + 0.5 * ((k * 37) % 5) / 4.0
            h = 0.25 + 0.2 * ((k * 53) % 3) / 2.0
            d = 1.0 + 0.6 * ((k * 29) % 4) / 3.0
            add_box(bm, x, min(x + w, WIDTH - 0.2), y1 - d, y1, 0.0, h)
            add_box(bm, x + 0.1, min(x + w - 0.1, WIDTH - 0.3), y1 - 0.08, y1, h, h + 1.5 + 2.4 * ((k * 41) % 5) / 4.0)
            x += w + 0.15
            k += 1
    solid(name + "__moss", r, [MOSS], moss)

    def stone(bm):
        add_box(bm, WIDTH / 2 - 0.25, WIDTH / 2 + 0.25, y1 - 0.4, y1, LIGHT_UP - 0.3, LIGHT_UP + 0.3)
    solid(name + "__lumen", r, [LUMEN], stone)
    # A dim warm fill in the slot, so the glass is lit from behind evenly
    # (the glass glows by itself; this lights the moss and rock you see through it).
    marker("LIGHT_lumenmoss__fill", r, (WIDTH / 2, y0 + GARDEN_DEPTH * 0.5, 2.0))


# --- step 2: the hall ------------------------------------------------------------

NICHE_PLASTER = "persian_plaster"       # the niches' insides: a shade warmer than the wall
CORNICE = 6.0                           # the wood cornice's foot, up to HEIGHT
FACE = T                                # the walls' room face (Y), as the kit's


def niche_cutter(r, x0, sill, span, spring, depth):
    """A pointed niche's cutter, span wide from x0, its foot at sill, cut depth
    into the room face."""
    return solid("cutter", r, [NICHE_PLASTER],
                 lambda bm: add_prism(bm, arch_outline(span, spring, 0.6, 10), x0, sill, FACE - depth, FACE + 0.2))


def hall_trim(r, name, door=False):
    """The dark wood cornice under the ceiling and a low skirting, proud of the face."""
    solid(name + "__cornice", r, [WOOD], lambda bm: (add_box(bm, 0.0, 4.0, FACE, FACE + 0.12, CORNICE, HEIGHT),
                                                    add_box(bm, 0.0, 4.0, FACE, FACE + 0.2, CORNICE - 0.08, CORNICE + 0.06)))

    def skirting(bm):
        for (a, b) in ([(0.0, 0.5), (3.5, 4.0)] if door else [(0.0, 4.0)]):
            add_box(bm, a, b, FACE, FACE + 0.04, 0.0, 0.18)
    solid(name + "__skirting", r, [WOOD], skirting)


def niche_wall(r):
    name = r.name[2:]
    body = solid(name + "__body-col", r, [PLASTER], lambda bm: add_box(bm, 0.0, 4.0, -T, T, 0.0, HEIGHT))
    for x0 in (0.6, 2.4):
        cut(body, niche_cutter(r, x0, 1.2, 1.0, 1.0, 0.35))
    cut(body, niche_cutter(r, 0.5, 3.4, 3.0, 0.6, 0.3))
    hall_trim(r, name)


def door_wall(r):
    name = r.name[2:]
    body = solid(name + "__body-col", r, [PLASTER], lambda bm: add_box(bm, 0.0, 4.0, -T, T, 0.0, HEIGHT))
    cut(body, solid("cutter", r, [PLASTER], lambda bm: add_prism(bm, arch_outline(3.0, 1.8, 0.6, 12), 0.5, -0.01, -T - 0.2, T + 0.2)))
    cut(body, niche_cutter(r, 1.5, 4.3, 1.0, 0.6, 0.3))
    # A wood frame round the doorway on the room face.
    inner = [(0.5 + u, v) for (u, v) in arch_outline(3.0, 1.8, 0.6, 12)]
    outer = [(0.36 + u, v) for (u, v) in arch_outline(3.28, 1.84, 0.6, 12)]
    solid(name + "__frame", r, [WOOD], lambda bm: arch_ring(bm, inner, outer, FACE - 0.02, FACE + 0.06, smooth=False), recalc=False)
    hall_trim(r, name, door=True)


def ceiling(r):
    name = r.name[2:]
    solid(name + "__planks", r, [WOOD], lambda bm: add_box(bm, 0.0, WIDTH, 0.0, 4.0, HEIGHT, HEIGHT + 0.2))

    def beams(bm):
        for k in range(3):
            y = (k + 0.5) * 4.0 / 3.0
            add_box(bm, 0.0, WIDTH, y - 0.13, y + 0.13, HEIGHT - 0.3, HEIGHT)
    solid(name + "__beams", r, ["wood"], beams)


# --- step 3: desks, copyists and lamps ----------------------------------------------
# A copy place's frame: the copyist kneels at the origin facing -Y (Godot +Z),
# the low desk in front of them (Y -0.85..-0.35, top DESK_TOP).

DESK_TOP = 0.32


def _moved(bm, build, m):
    """Runs `build(bm)` and moves what it added by matrix `m` (kit_add_r15.py's)."""
    before = set(bm.verts)
    build(bm)
    bmesh.ops.transform(bm, matrix=m, verts=[v for v in bm.verts if v not in before])


def copy_desk(lamp, state="tended"):
    """A low copy desk. `state` (phase 17 step 4, the busy-to-abandoned walk):
    "tended" the copy under way, everything to hand; "left" the copy left half
    done: the cushion pushed back, the pen and a sheet dropped on the floor;
    "dust" nobody has come back: dust over the desk, the pages and the cushion,
    more sheets on the floor, a cobweb on the rahl. A lamp on a dust desk is
    cold (no flame, no light)."""
    left, dust = state in ("left", "dust"), state == "dust"
    paper = "sc_dust" if dust else "pages"

    def build(r):
        name = r.name[2:]

        def desk(bm):
            add_box(bm, -0.6, 0.6, -0.85, -0.35, DESK_TOP - 0.05, DESK_TOP)          # the top
            for x in (-0.55, 0.55):                                                    # two plank ends for legs
                add_box(bm, x - 0.04, x + 0.04, -0.82, -0.38, 0.0, DESK_TOP - 0.05)
            add_box(bm, -0.55, 0.55, -0.83, -0.79, 0.04, DESK_TOP - 0.05)              # the back apron
        solid(name + "__desk", r, ["persian_wood"], desk)
        if dust:
            solid(name + "__dust", r, ["sc_dust"], lambda bm: add_box(bm, -0.58, 0.58, -0.83, -0.37, DESK_TOP, DESK_TOP + 0.003))

        def stand(bm):
            # The rahl on the desk's back: two leaves crossed, open as a V, holding
            # the book being copied.
            add_obox(bm, (0.0, -0.7, DESK_TOP + 0.14), (0.46, 0.02, 0.3), (math.radians(-28), 0.0, 0.0))
            add_box(bm, -0.24, 0.24, -0.8, -0.62, DESK_TOP, DESK_TOP + 0.02)
        solid(name + "__rahl", r, ["wood"], stand)

        def exemplar(bm):
            for side in (-1, 1):
                add_obox(bm, (side * 0.105, -0.68, DESK_TOP + 0.17), (0.2, 0.012, 0.27), (math.radians(-28), side * math.radians(8), 0.0))
        solid(name + "__exemplar", r, [paper], exemplar)
        solid(name + "__cover", r, ["book_leather"], lambda bm: add_obox(bm, (0.0, -0.69, DESK_TOP + 0.165), (0.44, 0.01, 0.29), (math.radians(-28), 0.0, 0.0)))

        def sheet(bm):
            add_box(bm, -0.2, 0.18, -0.58, -0.4, DESK_TOP, DESK_TOP + 0.006)           # the copy, half written
            add_box(bm, 0.25, 0.5, -0.62, -0.44, DESK_TOP, DESK_TOP + 0.03)            # fresh sheets
            if left:
                add_obox(bm, (0.78, -0.08, 0.003), (0.19, 0.26, 0.004), (0.0, 0.0, 0.5))     # one slid to the floor
            if dust:
                add_obox(bm, (-0.82, -0.3, 0.003), (0.19, 0.26, 0.004), (0.0, 0.0, -0.9))
                add_obox(bm, (0.55, 0.35, 0.005), (0.19, 0.26, 0.004), (0.0, 0.0, 1.9))
        solid(name + "__sheets", r, [paper], sheet)

        def ink(bm):
            add_lathe(bm, [(0.0, 0.0), (0.04, 0.0), (0.045, 0.035), (0.02, 0.05), (0.0, 0.05)], 0.36, -0.4, segs=8)
            add_box(bm, -0.42, -0.26, -0.48, -0.42, 0.0, 0.012)                        # a pen box
        _moved_ink = bmesh.new()
        ink(_moved_ink)
        bmesh.ops.translate(_moved_ink, verts=_moved_ink.verts, vec=(0.0, 0.0, DESK_TOP))
        mesh_object(name + "__ink", _moved_ink, ["iron"], r)
        if left:       # dropped beside the cushion
            solid(name + "__pen", r, ["wood"], lambda bm: add_obox(bm, (0.42, 0.18, 0.012), (0.012, 0.22, 0.012), (0.0, 0.0, 1.2)))
        else:
            solid(name + "__pen", r, ["wood"], lambda bm: add_obox(bm, (0.05, -0.46, DESK_TOP + 0.01), (0.012, 0.22, 0.012), (0.0, 0.0, 0.5)))
        # The cushion the copyist kneels on (pushed back when the copy was left),
        # and a pile of scrolls to the right.
        if left:
            solid(name + "__cushion", r, ["sc_dust" if dust else "cushion_termeh"], lambda bm: add_obox(bm, (0.1, 0.16, 0.05), (0.64, 0.54, 0.1), (0.0, 0.0, 0.35)))
        else:
            solid(name + "__cushion", r, ["cushion_termeh"], lambda bm: add_box(bm, -0.32, 0.32, -0.22, 0.32, 0.0, 0.1))

        def scrolls(bm):
            for (x, y, z, rot) in ((0.95, -0.5, 0.05, 0.1), (0.95, -0.66, 0.05, -0.05), (0.95, -0.34, 0.05, 0.0), (0.95, -0.58, 0.14, 0.2)):
                _moved(bm, lambda b: add_lathe(b, [(0.0, -0.22), (0.045, -0.22), (0.045, 0.22), (0.0, 0.22)], segs=7),
                       Matrix.Translation((x, y, z)) @ Matrix.Rotation(math.pi / 2, 4, "X") @ Matrix.Rotation(rot, 4, "Y"))
        solid(name + "__scrolls", r, [paper], scrolls)
        if dust:
            # A cobweb from the rahl's top to the desk's corner and the scrolls.
            top = (0.22, -0.76, DESK_TOP + 0.27)

            def web(bm):
                for end in ((0.58, -0.8, DESK_TOP), (0.58, -0.55, DESK_TOP), (0.9, -0.66, 0.12), (0.4, -0.84, DESK_TOP - 0.02)):
                    mid = tuple((a + b) / 2 for a, b in zip(top, end))
                    add_tube(bm, [top, (mid[0], mid[1], mid[2] - 0.02), end], [0.0025, 0.002, 0.0025], segs=3)
            web_bm = bmesh.new()
            web(web_bm)
            mesh_object(name + "__web", web_bm, ["cobweb"], r)
        if lamp:
            # A small brass oil lamp on the desk's left corner (the near half's
            # only light: Light in the brief, low and on the desks).
            on_desk = Matrix.Translation((0.0, 0.0, DESK_TOP))
            solid(name + "__lamp", r, ["brass"], lambda bm: (
                _moved(bm, lambda b: add_lathe(b, [(0.0, 0.0), (0.05, 0.0), (0.06, 0.03), (0.03, 0.06), (0.0, 0.065)], -0.45, -0.45, segs=8), on_desk),
                _moved(bm, lambda b: add_obox(b, (-0.38, -0.45, 0.045), (0.08, 0.02, 0.015), (0.0, 0.0, 0.0)), on_desk)))
            if not dust:
                solid(name + "__flame", r, ["emit_lantern"], lambda bm: _moved(
                    bm, lambda b: add_lathe(b, [(0.0, 0.0), (0.012, 0.012), (0.008, 0.04), (0.0, 0.055)], -0.33, -0.45, segs=6),
                    Matrix.Translation((0.0, 0.0, DESK_TOP + 0.05))))
                marker("LIGHT_desk__copy", r, (-0.33, -0.45, DESK_TOP + 0.2))
        solid(name + "-colonly", r, ["persian_wood"], lambda bm: add_box(bm, -0.62, 0.62, -0.87, -0.33, 0.0, 0.5))
    return build


def _figure(r, name, hip, lean, hands):
    """A kneeling copyist (kit_add_r15.py's worker, kneeling): a robe from the
    ground to `hip`, the body leaning `lean` radians toward the desk (-Y), a
    hood with a shaded face, sleeves from the shoulders to `hands`."""
    from mathutils import Vector
    robe, hood, shade, hb = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    add_lathe(robe, [(0.3, 0.0), (0.33, 0.12), (0.22, hip)], 0.0, 0.12, segs=8)
    body = Matrix.Translation((0.0, 0.0, hip)) @ Matrix.Rotation(lean, 4, "X")
    _moved(robe, lambda bm: add_lathe(bm, [(0.21, 0.0), (0.22, 0.3), (0.19, 0.5), (0.1, 0.56)], segs=8), body)
    head = body @ Matrix.Translation((0.0, -0.04, 0.5))
    _moved(hood, lambda bm: add_lathe(bm, [(0.0, 0.0), (0.2, 0.04), (0.19, 0.2), (0.14, 0.32), (0.0, 0.38)], segs=8), head)
    _moved(shade, lambda bm: add_lathe(bm, [(0.0, 0.0), (0.1, 0.02), (0.1, 0.18), (0.0, 0.2)], segs=6),
           head @ Matrix.Translation((0.0, -0.1, 0.17)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
    for k, hx in enumerate((-0.2, 0.2)):
        sh = body @ Vector((hx, 0.0, 0.46))
        hp = Vector(hands[k])
        el = (sh + hp) / 2 + Vector((hx * 0.3, 0.04, -0.02))
        add_tube(robe, [tuple(sh), tuple(el), tuple(hp + Vector((0.0, 0.0, 0.05)))], [0.075, 0.065, 0.06], segs=6)
        _moved(hb, lambda bm: add_lathe(bm, [(0.0, -0.05), (0.045, -0.03), (0.04, 0.04), (0.0, 0.05)], segs=5), Matrix.Translation(hp))
    mesh_object(name + "__robe", robe, ["gorge_cloth"], r)
    mesh_object(name + "__hood", hood, ["camp_cloth"], r)
    mesh_object(name + "__shade", shade, ["culvert_dark"], r)
    mesh_object(name + "__hands", hb, ["camp_leather"], r)
    solid(name + "-colonly", r, ["persian_wood"], lambda bm: add_box(bm, -0.3, 0.3, -0.3, 0.35, 0.0, 1.0))


def copyist_write(r):
    """Bent to the desk, the pen hand on the copy, the other steadying it."""
    _figure(r, "sc_copyist_write", 0.42, 0.55, [(-0.14, -0.46, DESK_TOP + 0.02), (0.06, -0.5, DESK_TOP + 0.02)])


def copyist_read(r):
    """Upright, reading over a sheet held up to the light."""
    name = "sc_copyist_read"
    _figure(r, name, 0.42, 0.12, [(-0.16, -0.36, 0.66), (0.16, -0.36, 0.66)])
    solid(name + "__sheet", r, ["pages"], lambda bm: add_obox(bm, (0.0, -0.39, 0.74), (0.3, 0.008, 0.38), (math.radians(-12), 0.0, 0.0)))


MODULES = [
    ("M_sc_orosi_wall", props((3, 1, 2)), orosi_wall),
    ("M_sc_moss_garden", props((3, 1, 3)), moss_garden),
    ("M_sc_niche_wall_4m", props((1, 1, 0), shape="edge", edge="solid"), niche_wall),
    ("M_sc_door_wall_4m", props((1, 1, 0), shape="edge", edge="opening_3m"), door_wall),
    ("M_sc_ceiling_12m", props((3, 1, 1)), ceiling),
    ("M_sc_copy_desk", dict(props((1, 0, 1), "scriptorium,r08,desk"), kit_family="dressing"), copy_desk(False)),
    ("M_sc_copy_desk_lamp", dict(props((1, 0, 1), "scriptorium,r08,desk,lamp"), kit_family="dressing"), copy_desk(True)),
    ("M_sc_copyist_write", dict(props((1, 0, 1), "scriptorium,r08,figure"), kit_family="dressing"), copyist_write),
    ("M_sc_copyist_read", dict(props((1, 0, 1), "scriptorium,r08,figure"), kit_family="dressing"), copyist_read),
    ("M_sc_copy_desk_left", dict(props((1, 0, 1), "scriptorium,r08,desk"), kit_family="dressing"), copy_desk(False, "left")),
    ("M_sc_copy_desk_dust", dict(props((1, 0, 1), "scriptorium,r08,desk"), kit_family="dressing"), copy_desk(False, "dust")),
    ("M_sc_copy_desk_dust_lamp", dict(props((1, 0, 1), "scriptorium,r08,desk,lamp"), kit_family="dressing"), copy_desk(True, "dust")),
]
REBUILD = [("M_sc_orosi_wall", 2), ("M_sc_moss_garden", 1), ("M_sc_copyist_write", 2), ("M_sc_copyist_read", 2)]   # copyists rev 2: a solid robe (gorge_cloth)


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
        x += 16.0
    rebuilt = ["%s (rev %d)" % (n, v) for (n, v) in REBUILD if rebuild(n, v, MODULES)]
    if not added and not rebuilt:
        print("kit_add_r08: everything already present; nothing to do.")
        return
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("kit_add_r08: added %d; rebuilt %s" % (len(added), ", ".join(rebuilt) or "nothing"))


main()
