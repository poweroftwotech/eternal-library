# AGENTS.md: engineering rules for The Eternal Library (Godot 4.x)

## 1. Engine and environment

- **Engine:** Godot 4.7 (stable, Mono build). **Language:** statically typed GDScript.
- **Godot binary:** `C:\projects\Godot_v4.7.2-stable_mono_win64_console.exe`. Always
  use the `_console.exe` variant for headless runs; it pipes stdout.
- **Blender:** 5.2.2 LTS portable at
  `C:\projects\blender-5.2.2-windows-x64\blender-5.2.2-windows-x64\blender.exe`
  (nested folder). Used headless for kit modules and props.
- **No Python** on the dev machine outside Blender. Tools that need scripting run
  as Godot `--script` files or Blender `--python` files.
- **GPU:** RTX 5090, Forward+ renderer. GPU captures run here (not `--headless`).
- **Scratch projects** go under `C:\projects\<name>-test`. Keep them lightweight
  and don't start asset downloads.

## 2. Project documents (read before working in their area)

| Area | Source of truth |
|---|---|
| Look, materials, lighting, concept matching | `ART_DIRECTION.md` |
| Level building: kit, rooms, generation, props, roadmap | `ENVIRONMENT_PLAN.md` (front page: status, what needs approval, roadmap; detail and progress logs in `docs/environment/`) |
| Room types and their mocks | `design/room-atlas.html` |
| Game design | `design/The_Eternal_Library_Game_Design_Foundation_v0.1 (1).docx` |

## 3. UI layout

- **No absolute positioning.** Never use raw pixel offsets or free-floating
  `Node2D` elements for UI.
- **Container hierarchy:** `CanvasLayer` → `MarginContainer` →
  `VBoxContainer` / `HBoxContainer` → content nodes.
- **Bottom-anchored HUDs** use negative `offset_top` / `offset_bottom`, not
  `position.y` tracking of the viewport height.
- **Spacing** comes from theme constants (e.g. `theme_override_constants/margin_left`).
- **Visual match gate:** if a mockup can't be mapped to native containers within
  2 attempts, STOP. Output a markdown table of the proposed node structure and ask
  for exact margins or structural guidance before writing more code.

## 4. Workflow

- Deliver **user-visible vertical slices**, not a run of infrastructure-only
  checkpoints.
- **Before committing**, audit staged files and leave out local configuration,
  caches (`.godot/`), Blender backups (`*.blend1`) and personal data.
- **Commit only when the user asks.** The repository has no remote yet; if one is
  added, confirm the remote branch matches local HEAD before reporting a push as done.

## 5. GDScript style

- **Static typing everywhere:** `var health: int = 100`,
  `func take_damage(amount: int) -> void`.
- **Node references:** `@onready` with explicit types,
  e.g. `@onready var camera: Camera3D = $Camera3D`.
- **Signals** are connected in code (`signal_name.connect(_on_callback)`) in
  `_ready()`, not in the editor, so wiring stays visible in source control.
- A `SceneTree` script must not declare a member named `root` (it shadows
  `SceneTree.root`).

## 6. Verification gates

"Files written" is never success. Verify every architectural change locally.

- **Hard iteration gate:** if a verification step fails 3 times in a row with the
  same error, STOP. Don't try a 4th blind fix. Show the exact error and stack
  trace, and offer 2 distinct approaches for the user to choose from.
- **Headless pipeline** (script compilation and runtime errors over 240 frames):
  ```bash
  cd /c/projects && timeout 30 ./Godot_v4.7.2-stable_mono_win64_console.exe --headless --path C:/projects/eternal-library --quit-after 240
  ```
  Pass a scene path to gate a specific scene, e.g. `res://rooms/test/kit_graybox.tscn`.
- **Import before GPU captures:** run `--headless --import` first, or pixel
  textures render white.
- **GPU visual capture gate:** the headless renderer is a dummy, so it can't judge
  lighting, layout or materials. For UI, lighting or spatial changes, save a
  viewport capture after about 100 frames
  (`get_viewport().get_texture().get_image().save_png(...)`, see
  `tests/capture.gd` and `tests/kit_capture.gd`), inspect the PNG, and report
  visual caveats honestly.
- **Spatial verification:** every visible room needs explicit floor and collision
  geometry before movement testing. Audit routes with
  `PhysicsServer3D.body_test_motion` using the real player capsule, and add a
  temporary safety floor under unfinished areas so the player can't fall forever.
- **Persistence gate:** save in one OS process and restore in a freshly launched
  one. Same-process reloads can hide static state.

## 7. Kit pipeline (ENVIRONMENT_PLAN.md phase 0)

- Module sources: `art_src/kit/*.blend` (Godot ignores this folder).
  `tools/kit_seed_walls.py` only seeds a new file; after that the `.blend` is
  edited by hand.
- After editing a `.blend`, run `tools/export_kit.bat`: Blender export → Godot import
  (twice) → wrapper scenes and `kit/catalog.tres`.
- Gate for kit changes: `--headless --script res://tests/kit_test.gd`.
- Blender in `--background`: booleans need closed meshes with the cutter in the
  same parent space, and modifiers must be baked with
  `bpy.data.meshes.new_from_object(evaluated)`; `bpy.ops.object.modifier_apply`
  silently does nothing there.
