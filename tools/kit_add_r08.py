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
"""
import math
import os
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit_blender import add_box, arch_ring, marker, mesh_object, module, rebuild  # noqa: E402

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


def props(size=(3, 1, 2), tags="scriptorium,r08"):
    return {"kit_shape": "free", "kit_family": "walls", "size_cells": list(size), "edge": "", "tags": tags, "weight": 1.0}


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


MODULES = [
    ("M_sc_orosi_wall", props((3, 1, 2)), orosi_wall),
    ("M_sc_moss_garden", props((3, 1, 3)), moss_garden),
]
REBUILD = [("M_sc_orosi_wall", 2), ("M_sc_moss_garden", 1)]


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
