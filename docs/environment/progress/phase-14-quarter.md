# Progress: phase 14, the Domicile Quarter (R06)

[Back to the front page](../../../ENVIRONMENT_PLAN.md) · [Approval brief](../phase-14-approval.md)

**In short:** all five steps are built and the quarter is live in the Mahaleh: two to four quarters per world. Committed 2026-11-06 at your word.

## Step 1: lanes and houses (built 2026-11-05)

- **To walk it:** on the Strata Board, open the Mahaleh's copy `quarter_test` and use Walk this seed. The quarter grows off the garden or an alley (20 of 20 seeds).
- **Built:** `tools/kit_add_r06.py` makes 48 pieces in `art_src/kit/kit_quarter.blend`; `QuarterGrammar` (`scripts/gen/quarter_grammar.gd`) lays out the lanes, 1-3 storey houses, two sabats, the hauz and the rock; `tools/make_r06_rules.gd`, `tools/make_r06_draft.gd`; `tests/r06_capture.gd`. New materials: `quarter_plaster_rose`, `quarter_plaster_clay`, `quarter_lane`. New light profile `home`.
- **Room:** 36 × 32 m, 357-372 pieces, 10-11 lights in the seeds captured.

### Checked

- Kit test: 9,600 checks, 0 failures.
- Route audit, seed 7: the capsule walks to the quarter and up its stair to the far door. Two warnings remain, not failures of the walk: the door wall's growth socket runs into `qt_gate`, and the same kind in the Bridge Hall entrance.
- Captures in `previews/phase14_step1/c/` (seed 7) and `b/` (seeds 1 and 4, before the stair lights and blank-wall fix).

### Not checked or not done

- Seed 4's walk fails at its first stop, before the quarter. The plain Mahaleh recipe fails the same way, so the quarter didn't cause it; the quarter itself is unwalked on that seed.
- The route audit follows the far-door route. The side arms are not walked yet.
- The tint is too orange for "rose clay at dusk".
- Doors don't open; no cloth, smoke, figures or abandoned edge yet (steps 2-4).
- No frame gate, per the rule to test once the look is final.

## After your first walk: layouts, entry alley, Itself (built 2026-11-06)

Your walk: several quarters side by side work but are confusing to navigate.

- **To walk it:** `quarter_test` now grows two to four quarters off the alleys, the garden and each other, each behind a short entry alley. Seeds 2, 3, 8 and 9 have all four layouts.
- **Four layouts:** `hauz`, `wind`, `bath`, `pigeon` in `QuarterGrammar`, each mirrored by seed. New pieces `qt_badgir`, `qt_bath`, `qt_bath_portal`, `qt_pigeon`. Quarters of an area are dealt from a shuffled order (the planner now gives a grammar its slot id and area seed in `grid.meta`), so no repeats until all four are used.
- **Board settings on the room:** Layout (Seed picks or one of the four), Entry alley (None, Short 8 m, Long 12 m). New pieces `qt_cavern_neck_2`, `_3`, `qt_rock_low`, `_b`, `_top`.
- **Grows from:** a new Itself toggle for every grow rule. Under Any generated room it shows on and greyed, as that already includes itself. A rule with only Itself gets a note, as its first room would have nothing to grow from.
- **Deserted version back in** (Q6), for step 4.
- Walls beside a sabat are now blank: its body was cutting through their windows.

### Checked

- `tests/r06_layout_test.gd`: 6,520 checks pass (every layout with every alley over 40 seeds: lanes joined, doors reached, no repeats among four quarters).
- `tests/board_form_test.gd`: 25 checks pass, with Itself on, off and following the count.
- Kit test: 9,719 checks, 0 failures.
- 20 of 20 draft seeds grow at least one quarter with the alley on.
- Captures of seed 3 in `previews/phase14_layouts/`; `four_layouts.png` shows each layout from where the lanes begin.

### Not checked or not done

- No capsule walk of the new layouts or the alley, per the rule to test once the look is final. The layout test checks the grid, not collision.
- Lights: 10-16 per quarter, so three or four joined quarters could press on the 50-light limit if near each other. Not measured.
- The `qt_gate` socket warnings are still to clear in step 5.
- Far-door and side-door views from the stairs are not judged: the capture's "far" view looks into the stair walls.

## Step 2: light and mood (built 2026-11-06)

- **To walk it:** the same copy, `quarter_test`, on the Strata Board. Seeds 2, 3, 8 and 9 have all four layouts.
- **Colour:** the orange came mostly from the Persian brick and the warm light on it. The quarter now has its own dusty brick (`quarter_brick`), pinker plaster in both tints, a paler `home` light and a cool mood tint (`mood_tint` 0.7, 0.66, 0.78 at 0.4). Rose shows near the windows and lamps, cool dusk between them.
- **Light:** small lanterns on brackets (`qt_door_lamp`) by doors that get a real light; up to five dim cool fills along the lanes at 1.3 m (`CoolAir*`), so the dark between pools is dusk and not black. The wind tower's head has its own light.
- **Washing and cloth:** `qt_washing_a`, `qt_washing_b`, `qt_cloth`, up to four per quarter over straight lanes, on a new `quarter_cloth` map. They use the foliage wind shader, hems moving most.
- **Smoke and steam:** `QuarterLife` (`scripts/gen/quarter_life.gd`, slot `qt:life`): smoke from up to three brick chimneys, steam from the bath-house lantern, a drop now and then on the hauz. Warmed by PipelineWarm.
- All 57 earlier pieces were rebuilt in the .blend for the new brick (rev 3). The file had no hand edits: its date matched the last script run.

### Checked

- Kit test: 9,761 checks, 0 failures. `tests/r06_layout_test.gd`: 6,520 checks pass.
- Captures of seed 3 in `previews/phase14_step2/`: `sheet_mouth.png` (each layout where the lanes begin), `sheet_smoke.png` (from above the roofs).
- 15-19 lights per quarter in that seed.

### Not checked or not done

- Everything that moves was judged from stills only: the cloth's sway and the drops on the hauz have not been seen moving. The emitters are in the room (3-4 per quarter).
- The smoke shows as small wisps from above the roofs; from the lanes the chimneys are mostly hidden. It may need to be stronger or nearer the lanes.
- The Hauz Square is the darkest layout.
- Lights: 15-19 per quarter means three joined quarters in reach would be close to the 50 limit. Not measured; the frame gate waits for step 5.
- No capsule walk yet.

## Step 3: the homes (built 2026-11-06)

- **To walk it:** on the Strata Board, open the Mahaleh's copy `quarter_test` and use Walk this seed. Seeds 2, 3, 8 and 9 have all four layouts. Lit windows mark the homes; look at a door and press E.
- **Homes:** four or five per quarter, on lane and square fronts clear of the rock, the blank walls and the landmarks. About two in three have two rooms joined by an arch; the rest have one. Every quarter gets a scholar, a family, a hunter and an abandoned home. The abandoned one is the home furthest from the quarter's middle.
- **Doors:** they open and shut with E, swing into the house, and don't block you while moving. Doors aren't saved. The abandoned home's door stands ajar. Other doors stay shut, as in the brief.
- **Households:**
  - Scholar: shelves, a reading table with its lantern, a rug and cushion, books and scrolls.
  - Family: a hearth with a fire, a low table with a lamp, poufs, and in two-room homes a sleeping ledge with bedding and a pantry.
  - Hunter: traps, stretched hides, a pack, and in two-room homes nets and a bedroll.
  - Abandoned: webbed shelves, broken things, rubble, spent candles, a faint cool light, no lamp.
- **Built:** `QuarterGrammar._lots` and `_furnish`; pieces `qt_g_home_<tint>`, `qt_home_1`, `qt_home_2`, `qt_home_leaf`, `qt_home_hides`; `HomeDoor`; `QuietWall` (takes the Cistern's glowing fungus and its light off the traps and nets); `quarter_hide` material. Door lamps are now capped at 12 (was 16), and a home's lamp counts as one of them.

### Checked

- Kit test: 9,872 checks, 0 failures. `tests/r06_layout_test.gd`: 7,480 checks pass, including three to five homes and different households in each.
- New `tests/r06_door_test.gd`: 32 checks pass. Placed facing each of the four ways, the door stops the capsule shut, lets it through open, swings inward and answers the interaction ray.
- `tests/r06_capture.gd` now walks the player's capsule from the lane to the back of each home with its door open: all 16 homes in seed 2 walk in. Seed 2 only.
- Captures of seed 2 in `previews/phase14_step3/`, one sheet per layout: each home from inside and from the lane.

### Not checked or not done

- Lights: 23-27 per quarter in seed 2, up from 15-19. Two joined quarters in reach would be about at the 50 limit, so this needs bringing down or measuring. The frame gate waits for step 5.
- The door has been tried by test and from stills only: nobody has pressed E on it in the game, and the swing hasn't been watched.
- The capsule walk covers homes only, in one seed. The new lanes haven't been walked yet; that audit is step 5.
- No figures, working hearths or notes yet (step 4).

After you looked at step 3: it isn't obvious which doors open without looking for the see-through window. You said that can wait, so it's still open.

## Step 4: life and story (built 2026-11-06)

- **People:** up to six at their doors and on their steps near the quarter's heart, standing, sitting or carrying a jar, plus someone in each lived-in home: reading, stirring the pot, mending. They don't move or talk.
- **Working hearths:** every family home has a hearth you can cook at and warm yourself by. The hearth piece from step 3 already did this.
- **Notes:** E reads one and it stays where it lies. 12 short placeholder notes, three per kind of household. A lived-in home has a 60% chance of one; an abandoned home always has one. Text is in `scripts/world/home_note.gd`, for you to replace or approve.
- **Gradient:** the quarter thins out from a heart three cells in from the entry row, so you arrive somewhere lived in and it empties ahead of you. Further out, windows are shuttered, lamps stop, chimneys stop smoking, washing turns to rags, plants and rubble line the walls. Lit fronts and doors: 32% near the heart, 16% further out.
- **Deserted version:** a new State setting on the room (Lived in, Deserted). No people, lamps, fires, smoke or washing; lit glass goes dark; homes are abandoned, fled (a cold hearth, things left behind) or bare; ivy on the fronts; pale cool light so it's dim but not black, with the landmark still visible. Copy `quarter_deserted` shows it until the Forgotten City exists.
- **Left out:** rest. The brief's life line mentions it, but the game has no resting yet.

## Step 5: live and tested (built 2026-11-06)

- **Live:** `tools/make_r06_live.gd` adds the quarter to the Mahaleh's recipe (v6): two to four quarters off an alley, the garden or each other, with a short entry alley. Over 40 worlds: 2 quarters in 16, 3 in 11, 4 in 13, no plan errors; the four layouts come up about equally.
- **Route audit:** `tests/area_route_test.gd` with the new `from=` option, seeds 1-7 of the live recipe: the capsule walks through every quarter and join, down every side lane, and into every home and back, nothing stuck. Validation is clean on every quarter after the fixes below.
- **Fixed by the audit:** the tour followed the far-door route out of a quarter even when the next room hung off a side door; door walls grew plants into the gate; a family's cook stood too close to the table; a figure or rubble could block a home's door, so nothing stands within 2.4 m of one now.
- **Save and resume:** `tests/r06_resume_test.gd` saves inside a home and resumes in a fresh process, on its floor with the room's life built.
- **Map:** the quarter's lanes, the block in the middle and the home you're in are drawn, with you on it; see `previews/phase14_step5/map.png`. The hauz has no mark of its own.
- **Atlas:** R06 marked as in the game, and its character brief updated; the colour table in `room-character.md` has its line.
- **Cost:** a home's furniture is now only drawn within 20 m, since nothing culled it behind the walls.

### Frame gate (seed 2, four quarters in a chain, Medium, walked at 8 m/s)

| | Limit | Worst in a quarter | Result |
|---|---|---|---|
| GPU per frame | 4 ms | 2.6 ms | Pass (7.2 ms once in an alley, not a quarter) |
| CPU per frame | 8 ms | 17.2 ms | **Over** on 15 of about 32,000 quarter frames |
| GPU and CPU means | 3 ms, 4 ms | about 1.0 ms, 1.7 ms | Pass |
| Draw calls | 1,500 | 1,580 | **Over** on one frame |
| Lights in reach | 50 | 47 | Pass (51 in the entrance hall, from the entrance and the square) |
| Shadowed lights | 4 | 4 | Pass |

The gate as a whole reports FAIL. Each quarter has one slow frame of 14-17 ms with no room loading at the time; the cause isn't found. Only seed 2 was measured.

### Not checked or not done

- No walk reports came back on steps 4 and 5 before the commit. The checks here were stills and tests; none of them saw anything moving.
- The slow frames above aren't explained.
- The Mahaleh's walk from its entrance: the capsule falls off in the Bridge Hall when the tour follows the hall's route from the root, so the audit starts past it. It may be the tour rather than the room; not looked into. The entrance also has one socket warning of its own.
- The deserted version: route audit run on one seed only.
- Which doors open isn't obvious (above).
