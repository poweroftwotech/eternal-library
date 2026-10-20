# Progress: phase 0, the kit spike (done 2026-10-18)

[Back to the front page](../../../ENVIRONMENT_PLAN.md)

**In short:** the Blender → Godot pipeline works. Edit a wall in Blender, run tools/export_kit.bat, and every room using it updates with the right pixel materials and collision.

---

### Phase 0: kit spike (done 2026-10-18)

**Try it:** open the project in Godot, open `rooms/test/kit_graybox.tscn`, and use
the **Kit** dock (bottom left) to place modules: click a module, then click in
the 3D view. R rotates, Page Up/Down changes storey, Ctrl snaps to 2 m, Shift
to 0.5 m, Esc stops. Placement is undoable.

**Edit a module:** open `art_src/kit/kit_walls.blend` in Blender, change it,
save, double-click `tools/export_kit.bat`. Godot reimports and every room using
the module updates.

| Piece | File |
|---|---|
| Starter `.blend` generator (one-time, refuses to overwrite) | `tools/kit_seed_walls.py` |
| Blender exporter, one `.glb` per `M_*` empty | `tools/export_kit.py` |
| One-click export, import and catalog refresh | `tools/export_kit.bat` |
| Post-import (materials, collision layer, markers, lights, metadata) | `tools/kit_import.gd`, set for all scenes in `project.godot` `[importer_defaults]`; it skips anything outside `assets/kit/` |
| Shared material library (editable `.tres`, built from the pixel maps) | `scripts/world/px_material.gd` → `kit/materials/` |
| Module wrapper root, catalog, builder, validator | `scripts/world/kit_module.gd`, `kit_catalog.gd`, `kit_catalog_builder.gd`, `kit_validate.gd` |
| Wrapper scenes and catalog (generated, then extended by hand) | `kit/modules/walls/*.tscn`, `kit/catalog.tres` |
| Kit dock editor plugin | `addons/kit_palette/` |
| Graybox room (1 × 3 bays, two storeys, vaulted) | `rooms/test/kit_graybox.tscn` (from `tools/build_graybox.gd`) |
| Gate and capture | `tests/kit_test.gd` (121 checks in phase 0; 129 now), `tests/kit_capture.gd` → `previews/kit_graybox_*.png` |

Nine modules: plain wall, shelf-recess bay, 3 m arch (with a `SNAP_door`
connector), pier, floor, pointed vault bay, vault gable, gallery slab with
balustrade, and a hanging lantern that carries its own light.

**Verified:** `tests/kit_test.gd` passes (catalog, every wrapper, library materials
only, collision on layer 1, markers in groups, a hand-added wrapper node
surviving a refresh, graybox validation, floor/wall/vault ray hits, and a player
capsule walking through the arch but stopped by the wall). The 240-frame
headless gate is clean for the graybox and the prototype. GPU captures look
right. A Blender edit (pier widened 25%) reached the graybox through one export.
Import never needs Blender (`art_src/` has a `.gdignore`).

**Not verified, and known gaps:**
- ~~Interactive placement in the Kit dock~~: the user confirmed click-to-place
  works in the editor (2026-10-18).
- The first import that creates a new library material prints "invalid UID"
  warnings until a second import; `export_kit.bat` imports twice.
- Shelf recesses use simple book blocks; real book dressing is phase 1
  (`SHELF_FILL`).
- `-occonly` occluders, visibility ranges and "repeat along edge" placement are
  not in yet.
- The shelf-recess bay's back protrudes 0.25 m past the standard wall face.
  That is fine against rock, but two recess bays back to back would overlap.

