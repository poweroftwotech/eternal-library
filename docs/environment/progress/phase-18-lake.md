# Progress: the Lake Landing (R20), phase 18

[Back to the front page](../../../ENVIRONMENT_PLAN.md) · [Approval brief](../phase-18-approval.md)

## Steps 1-4: built in one go (2026-11-08), waiting for your look

You asked for steps 1-4 to be built without walks in between, and for the
landing doors to be sealed for now (Q3: you have another idea for travel
between areas). Everything else is as recommended. Step 5 (live behind a Gorge
door, the frame gate, the commit) waits for your check.

**Walk it.** The lake is a place of its own and no door leads to it yet, so
start the game straight into it:

```
C:\projects\Godot_v4.7.2-stable_mono_win64_console.exe --path C:/projects/eternal-library -- --room=res://rooms/lake/landing.tscn
```

You arrive in the cave passage; its door behind you is sealed. Walk out onto
the quay, down the pier to its head, and talk to the ferryman (E) to cross.
Ring a landing's bell to call the empty ferry to you. V flies, as anywhere.

**Pictures:** `previews/phase18_step1/` (the water at scale),
`previews/phase18_step2/` (the quay), `previews/phase18_step4/` (landings,
life, the ferry, world 7).

### What each step made

1. **The water at scale.** An elliptic cavern of rough rock about 170 by 160 m
   with a roof and stalactites (`lk_cavern`), the lake bed under it, the black
   water (`kit/materials/lake_water.tres`: a faint cold glow so the lake is
   never pitch black), a low mist, and the lake's own atmosphere
   (`kit/atmosphere/lake_landing.tres`: indigo ambient; SDFGI off, as it
   swallowed the ambient and left everything black). The fog reaches the whole
   160 m. Every lantern paints a gold streak on the water that stretches with
   distance (`shaders/lake_streak.gdshader`; painted, not real reflections,
   Q7). Lights fade out past 48 m, so far landings show as lit windows.
2. **The quay.** `art_src/kit/kit_lake.blend` (written by
   `tools/kit_add_r20.py`): the stone quay with water steps down to a wading
   shelf, a pier on piles with lanterns and a bell, the pier head and the
   ferry's stage, a boardwalk behind five boathouses on piles, moored boats,
   crates. The scene is built by `tools/build_lake.gd` into
   `rooms/lake/landing.tscn`.
   - **Wading (Q5):** off the shelf you wade to your knees; step off into deep
     water and you splash, the screen fades, and you stand back on the nearest
     safe point facing the shore. No swimming, no invisible walls.
3. **The ferry.** `scripts/world/lake_ferry.gd`: an 8 m barge with an awning,
   two lanterns and the ferryman at the stern. Ask him and choose a stop; he
   waits until you're on deck, backs off the stage, turns, crosses at a walking
   pace and noses into the far stage. You ride standing (Q4). A landing's bell
   brings it to you empty. Save mid-crossing and you resume on the stage you
   left from (Q9).
4. **Landings and life.** Four landings across the water, each dressed for
   where it would lead: the **Mahaleh** (a lit house front with a dome, an
   awning, people at the door, moored boats), the **Gardens** (daylight falls
   through a crack in the roof onto beds and pomegranate trees), the
   **Forgotten City** (one lantern, rubble) and the **dark landing** (a sunk
   quay and a sunk boat; no stop, Q6). All four doors are sealed. By world seed
   (`scripts/world/lake_life.gd`): which boats are moored and which carry
   lanterns, which boathouses are lit, and where the fisher sits mending his
   nets. A distant boat with a lantern rows between the Mahaleh and the
   Forgotten City every three minutes.

### Tests (run at the end, after the look)

- `tests/r20_ferry_test.gd` (headless, the real player capsule): walks the
  passage, quay, pier and boardwalk; rides every crossing standing (quay,
  Mahaleh, Gardens, Forgotten City, quay); steps off and climbs each
  landing's steps; rings a bell; wades off the shelf into deep water.
  **29 checks, 0 failures.** You stay on the deck the whole way (worst drift
  0.34 m). Each crossing takes 44-56 s.
- The same test's save and load runs (two processes): saved halfway across,
  resumed on the quay's stage with the ferry at the quay. **7 checks, 0
  failures.**
- Headless gate on the lake (240 frames): no errors. `kit_test`: 11609 checks,
  0 failures.
- Cost, from `tests/r20_capture.gd` at 1080p on this machine: 21 lights (2
  shadowed, over the water steps), at most 14 in reach; at most 438 draw
  calls and about 100k triangles; GPU 0.6-1.3 ms. The frame gate on the base
  spec is part of step 5.

### Fixed while building

- Every stair in the place is walked on a hidden ramp through its treads (the
  player has no step-up, so the box steps let you down but not back up).
- Moored boats float 0.24 m higher, so the lake no longer shows inside their
  hulls.
- The fisher, his nets and traps moved against the rock so they don't block
  the boardwalk.
- A lantern on the boardwalk, which was pitch dark.

### Worth your eye

- **The Gardens' daylight** is a strong cold-white shaft in the haze; it reads
  from across the lake as a pale glow. Say if you want it warmer or fainter.
- **The dark landing** is very dark from the water by design; you only make it
  out close up.
- The lake is dark overall: lanterns, streaks and lit windows carry it. Open
  water reads as deep blue, not black.
- The submerged bottom steps of the quay don't slow you as wading does; only
  the shelf does.

## Walk 1 (2026-11-08): your six reports

Pictures: `previews/phase18_walk1/` (your report views re-taken, and wide
views `r20_7_*.png`). Nothing is committed.

| Your note | What changed |
|---|---|
| The cavern is "a giant square", not natural | `lk_cavern` rebuilt: the shore swings in and out in lobes and bays (up to about 13 m), the wall's height varies (14-31 m) and it leans in as it rises, so the walls curve into the roof; the roof rises and sags. Built facades and the quay keep their places. The rock now has collision. |
| More obstacles: rock out of the water, rock dropping from low parts of the ceiling | 18 rock stacks stand out of the lake, some in clusters of up to four, 9 m or more clear of every ferry crossing and the lantern boat's path. Five low parts of the roof (down to 8.5-12 m) hang long stalactites to a metre or two above the water, with stalagmites under some and 1-3 full columns each. 120 shorter stalactites elsewhere, short where the ferry passes under. |
| Boat textures stay in place while the boats move | The ferry, the moored boats and the far lantern boat use object-space copies of their materials (`WorldProp.localize_materials`), so the planks move with the hull. |
| Passages into cave-like structures | The Gardens, Forgotten City and dark landings now have their doors at the back of a natural grotto cut 12 m into the wall (a sloping roof from about 8 m at the mouth to 4.8 m over the door, a rock floor you can walk). The dark landing's grotto is flooded. The Mahaleh keeps its built house front. The Gardens has a lamp by its door. |
| Fishing spots, a resting/hearth area | A stone terrace off the quay's east end with a working hearth (it warms you and you can cook, as a stacks niche's), bedrolls and crates. Fishing spots (stool, rod on a rest with its line in the water, bucket, tackle box) on the terrace, the pier and the Forgotten City landing, in group `fishing_spot` for when fishing comes. |
| Mushrooms on the ceiling and walls; fog | 66 colonies of glowing teal caps (shelf brackets on walls, hanging caps under the roof, upright ones on ledges; a dense heart thinning out), on the cavern, the stacks, the hanging rock, the back wall and the headland, and inside each grotto. The 18 near the ferry's water and the 2 on the back wall cast a faint teal light on the rock. The low mist over the water is thicker and taller, the cavern's fog a little denser, and the ambient a little brighter. |

Cost now, at 1600x900: about 230-310k triangles in view, at most 350 draw
calls, GPU 0.5-0.8 ms on this machine; 42 lights in the place (2 shadowed), at
most 22 in reach. The cavern's shell no longer casts shadows; it was being
drawn whole into each shadow face (3.3M triangles at the quay before that).

Worth your eye:
- The lake is still dark between the glowing patches; the rock's new shape
  shows best near the lit colonies and from high up.
- The Gardens grotto is hidden in the daylight's haze from the water; the
  Forgotten City's shows only its lantern and door from far off.
- The hearth is the stacks' niche hearth: its pot is big next to the bedrolls.
- Found by the new checks: the far lantern boat ran on its own clock and the
  ferry could sail straight through it. It now lies still while the ferry is
  within 15 m. `tests/r20_ferry_test.gd` ride now also checks that no rock is
  in the barge's way on any crossing, that the lantern boat's whole path is
  clear water, and that the two boats never meet: **32 checks, 0 failures.**

## Revised step 1: the harbour (2026-11-08)

Built to the revised brief (step 1: look first, no ferry trips yet).

- **The chamber** (`lk_harbour`, `tools/kit_add_r20.py` `harbour()`, rev 3):
  one natural shell round the quay, pier, boathouses and terrace, about 50 m
  across instead of 170 m. The roof sits 5-8 m over the water (6.2 m least
  over the quay and pier, 4.8 m over the ferry's water), stepped in tilted
  sheets of bedding plane with pockets rising between them and flowstone
  masses hanging below. The rock is eaten back into a notch at the waterline.
  Shelving rock bed, 46 boulders and ledges at the waterline (none on the
  ferry's water), 150 curtains of short stalactites along the sheets' edges.
- **Two channels:** the lit one (the ferry's, step 2) bends east out of
  sight with a lantern on a rock plinth at each side of its mouth and a fog
  bank in its bend; the dark one leads west, its roof sinking to a metre over
  the water, with fog and no lantern: the place you can't go yet.
- **Warm limestone** (`kit/materials/limestone.tres`, texture by
  `tools/tile_limestone.gd`): cream, sand, ochre and rust bands with grey
  seams, world-mapped so they run level through the rock. On the roof's
  undersides the bands are widened (`top_squash`, a new `kit_px_world`
  setting, 1.0 for every other material) so they read as broad sheets, not
  stripes. Warm where the lanterns reach, indigo beyond.
- **Teal caps** only in the two channels' depths, never by a lantern.
- The great cavern, its stacks, headland and the four far landings are no
  longer placed; their modules stay in the .blend for the dock styles
  (step 3). `LakeLayout.FERRY_RUNS = false` until step 2: the ferryman says
  the channels aren't open yet, and `tests/r20_ferry_test.gd` will fail until
  then (expected).

Cost at 1600x900: 64-116k triangles in view, at most 230 draw calls, GPU
0.5-0.8 ms on this machine; 18-19 lights (2 shadowed). Pictures:
`previews/phase18_harbour/r20_10_*.png`.

Worth your eye:
- **Far-shore lanterns (your call after the first pictures):** three lantern
  posts on rock plinths across the water (east, south-west, west; `H_SHORE`,
  harbour rev 4), arms toward the water, the roof kept 4.3 m clear over them.
  The rock opposite the quay now shows as warm pools between indigo; the
  dark channel still has none. 20 lights in the place (2 shadowed), GPU
  0.5-0.75 ms. Pictures `previews/phase18_harbour/r20_11_*.png`.
- The channel mouths are best seen from the pier head.

## Harbour walk 2 (2026-11-08, 8 reports)

| Your note | What changed |
|---|---|
| The roof is still too flat; stalactites; stalagmites in the water | The roof's clearance now hugs what stands under it (quay strip, pier, the ferry's water) and falls away round it, so over open water the roof comes down in hanging masses, some to the water. Deeper pockets over the quay. 60 big stalactites (1.2-5.5 m, long where there is room) with small ones round their roots, on top of the 150 short curtains. 27 pointed stalagmites stand out of the open water in clusters, off the ferry's water, the pier and the quay. |
| Sediment layers don't belong on the roof | Faces of the roof looking down take a new plain flowstone (`limestone_roof`: mottled cream with tan patches and drip spots, by `tools/tile_limestone.gd`); the risers between the sheets and the walls keep the bands. |
| Layers repeat too much: thicker | The wall limestone is now 64 x 160 at 5 m a tile up the wall (`uv1_scale` 0.5, 0.2, 0.5): bands up to a metre thick, each edge waving on its own so they swell and pinch. |
| Z-fighting at the cave mouth and by the water steps | The cave mouth sits 1 cm lower (its floor ran under the quay paving); the paving stops short of the steps' stone coping (they overlapped). Quay rev 4. |
| The walls look cut straight | Back wall rev 6: big swells and hollows, ledges where the beds step out, fissures, a lean out as it rises. Along the quay and boardwalk it only goes back below head height (the quay runs 1 m into the rock) and swells out over the walk above it, kept 1.6 m clear of the boathouse roofs. |
| Light off the pier from glowing fungi, a colour to each part | The three far-shore lanterns and the two at the lit channel's mouth are gone. In their places, low rock ledges with upright glowing mushrooms (stalk, cap, gills), brackets on the rock behind and strands hanging over them, each with a light of its colour: amber east, violet south-west, lime west, teal at the lit channel (`H_GLOW`, new `emit_lake_glow_amber/violet/lime`). |
| Hanging mushrooms on ceilings; upright ones on the ground | Caps on the roof are now fungus strands hanging down with small caps along them and a glowing drop at the tip (as the Gorge's glow moss); upright caps only on ledges and the ground, brackets on walls. |

Cost at 1600x900 from the report views: 33-213 draw calls, 0.08-0.15M
triangles, GPU 0.5-1.1 ms. Lights unchanged in number (five lanterns out,
five fungus lights in). Pictures: `previews/phase18_walk2/`.

Worth your eye: the roof right over the quay is still the plainest part
(it has to clear 6.2 m there); the hanging masses and stalactites show
best over the open water east and west.

## Harbour walk 3 (2026-11-08, 4 reports)

| Your note | What changed |
|---|---|
| Still strong z-fighting at the passage | The real cause: the two passage pieces' floors run a metre out under the quay paving at the same height (a probe over the floor found them). Both passage pieces now sit 1 cm down, as the mouth does; you walk on the passage's collision floor, unchanged. |
| Still too many flat sections on the roof | Where the clearance holds the roof up (over the quay, pier and ferry's water) it no longer stops in a flat lid: domes and scallops rise 0.5-3.5 m into the rock from the clearance line, with the stepped sheets showing through. Harbour rev 7. |
| Make the cave wet and detailed: speculars, normal maps | Both limestones are wet (`wetness` 0.7: darker, glossy streaks) with the normal maps at 1.7, so the lanterns and fungi glint on the rock. |
| Darker overall, more contrast, strong local light | Ambient down from 0.58 to 0.2, less ambient in the fog; the fungus ledges' lights stronger (3.2) and shorter (10 m). The lit quay and pier stand out of a dark cave. |

Cost from the report views: GPU 0.66-1.1 ms, at most 213 draw calls.
Pictures: `previews/phase18_walk3/`.

### Harbour walk 4 (5 reports, 2026-11-08)

- **Drips** ("occasional water drips"): `build_lake.gd _drips()` puts 17 StackDrips around the harbour, 4 on the quay and the rest over open water (kept off the pier and boats). Each falls from the roof straight above it, found by a ray against the harbour rock.
- **Bright water by the steps:** `lake_water.tres` `glow` was 1.0, and the water shader emits (bed + glow) × tint, so shallow water over the steps glowed light blue. Now glow 0.35 with darker shallow and deep tints, murk_depth 2.5.
- **Waves:** new `water.gdshader` uniform `wave_strength` (lake 1.8) scales the wave normals. Other waters keep 1.0.
- **Ripples at boats and objects:** new `contact_ripple` uniform (lake 1.0). Rings of foam move outward where the depth buffer says something stands in the water (within 0.4 m). Other waters keep 0.
- **Pitched boathouse roofs** ("why sloped underground?"): flat now at the user's choice. `boathouse()` rev 2: no gables, beams across with proud ends, a flat deck at 3.04 m with a low rim and planks. `build_lake.gd` puts crates, traps and a net rack on the three roofs, a different load on each. Pictures in `previews/phase18_walk4b/` (including `roofs_above.png`, a made-up overhead view).
- Replays in `previews/phase18_walk4/`: GPU 0.73–1.08 ms, ≤ 221 draw calls.

### Harbour walk 5 (2 reports, 2026-11-08)

- **Wet pier and landing:** `LakeLife._wet_structures()` gives the Quay, Pier, Boathouses and Landings groups wet copies of their materials as surface overrides, so the shared kit stays dry elsewhere. Stone (kit_px_world) gets wetness 0.8 (darker, glossy patches). Wood is darkened by about 30% with roughness 0.38. Glass, water and `emit_` materials are skipped.
- **Boathouse windows:** the glowing pane is gone (boathouse rev 3), leaving an open hole into the house. LakeLife no longer boards up the windows of unlit houses.
- Replays in `previews/phase18_walk5/`: GPU about 0.75 ms, ≤ 248 draw calls.

### Harbour walk 6 (3 reports, 2026-11-08)

- **Wood too smooth ("wet but also rough"):** the wet wood copies are now kit_px_world ShaderMaterials built from the wood's own textures. They use wetness 0.55 (glossy in patches, rough grain between), normal_scale 1.6, rough_variation 0.2 and albedo 0.85. This replaces walk 5's flat StandardMaterial gloss.
- **Pier lights dimmer:** LakeLife scales the lights under Pier to 0.55 of their energy (PIER_LIGHT_SCALE). Their emit_lantern panes get a dimmer, warmer copy (0.62, 0.36, 0.15) at the user's yes (`previews/phase18_walk6b/`). The quay lanterns are unchanged.
- Replays in `previews/phase18_walk6/`.

## Revised step 2: one trip through the fog (2026-11-08)

The user approved the harbour's look ("pier area looks really good now") and asked to go on.

- **A dock chamber kit piece, `lk_dock_a`** (`kit_add_r20.py dock_a`). The harbour's rock builder is now `chamber(r, P)`, shared by both (`HARBOUR_P`, `DOCK_P`, with `SHAPE` switching `h_inside` / `h_clear`). The harbour itself was not rebuilt. The dock is in its own frame:
  - a small round chamber with a tall alcove over the house front (storeys 12, 8 and 4 m);
  - a stone strip either side of the landing quay;
  - a 45 m channel bending west out of sight;
  - four fungus ledges (violet, amber, two teal down the channel);
  - stalactites and stalagmites.
- **The Mahaleh dock** (`build_lake.gd _dock`):
  - `lk_dock_a` placed at (0, 0, -420), its water, mist, and fog in its channel;
  - the old Mahaleh landing's dressing in it: house front, sealed door, lanterns, figures, bell, moored boats.
  - `LakeLayout.DOCKS` holds its frame. `stop_dock`, `channel`, `place_of` and `stops()` cover the quay and the Mahaleh, and `FERRY_RUNS` is true.
- **The trip** (`LakeFerry`):
  - The ferry backs off the stage, turns, and poles out along its stop's channel (`HARBOUR_CHANNEL` ends at the bend, short of low rock beyond it).
  - A dark fog volume on the barge thickens over the last 22 m (density 2.4 at its heart) and holds for 2 s while the barge drifts.
  - The barge, and you at the same spot of the deck facing the same way, are moved to the end of the other stop's channel (R3).
  - The fog thins over the first 22 m of the way in, and the barge noses into the stage.
  - `set_place` shows only the harbour or the dock you are in, so hidden lights are off.
  - About 45 s each way.
- **Saves (R4):** a save before the fog resumes on the stop you left; in or after the fog, at the stop you were going to.
- **Tests:**
  - `tests/r20_ferry_test.gd` ride: quay to the Mahaleh and back plus the bell, 19 checks, 0 failures. Drift on deck ≤ 0.22 m, no rock in the way.
  - save/load (before the fog, separate processes): 0 failures. A save after the fog resumed at the Mahaleh stage.
  - The first ride found rock hanging into the harbour channel past its bend, which made the player slide 3–4 m on the deck. The fix was to cross at the bend.
- **Pictures:** `previews/phase18_step2/` (`tests/r20_trip_capture.gd`): quay deck, leaving, fog closing, in the fog, emerging, channel in, approach, docked, dock front, dock from the water, dock channel. GPU 0.5–0.8 ms, ≤ 159 draw calls.
- **Not yet:**
  - the other docks, the ferry table and the lantern boat (step 3);
  - the old far landings' dressing for the Gardens and Forgotten City (step 3).

## Revised step 3: every dock (2026-11-08)

Steps 1 and 2 were committed together (32a4552). The user asked to go on.

- **Docks by style (R1b):**
  - `LakeLayout.STYLES` has four dock styles: town (0, 0, -420), garden (320, 0, -420), ruin (-320, 0, -420) and default (0, 0, -760).
  - Each is an `lk_dock_a` chamber holding the dressing of the landing that used to serve its theme: the Mahaleh house front, the Gardens' light shaft and planters, the Forgotten City's rubble, and a plain arch for the default style.
  - `style_of(dest)` picks a style by the destination's theme. Ties are broken by world seed. A destination with no matching theme uses the default.
- **The ferry table (R5):**
  - `scripts/world/lake_ferry_table.gd` defines the table, and `gen/lake/ferry_table.tres` holds it: the Mahaleh (town), the Gardens (garden) and the Forgotten City (ruin), all open.
  - The ferryman offers what the table says. The pier head has a low board listing them.
- **Two channel mouths (R1c):**
  - `lk_dock_a` rev 2 added an east mouth. Rev 3 removed the rock ledge between the two mouths, which was in the ferry's way.
  - The ferry leaves a dock by the west mouth and comes in by the east one.
  - Under the fog the arrival dock is re-dressed for where you are going: its board (`Sign`) and its bell.
  - A trip from one dock to another dock of the same style therefore never comes back out where it went in.
- **Bells:** each dock's bell calls the empty ferry out of the fog to that dock's current destination.
- **The flooded channel** has a board in the water: "Flooded. No passage."
- **The lantern boat:**
  - A small boat, a seated rower and a lantern, crossing whichever place you are in once every 2 minutes and taking 75 s.
  - In the harbour it comes in down the west side of the lit channel and goes on into the dark flooded one, its lantern dimming. The ferry's harbour channel now keeps east of the middle to leave it room.
  - At a dock it comes in along the east channel's outer bank, crosses just past the berth's run, and goes out along the west bank.
  - It lies still while the ferry is near, unless it is on the ferry's line; then it rows on, quicker, out of the way.
- **Tests:**
  - `tests/r20_ferry_test.gd` ride covers quay → the Mahaleh → the Gardens → the Forgotten City → quay, then the Mahaleh dock's bell: 33 checks, 0 failures.
    - Drift on the deck was at most 0.22 m, and no rock was in the ferry's way.
    - The lantern boat's whole route through the harbour and all four dock styles is clear of rock, checked with a small-boat box (2 × 2.6 × 4.8 m).
    - The ferry never came within 4 m of the lantern boat.
  - save and load, in separate processes: 0 failures.
  - The first ride found a dock boulder in the ferry's way (the ledge, now gone) and a lantern route through harbour boulders. Both are fixed.
- **Pictures:** `previews/phase18_step3/` (`tests/r20_docks_capture.gd`) show:
  - the pier board, the flooded board and the lantern boat in the harbour;
  - for each destination, the deck on arrival, the dock front, the dock from its water, its board, and the lantern boat.
  - GPU 0.5–0.8 ms, at most 160 draw calls.
- **Found while taking pictures:** the dock boards were built at the harbour's origin and facing the house. They now stand in their docks and read from the water.
- **Caveat:** at a dock the lantern boat crosses about 18 m from the stage, so its lantern is only a small light that far off.
- **Not yet (step 4):** life and dressing checks across the docks, and the default style's own look.

### Step 3 ride, report 1 (2026-11-08): "where is the ferry?"

- **Cause:** an older save had left the ferry at a dock, so when you came into the harbour it wasn't at the pier head.
- **Fix:** once you are placed (after a load or arriving through a door), the docked ferry waits where you are: at the quay, or at the dock you're standing in (`LakeFerry._wait_for_you`). The dock doors are sealed, so you can only be in one of those places.
- **Test:** `r20_ferry_test.gd -- elsewhere` passes 5 checks. Ride, save and load still pass.

### Step 3 ride, report 2 (5 reports, 2026-11-08)

- **Floating rocks at the Forgotten City dock:** the rubble now lies on the dock's strip (`build_lake.gd`).
- **A rail sticking out at the bow:** the taper rails were mirrored. They now run inward in the model, and the ferry's collision (`LakeFerry._build`) matches.
- **The ferryman had no body:** his robe used a cut-out cloth shader that needs UVs, so it drew nothing. It is now a plain cloth.
- **"The ferry needs to be redesigned"** (you chose the Persian lantern barge). `lk_ferry` rev 4 keeps the hull, deck and boarding gap, and adds:
  - a tile band and carved trim on the hull;
  - bulwarks sweeping up to two carved bow posts, each hanging a brass lantern over the water;
  - turned balusters, kilim cushions and bolsters, and a kilim on the deck;
  - an arched striped canopy with valances, brass tassels and two lanterns under its ridge;
  - a tall stern post curling forward, with a lantern hanging from the curl.
  - Two lights: the starboard bow lantern, and a softer forward canopy light (`lake_canopy` profile). The other lanterns glow only.
- **"These lamp posts need a better look"** (you chose the pierced brass lanterns). `lk_lantern_post` rev 2 is a carved post with turned brass rings and finial, a scrolled iron arm, and an eight-sided pierced brass lantern (fanous). The lantern is the same one used on the ferry.
- **Pictures:** `previews/phase18_ride2/`. Headless gate clean. Ride and save tests still to run, once the look is agreed.

### Step 3 ride, report 3 (2 reports, 2026-11-08)

- **"What are these floating cylinders?"** These were the iron bollards at the pier head's stage, and at every landing quay's stage too. They were built at deck height, 0.9 m above the stage. `bollards()` now takes a base height, and the stages pass `STAGE` (pier head and landing quay rev 4).
- **"The pier is dark coming back from the Mahaleh until the boat lands."** Under the fog, the ferry showed the arrival place as the destination's dock style. The quay has no dock style, so it showed the default dock and hid the harbour until the ferry docked. It now shows the harbour when crossing to the quay, and no longer re-dresses the default dock's board and bell for "the quay".
- **Test:** each ride now also checks that, after the fog, the place shown is the one the ferry is in. Results:
  - ride: 37 checks, 0 failures;
  - save and load (separate processes): 2/2 and 5/5;
  - elsewhere: 5/5;
  - headless gate clean.
- **Picture:** `previews/phase18_ride3/`.

## Step 4: life and dressing at the docks (2026-11-08, first pass)

- **Fungi:** each dock style has its own fungus colour (the cave rule: light away from buildings comes from glowing fungi, a colour to each place). The town dock is amber, the garden dock lime, the ruin violet, and the default dock teal. It applies to the two glow ledges in the chamber, their caps and their lights (`LakeLife._dock_glows`). The channel mouths keep the lake's colours.
- **Life by world seed** (`build_lake.gd _dock_life`, picked by `LakeLife._seeded`):
  - **Town:** a fisher mending at one end of the strip or the other, with his nets and traps; pots and crates. Up to 2 extra moored boats.
  - **Garden:** up to 5 beds, planters and shrubs; a gardener with a jar; a fishing line. Up to 1 extra boat.
  - **Ruin:** nobody. A boat sunk at one mooring or the other, broken jars and fallen stone.
  - **Default:** a figure sitting on the strip. Up to 1 extra boat.
  - Dock boats come from their own random sequence, so the harbour's boats for a seed are unchanged.
- **Lighting:** lantern posts at both ends of the strips for the town, garden and default docks. The ruin keeps to its fungi. The garden's daylight from the crack is wider and brighter (radius 6, energy 14).
- **Found while taking pictures:** the facade's top cornice was placed one storey too high on every dock and landing, so it floated about 3.5 m above the wall. It now sits on the wall.
- **Pictures:** `previews/phase18_step4/` (seeds 1 and 5: each dock wide, both strips, a glow ledge). Headless gate clean.
- **Look approved 2026-11-08 ("looks good").** Tests: ride 37/37, save 2/2, load 5/5 (separate processes), elsewhere 5/5. The harbour's own life (fisher, boats, hearth, fishing spots) is unchanged from the walks you approved. Route audit and frame gate come in step 5.
