# The gorge: for a later pass

Things noticed while building phase 8 and left for another pass over the gorge. None of them blocks play. Phase 8 is complete (last commit 0479835, 2026-10-27).

## Look and layout

- **Two links' waterfalls almost overlap.** In the seed you've been flying (433536861), two links sit side by side and their waterfalls nearly meet, around (-27, -136). This comes from how the network is planned for that seed: the planner lets two links leave neighbouring connectors in parallel. Either keep falls a few metres apart across links, or keep parallel links further apart.
- **Fewer clearings on the far banks than the ramp asks for.** From bank 5 on, the plan asks for more clearings (domes and minarets open to the cavern) the further a bank is: five at bank 8. Bank 8 got two, and bank 7 two. Their faces run out of room once the clearings keep their spacing (30 m), stay clear of the iwans, the bridge connection points (frontage slots), the quarried rock pillars (cavern spurs) and the sanctum. Options: a tighter spacing on the far banks, or smaller clearings (two bays, the small dome).
- **The gorge scenery clean-up pass** (asked for during phase 6): gaps, clipping and extra geometry across the gorge, found by flying it (V for fly mode, the ` key for reports).

## Smaller items seen along the way

- **Dark rock behind some clearings.** Where a quarried rock pillar closes a clearing's back, the back wall is plain dark rock.
- **Dead camp-view code in `vista.gd`.** Its branches for the old code-built camp's view (old waterfall ribbons, old rock gate, used only when `walkable_overlook` is off) are no longer run by anything: the game uses the kit camp, which draws no gorge. Phase 9 step 1 removes them.
- **The box-art far depth band** is accepted at 0.5 (`tests/compare_vista.gd` `ACCEPTED_LOW`) after the thinner mist; revisit if the mist changes again.
- **Network planning time.** The slowest plan in the network test is about 7–9 s (seed 3). Fine at load, but worth a look if areas start planning during play.

## Where to look

- Banks, clearings, iwans: `scripts/gen/persian_town.gd` (`_clearings`, `_clear_fits`, `CLEAR_*`).
- Links and their falls: `scripts/world/area_network.gd`, `scripts/gen/chasm_link.gd`, `scripts/gen/chasm_grammar.gd` (`TROUGH`, `FALL_*`).
- The bake: `tools/bake_gorge.gd`; progress and history: [phase 8 progress](progress/phase-8-gorge-redesign.md).

## Seen during phase 9

- **A dark plain corner on ledge_2** (seed 433536861, by (49.6, 0, -111)): the bank's stone core shows where the ledge's own clearing took the face bays away. It looks the same with phase 9's system switched off (`--no-seamless`), so it predates it (phase 6's ledge claims).

- **Draw calls a little over the Gorge's budget** (phase 9 step 3's frame gate, 2026-10-30): 2,640 at the door ledges and 2,717 from the camp looking through its doorway, against 2,600; GPU worst 4.51 ms against 4.5. The two slowest swaps (about 47 ms) come from showing or hiding the whole Gorge at once; hiding it by render layer instead would take most of that away.
