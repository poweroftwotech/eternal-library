"""One-time seed for art_src/kit/kit_walls.blend (ENVIRONMENT_PLAN.md phase 0).

  blender --background --factory-startup --python tools/kit_seed_walls.py [-- --force]

Creates the starter wall-family modules so the export/import pipeline has
something to chew on. After the first run the .blend is the source of truth:
edit it by hand in Blender and do NOT re-run this (it refuses to overwrite
unless --force is given).

Conventions (ENVIRONMENT_PLAN.md section 3):
  * Blender Z up, metres. Godot -Z == Blender +Y, so a cell occupies
    Blender X 0..4, Y 0..4 and an edge module's interior faces +Y.
  * One module = one top-level Empty named M_<family>_<name>; everything under
    it is exported together with the Empty at the origin.
  * Mesh children ending in "-col" get trimesh collision in Godot.
  * Child empties: SNAP_<kind>, SOCKET_<set>, LIGHT_<profile>, ANCHOR_<kind>.
    Text after a double underscore is ignored, so names stay unique per file.
  * Only material slot names matter; Godot swaps in the pixel materials.
    Names starting with "emit_" become glowing materials.
  * Custom properties on the module Empty become KitModule metadata.
"""
import math
import os
import sys

import bmesh
import bpy

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art_src", "kit", "kit_walls.blend")
H = 4.0          # storey
T = 0.3          # half wall thickness
BAND = 0.3       # tile band under the wall top


def material(name):
    return bpy.data.materials.get(name) or bpy.data.materials.new(name)


def mesh_object(name, bm, mats, parent):
    me = bpy.data.meshes.new(name)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(material(m))
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    ob.parent = parent
    return ob


def add_box(bm, x0, x1, y0, y1, z0, z1, mat=0):
    vs = [bm.verts.new(v) for v in (
        (x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
        (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1))]
    for f in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
        bm.faces.new([vs[i] for i in f]).material_index = mat


def arch_outline(span, spring, k=0.6, n=8):
    """Pointed (k > .5) or round (k == .5) arch in the XZ plane, from (0,0) round to (span,0)."""
    r = span * k
    top = []
    for i in range(1, n + 1):
        u = span / 2 * i / n
        top.append((u, spring + math.sqrt(max(0.0, r * r - (u - r) ** 2))))
    pts = [(0.0, 0.0), (0.0, spring)] + top
    pts += [(span - u, v) for (u, v) in reversed(top[:-1])]
    return pts + [(span, spring), (span, 0.0)]


def add_prism(bm, outline, x_off, z_off, y0, y1, mat=0):
    """Extrude an XZ outline along Y (used for boolean cutters)."""
    a = [bm.verts.new((x_off + u, y0, z_off + v)) for (u, v) in outline]
    b = [bm.verts.new((x_off + u, y1, z_off + v)) for (u, v) in outline]
    bm.faces.new(a).material_index = mat
    bm.faces.new(list(reversed(b))).material_index = mat
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i])).material_index = mat


def cut(target, cutter):
    mod = target.modifiers.new("cut", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.solver = "EXACT"
    mod.object = cutter
    if hasattr(mod, "material_mode"):
        mod.material_mode = "TRANSFER"
    # Bake the evaluated result instead of bpy.ops.object.modifier_apply, which
    # needs a UI context and silently does nothing in --background runs.
    depsgraph = bpy.context.evaluated_depsgraph_get()
    baked = bpy.data.meshes.new_from_object(target.evaluated_get(depsgraph))
    old = target.data
    target.modifiers.clear()
    target.data = baked
    bpy.data.meshes.remove(old)
    bpy.data.objects.remove(cutter, do_unlink=True)


def module(name, slot, props):
    root = bpy.data.objects.new(name, None)
    root.empty_display_type = "PLAIN_AXES"
    bpy.context.collection.objects.link(root)
    root.location = (slot * 7.0, 0.0, 0.0)  # laid out in a row for viewing; export resets this
    for k, v in props.items():
        root[k] = v
    return root


def marker(name, parent, loc, props=None):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = "ARROWS"
    e.empty_display_size = 0.4
    bpy.context.collection.objects.link(e)
    e.parent = parent
    e.location = loc
    for k, v in (props or {}).items():
        e[k] = v
    return e


def wall_body(name, root, y0=-T, y1=T):
    """One closed box with an extra edge loop, so booleans see a manifold solid.
    Side faces above the loop get the tile band material."""
    bm = bmesh.new()
    rings = [[bm.verts.new(p) for p in ((0, y0, z), (4, y0, z), (4, y1, z), (0, y1, z))]
             for z in (0.0, H - BAND, H)]
    bm.faces.new(list(reversed(rings[0]))).material_index = 0
    bm.faces.new(rings[2]).material_index = 0
    for level in (0, 1):
        lo, hi = rings[level], rings[level + 1]
        for i in range(4):
            j = (i + 1) % 4
            bm.faces.new((lo[i], lo[j], hi[j], hi[i])).material_index = level
    return mesh_object(name, bm, ["brick", "tile"], root)


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)

    # 1. Plain wall bay ---------------------------------------------------------
    r = module("M_wall_plain_4m", 0, {"kit_shape": "edge", "kit_family": "walls",
               "size_cells": [1, 1, 0], "edge": "solid", "tags": "brick,structure", "weight": 3.0})
    wall_body("wall_plain_4m__body-col", r)

    # 2. Shelf-recess bay -------------------------------------------------------
    r = module("M_wall_shelfbay_4m", 1, {"kit_shape": "edge", "kit_family": "walls",
               "size_cells": [1, 1, 0], "edge": "recess", "tags": "brick,structure,storage", "weight": 8.0})
    body = wall_body("wall_shelfbay_4m__body-col", r, y0=-T - 0.25)
    bm = bmesh.new()
    add_prism(bm, arch_outline(3.0, 1.9), 0.5, 0.0, -0.25, T + 0.2)
    cutter = mesh_object("cutter", bm, ["wood"], r)
    cut(body, cutter)
    bm = bmesh.new()
    for z in (0.12, 0.54, 0.96, 1.38, 1.80):   # boards only; books come from the socket (ShelfFill)
        add_box(bm, 0.52, 3.48, -0.25, 0.22, z, z + 0.05, 0)
    mesh_object("wall_shelfbay_4m__shelves", bm, ["wood"], r)
    marker("SOCKET_recess_fill__shelfbay", r, (2.0, 0.0, 0.0), {"socket_set": "recess_library"})
    marker("ANCHOR_browse__shelfbay", r, (2.0, 1.2, 0.0))

    # 3. Arch opening (3 m) -----------------------------------------------------
    r = module("M_wall_arch_3m", 2, {"kit_shape": "edge", "kit_family": "walls",
               "size_cells": [1, 1, 0], "edge": "opening_3m", "tags": "brick,structure,passage", "weight": 2.0})
    body = wall_body("wall_arch_3m__body-col", r)
    bm = bmesh.new()
    add_prism(bm, arch_outline(3.0, 1.8), 0.5, -0.01, -T - 0.2, T + 0.2)
    cutter = mesh_object("cutter", bm, ["arch_stone"], r)
    cut(body, cutter)
    marker("SNAP_door__arch3", r, (2.0, 0.0, 0.0), {"snap_kind": "door"})

    # 4. Corner / junction pier -------------------------------------------------
    r = module("M_post_pier", 3, {"kit_shape": "post", "kit_family": "walls",
               "size_cells": [0, 1, 0], "edge": "", "tags": "stone,structure", "weight": 1.0})
    bm = bmesh.new()
    add_box(bm, -0.48, 0.48, -0.48, 0.48, 0.0, 0.3)
    add_box(bm, -0.4, 0.4, -0.4, 0.4, 0.3, H - 0.3)
    add_box(bm, -0.5, 0.5, -0.5, 0.5, H - 0.3, H)
    mesh_object("post_pier__body-col", bm, ["arch_stone"], r)

    # 5. Floor cell -------------------------------------------------------------
    r = module("M_floor_4m", 4, {"kit_shape": "cell", "kit_family": "walls",
               "size_cells": [1, 0, 1], "edge": "", "tags": "stone,floor", "weight": 1.0})
    bm = bmesh.new()
    add_box(bm, 0, 4, 0, 4, -0.2, 0.0)
    mesh_object("floor_4m__body-col", bm, ["floor_stone"], r)

    # 6. Pointed barrel-vault bay (spans X, runs along Y, sits on wall tops) -----
    r = module("M_vault_bay_4m", 5, {"kit_shape": "cell", "kit_family": "walls",
               "size_cells": [1, 1, 1], "edge": "", "tags": "plaster,ceiling", "weight": 1.0})
    inner = [(T + u, H + v) for (u, v) in arch_outline(4 - 2 * T, 0.0, 0.6, 10)[1:-1]]
    outer = [(u, H + v) for (u, v) in arch_outline(4.0, 0.0, 0.6, 10)[1:-1]]
    bm = bmesh.new()
    rings = []
    for y in (0.0, 4.0):
        rings.append(([bm.verts.new((x, y, z)) for (x, z) in inner],
                      [bm.verts.new((x, y, z)) for (x, z) in outer]))
    (i0, o0), (i1, o1) = rings
    n = len(inner)
    for i in range(n - 1):
        bm.faces.new((i0[i], i0[i + 1], i1[i + 1], i1[i])).smooth = True    # intrados
        bm.faces.new((o0[i], o1[i], o1[i + 1], o0[i + 1])).smooth = True    # extrados
        bm.faces.new((i0[i], o0[i], o0[i + 1], i0[i + 1]))     # front cap
        bm.faces.new((i1[i], i1[i + 1], o1[i + 1], o1[i]))     # back cap
    for (a, b) in ((0, 0), (n - 1, n - 1)):                     # springing strips
        bm.faces.new((i0[a], i1[a], o1[b], o0[b]))
    mesh_object("vault_bay_4m__body-col", bm, ["vault_plaster"], r)

    # 7. Gallery slab with balustrade (edge, upper level) -----------------------
    r = module("M_gallery_slab_4m", 6, {"kit_shape": "edge", "kit_family": "walls",
               "size_cells": [1, 1, 0], "edge": "gallery", "tags": "wood,vertical", "weight": 1.0})
    bm = bmesh.new()
    add_box(bm, 0, 4, T, 1.6, H - 0.15, H + 0.15, 0)
    mesh_object("gallery_slab_4m__slab-col", bm, ["wood"], r)
    bm = bmesh.new()
    x = 0.05
    while x < 4.0:
        add_box(bm, x, x + 0.06, 1.48, 1.54, H + 0.15, H + 0.95)
        x += 0.5
    add_box(bm, 0, 4, 1.46, 1.56, H + 0.92, H + 1.0)
    mesh_object("gallery_slab_4m__rail-col", bm, ["wood"], r)
    marker("ANCHOR_lookout__gallery", r, (2.0, 1.0, H + 0.15))

    # 7b. Vault gable: fills the pointed end of a vault bay above the wall top --
    r = module("M_wall_gable_4m", 8, {"kit_shape": "edge", "kit_family": "walls",
               "size_cells": [1, 1, 0], "edge": "gable", "tags": "brick,structure,ceiling", "weight": 1.0})
    bm = bmesh.new()
    gable = [(u, v) for (u, v) in arch_outline(4.0, 0.0, 0.6, 10)][1:-1]
    add_prism(bm, gable, 0.0, H, -T, T, 0)
    mesh_object("wall_gable_4m__body-col", bm, ["brick"], r)

    # 8. Hanging lantern (free dressing, carries its light) ---------------------
    r = module("M_lantern_hanging", 7, {"kit_shape": "free", "kit_family": "walls",
               "size_cells": [0, 1, 0], "edge": "", "tags": "brass,light", "weight": 1.0})
    bm = bmesh.new()
    for (sx, sy) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        add_box(bm, sx * 0.14 - 0.02, sx * 0.14 + 0.02, sy * 0.14 - 0.02, sy * 0.14 + 0.02, 2.55, 3.05, 0)
    add_box(bm, -0.18, 0.18, -0.18, 0.18, 2.5, 2.56, 0)
    add_box(bm, -0.18, 0.18, -0.18, 0.18, 3.04, 3.1, 0)
    add_box(bm, -0.015, 0.015, -0.015, 0.015, 3.1, H, 0)
    add_box(bm, -0.1, 0.1, -0.1, 0.1, 2.6, 2.98, 1)
    mesh_object("lantern_hanging__body", bm, ["brass", "emit_lantern"], r)
    marker("LIGHT_lantern__hanging", r, (0.0, 0.0, 2.8))


def main():
    force = "--force" in sys.argv
    if os.path.exists(OUT) and not force:
        print("kit_seed_walls: %s exists; edit it in Blender instead (or pass --force)." % OUT)
        return
    build()
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=OUT)
    print("kit_seed_walls: wrote", OUT)


main()
