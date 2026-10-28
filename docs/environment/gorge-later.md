# The gorge: for a later pass

Things noticed while building phase 8 and left for another pass over the gorge. None of them blocks play. Phase 8 is complete (last commit 0479835, 2026-10-27).

## Look and layout

- **Two links' waterfalls almost overlap.** In the seed you've been flying (433536861), two links sit side by side and their waterfalls nearly meet, around (-27, -136). This comes from how the network is planned for that seed: the planner lets two links leave neighbouring connectors in parallel. Either keep falls a few metres apart across links, or keep parallel links further apart.
- **Fewer clearings on the far banks than the ramp asks for.** From bank 5 on, the plan asks for more clearings (domes and minarets open to the cavern) the further a bank is: five at bank 8. Bank 8 got two, and bank 7 two. Their faces run out of room once the clearings keep their spacing (30 m), stay clear of the iwans, the bridge connection points (frontage slots), the quarried rock pillars (cavern spurs) and the sanctum. Options: a tighter spacing on the far banks, or smaller clearings (two bays, the small dome).
- **The gorge scenery clean-up pass** (asked for during phase 6): gaps, clipping and extra geometry across the gorge, found by flying it (V for fly mode, the ` key for reports).

## Smaller items seen along the way

- **Dark rock behind some clearings.** Where a quarried rock pillar closes a clearing's back, the back wall is plain dark rock.
- **Old-style waterfall ribbons in the camp's own view.** The camp's code-built view of the gorge (not the walkable gorge) still uses the old narrow waterfall ribbons and the old rock gate.
- **The box-art far depth band** is accepted at 0.5 (`tests/compare_vista.gd` `ACCEPTED_LOW`) after the thinner mist; revisit if the mist changes again.
- **Network planning time.** The slowest plan in the network test is about 7–9 s (seed 3). Fine at load, but worth a look if areas start planning during play.

## Where to look

- Banks, clearings, iwans: `scripts/gen/persian_town.gd` (`_clearings`, `_clear_fits`, `CLEAR_*`).
- Links and their falls: `scripts/world/area_network.gd`, `scripts/gen/chasm_link.gd`, `scripts/gen/chasm_grammar.gd` (`TROUGH`, `FALL_*`).
- The bake: `tools/bake_gorge.gd`; progress and history: [phase 8 progress](progress/phase-8-gorge-redesign.md).
