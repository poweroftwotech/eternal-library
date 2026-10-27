"""Creates or extends art_src/kit/kit_camp.blend: the camp's kit pieces
(phase 7, docs/environment/camp-rebuild-approval.md), family "camp".

  blender --background --factory-startup --python tools/kit_add_camp.py [-- camp_rug camp_mug ...]

Each piece starts as art_src/kit/camp/src/<name>.glb, cut from the code-built
camp by camp_extract.gd (now art_src/kit/camp/retired_tools/, with the code-built
camp it read gone, phase 7 step 4) so it looks exactly as the camp did (meshes
named <piece>__<material>, materials by their kit names camp_*, collision as
*-convcolonly hulls). This brings each into the .blend as module M_<name>,
its origin the piece's foot (Blender axes; Godot -Z = +Y).

Additive like the other kit_add scripts: a piece already in the .blend is
left alone (it's yours once it's there); name pieces after "--" to replace
just those with a fresh cut. Then run tools/export_kit.bat kit_camp.blend.
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit_blender import module  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(ROOT, "art_src", "kit", "kit_camp.blend")
SRC = os.path.join(ROOT, "art_src", "kit", "camp", "src")
SPACING = 6.0      # modules laid out along X for viewing (export resets this)


def props(name):
    return {"kit_shape": "free", "kit_family": "camp", "size_cells": [0, 0, 0], "edge": "",
            "tags": "camp,dressing", "weight": 1.0, "kit_vertex_colors": True}


def remove_module(name):
    root = bpy.data.objects.get(name)
    if root is None:
        return
    for o in [root] + list(root.children_recursive):
        bpy.data.objects.remove(o, do_unlink=True)


def add_piece(name, slot):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, name + ".glb"))
    new = [o for o in bpy.data.objects if o not in before]
    root = module("M_" + name, (slot * SPACING, 0.0, 0.0), props(name))
    for o in new:
        if o.parent is None:
            o.parent = root
    return len(new)


def main():
    replace = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if os.path.exists(BLEND):
        bpy.ops.wm.open_mainfile(filepath=BLEND)
    else:
        bpy.ops.wm.read_factory_settings(use_empty=True)
    names = sorted(f[:-4] for f in os.listdir(SRC) if f.endswith(".glb"))
    added = []
    for slot, name in enumerate(names):
        mod = "M_" + name
        if mod in bpy.data.objects and name not in replace:
            continue
        remove_module(mod)
        add_piece(name, slot)
        added.append(name)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("kit_add_camp: %d piece(s) added or replaced: %s" % (len(added), ", ".join(added) or "none"))


main()
