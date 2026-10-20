# Environment plan: front page

This page is the plan for building the Library's rooms. It says where things
stand, what is waiting for you, and what changed lately. The detail is in
`docs/environment/` (see "The documents" below).

## Waiting for you

| What | Read this | What to do |
|---|---|---|
| **Phase 3 step 2: it stays knocked over** (plus the janitor plumbing you asked for) | [Progress: phase 3, step 2](docs/environment/progress/phase-3-props.md) ("Try it") | Break and push things, Quit, start the game again: they stay changed. Try Esc → **Tidy up** too. Step 3 (lore books) starts after your OK. Step 2 is not committed |

## What's new

| Date | Change |
|---|---|
| 2026-10-20 | **Phase 3 step 2 built:** the game saves (`user://saves/slot0.json`) and resumes where you quit. Every change keeps its original, so a future janitor can put things back (Esc → Tidy up tests it). Proved across three separate processes ([progress](docs/environment/progress/phase-3-props.md)). |
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
| **3. Props and persistence** | Push and break props, take lore books, save and restore, aging lamps | 🔨 Step 2 of 4 built, waiting for your review (step 1 committed) |
| 4. Areas and streaming | 6–10 connected rooms that load as you walk | Not started |
| 5. Kit breadth | More room types, mostly from data | Not started |

## 10. Roadmap (each phase is a playable slice)

Each phase passes the headless 240-frame gate, a GPU capture and, where
relevant, the route audit and the two-process persistence test.

| Phase | Builds | Done when |
|---|---|---|
| **0. Kit spike** | `export_kit.py`, `kit_import.gd`, `kit_catalog.gd`; one `kit_walls.blend` with about 8 modules (plain wall, shelf bay, arch 3 m, corner pier, floor, vault bay, gallery slab, lantern); the Kit dock with place and rotate | You edit a wall in Blender, run the export, and it updates in a graybox room in Godot with correct pixel materials and collision. Headless import works without Blender installed. |
| **1. Authored R01** | `RoomTemplate`, `VariantSocket`, `SocketSet`, `SHELF_FILL`; the Reading Room rebuilt in the editor from modules; Validate Room; atmosphere ported | R01 is playable in place of the code-built interior, and re-rolling the preview seed changes recesses, the iwan centrepiece and lamps. (The capture-vs-concept criterion was dropped by decision on 2026-10-19: R01 sits alongside the camp.) |
| **2. Generated R02** | Cell grid, edge marking, `ModuleRules`, the R02 `RoomGrammar`, `GeneratorPreview` with overlay and bake, and connector joining to R01 | Walking from R01 into a generated gallery works; changing `max_straight_bays` and pressing Generate visibly changes the corridor; the route audit passes on 20 seeds. |
| **3. Props and persistence** | `WorldProp`, wake and sleep, breakables, book promotion, `ItemDef` pickup, `AreaState`, aging rules | Knock over a vase, pull a lore book and take it, quit; in a new process both stay changed. Advancing the world clock darkens untouched lamps only. |
| **4. Areas and streaming** | `AreaRecipe`, graph and routing, threaded room streaming, light budget | An area of 6–10 rooms (R01, several R02, one baked room) streams without hitches at the frame target. |
| **5. Kit breadth** | R03 grid generator, R05 courtyard template, R09 ring generator, R11 (R03 plus water), and porting the Overlook and R10 from `vista.gd` | Each new type is added mostly through modules and `.tres` rules, with little new code. That is the test of the architecture. |

## The documents

| Page | What's in it | When to read it |
|---|---|---|
| [Architecture](docs/environment/architecture.md) | How the system works: kit, sockets, authored and generated rooms, props, NPC readiness, streaming, folders, risks (§0–9, §11) | Reference. Rarely changes |
| [Phase 2 design](docs/environment/phase-2-design.md) | The generated gallery (§5.5) | Built; reference |
| [Phase 3 approval brief](docs/environment/phase-3-approval.md) | Plain-language: what you get, the steps, the decisions | **Now** |
| [Phase 3 design](docs/environment/phase-3-design.md) | Technical detail behind the brief (§6.5) | Optional |
| Progress logs in `docs/environment/progress/` | What was built, how it was verified, caveats: [phase 0](docs/environment/progress/phase-0-kit.md), [phase 1](docs/environment/progress/phase-1-reading-room.md), [R01 weathering](docs/environment/progress/r01-weathering.md), [R01 polish](docs/environment/progress/r01-polish.md), [phase 2](docs/environment/progress/phase-2-stack-gallery.md), [phase 3](docs/environment/progress/phase-3-props.md) | When you want the detail of a finished step |

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
