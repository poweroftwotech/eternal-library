AGENTS.md - Godot 4.x AI Engineering Rules (UW2 Remaster & General)
1. Engine & Environment Context
Target Engine: Godot 4.x (Stable Mono / .NET)
Primary Languages: GDScript (Strongly Typed) / C# Reconstructions
User's Godot Binary: Portable Mono install at `C:\projects\Godot_v4.7.2-stable_mono_win64_console.exe`
Note: Always use the `_console.exe` variant for headless execution as it correctly pipes stdout.
Test Environments: Temporary, disposable test paths located under `C:\projects\<name>-test`. Keep them lightweight; do not initiate asset downloads.
2. Visual & UI Mockup Realization
To close the vision-to-code alignment gap and eliminate layout guessing loops:
No Absolute Positioning: Never use raw pixel offsets or free-floating Node2D elements for UI layouts.
Structural Hierarchy: Structure screens strictly using nested container nodes:
Standard UI Flow: `CanvasLayer` -> `MarginContainer` -> `VBoxContainer` / `HBoxContainer` -> Content Nodes.
Bottom-Anchored HUDs: Use negative `offset_top` / `offset_bottom` values rather than absolute viewport-height tracking (`position.y`).
Theme Overrides: Apply explicit theme constants (e.g., `theme_override_constants/margin_left`) to control margins and spacing cleanly.
Visual Match Failure Gate: If you cannot map a mockup's spatial layout to native Godot containers within 2 attempts, STOP. Output a markdown table mapping your proposed node structure and request precise pixel margins or structural guidance before generating more code.
3. UW2 Remaster Features & Gameplay Safeguards
Inventory Panel Live-Gameplay Rule: Keep the game world live (enemies active, damage ticking, timers running) while inventory or character panels are open.
UI Layout: Use a movable floating popup containing an avatar/paper-doll with anatomically placed equipment slots on the left, and backpack/container slots on the right. Ensure the surrounding world remains visible.
Pausing Exception: Only the explicit, separate "Journey Paused" menu is permitted to halt gameplay. Maintain legacy prompt and conversation ownership constraints.
Quick-Action Slots: Maintain ten persistent-on-screen quick-action slots ordered 1–9, then 0. These must reference existing owned items rather than allocating new storage or duplicating data. Support drag-and-drop management and reordering. Treat a missed drop as an operation cancellation, not item disposal.
Workflow Delivery: Deliver user-visible vertical slices rather than successive infrastructure-only checkpoints.
Data Protection: Maintain absolute safeguards for original user saves, cache files, and proprietary source data. Before pushing updates, audit staged files to exclude any local configuration, caches, or personal data.
4. GDScript Styling & Architecture
Type Safety: Enforce static typing across all variables, function arguments, and return types (e.g., `var health: int = 100`, `func take_damage(amount: int) -> void`).
Node Referencing: Use the modern `@onready` syntax paired with explicit types: `@onready var player_sprite: Sprite2D = $Sprite2D`.
Signals: Prefer connecting signals programmatically via code (`signal_name.connect(_on_callback)`) in the `_ready()` function over GUI editor hookups to keep project wiring visible in source control.
5. Execution, Verification & Testing Gates
"Files written" is never considered success. You must headlessly verify every architectural change locally.
Hard Iteration Loop Gate: If an automated verification step or test fails 3 times consecutively for the same error, STOP execution loop. Do not attempt a 4th blind automated fix. Output the exact error stack trace and present 2 distinct architectural strategies for the user to select from.
Headless Pipeline Command: Use the following command string to parse script compilation and runtime crashes over a 240-frame run window:
```bash
  cd /c/projects && timeout 30 ./Godot_v4.7.2-stable_mono_win64_console.exe --headless --path C:/projects/<current_project_name> --quit-after 240
  ```
GPU Visual Capture Gate: Because headless execution uses a dummy renderer, it cannot validate spatial paths, lighting, or anchor visuals. For UI layout changes or first-person spatial tests:
Ensure the scene executes an internal capture script to save a viewport snapshot after ~100 frames (`get_viewport().get_texture().get_image().save_png(...)`).
Inspect the resulting PNG to verify HUD alignments, lighting artifacts, or oversized handheld props.
Report honest layout/visual caveats to the user since atmosphere cannot be fully confirmed headlessly.
Spatial Verification: For first-person dungeon prototypes, connect every visible side room with explicit floor and collision geometry before testing pathfinding or movement. Use `PhysicsServer3D.body_test_motion` with the real player capsule to audit room routes, and implement a temporary safety underlay geometry to prevent unrecoverable falling through unfinished boundaries.
Persistence Features Gate: To verify restart-safe behavior for saving/loading systems, require a successful save state in one OS process and a successful restoration within a entirely newly launched process. Do not rely on same-process reloads which can mask static state retention.
6. Git Worktree & Automated Commit Procedures
For the UW2 Remaster project, automatically commit and push verified checkpoints as needed once they pass independent review and the headless pipeline gate.
Ensure the remote branch SHA perfectly matches the local HEAD before reporting completion.
Keep walking and turning physics deferred unless explicitly directed by the user to revisit them.
7. Crucial Project References
Before writing hand-crafted configuration files or custom lighting mechanics, read and implement guidelines found in:
`references/legacy-data-remaster.md` (Provenance, data isolation, and asynchronous boot pitfalls)
`references/godot4-pitfalls.md` (Scene formatting, keycodes, and hand-written syntax traps)
`references/atmospheric-lighting.md` (3D lighting recipes: VSM, SDFGI, volumetric fog, and light flickering)