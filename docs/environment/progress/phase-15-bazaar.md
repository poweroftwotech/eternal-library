# Phase 15 progress: the Grand Bazaar (R04)

[Back to the front page](../../../ENVIRONMENT_PLAN.md) · [Approval brief](../phase-15-approval.md)

## Step 5: live and tested (built 2026-11-07, committed after your walk: phase 15 is complete)

- **Your walk:** you walked and tested the deserted version by adding it to the Forgotten City, and it looks good enough for now. That recipe now also has a deserted quarter.

- **Live:** `tools/make_r04_live.gd` adds one bazaar to the Mahaleh's recipe (now v7), off an alley or the garden. It grows in 40 of 40 worlds, with no plan errors.
- **Quarters:** the bazaar took their space (0 quarters in 33 of 40 worlds), so quarters can now also grow off the bazaar's doors. Now: 2 quarters in 9 worlds, 3 in 8, 4 in 11, and **none in 12**.
- **Route audit:** `tests/area_route_test.gd` on seeds 1, 2, 7 and 13 of the live recipe, and 13 deserted. The capsule walks through the bazaar, round the middle, down every street and into every open shop and back, nothing stuck. Every room passes its checks except the entrance's old socket warning (also noted in phase 14).
- **Wall checks:** the bazaar's walls don't lie on its cell edges, so the audit now tests real points ("bounds" in its meta): each shop's back and sides, shut fronts, street ends and the crossing's walls. Where a figure stands at the start, it goes by a ray past the figure.
- **Fixed by the audit:** groups stood too close to the walk round the middle, and row figures could stand in a shop's way in.
- **Save and resume:** `tests/r04_resume_test.gd` saves inside a shop and resumes in a fresh process, on its floor, with the room's life built. The quarter's resume test still passes.
- **Map:** the bazaar draws as one plain block with you on it, and shops, crossing and middle have no marks of their own; see `previews/phase15_step5/map.png`.
- **Atlas:** R04 marked as in the game; `room-character.md` has its line.

### Frame gate (seed 13, the largest bazaar: four streets of six bays, 29 open shops, four quarters; Medium, walked at 8 m/s)

| | Limit | In the bazaar | Whole area | Result |
|---|---|---|---|---|
| GPU per frame | 4 ms | 2.3 ms | 8.7 ms | Bazaar passes. Area over on 6 frames: 4 in `alley_1`, 2 in `quarter_2` |
| CPU per frame | 8 ms | 19.4 ms | 20.0 ms | **Over** on 2 of 19,961 bazaar frames |
| GPU and CPU means | 3 ms, 4 ms | 1.03 ms, 1.67 ms | 1.02 ms, 1.66 ms | Pass |
| Draw calls | 1,500 | 1,324 | 1,864 | Bazaar passes. **Over** on 585 frames in `quarter_4` and `quarter_2` |
| Lights in reach | 50 | 52 | 53 | **Over** on 615 bazaar frames, and in the square and quarters |

The gate as a whole reports FAIL. Only seed 13 was measured.

- Every room has one or two frames of 18-20 ms with nothing loading, as in phase 14. The cause still isn't found.
- `alley_1` has 26 frames over 8 ms, worst 14.6 ms, most of them while the bazaar and the rooms past it stream in.
- Why `quarter_4` went over on draw calls wasn't looked into. It was 1,580 at worst in phase 14, on a different seed.

### Not checked or not done

- The live, lived-in Mahaleh wasn't reported on separately: your walk was of the deserted version.
- 12 of 40 worlds have no quarter.
- The audit starts at the bazaar's door, as phase 14's did, because the walk from the Mahaleh's entrance through the Bridge Hall is still unsolved.

## Step 4: life and story (built 2026-11-06, accepted 2026-11-07)

- **Walk it:** the copies `bazaar_test` (lived in) and `bazaar_deserted`. Pictures in `previews/phase15_step4/`.
- **People:** a keeper behind every open counter (three looks). About 36 still figures and groups at the crossing, in a loose ring, with the four ways through left clear. Along the rows they thin out toward the ends. Each figure is one draw call.
- **The middle, by seed:** a fountain with running water, or a storyteller on a low stage with eleven people sitting round. The walking route now goes round it.
- **Rumour board:** in a blind arch on the south side of the crossing, under a candle. E reads three notes, chosen by where the board stands. The texts are placeholders, marked as such in the panel, for you to replace or approve.
- **Steam** rises from the food stall's pot.
- **The gradient:** open shops fall from about 85% at the crossing to 20% at the row ends, and awnings and pennants stop before the ends. Shut shops in the far half get empty hooks and dust.
- **Deserted:** a State setting (Lived in, Deserted), as on the quarter. No people, keepers or steam. Stalls bare, awnings in rags, few pennants, about a quarter of the panes gone in half the bays, the fountain dry or the stage bare, the board nearly empty. The beams still fall.

### Checks

| Check | Result |
|---|---|
| Headless, 240 frames | 0 errors |
| Kit test | 10,569 checks, 0 failures |
| GPU pictures | Lived in seeds 1 to 7; deserted seeds 1, 2 and 7 |

### Not checked or not done

- No capsule route test or frame gate yet (step 5). The crowd and the new route round the middle have only been seen in pictures.
- Reading the board has not been tried in play.
- The dust goes orange where the beam falls on it, as in the dry fountain.
- In the deserted rows the shut shops' bars look too bright against the dark.
- Blender crashed once rebuilding the shops (EXCEPTION_ACCESS_VIOLATION, cause not found). The same run went through on the next try.

## Step 3: the shops (accepted 2026-11-06, walked once, 2 reports fixed)

- **Walk it:** the same copy, `bazaar_test`. Pictures in `previews/phase15_step3/`: `t_` from the street into each trade, `i_` at its counter, `a_` and `b_` at its side walls.
- **Seven trades, all in every bazaar:** rugs, copper, lamps, books, spices, curiosities, food. They are dealt from a shuffled deck, so neighbours differ. About half the shops are open, and never fewer than seven.
- **You can walk into every open shop:** a counter across the back with room for a keeper behind it, goods on the walls, and a little spilling out beside the piers. The middle of each arch stays clear.
- **Awnings** on about 60% of open shops, in two cloths. **Pennants** cross every third bay. **Shut shops** get a brass bar or crates, or stay bare.
- **Cost:** each trade is one mesh, with a few surfaces, plus one mesh of plain collision boxes. Goods and awnings draw only within 34 m. There are no new lights.
- **New materials:** `bazaar_copper`, `bazaar_brass`, `bazaar_embers` and the palette `bazaar_goods`. The first copper was the camp's patina and looked rusty.
- **Shell fix:** the crossing's side wall stood 0.4 m into the first shops on each street and buried their shelves. Beside the street it is now 0.15 m thick up to the shop roofs.
- Tool: `tools/kit_add_r04_shops.py`.

**Walk 1 (2 reports, fixed):** the shops were too bright, and you asked for a colour and mood per trade. Each trade now brings its own lamp and light (`MOODS` in `tools/kit_add_r04_shops.py`): rugs wine, copper forge orange, lamps nearly dark so the glass shines, books a quiet pale light, spices saffron, curiosities sea-green, food warm hearth. Energy is down from 0.9 to about 0.3-0.7. Pictures: `previews/phase15_step3b/`.

The lights cast no shadows, so a colour shone through walls onto the next arch. Their reach went from 5.5 m to 3.7 m to stop that. Two costs: less glow on the street floor, and goods out in the street are dimmer. A faint red line still shows round one shut arch in a corner bay.

### Checks

| Check | Result |
|---|---|
| Headless, 240 frames | 0 errors |
| Kit test | 10,329 checks, 0 failures |
| Bazaar fits | 20 of 20 seeds |
| Pictures | All seven trades in seed 1, in the game's renderer; the streets of seed 4 |

### Not checked or not done

- **No capsule route test or frame test yet** (they come once the look is final), so no walk through the shops has been tested, and there is no frame test yet. Your walk's F3 panel showed 815 and 981 draw calls of 1500 at two spots with goods in.
- Shops have no keepers yet; those come in step 4, with the crowd, steam and rumour board.
- Lamp shop lamps glow by their own colour and throw no light.

## Step 2: light and mood (built 2026-11-06, walked twice, 6 reports fixed, accepted: "that's better")

- **Walk it:** the same copy, `bazaar_test`. Pictures in `previews/phase15_step2c/`.
- **Gaps closed:** over the shop arches, at the top of the street arches at the crossing, and under the shutters (a shut shop had no floor beneath its arch).
- **Glass:** star-and-cross panes in a dark lattice, cut to each arch, in ruby, cobalt, amber and pale straw with three shades each. One mesh and one material (`bazaar_glass`).
- **Why the glass looked wrong on your walk:** the import compressed its small palette texture, and that mixed neighbouring colours, so the blue came out maroon. It is now lossless, and each shade has its own block, so compression could not mix them anyway.
- **Beams:** a new `beam` light stands over the eye, so the beam fills the eye. Very narrow cones stopped reaching the floor.
- **The eye was see-through:** its walls and its day disc faced the wrong way, so from below you looked past them. Both now face in. The collar is stone.
- **Dome:** a painted map that follows the curve (`bazaar_dome.png`, `dome_uv`): a sunburst round the eye, a bead ring, sixteen pointed arches, brick coursed round the dome, an eight-point star in each corner. The street vaults lost their dark tile patch and are brick.
- **Contrast:** the fills are much lower and the beams narrower, with less haze: pools of light with dim stretches between, and the lit shops stand out. After your second walk the crossing matches the streets: its one high, wide fill is now a low pool under the beam, so the walls and dome fall into dimness and the eye and glass carry the room.
- **Colour patches on the floor: removed,** at your word, since they would not sit well on goods and people.
- **Shop lamps:** a brass lamp on a rod in every open shop. **Dust** turns slowly in the crossing's beam.

### Checks

| Check | Result |
|---|---|
| Headless, 240 frames | 0 errors |
| Kit test | 10,192 checks, 0 failures |
| Bazaar fits | 20 of 20 seeds |
| Your reports | Four retaken in the game's renderer; the fifth (the patches) is gone. Pictures are seed 1 only for this round |

### Not checked or not done

- No capsule route test or frame test yet (they come once the look is final).
- **Lights: 40 in the four-street bazaar,** over the brief's estimate of about 30, under the limit of 50 in reach. The step 5 gate counts neighbours too.
- The dome is now dim: the pattern reads round the eye, but the corner stars are nearly dark. A small lift is easy if you want more of it seen.
- Shut shops far from an eye are very dark. The guide says dim, never black, so tell me if any stretch goes too far.
- The eye's stone collar still shows faint rings.

## Step 1: the crossing and the streets (built 2026-11-06, walked by you 2026-11-06: "overall good start")

- **Walk it:** Strata Board, the Mahaleh, copy `bazaar_test`, Walk this seed. Seed 1 has all four streets; seed 2 has two, and shows the tall glass arch.
- **Built:** `tools/kit_add_r04.py` -> `kit_bazaar.blend` (11 pieces), `BazaarGrammar`, `tools/make_r04_rules.gd`, `tools/make_r04_draft.gd`, `tests/r04_capture.gd`. Pictures in `previews/phase15_step1/`.
- **More than the step asked for:** all the streets rather than one, since a street is just a loop in the generator. The shops have rooms and shutters already, but no goods.
- **Fit:** in the test copy, grown after the alleys and garden and before the quarters, it fits in 20 of 20 seeds, with two to four streets. In the first try it grew before the alleys existed, so 0 of 20.
- **New brick:** `bazaar_brick`, honey with pale joints (`pixel_materials_ext.gd -- bazaar`). The Persian kit's brick came out fiery orange, nothing like your photos.
- **Light is a working first pass,** so the space can be judged. Step 2 sets it properly. The vault's fill is bright enough to judge the dome; the guide wants the ceiling darker than the walls, so it may come down.

### Checks

| Check | Result |
|---|---|
| Headless, 240 frames | 0 errors |
| Kit test | 10,228 checks, 0 failures |
| GPU pictures | Seeds 1 and 2 |

### Not checked or not done

- Nobody has walked it: no capsule route test yet (route tests come once the look is final). The doors and shop floors have only been seen in pictures.
- The capture's view inside a shop missed: it shows a close wall. Shop rooms are only seen from the street.
- Lights: 41 in the four-street bazaar against the brief's estimate of about 30. Step 2 should bring that down.
- The glass is flat primary colours in a plain grid, more like a modern window than your Tabriz photo. Step 2.
- The neighbouring rooms and the doorway ends haven't been looked at.
