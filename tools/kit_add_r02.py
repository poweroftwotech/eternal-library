"""Adds the R02 Stack Gallery modules to art_src/kit/kit_walls.blend
(ENVIRONMENT_PLAN.md phase 2, slice 2).

  blender --background --factory-startup --python tools/kit_add_r02.py

Additive, like kit_add_r01.py: opens the hand-edited .blend, adds only the
modules that are not in it yet, and saves. Then run tools/export_kit.bat.

New modules (laid out on a row at Blender Y = -40 for viewing):
  vault_cross_4m   cell 1x1: a groin vault, two of vault_bay_4m's pointed
                   barrels crossing. Every side shows the same arch as the
                   barrel's end, so it meets a barrel on any side and takes a
                   wall_gable_4m on a closed one. For corridor corners, later
                   T-junctions and crossings.
"""
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit_blender import H, T, arch_outline, mesh_object, module  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(ROOT, "art_src", "kit", "kit_walls.blend")
ROW_Y = -40.0
BAY = 4.0
VAULT_K = 0.6     # vault_bay_4m's pointedness
VAULT_N = 10      # and its profile resolution


def props(shape, size, edge, tags, weight=1.0):
    return {"kit_shape": shape, "kit_family": "walls", "size_cells": size, "edge": edge,
            "tags": tags, "weight": weight}


def profiles():
    """vault_bay_4m's cross-sections: intrados over the 3.4 m between wall
    faces, extrados over the full 4 m. (across, height) pairs, springing to
    springing, crown in the middle."""
    inner = [(T + u, H + v) for (u, v) in arch_outline(BAY - 2 * T, 0.0, VAULT_K, VAULT_N)[1:-1]]
    outer = [(u, H + v) for (u, v) in arch_outline(BAY, 0.0, VAULT_K, VAULT_N)[1:-1]]
    return inner, outer


# The four sectors of a groin vault. Each is a piece of one barrel: its profile
# runs across the sector's face and it extends from that face to the
# diagonals, where it meets its neighbours at the crease. point(along, across)
# gives the plan position of a profile point `across` at depth `along` from
# the face.
SECTORS = {
    "W": lambda along, across: (along, across),
    "E": lambda along, across: (BAY - along, across),
    "S": lambda along, across: (across, along),
    "N": lambda along, across: (across, BAY - along),
}
FACE_OUT = {"W": Vector((-1, 0, 0)), "E": Vector((1, 0, 0)), "S": Vector((0, -1, 0)), "N": Vector((0, 1, 0))}


def sector(bm, profile, side):
    """Strip faces for one sector of one surface; returns them."""
    at = SECTORS[side]
    faces = []
    for k in range(len(profile) - 1):
        (u0, z0), (u1, z1) = profile[k], profile[k + 1]
        d0, d1 = BAY / 2 - abs(u0 - BAY / 2), BAY / 2 - abs(u1 - BAY / 2)   # depth to the diagonal
        quad = [(at(0.0, u0), z0), (at(d0, u0), z0), (at(d1, u1), z1), (at(0.0, u1), z1)]
        verts = []
        for (xy, z) in quad:
            v = (xy[0], xy[1], z)
            if not verts or (Vector(v) - verts[-1].co).length > 1e-5:
                verts.append(bm.verts.new(v))
        if len(verts) >= 3 and (verts[0].co - verts[-1].co).length > 1e-5:
            faces.append(bm.faces.new(verts))
    return faces


def orient(bm, faces, want):
    """Flip faces whose normal disagrees with want(face centre) (a direction)."""
    bm.normal_update()
    flip = [f for f in faces if f.normal.dot(want(f.calc_center_median())) < 0.0]
    if flip:
        bmesh.ops.reverse_faces(bm, faces=flip)


def vault_cross(r):
    inner, outer = profiles()
    centre = Vector((BAY / 2, BAY / 2, H))      # under the crown: inside the vault
    bm = bmesh.new()
    for side in SECTORS:
        intrados = sector(bm, inner, side)
        orient(bm, intrados, lambda c: centre - c)                    # faces the room
        for f in intrados:
            f.smooth = True                     # smooth within a sector; the creases stay sharp
        extrados = sector(bm, outer, side)
        orient(bm, extrados, lambda c: c - centre)
        for f in extrados:
            f.smooth = True
        # End cap on the cell face, between the two profiles (as vault_bay_4m's caps).
        at = SECTORS[side]
        caps = []
        for k in range(len(inner) - 1):
            ring = [(at(0.0, inner[k][0]), inner[k][1]), (at(0.0, outer[k][0]), outer[k][1]),
                    (at(0.0, outer[k + 1][0]), outer[k + 1][1]), (at(0.0, inner[k + 1][0]), inner[k + 1][1])]
            caps.append(bm.faces.new([bm.verts.new((xy[0], xy[1], z)) for (xy, z) in ring]))
        out = FACE_OUT[side]
        orient(bm, caps, lambda _c: out)
    mesh_object("vault_cross_4m__body-col", bm, ["vault_plaster"], r, recalc=False)


MODULES = [
    ("M_vault_cross_4m", props("cell", [1, 1, 1], "", "plaster,ceiling,cross"), vault_cross),
]


def main():
    if not os.path.exists(BLEND):
        print("kit_add_r02: %s not found; run kit_seed_walls.py first." % BLEND)
        sys.exit(1)
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    added = []
    x = 0.0
    for (name, p, build) in MODULES:
        if bpy.data.objects.get(name) is None:
            build(module(name, (x, ROW_Y, 0.0), p))
            added.append(name)
        x += 8.0
    if not added:
        print("kit_add_r02: everything already present; nothing to do.")
        return
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("kit_add_r02: added " + ", ".join(added))


main()
