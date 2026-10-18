"""Hero props for the camp (ART_DIRECTION.md backlog 4), built headlessly in Blender.

  blender --background --factory-startup --python tools/build_props.py

Writes assets/models/<name>.glb. Geometry only: each surface carries a material
*name* (bark, log_end, char, stew) that asset_factory.gd swaps for the matching
pixel material, so texel density stays 32/m via world-triplanar mapping.
Models are authored in metres, origin at the hearth centre on the floor.
"""
import math
import os
import random

import bmesh
import bpy

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "models")


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name):
    return bpy.data.materials.get(name) or bpy.data.materials.new(name)


def new_object(name, bm, materials):
    # Planar UVs only so Godot can build tangents; the px materials map
    # world-triplanar and ignore them.
    uv = bm.loops.layers.uv.new()
    for face in bm.faces:
        for loop in face.loops:
            loop[uv].uv = (loop.vert.co.x, loop.vert.co.y + loop.vert.co.z)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for m in materials:
        mesh.materials.append(material(m))
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    for poly in mesh.polygons:
        poly.use_smooth = True
    return obj


def export(name):
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB",
                              export_apply=True, export_materials="EXPORT")
    print("wrote", name)


def log(bm, rng, start, end, radius, charred_from=0.7):
    """Furrowed, slightly bent log from start to end; faces past charred_from
    (fraction toward end) get the char material, caps get log_end."""
    segs, rings = 10, 9
    axis = [end[i] - start[i] for i in range(3)]
    length = math.sqrt(sum(a * a for a in axis))
    d = [a / length for a in axis]
    up = (0, 0, 1) if abs(d[2]) < .9 else (1, 0, 0)
    u = (d[1] * up[2] - d[2] * up[1], d[2] * up[0] - d[0] * up[2], d[0] * up[1] - d[1] * up[0])
    n = math.sqrt(sum(a * a for a in u))
    u = [a / n for a in u]
    v = (d[1] * u[2] - d[2] * u[1], d[2] * u[0] - d[0] * u[2], d[0] * u[1] - d[1] * u[0])
    bend = rng.uniform(-.03, .03)
    furrow_phase = rng.uniform(0, math.tau)
    grid = []
    for r in range(rings + 1):
        t = r / rings
        centre = [start[i] + axis[i] * t + u[i] * bend * math.sin(t * math.pi) for i in range(3)]
        ring = []
        for s in range(segs):
            a = s / segs * math.tau
            rad = radius * (1 + .09 * math.sin(a * 5 + furrow_phase) + rng.uniform(-.05, .05))
            if t > charred_from:   # burnt tip thins out
                rad *= 1 - (t - charred_from) * .5
            p = [centre[i] + (u[i] * math.cos(a) + v[i] * math.sin(a)) * rad for i in range(3)]
            ring.append(bm.verts.new(p))
        grid.append(ring)
    for r in range(rings):
        char = (r + .5) / rings > charred_from
        for s in range(segs):
            f = bm.faces.new((grid[r][s], grid[r][(s + 1) % segs], grid[r + 1][(s + 1) % segs], grid[r + 1][s]))
            f.material_index = 2 if char else 0
    for r, flip in ((0, True), (rings, False)):
        cap = grid[r][::-1] if flip else grid[r]
        f = bm.faces.new(cap)
        f.material_index = 1 if r == 0 else 2


def fire_logs():
    reset()
    rng = random.Random(4401)
    bm = bmesh.new()
    # Star fire: outer ends on the floor, inner (charred) ends raised under the pot.
    # Blender is Z-up; the glTF exporter converts to Godot's Y-up.
    for i in range(6):
        a = i / 6 * math.tau - math.pi / 2 + (0 if i == 0 else rng.uniform(-.15, .15))
        reach = 1.0 if i == 0 else .82   # log 0 pokes out of the open front
        outer = (math.cos(a) * reach, math.sin(a) * reach, .07)
        inner = (math.cos(a) * .12, math.sin(a) * .12, .17)
        log(bm, rng, outer, inner, rng.uniform(.06, .08))
    # Two half-burnt cross pieces lying in the coals.
    for a in (.4, 2.1):
        p = (math.cos(a) * .32, math.sin(a) * .32, .06)
        q = (-math.cos(a) * .32, -math.sin(a) * .32, .055)
        log(bm, rng, p, q, .055, charred_from=.15)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    new_object("FireLogs", bm, ["bark", "log_end", "char"])
    export("fire_logs")


def stew():
    """Lumpy stew surface filling the pot rim (radius .61), chunks pushed up."""
    reset()
    rng = random.Random(4402)
    bm = bmesh.new()
    rings, segs, radius = 12, 48, .61
    lumps = [(rng.uniform(-.45, .45), rng.uniform(-.45, .45), rng.uniform(.06, .12)) for _ in range(14)]

    def height(x, y):
        h = .006 * math.sin(x * 23) * math.cos(y * 19)
        for lx, ly, lr in lumps:
            dd = (x - lx) ** 2 + (y - ly) ** 2
            if dd < lr * lr:
                h += .028 * (1 - dd / (lr * lr))
        return h

    centre = bm.verts.new((0, 0, height(0, 0)))
    grid = []
    for r in range(1, rings + 1):
        rr = radius * r / rings
        ring = []
        for s in range(segs):
            a = s / segs * math.tau
            x, y = math.cos(a) * rr, math.sin(a) * rr
            ring.append(bm.verts.new((x, y, height(x, y) * (1 - (r / rings) ** 6))))
        grid.append(ring)
    for s in range(segs):
        bm.faces.new((centre, grid[0][s], grid[0][(s + 1) % segs]))
    for r in range(rings - 1):
        for s in range(segs):
            bm.faces.new((grid[r][s], grid[r + 1][s], grid[r + 1][(s + 1) % segs], grid[r][(s + 1) % segs]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:   # all faces up
        if f.normal.z < 0:
            f.normal_flip()
    new_object("Stew", bm, ["stew"])
    export("stew")



def tube(bm, rng, path, radius, mat_index, segs=8):
    """Round tube along a polyline (handles, legs)."""
    rings = []
    for k, p in enumerate(path):
        q = path[min(k + 1, len(path) - 1)]
        o = path[max(k - 1, 0)]
        d = [q[i] - o[i] for i in range(3)]
        n = math.sqrt(sum(a * a for a in d)) or 1
        d = [a / n for a in d]
        up = (0, 0, 1) if abs(d[2]) < .9 else (1, 0, 0)
        u = (d[1] * up[2] - d[2] * up[1], d[2] * up[0] - d[0] * up[2], d[0] * up[1] - d[1] * up[0])
        un = math.sqrt(sum(a * a for a in u))
        u = [a / un for a in u]
        v = (d[1] * u[2] - d[2] * u[1], d[2] * u[0] - d[0] * u[2], d[0] * u[1] - d[1] * u[0])
        r = radius(k / (len(path) - 1)) if callable(radius) else radius
        rings.append([bm.verts.new([p[i] + (u[i] * math.cos(s / segs * math.tau) + v[i] * math.sin(s / segs * math.tau)) * r for i in range(3)]) for s in range(segs)])
    for a, b in zip(rings, rings[1:]):
        for s in range(segs):
            bm.faces.new((a[s], a[(s + 1) % segs], b[(s + 1) % segs], b[s])).material_index = mat_index
    for ring, flip in ((rings[0], True), (rings[-1], False)):
        bm.faces.new(ring[::-1] if flip else ring).material_index = mat_index


def cauldron():
    """Round-bellied hammered iron cauldron: rolled lip, 3 legs, D-ring side
    handles on lugs. Rim radius ~.70 at 1.06 m so the stew (.92) and the pot
    interaction volume keep their positions."""
    reset()
    rng = random.Random(4403)
    bm = bmesh.new()
    # (radius, height) outer belly up to the lip, then the inner wall down to
    # a hidden floor under the stew surface.
    profile = [(.0, .30), (.30, .30), (.50, .35), (.64, .45), (.73, .60), (.74, .70), (.70, .84),
               (.65, .95), (.64, .99), (.69, 1.02), (.72, 1.055), (.69, 1.08), (.64, 1.07),
               (.61, 1.02), (.60, .95), (.0, .88)]
    segs = 40
    grid = []
    for k, (r, z) in enumerate(profile):
        ring = []
        for s in range(segs):
            a = s / segs * math.tau
            # Hammered belly: small per-vertex dents, none on the lip.
            rr = r * (1 + (rng.uniform(-.018, .012) if 2 <= k <= 6 else 0))
            ring.append(bm.verts.new((math.cos(a) * rr, math.sin(a) * rr, z)))
        grid.append(ring)
    for a, b in zip(grid, grid[1:]):
        for s in range(segs):
            bm.faces.new((a[s], a[(s + 1) % segs], b[(s + 1) % segs], b[s]))
    bmesh.ops.remove_doubles(bm, verts=grid[0] + grid[-1], dist=.001)
    for i in range(3):
        a = i / 3 * math.tau + math.pi / 6
        top = (math.cos(a) * .44, math.sin(a) * .44, .36)
        foot = (math.cos(a) * .56, math.sin(a) * .56, .02)
        tube(bm, rng, [top, ((top[0] + foot[0]) / 2, (top[1] + foot[1]) / 2, .17), foot], lambda t: .05 - t * .02, 0)
    for side in (-1, 1):
        # Lug on the shoulder, then a drooping D-ring through it.
        tube(bm, rng, [(side * .66, 0, .97), (side * .78, 0, .97)], .035, 0, 6)
        path = [(side * (.78 + math.sin(j / 12 * math.pi) * .17), 0, .97 - (1 - math.cos(j / 12 * math.pi)) * .17) for j in range(13)]
        tube(bm, rng, path, .02, 0)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    new_object("Cauldron", bm, ["cauldron_iron"])
    export("cauldron")


fire_logs()
stew()
cauldron()
