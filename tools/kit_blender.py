"""Shared Blender helpers for kit module scripts (kit_seed_walls.py, kit_add_*.py).

Conventions (ENVIRONMENT_PLAN.md section 3):
  * Blender Z up, metres. Godot -Z == Blender +Y, so a cell occupies
    Blender X 0..4, Y 0..4 and an edge module's interior faces +Y.
  * One module = one top-level Empty named M_<family>_<name>; everything under
    it is exported together with the Empty at the origin.
  * Mesh children ending in "-col" get trimesh collision in Godot; "-colonly"
    meshes become collision only.
  * Child empties: SNAP_<kind>, SOCKET_<set>, LIGHT_<profile>, ANCHOR_<kind>.
    Text after a double underscore is ignored, so names stay unique per file.
  * Only material slot names matter; Godot swaps in the pixel materials.
    Names starting with "emit_" become glowing materials.
  * Custom properties on the module Empty become KitModule metadata.
"""
import math

import bmesh
import bpy

H = 4.0          # storey
T = 0.3          # half wall thickness
BAND = 0.3       # tile band under the wall top


def material(name):
    return bpy.data.materials.get(name) or bpy.data.materials.new(name)


def mesh_object(name, bm, mats, parent, recalc=True):
    me = bpy.data.meshes.new(name)
    if recalc:
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


def add_plan_prism(bm, outline, z0, z1, mat=0):
    """Extrude an XY (plan) outline along Z: a closed wall body of any plan shape."""
    a = [bm.verts.new((x, y, z0)) for (x, y) in outline]
    b = [bm.verts.new((x, y, z1)) for (x, y) in outline]
    bm.faces.new(list(reversed(a))).material_index = mat
    bm.faces.new(b).material_index = mat
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


def module(name, location, props):
    root = bpy.data.objects.new(name, None)
    root.empty_display_type = "PLAIN_AXES"
    bpy.context.collection.objects.link(root)
    root.location = location  # laid out for viewing; export resets this
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


def wall_body(name, root, y0=-T, y1=T, width=4.0):
    """One closed box with an extra edge loop, so booleans see a manifold solid.
    Side faces above the loop get the tile band material."""
    bm = bmesh.new()
    rings = [[bm.verts.new(p) for p in ((0, y0, z), (width, y0, z), (width, y1, z), (0, y1, z))]
             for z in (0.0, H - BAND, H)]
    bm.faces.new(list(reversed(rings[0]))).material_index = 0
    bm.faces.new(rings[2]).material_index = 0
    for level in (0, 1):
        lo, hi = rings[level], rings[level + 1]
        for i in range(4):
            j = (i + 1) % 4
            bm.faces.new((lo[i], lo[j], hi[j], hi[i])).material_index = level
    return mesh_object(name, bm, ["brick", "tile"], root)


def arch_ring(bm, inner, outer, y0, y1, mat_for=None, smooth=True):
    """Solid arch band between two outlines with the same point count, extruded
    from y0 to y1 (vault shells, ribs). mat_for(i, n) gives the intrados
    material index per strip."""
    rings = []
    for y in (y0, y1):
        rings.append(([bm.verts.new((x, y, z)) for (x, z) in inner],
                      [bm.verts.new((x, y, z)) for (x, z) in outer]))
    (i0, o0), (i1, o1) = rings
    n = len(inner)
    for i in range(n - 1):
        f = bm.faces.new((i0[i], i0[i + 1], i1[i + 1], i1[i]))     # intrados
        f.smooth = smooth
        f.material_index = mat_for(i, n - 1) if mat_for else 0
        bm.faces.new((o0[i], o1[i], o1[i + 1], o0[i + 1])).smooth = smooth    # extrados
        bm.faces.new((i0[i], o0[i], o0[i + 1], i0[i + 1]))           # front cap
        bm.faces.new((i1[i], i1[i + 1], o1[i + 1], o1[i]))           # back cap
    for a in (0, n - 1):                                             # springing strips
        bm.faces.new((i0[a], i1[a], o1[a], o0[a]))


def add_obox(bm, center, size, rot, mat=0):
    """Box of `size` rotated by Euler XYZ radians `rot`, centred on `center`."""
    from mathutils import Euler, Vector
    m = Euler(rot, "XYZ").to_matrix()
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    c = Vector(center)
    vs = [bm.verts.new(c + m @ Vector((sx * hx, sy * hy, sz * hz)))
          for (sx, sy, sz) in ((-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1),
                               (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1))]
    for f in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
        bm.faces.new([vs[i] for i in f]).material_index = mat


def add_lathe(bm, profile, cx=0.0, cy=0.0, segs=12, mat=0, uv=None):
    """Closed solid of revolution. profile: [(radius, z), ...] from bottom to
    top; first and last radius may be 0 (pole) or > 0 (capped). With a UV
    layer, u wraps around and v runs up the profile (for uv-mapped maps)."""
    rings = []
    for (r, z) in profile:
        rings.append([bm.verts.new((cx + r * math.cos(2 * math.pi * i / segs),
                                    cy + r * math.sin(2 * math.pi * i / segs), z)) for i in range(segs)])
    zs = [z for (_, z) in profile]
    z0, z1 = min(zs), max(zs)
    for k in range(len(rings) - 1):
        for i in range(segs):
            j = (i + 1) % segs
            f = bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
            f.material_index = mat
            if uv is not None:
                for loop, (u, kk) in zip(f.loops, ((i, k), (i + 1, k), (i + 1, k + 1), (i, k + 1))):
                    loop[uv].uv = (u / segs, (profile[kk][1] - z0) / max(z1 - z0, 1e-6))
    for ring in (rings[0], rings[-1]):
        bm.faces.new(ring if ring is rings[-1] else list(reversed(ring))).material_index = mat
    bmesh.ops.remove_doubles(bm, verts=[v for ring in rings for v in ring], dist=1e-5)


def add_ngon_prism(bm, n, radius, z0, z1, cx=0.0, cy=0.0, mat=0, phase=None):
    """Closed n-sided prism (octagonal basins, planters)."""
    ph = math.pi / n if phase is None else phase
    pts = [(cx + radius * math.cos(ph + 2 * math.pi * i / n), cy + radius * math.sin(ph + 2 * math.pi * i / n))
           for i in range(n)]
    add_plan_prism(bm, pts, z0, z1, mat)


def rebuild(name, rev, modules):
    """Rebuild a script-made module in place (same location and custom
    properties) when its root's "kit_rev" is below `rev`. `modules` is the
    caller's [(name, props, build)] list. Hand edits to that module are lost, so
    only list modules nobody has changed in Blender. Returns True if rebuilt."""
    root = bpy.data.objects.get(name)
    if root is None or int(root.get("kit_rev", 1)) >= rev:
        return False
    loc, saved = root.location.copy(), {k: root[k] for k in root.keys()}
    saved["kit_rev"] = rev
    for ob in reversed([root] + list(root.children_recursive)):
        bpy.data.objects.remove(ob, do_unlink=True)
    build = {n: b for (n, _p, b) in modules}[name]
    build(module(name, tuple(loc), saved))
    return True
