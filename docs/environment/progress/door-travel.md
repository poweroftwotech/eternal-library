# Door travel: doors between places load the other side

[Back to the front page](../../../ENVIRONMENT_PLAN.md) · Asked for 2026-11-01 (after walking phase 9's continuous world) · Status: **door travel and ornate doors walked ("looks good"); sealed doors built 2026-11-02; all committed 86a7303**

## Why

Walking phase 9's one continuous world showed two problems:

1. Areas placed at their Gorge doors can overlap in space. That's fine while
   only the place you're in is drawn, but it gets harder to manage once there
   are triggers and NPCs.
2. Around each Gorge door into an interior, the bank's geometry was missing:
   the vestibule passage behind an open door cleared the bank's core cells and
   scenery it ran through (`Area._vestibule_claims`, `Area._open_cores`).

Your call: doors between places go back to being closed doors. You open one
and the area behind it loads as its own scene. The camp stays open to the
Gorge along its corridor (still streamed), and the camp's back door can lead
to an area too. The streaming between places (SeamlessPlaces) is kept for a
future hub other than the Gorge. Doors linking rooms of the same area ("fake
loops") come later.

## What you can try

- **In the Gorge:** every door into an interior is a closed door again, and
  the bank around it is whole (no passage cut through it). Aim at it: the HUD
  says **[E] Open the door to the Lower Stacks**. Press E: the loading screen,
  then you stand just inside the Lower Stacks' entrance, facing in. Its
  entrance works the same way back to the same ledge.
- **The camp's back door** (the glowing doorway at the far end of the camp
  from the Gorge) opens onto the area the Strata Board puts behind it.
  Nothing is behind it in the committed stratum, so it stays the glowing stub
  until you pick one.
- **On the Strata Board:** the picker by the open area's name is now **DOOR**
  (was GORGE DOOR). It lists the Gorge's door places and **The camp's back
  door**. Pick one and the area is reached from there; its entrance leads back
  there (the entrance says "gorge" in the recipe, and the stratum plan
  redirects it). **+ Area…** can put a new area behind the camp's back door
  too. Moving an area out of the Gorge raises the Gorge's version, as any
  change to its doors does.
- **From above:** interiors no longer share the Gorge's space, so the board
  only reports overlaps between places that still stream into one world. An
  area behind the camp's back door has nothing to draw there.

**Look at** `previews/door_travel/`: each door from its ledge (`_ledge`; taken
from beyond the ledge's railing, so the balusters are in front), the prompt
(`_prompt`), and where you arrive (`_inside`), for the Lower Stacks, the
Library Wing and the camp's back door with the Sanctum behind it (`door_camp_*`,
set up in memory for the capture only).

## How it works

- **The stratum plan** (`scripts/world/stratum_plan.gd`): a link can carry
  `seamless: true`. The camp–Gorge corridor always streams; every door link
  without the flag travels. New: `CAMP_BACK_DOOR` (`SNAP_exit_front`) as a
  link's `at`; `door_link`, `outside_of`, `camp_back_area`; `door_target`,
  which sends an area's entrance to the place its door link comes from;
  `place_name` for the prompt.
- **SeamlessPlaces** follows only seamless links (`links()`, `applies()`), and
  plans only the interiors it streams. With no seamless door, the Gorge has no
  open doors, so no vestibules and nothing cleared from its banks.
- **Threshold** (`scripts/world/threshold.gd`) is no longer a walk-in trigger.
  Its wall (`Threshold.Leaf`, on the interaction layer as well) answers the
  interaction ray: the prompt, and E calls `main.cross`, the travel path from
  before phase 9 (save, loading screen, arrive at the door back). New look
  `stub` for the camp's back door (its glow is baked into the camp).
- **Area**: each Threshold's `to` comes from `StratumPlan.door_target`;
  arriving uses `Area.door_to(from)`, so an area behind the camp's back door
  arrives at its entrance from the camp too.
- **CampRoom** adds the back door's Threshold when the stratum plan puts an
  area behind it.
- **The Strata Board service** lists the camp's back door as a door place;
  `set_door` and `add_area` take it; `layout` lists such an area without
  cells and checks overlaps only between streamed places.

## Tests

| Test | Result |
|---|---|
| Headless pipeline, 240 frames | Clean |
| `persist_test` door_save → door_cross → door_back (three processes): open the Gorge's door to the Lower Stacks with the HUD's prompt, arrive just inside, quit, resume, open its entrance back onto the same ledge | 4 + 11 + 12 checks pass; door_save also checks the Gorge has no vestibules or open doors |
| `persist_test` camp_door (new, in `persist_gate.sh`): the Sanctum behind the camp's back door, there and back | 11 checks pass |
| `persist_test` mid_save → mid_cross → mid_back: saves in a passage, the Lower Stacks' door made seamless for these runs only, so the kept streaming code stays tested | 6 + 8 + 10 pass |
| `persist_test` camp_save, camp_load, camp_cross, camp_back, corridor_save, corridor_load | All pass |
| `strata_board_test -- stratum` (updated: the stratum it expected was the three-area one before you added two areas; new checks for the camp's back door) | 37 checks pass |
| `gorge_network_test --seeds=2` (walk from a door's arrival into it, stopped by its wall) | 104 checks pass |
| GPU capture, `tests/door_capture.gd` (rewritten for door travel) | 3 doors, 0 failures; captures above |

**Failing before this change, not fixed here:** `playtest` ("walking into the
gallery doorway goes on along the corridor", stops at z −13.2) and `fly_test`
(the same doorway). Both fail the same way on the committed code (checked by
running them with this change stashed). Most likely the tests reach the
doorway before the Gorge has built in the background, so the corridor's
wait-for-the-Gorge holds the player; `fly_test` also still expects the camp's
door to the Gorge, which the corridor removed in phase 9.

## Open points

- **Intra-area links** ("fake loops", a door to another room of the same
  area): later, as you said. They need stable room ids across seeds and rules
  for which rooms a door may lead to.
- The phase 9 frame gate measured swaps along passages that interiors no longer
  use; it should be re-run and trimmed to the camp–Gorge corridor.

## Ornate doors

Asked for 2026-11-01 after your walk: a real, solid door at the camp's back
door and in each area's way back, and the Gorge's doors to cover their whole
doorway (the pishtaq's leaves stopped at the springing, leaving its lit
fanlight open above them); all of them ornate, so a door to another place
stands out.

**What you'll see:** one door piece in every arch between places, filling it
to the crown:

- a pair of lacquered cedar leaves, a gilt border round each, a gilt stile
  where they meet;
- on each leaf a gilt eight-pointed star (khatam) with a turquoise boss, a
  gilt-framed panel below it, rows of gilt studs, a bronze ring pull;
- over the springing a turquoise-tile tympanum with a gilt sunburst rising
  from a half sun, and a glowing turquoise band;
- a thread of warm light under the leaves, as if lamps burned beyond.

The gilt and the turquoise glow faintly, so the door reads from across the
Gorge in the dark. A door out of an area has a warm lamp before it (the old
glowing doorway's light, which lit that wall).

**Where:** the Gorge's door galleries (in front of the pishtaq's own leaves
and fanlight, inside its stone ring), each area's way out (the kit's 3 m wall
arch, mid-wall), and the camp's back door (its taller arch, in the reveal;
only when an area is behind it, otherwise it stays the glowing stub). The
Overlook's bronze door is unchanged.

**How:** `scripts/world/ornate_door.gd` builds the door in code from the
arch's three numbers (half width, springing, rise, as the kit's `pointed()`),
so one piece fits all three openings. `Threshold` has a new look `ornate` and
`ARCHES` (each opening and how far out the leaves' face stands); the door's
wall (what E finds and what stops you) now stands just behind the leaves.
`tests/door_probe.gd` (new) measured the openings: it stands before a door,
captures it and scans the opening with rays.

**Look at** `previews/ornate_doors/`: for the Lower Stacks and the Library
Wing, the Gorge door from its ledge (`_ledge`), close up with the prompt
(`_prompt`), inside (`_inside`) and the door back from inside (`_back`); the
camp's back door with the Sanctum behind it (`door_camp_*`).

| Test | Result |
|---|---|
| GPU capture, `tests/door_capture.gd` (now also captures the door back from inside) | 3 doors, 0 failures |
| Headless pipeline, 240 frames, in the camp and the Gorge | Clean |
| `persist_test` door_save → door_cross → door_back (three processes) | 5 + 11 + 12 checks pass |
| `persist_test` camp_door (now checks the back door is an ornate door) | 11 checks pass |
| `gorge_network_test --seeds=2` (walk from a door's arrival into it, stopped by its wall) | 98 checks pass (104 before: the Sanctum's door moved from the Gorge to the camp) |

**Caveat:** in the Library Wing, a glint still sparkles on the tympanum's
tile near its crown in the capture from inside. Dimming the door's own lamp
didn't remove it, so it is probably the room's own light on the tile.

## Sealed doors

Asked for 2026-11-02 after your walk of the ornate doors: the doorways that
lead nowhere (a glow at the end of a gallery, which you could fall out of the
map from) become a plainer door that still says "door", for later use as a
way to another part of the map.

**Where they were:** the room grammars leave an exit stub
(`gen/modules/exit_glow.tscn`, slot `stub:exit`) wherever an exit has nothing
joined to it: a warm glowing card 1.4 m past the wall, a light, and a blocker
0.7–1.1 m past the wall line. Where the floor stops at the wall (the
Light-Well Stair's upper gallery in the Lower Stacks and the Forgotten Wing),
the 0.7 m gap in front of the blocker was wide enough to drop through: the
new audit walked the player's capsule 5.8 m out and 7.9 m down.

**What you'll see now:** in every such doorway a plain shut door fills the
3 m arch to its crown: weathered planks, three iron straps with nail heads, an
iron stile and lock plate with a ring, on a stone sill. Nothing gilt, nothing
glowing, so it doesn't read as a way between places. Aiming at it says **The
door won't open**. A warm lamp stands before it (the glow's light, moved into
the room and dimmer), and the door's wall stands in the arch itself, so
there's no gap left to fall into.

**How:** `scripts/world/sealed_door.gd` (`SealedDoor`): the door
(`OrnateDoor` with `plain`, the same builder as the ornate doors) and its wall.
`gen/modules/exit_glow.tscn` keeps its name (the rules and baked rooms point
at it) but now holds a SealedDoor and the lamp; `tools/seed_gen.gd` writes it
the same way.

**Look at** `previews/sealed_doors/`: the Lower Stacks' two at seed 1 (the
Light-Well Stair's gallery, `_0`, and the Upper Galleries, `_1`) and the
Library Wing's two galleries.

| Test | Result |
|---|---|
| `tests/dead_end_audit.gd` (new): every dead end in every area, 3 seeds; the capsule walks into it from 2 m and must stop in the doorway | Before: 2 failures (the light-well's gallery, falling 7.9 m). Now: 18 checks, 0 failures |
| GPU capture, `tests/sealed_door_capture.gd` (new) | 4 doors, all fill their arch; the HUD says "The door won't open" |
| Headless pipeline, 240 frames | Clean |
| `r02_route_test` (the stack gallery's route, its own exit stub) | 2321 checks pass |
| `r05_layout_test` (courtyard exits as stubs) | 11219 checks pass |
