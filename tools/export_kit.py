"""Export kit modules from art_src/kit/*.blend to assets/kit/<family>/<module>.glb.

  blender --background --factory-startup --python tools/export_kit.py [-- kit_walls.blend ...]

With no file names, every .blend in art_src/kit is exported. Each top-level
Empty named M_* is one module: it is moved to the world origin, exported with
all its children as one .glb, and moved back. The file name drops the "M_"
prefix and the family prefix (M_wall_plain_4m in family "walls" ->
assets/kit/walls/wall_plain_4m.glb). The .blend itself is never saved.

Also runnable from inside Blender (Scripting tab > Run Script) to export the
currently open file only.
"""
import os
import sys

import bpy

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art_src", "kit")
DST = os.path.join(ROOT, "assets", "kit")


def module_roots():
    return [o for o in bpy.data.objects if o.parent is None and o.name.startswith("M_") and o.type == "EMPTY"]


def descendants(ob):
    out = [ob]
    for c in ob.children:
        out += descendants(c)
    return out


def export_open_file():
    count = 0
    for root in module_roots():
        family = str(root.get("kit_family", "misc"))
        out_dir = os.path.join(DST, family)
        os.makedirs(out_dir, exist_ok=True)
        path = os.path.join(out_dir, root.name[2:] + ".glb")
        saved = root.matrix_world.copy()
        root.matrix_world.identity()
        bpy.context.view_layer.update()
        for o in bpy.context.view_layer.objects:
            o.select_set(False)
        for o in descendants(root):
            o.hide_set(False)
            o.select_set(True)
        bpy.ops.export_scene.gltf(
            filepath=path, export_format="GLB", use_selection=True, export_extras=True,
            export_yup=True, export_apply=True, export_lights=False, export_cameras=False,
            export_texcoords=False, export_normals=True, export_materials="EXPORT",
            export_animations=False)
        root.matrix_world = saved
        count += 1
        print("export_kit:", os.path.relpath(path, ROOT))
    return count


def main():
    if not bpy.app.background:       # run from Blender's text editor
        export_open_file()
        return
    names = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    files = names or sorted(f for f in os.listdir(SRC) if f.endswith(".blend"))
    total = 0
    for f in files:
        bpy.ops.wm.open_mainfile(filepath=os.path.join(SRC, os.path.basename(f)))
        total += export_open_file()
    print("export_kit: %d modules from %d file(s)" % (total, len(files)))


main()
