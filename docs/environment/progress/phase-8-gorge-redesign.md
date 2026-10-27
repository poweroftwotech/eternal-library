# Progress: phase 8, the gorge redesigned

[Back to the front page](../../../ENVIRONMENT_PLAN.md) · [Brief](../phase-8-approval.md) · [Design](../phase-8-design.md)

**In short:** step 1 is built. A reusable Persian kit of 45 pieces (houses,
openings, portal, dome, minaret, carved rooms, the great iwan, gardens,
fungi, the lumen stone, spillways) in its own `persian` family, its pixel
materials, two reusable nodes (`GreatFall`, `LightShaft`), and a gallery
scene that shows them all lit as in the gorge. The kit test passes; the
gorge itself is unchanged until step 2.

## Step 1: the Persian kit (2026-10-26)

**What you can look at:** `rooms/test/persian_gallery.tscn` (open it in the
editor), and the GPU captures in `previews/p8_step1/`:

| View | What it shows |
|---|---|
| `gallery_wide.png` | The whole gallery from the air |
| `gallery_houses.png` | A plaster and a lime house, lattice windows, doors with lanterns, a windcatcher, a lit bed under a shaft of light |
| `gallery_window.png`, `gallery_door.png` | Close-ups of the house window and door |
| `gallery_monument.png`, `gallery_portal.png` | Arcades, coloured-glass windows, the portal, dome and minarets, a chahar bagh lit by two lumen stones |
| `gallery_carved.png` | Carved doors and windows, a rock path |
| `gallery_iwan.png`, `gallery_iwan_close.png` | The great iwan, its lumen stone over the spring, its garden; fungi where the light ends |
| `gallery_dark.png`, `gallery_dark_low.png` | Giant and jelly fungi, fungal beds, glow moss |
| `gallery_fall.png` | A great fall from a great spillway |

**Built:**
- `tools/kit_add_persian.py` → `art_src/kit/kit_persian.blend` (45 modules,
  `kit/modules/persian/`); `KIT_REV` rebuilds them all when the builders
  change.
- `tools/pixel_materials_ext.gd` `persian()`: 19 pixel maps (the existing
  maps regenerate byte for byte).
- Glow materials in `kit/materials/`: `emit_orosi`, `emit_glowmoss`,
  `emit_strands`, `emit_gills`, `emit_fungus_jelly`, `emit_interior`;
  `emit_lumen` in `PxMaterial.EMIT_COLORS`; `persian_mirror` made metallic.
- Light profiles `lumen` and `fungus` (`tools/kit_import.gd`).
- `scripts/world/great_fall.gd` + `shaders/great_fall.gdshader`;
  `scripts/world/light_shaft.gd`.
- `tools/build_persian_gallery.gd` → the gallery; `tests/persian_gallery_capture.gd`.

**Verified:**
- `kit_test`: 5,745 checks, 0 failures (297 modules in the catalog).
- GPU captures at 1600 × 900: the widest view draws 19,859 triangles in 152
  draw calls, 0.8 ms GPU (RTX 5090).

**Fixed on the way (from the captures):**
- The dome hid behind the portal and poked through its hood: it now stands
  on a 6 m drum with lit windows, set back.
- Mushroom gills read as flat bright discs: now a shallow cone with a gill
  texture; giant caps and stalks rounder.
- The fall showed horizontal bands: two noise layers half a cell apart, and
  its own distance haze instead of volumetric fog.
- Arch crowns, rings and spandrels are now built from convex pieces (one
  concave face per crown can export with a sliver across the springing).
- Calmer plaster up close; the iwan's relief no longer reads as lettering;
  carved interiors glow dimmer than house windows.

**Caveats:**
- The gallery's cliff is a box, so the carved pieces and the iwan stand out
  from it; in the gorge they sit flush with the rock (design 8.2).
- The gallery has no player; it's for looking and capturing. Walking comes
  with bank 1 (step 2).
- The cypresses are the gorge's existing ones; flowers and pomegranate
  leaves are simple cards.

## Step 2: bank 1 in the new look (2026-10-27)

**What you can try:** Esc → Walk the Gorge. Bank 1 (the left bank you see
first from the Overlook) is a Persian hill town; the other banks are as
before. Fly mode (V) reaches every terrace. GPU captures in
`previews/p8_step2/` (`tests/gorge_capture.gd` views `b1_*`):

| View | What it shows |
|---|---|
| `gorge_b1_shaft.png` | The terraces from above: houses stepping down, stairs between terraces, the iwan garden and the shaft garden, lanterns at doors |
| `gorge_b1_garden.png` | The iwan cut into tier 17, its lumen stone over the spring, the pool, beds, cypresses and pomegranates on the terrace in front |
| `gorge_b1_top.png`, `gorge_walls.png` | The monument on the top tier (portal, arcades with coloured glass, crown, dome, minarets) over the houses and carved fronts |
| `gorge_b1_fall.png` | The great fall stepping down three terraces into the mist |
| `gorge_b1_north.png` | The dark north side: fungal terraces with teal glow, glow moss on the carved fronts |
| `gorge_concept.png` | The box-art view |

**Built:**
- `scripts/gen/persian_town.gd` (`PersianTown`): bank 1's tiers dressed per
  building (phase-8-design.md 8.3). `GorgeGrammar.PERSIAN_BANKS = [1]`
  hands a bank to it; the tiers themselves are unchanged, so walk planning,
  frontage slots, links and keep-out are as before (no re-bake of them).
  - Each face run is split into buildings of 1–3 bays: house (plaster or
    lime), carved front (rock; more near the mist and the roof), or the
    monument run. Buildings stand 0, 0.2 or 0.45 m proud so neighbours read
    apart. A house's door is on the storey that meets a terrace, with a
    lantern where the cluster noise burns; windows lit or dark by the same
    noise.
  - Roofs (`persian_roof`), parapets (plaster, lime or rock; the crown on the
    monument), a stair (`persian_stair_flight`, one flight per storey) up
    every tier from the terrace below.
  - Once per bank: the monument on the top tier; the iwan (`persian_iwan_tier`)
    on the best three-storey run facing the Overlook with a terrace at least
    9 m deep, its lumen stone and garden; the great fall from a
    `persian_spillway_great`, stepping down terraces (a pool where it lands)
    to the mist; the shaft garden on the terrace most squarely facing the
    Overlook that is open to the cavern and away from the lumen light.
  - Roof life by the light: fungal beds, giant and jelly fungi and a teal glow
    in the dark; beds and cypresses under the shaft or the lumen stone.
- New kit pieces: `persian_wall_rock` (+ `_window`, `_window_dark`, `_door`,
  `_door_dark`), `persian_parapet_rock`, `persian_stair_flight`,
  `persian_iwan_tier`; `persian_spillway_great` is now two storeys tall.
- `tools/bake_gorge.gd`: builds `GreatFall` and `LightShaft` nodes from the
  grammar's extras; lamp brackets join the lamp clusters; tall pieces (portal,
  dome, minarets) tell the rock how much clearance they need (`top`).
- `GorgeScenery.REMOVABLE`: the Persian facade and roof pieces clear behind
  galleries as the old bays did.
- `LightShaft`: its haze cone now points the right way (narrow at the crack,
  wide where the light lands).

**Numbers:** bank 1 is 4,588 pieces (about 7,000 before). From the
Overlook's box-art view: 1,665 draw calls, 3.32 M triangles, 2.7 ms GPU on
the RTX 5090 (the whole gorge; most of it is still the old banks).

**Verified:** `gorge_route_test` 8 checks, `r10_span_test` 485, `gorge_network_test` 790 (20 seeds; galleries still clear bank 1's facade), `kit_test` 5,855, all 0 failures; the headless gate is clean; box art (`compare_vista`) passes
all five regions and every check (`previews/p8_step2/vista_bank1.png`).

**Caveats:**
- Draw calls in the box-art view are 1,665, over the 1,500 limit (about 1,580
  before): bank 1 brings many new piece types, each its own batch. Step 4
  (the budget check) merges bank 1's middle-distance pieces.
- The shaft's beam is wide (10 m at its foot); easy to narrow.
- Up close, the upper storeys of the houses are plain (few windows, by the
  calm rule); more life on walls (carpets, vines, awnings) is Q4's dressing,
  not yet placed on bank 1.
- The iwan is partly behind the gate colossus from the balcony.

### After your look: the monument dominates the bank (2026-10-27)

You found the monument sitting on top of the houses like a hat. Now
(`PersianTown._monument`, pictures in `previews/p8_step2b/`):

- **Mid-stack:** it stands on the roof of tier 14 (at -16 m, about the
  middle of what the Overlook sees and above the mist), set back 8 m from the
  tier's face. The tier's houses are below it; the 8 m in front is its
  garden.
- **Grander:** four storeys (16 m) of arcades, coloured-glass windows and
  a crown band, a new **grand portal** (16 × 21 m, `persian_portal_grand`),
  the **grand dome** behind it (5.2 m radius on a taller drum,
  `persian_dome_grand`), and two **33 m minarets**
  (`persian_minaret_tall`) flanking the portal. The builders are now
  parametrised (`portal_of`, `dome_of`, `minaret_of`), so other sizes are
  one line each.
- **Garden in front:** a chahar bagh on the tier's roof: a pool along the
  front with its fountain, beds either side, a cypress row along the
  parapet, two lumen stones before the portal, pomegranates at the ends.
- **Sandwiched:** the tiers above lose the cells over the garden, the
  monument and its dome, so it stands in a clearing open to the cavern
  with houses rising either side; the faces round the clearing get walls,
  and leftover fragments under 12 cells are dropped. Features (iwan, falls,
  shaft) keep clear of the clearing and its garden.
- The iwan moved to tier 9 (-92 m) and the great fall to tier 13; the
  shaft garden is now on the top tier's open roof.
- `bake_gorge.gd` retries a save when another program briefly holds the
  file (it failed twice on bank scenes).

Verified: route 8, span 485, network 790 (20 seeds), kit 5,918 checks, all
passing; box art passes. Box-art view: 1,692 draw calls, 3.35 M triangles.

Caveats: walk planning still sees the cut-away cells as solid (it reads the
tiers, not the bake): harmless, it only keeps galleries out of that air. The
shaft of light now falls in the balcony's line of sight, past the gate
colossus; it can move if it gets in the way.

### After your walk: four reports on the houses (2026-10-27)

Re-taken from your spots with `tests/report_capture.gd` in `previews/p8_step2c/`.

| Your report | Cause | Fix |
|---|---|---|
| Flickering band at the top of the houses under the monument garden | each roof slab's edge sat in the plane of the wall front below it | roof slabs 2 cm below the walls' tops, walls (and the iwan, spillway and monument walls) at least 3 cm in front of the slab edge (`ROOF_DROP`, `WALL_PROUD`) |
| Water pool going over | the 8 m pools ran out from the face onto 7.5 m terraces | the iwan's pool lies along the face with beds between it and the iwan; cascade pools turned too, and skipped where their corners don't fit |
| Houses too plain | blank walls and single windows | blank walls 10–16% (was 20–28%); paired windows (`persian_wall_*_window2`) on about half the upper storeys; a wooden oriel (`persian_oriel`, a shanashil) on some blank upper walls; a striped awning (`persian_awning`) over some doors; a banner from some parapets; a corbelled brick cornice (`persian_cornice`) under every house parapet |
| Tints too extreme | plaster, lime and dark dressed rock far apart | one warm family: lime a step lighter than plaster, dressed rock a step darker, and calmer mottling |

Verified: route 8, network 790, kit 6,010, all passing; box art passes.

### After your walk: access, overhangs, parapet joints (2026-10-27)

Re-taken from your spots in `previews/p8_step2d/`.

| Your report | Fix |
|---|---|
| The iwan's garden blocks the whole terrace | As you suggested: the building below steps forward 3 m over the lower terrace (`PersianTown._extend_terrace`): new face with windows and a door, end walls, roof strip, parapet and cornice; the lower terrace keeps at least 2.5 m. The garden terrace is now about 10.5 m deep, the pool and beds against the iwan, a walk in front |
| Large overhangs should be visibly supported | carved stone brackets (`persian_corbel`, stretched to each overhang) under every tier that overhangs the one below by more than 1.2 m, at the lower wall's bay edges, which are clear of its windows, doors and oriels; not where a stair or feature stands (`_supports`) |
| The parapets break where buildings step in and out | an L return of the prouder building's parapet across each step, and the cornice turned the same way (`_joins`), on every floor |

Verified: route 8, span 485, network 790, kit 6,018, all passing; box art passes.

### After your walk: stairs, the iwan's front, soffits, the monument's view (2026-10-27)

Re-taken from your spots in `previews/p8_step2e/`.

| Your report | Fix |
|---|---|
| The stairs still look weird; fill the support down, with an arch or niche, in the monument's brick | under every upper flight a brick pier per storey down to the terrace, each with a pointed niche, stone ring and sill (new piece `persian_stair_pier`); the flights themselves are now brick with stone nosings, and their parapet brick |
| The pishtaq here still isn't updated: tiles on its face, the monument's brick inside the niche | `persian_iwan_tier`: a tiled field round the arch, a stone ring and frame, a banai band near the top; the hood's walls and back in the monument's brick |
| Z-fighting at the foot of the hanging buildings | the soffit under an overhang sat level with the walls' undersides; it now hangs 4 cm lower (`SOFFIT_DROP`) |
| An overhanging house blocks the view of the monument | the tiers above now lose everything up to 16 m out in front of the garden too, not just over it (`MON_SIGHT`) |
| This stair doesn't make sense here | it ran up into the Overlook's west arch where it lands on bank 1. Stairs now keep clear of that landing (`KEEP_CLEAR`), stand wholly over their terrace, and prefer a top that arrives on roof room to walk on; this one moved four bays along, up to the iwan's garden terrace |

Verified: route 8, span 485, network 790, kit 6,041, all passing; box art passes.

### After your walk: what the last round put in the way (2026-10-27)

Same seed as before. The last round's changes moved things into the Overlook's west bridge, which the town's rules didn't know about. Re-taken from your spots in `previews/p8_step2f/`.

| Your report | Fix |
|---|---|
| Trees on the bridge, a pool clipping into geometry | the shaft garden had moved under the bridge (its sky test only looked at the bank's tiers), and its cypresses grew through the deck. `KEEP_CLEAR` is now the bridge's real footprint, measured from `rooms/gorge/overlook.tscn` (deck at -12 m, arch down to -25 m), not a sphere. The shaft garden, stairs and all garden and roof life (`LOOSE`) keep out of it, and the shaft's pool must fit its roof |
| A staircase up to a terrace with no room to use | it had moved beside the bridge's landing and the iwan's stepped-forward building; it now stands on another face. Stairs score higher when nothing stands beside either end |
| A very narrow way in to the stairs | its foot was 0.75 m from the terrace's edge parapet. Stairs now prefer 3 m of terrace along the face before their foot (their own parapet closes the open side); this one moved one bay along |

Verified: route 8, span 485, network 790, kit 6,041, all passing; box art passes.

### After your walk: the stair's end (2026-10-27)

| Your report | Fix |
|---|---|
| The end of the stair has no railing; close it with the stair's brick | the top flight of every stair is a new piece, `persian_stair_flight_top`, whose brick parapet turns across its far end to the wall; the way off is onto the roof behind. Re-taken in `previews/p8_step2g/` |

Verified: route 8, span 485, network 790, kit 6,056, all passing.

## Step 3: the camp's front (2026-10-27)

Before and after from the same spots: `previews/p8_step3/before/` and `previews/p8_step3/after/` (far, near, oblique, the terrace looking out, the loggia looking back).

| Part | Was | Now |
|---|---|---|
| The pishtaq (`vista_cliff.gd` `iwan()`, `iwan_dressing()`) | sandstone brick, a plain tympanum | your call on the iwan applied: a brick body faced with tile, a banai band along the top, stone frame, pier niches with banai panels, stone and banai roundels, brick merlons with stone caps; the tympanum inside is brick |
| The loggia | bare rock cheeks and back | the pishtaq's niche: lined with the monument's brick (`loggia_lining()`) |
| The terrace (`vista.gd` `build_balcony()`) | sandstone parapets, tile strip and floor, two vases | brick parapets with a banai strip, stone paving, and a garden by the light rule: a planted bed along each side parapet, a lumen stone behind each (`balcony_garden()`, kit pieces copied in as meshes so the bake keeps their light layers) |
| The cliff either side and above (`GorgeGrammar.cliff`, removed) | the banks' library bay stacks and galleries | a cliff village (`PersianTown.cliff()`): two-storey bands on rock-cut ledge paths, dwellings carved into the rock mixed with plaster and lime house fronts built against it, a door per building with a lantern, oriels, glowing moss on dark rock; a plaster stair tower at each side's inner end with a door onto every ledge (an outside stair switching back between 1.8 m ledges blocks its own ledge); rock-cut windows and oriels over the pishtaq |

The camp's interior is unchanged.

Verified: route 8, span 485, network 790, kit 6,056, all passing; box art passes (near flanks 64 of the box art's 70, within range).

### After your walk of the camp's front (2026-10-27)

Re-taken from your spots in `previews/p8_step3b/`.

| Your report | Fix |
|---|---|
| Curve or shift the stair so it arrives centred on the camp's door | **Not done yet: needs your call.** Tried moving its top to the door's line (x -1). The landing, its flight and the ledge to bank 1 are laid along the stair's line, so the whole Overlook walk swung 5 degrees: the ledge's end opened onto bank 1 and the route and network tests failed. The box-art camera also stands where the stair would arrive. Put back. The front parapet now takes a gap anywhere along it (`stair_gap()`, `in_stair_gap()`), ready for whichever way you choose |
| The tiled arches should run to the walls (two reports) | both loggia arches widened (radius 6.23, `LOGGIA_ARCH_RADIUS`) so their jambs and tiled spandrels meet the brick-lined walls; their jambs' collision stands where the jambs are (`loggia_arches()`) |
| Remove the two columns by the door | gone, with their collision; the route test's probe of the stair head's west side now starts on the first step (from the head's middle that way is the balcony's floor, closed before only by the old columns' collision) |
| Raise the arch to meet the ceiling | the spandrels run up into the canopy (`GorgeHost.arch` takes a `top_at`) |
| The arch by the door should join the wall and frame the door; remove anything hidden | the back arch stands on the back wall (its stones against the brick) and frames the passage door; the passage, which stood 3.6 m out into the loggia, now ends at the back wall, and its arch and lantern out there are gone. The lumen stones moved forward clear of the arch |

Verified: route 8, span 485, network 790, kit 6,056, all passing; box art passes.

### The stair centred on the door (2026-10-27, your call: turn the stair only)

Re-taken in `previews/p8_step3c/`.

- The stair's top is on the door's line (`VistaForeground.STAIR_TOP` x -1); the landing, its flight and the ledge keep the old line (`LANDING_FROM`, `landing_flat()`), so the Overlook's walk, the west arch and the connector to the span are exactly where they were.
- The landing's near edge: its balustrade now runs from each corner to where the stair's balustrades cross it, stretched pieces and a newel at each crossing (`tools/bake_overlook.gd`).
- The route test and the tour follow the stair's line to the landing and the landing's line beyond; the route test's probe over the balcony's parapet stands east of the stair.
- **The box-art view:** its camera stood at x -1, where the stair now arrives. Tried x -1, 1.4, 2.6 and 3.6; none passes all checks. Closest is 2.6 (one miss: the mist floor 31% brighter than the box art, because the view now looks through the span's arches at the lit mist). Left at 2.6, for your call.

Verified: route 8, span 485, network 790, kit 6,056, all passing. Box art: 1 check misses (above).

### After your walk: the stair's head, the parapets, the back wall (2026-10-27)

You accepted the new box-art view: `tests/compare_vista.gd` allows the mist floor up to 1.4x for it (`ACCEPTED_HIGH`). Re-taken from your spots in `previews/p8_step3d/`.

| Your report | Fix |
|---|---|
| A gap between the stair's rail and the parapet | each stair balustrade now starts at a newel exactly where its line crosses the front parapet's line, and the parapet ends under that newel (`VistaForeground.parapet_s()`, `parapet_crossing()`); the east one runs level along the head to it first (the head is 2.7 m long now, was 2.2) |
| Clipping objects on the parapet | walked, the per-metre stone caps, turned balusters, faience posts and the rail over them are gone: one stone coping along each parapet run and one banai band along its face; the side parapets' gold bar is a coping too |
| The rail doesn't line up | as the gap: the west balustrade's newel stands on the crossing (the long bridging newel is gone) |
| Add garden along the sides of the arch; the crystal lights point the wrong way | a planted bed against the back wall either side of the door frame, a lumen stone at its outer end inside the arch's jamb, turned so its mirror faces out over the garden (it faced the door, showing you its back) |

Verified: route 8, span 485, network 790, kit 6,056, all passing; box art passes (mist floor 1.32, within the accepted 1.4).

### After your walk: the stair's corner, a fountain (2026-10-27)

Re-taken from your spots in `previews/p8_step3e/`.

| Your report | Fix |
|---|---|
| A disconnected railing at the stair's top | the east balustrade's level run along the head and its sloped run down the stair met at different heights with nothing between: a newel stands at the turn now |
| A small fountain or pool in the middle, with room to walk round | the kit's pool (scaled to 4.8 x 2.4 m) with its fountain in the loggia's middle: 2 m clear of the side beds, 1 m of the columns, 1.2 m of the back beds; solid, so you walk round it. The fountain's jet is left out here (its cards read as a dark strip against the door: `kit_piece`'s `skip`) |

Verified: route 8, span 485, network 790, kit 6,056, all passing; box art passes.
