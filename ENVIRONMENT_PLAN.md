# Environment plan: front page

This page is the plan for building the Library's rooms. It says where things
stand, what is waiting for you, and what changed lately. The detail is in
`docs/environment/` (see "The documents" below).

## Waiting for you

| What | Read this | What to do |
|---|---|---|
| Nothing right now. Next is **phase 5 step 2**, the big hall (up to 10 × 10 bays, more landmarks, the frame gate on any area) | [Phase 5 approval brief](docs/environment/phase-5-approval.md) | Say when to start step 2 |

## What's new

| Date | Change |
|---|---|
| 2026-10-22 | **Hall look settled:** the columns have 8 shallow flutes turning a third of a turn up the shaft (softened after the first try looked busy up close); the plaster domes are paler, with a tile band at the foot (`previews/p5_look/`, [progress](docs/environment/progress/phase-5-kit-breadth.md)). Your choices; committed. |
| 2026-10-22 | **Phase 5 step 1 built:** a new area on the Esc menu, the Lower Stacks, starts in a generated column hall: twisted columns, small tiled domes, freestanding bookcases, aisles to a landmark under an oculus (great lamp, reading tree or catalogue desk). The generator now follows its rules files, and every gallery still comes out exactly as before ([progress](docs/environment/progress/phase-5-kit-breadth.md)). You walked it; committed. |
| 2026-10-22 | **Phase 5 design drafted:** [approval brief](docs/environment/phase-5-approval.md) and [technical design](docs/environment/phase-5-design.md). Four new room types in a new area, the Lower Stacks; recommends moving the Overlook and R10 to a later phase (Q1). Waiting for your approval. |
| 2026-10-22 | **Fix:** the pale arch "trim" floating in R01's upper shelves above its doors (in the wing only) was each gallery's first vault seen through the recess; those vault bays now stop short of R01's recesses. A new route check guards it ([progress](docs/environment/progress/phase-4-areas.md)). You checked it; committed. |
| 2026-10-22 | **Phase 4 step 4 built:** quit anywhere in the wing and you resume in the same gallery; changes in rooms that aren't loaded are kept; after Let ten years pass, a gallery you walk into has aged exactly as a fresh process says. The persistence gate grows to seven processes, all passing. Travel shows a plain dark loading panel ([progress](docs/environment/progress/phase-4-areas.md)). You walked it; committed. **Phase 4 complete.** |
| 2026-10-20 | **Phase 4 step 3 built; the phase's finish line is met:** the wing streams without hitches at the RTX 3060 target (Medium, 1080p), passing three gate runs in a row: GPU worst 1.8 ms (limit 4), CPU worst 7.7 ms (limit 8). Only the nearest four lamps cast shadows; lighting doesn't pop when rooms arrive ([progress](docs/environment/progress/phase-4-areas.md)). Committed. |
| 2026-10-20 | **Live stats panel** (F3): performance, base-spec budgets and streaming ([progress](docs/environment/progress/phase-4-areas.md)). Committed. |
| 2026-10-20 | **Phase 4 step 2 built:** only the rooms near you exist; the next ones are built a few milliseconds a frame and the rest go. Walking every branch of three wings on the RTX 5090: no frame over 16.7 ms, worst 8.5 ms ([progress](docs/environment/progress/phase-4-areas.md)). You walked it; committed. |
| 2026-10-20 | **Phase 4 approved** with the recommended answers to Q1–Q11. **Step 1 built:** Esc → Walk the library wing, a wing of 6–9 rooms laid out from a plan, all loaded at once ([progress](docs/environment/progress/phase-4-areas.md)). You walked it in the game; committed. |
| 2026-10-20 | **World structure and graphics tiers written down** ([architecture §2.1 and §8.2](docs/environment/architecture.md)): strata of areas joined by thresholds, buildings carved into cavern walls, levels, a map with no overlaps; Low–Ultra settings with an RTX 3060 at Medium 1080p 60 fps as the base, FSR 2.2 built in, DLSS a research step. Phase 4 brief revised: five future-proofing changes, Q7 now targets the 3060, new Q11 (how deep you can see). |
| 2026-10-20 | **Phase 4 design drafted:** [approval brief](docs/environment/phase-4-approval.md) and [technical design](docs/environment/phase-4-design.md). Waiting for your approval. |
| 2026-10-20 | **Phase 3 complete (step 4 committed):** a world clock (Esc → Let ten years pass); untended lamps fail and go dark, tended ones stay lit; proved across five separate processes R01's two chandeliers never age, by your choice ([progress](docs/environment/progress/phase-3-props.md)). |
| 2026-10-20 | **Phase 3 step 3 committed** (90decb1): pull any shelf book; two lore books in R01 to take and read (J, Satchel); all saved across restarts. Lore texts are placeholders ([progress](docs/environment/progress/phase-3-props.md)). |
| 2026-10-20 | **Phase 3 step 2 committed** (2c60c70): the game saves (`user://saves/slot0.json`) and resumes where you quit. Every change keeps its original, so a future janitor can put things back (Esc → Tidy up tests it). Proved across three separate processes ([progress](docs/environment/progress/phase-3-props.md)). |
| 2026-10-20 | **Phase 3 step 1 committed** (7472a94): two breakable floor vases in R01, pushable table props, and the player's physics layer fixed ([progress](docs/environment/progress/phase-3-props.md)). |
| 2026-10-20 | Phase 3 design **approved** with the recommended answers to Q1–Q9. |
| 2026-10-20 | **This plan is split into several pages**, with this front page. Nothing in the content was dropped; the old single file is in git history. |
| 2026-10-20 | **Phase 3 design drafted:** [approval brief](docs/environment/phase-3-approval.md) and [technical design](docs/environment/phase-3-design.md). |
| 2026-10-20 | Phase 2 slice 5: generated galleries on all three R01 doors no longer grow into each other ([progress](docs/environment/progress/phase-2-stack-gallery.md)). |
| 2026-10-20 | Loose ends closed before phase 3: walkway width, the west door aisle, the corner arches ([progress](docs/environment/progress/phase-2-stack-gallery.md)). |

## Where things stand

| Phase | What it gives you | Status |
|---|---|---|
| 0. Kit spike | Edit a wall in Blender, export, and it updates in Godot | ✅ Done 2026-10-18 |
| 1. Authored Reading Room (R01) | A hand-built hall from kit pieces; variety from sockets; playable from the Esc menu | ✅ Done 2026-10-19 |
| R01 weathering and polish | Fallen books, debris, plants, stains, stairs, growth, surface relief, floor wear | ✅ Done 2026-10-19 |
| 2. Generated Stack Gallery (R02) | A seeded corridor off any R01 door; bakeable to a scene | ✅ Done 2026-10-20 |
| 3. Props and persistence | Push and break props, take lore books, save and restore, aging lamps | ✅ Done 2026-10-20 |
| 4. Areas and streaming | 6–10 connected rooms that load as you walk | ✅ Done 2026-10-22 |
| **5. Kit breadth** | More room types, mostly from data | Approved 2026-10-22 (Q1–Q12 as recommended); step 1 done; step 2 next |

## 10. Roadmap (each phase is a playable slice)

Each phase passes the headless 240-frame gate, a GPU capture and, where
relevant, the route audit and the two-process persistence test.

| Phase | Builds | Done when |
|---|---|---|
| **0. Kit spike** | `export_kit.py`, `kit_import.gd`, `kit_catalog.gd`; one `kit_walls.blend` with about 8 modules (plain wall, shelf bay, arch 3 m, corner pier, floor, vault bay, gallery slab, lantern); the Kit dock with place and rotate | You edit a wall in Blender, run the export, and it updates in a graybox room in Godot with correct pixel materials and collision. Headless import works without Blender installed. |
| **1. Authored R01** | `RoomTemplate`, `VariantSocket`, `SocketSet`, `SHELF_FILL`; the Reading Room rebuilt in the editor from modules; Validate Room; atmosphere ported | R01 is playable in place of the code-built interior, and re-rolling the preview seed changes recesses, the iwan centrepiece and lamps. (The capture-vs-concept criterion was dropped by decision on 2026-10-19: R01 sits alongside the camp.) |
| **2. Generated R02** | Cell grid, edge marking, `ModuleRules`, the R02 `RoomGrammar`, `GeneratorPreview` with overlay and bake, and connector joining to R01 | Walking from R01 into a generated gallery works; changing `max_straight_bays` and pressing Generate visibly changes the corridor; the route audit passes on 20 seeds. |
| 3. Props and persistence | `WorldProp`, wake and sleep, breakables, book promotion, `ItemDef` pickup, `AreaState`, aging rules | Knock over a vase, pull a lore book and take it, quit; in a new process both stay changed. Advancing the world clock darkens untouched lamps only. |
| **4. Areas and streaming** | `AreaRecipe`, graph and routing, threaded room streaming, light budget | An area of 6–10 rooms (R01, several R02, one baked room) streams without hitches at the frame target. |
| **5. Kit breadth** | R03 grid generator, R11 (R03 plus water), R09 ring generator, R05 courtyard template, in a new area (the Lower Stacks). Porting the Overlook and R10 from `vista.gd` moved to a later phase (phase 5 Q1) | Each new type is added mostly through modules and `.tres` rules, with little new code. That is the test of the architecture. |

## The documents

| Page | What's in it | When to read it |
|---|---|---|
| [Architecture](docs/environment/architecture.md) | How the system works: kit, sockets, authored and generated rooms, props, NPC readiness, world structure (§2.1), streaming, graphics settings and hardware tiers (§8.2), folders, risks (§0–9, §11) | Reference. Rarely changes |
| [Phase 2 design](docs/environment/phase-2-design.md) | The generated gallery (§5.5) | Built; reference |
| [Phase 3 approval brief](docs/environment/phase-3-approval.md) | Plain-language: what you get, the steps, the decisions | Built; reference |
| [Phase 3 design](docs/environment/phase-3-design.md) | Technical detail behind the brief (§6.5) | Built; reference |
| [Phase 4 approval brief](docs/environment/phase-4-approval.md) | Plain-language: what you get, the steps, the decisions | Approved; reference |
| [Phase 4 design](docs/environment/phase-4-design.md) | Technical detail behind the brief (§8.1) | Optional |
| [Phase 5 approval brief](docs/environment/phase-5-approval.md) | Plain-language: the four new rooms, the steps, the decisions | Approved; reference |
| [Phase 5 design](docs/environment/phase-5-design.md) | Technical detail behind the brief (§5.6) | Optional |
| Progress logs in `docs/environment/progress/` | What was built, how it was verified, caveats: [phase 0](docs/environment/progress/phase-0-kit.md), [phase 1](docs/environment/progress/phase-1-reading-room.md), [R01 weathering](docs/environment/progress/r01-weathering.md), [R01 polish](docs/environment/progress/r01-polish.md), [phase 2](docs/environment/progress/phase-2-stack-gallery.md), [phase 3](docs/environment/progress/phase-3-props.md), [phase 4](docs/environment/progress/phase-4-areas.md), [phase 5](docs/environment/progress/phase-5-kit-breadth.md) | When you want the detail of a finished step |

Room types and their mocks are in `design/room-atlas.html`. The look is in
`ART_DIRECTION.md`.

### Where the old section numbers went

Code comments cite sections like "ENVIRONMENT_PLAN.md 5.5.10". The numbers
are kept in the new pages:

| Cited as | Now in |
|---|---|
| §0–4, §5.1–5.4, §6.1–6.4, §7–9, §11 | [architecture.md](docs/environment/architecture.md) |
| §5.5 (5.5.1–5.5.10) | [phase-2-design.md](docs/environment/phase-2-design.md) |
| §6.5 (6.5.1–6.5.8) | [phase-3-design.md](docs/environment/phase-3-design.md) |
| §8.1 (8.1.1–8.1.8) | [phase-4-design.md](docs/environment/phase-4-design.md) |
| §10 | This page |
| §12 (progress), "phase N step M", "polish C item 7", "weathering slice" | `docs/environment/progress/` (the file named after that phase or slice) |

## How this plan is kept (for anyone working on it)

- **The front page stays short.** Update three things on it:
  - "Waiting for you": what needs the user, and the one page to read;
  - "What's new": dated, one line each, newest first;
  - "Where things stand".
- **A new phase gets two pages:**
  - `phase-N-approval.md`: plain language, covering what the user can try
    after each step and the decisions, each with a recommendation;
  - `phase-N-design.md`: the technical detail.

  The user approves the brief.
- **Progress goes in `docs/environment/progress/`**, one file per phase or
  slice, each starting with a one-paragraph "In short".
- Keep section numbers stable once code cites them.
