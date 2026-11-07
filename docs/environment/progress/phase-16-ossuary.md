# Progress: the Ossuary of Books (R17), phase 16

[Back to the front page](../../../ENVIRONMENT_PLAN.md) · [Approval brief](../phase-16-approval.md)

## Step 1: the passages and the shrine chamber (built 2026-11-07, walked)

Walk it from the Strata Board: the Mahaleh, copy `ossuary_test`, Walk this seed.
The ossuary grows off a quarter. Seed 1 has 25 cells, seed 3 has 14.

- **What's there:** the cave cell and throat from the door, low passages 2.2 m wide
  with bare niches (one long, four small per bay), the eight-sided shrine chamber,
  side passages, small empty bier rooms, and the far door.
- **Layout:** the chamber is placed first, 2 to 5 cells in from the entry, so the
  tended end is near the door. The long arm runs to the far door, the other ends
  in the rock.
- **Numbers:** grows in 20 of 20 seeds of the test copy, 14 to 25 cells, a far door
  every time, 1 to 3 dead ends. The grid's own layout check finds nothing wrong on
  any of them. Kit test: 10,696 checks, 0 failures.
- **Pieces:** `tools/kit_add_r17.py` writes `kit_ossuary.blend`. Each piece comes
  from one floor plan, so every junction meets. Generator:
  `scripts/gen/ossuary_grammar.gd`.

### Not final, for step 2

- The light is a first pass: dim fills every second cell and plain candles, to make
  the bare space walkable. 26 lights at seed 1, which step 2 should bring down.
- The fill reads greener than "bone". It needs to move toward grey.
- The shrine's niche is too bright and flat with five candles in it.

### Not tested yet

Route audit, frame gate, save and resume and the map wait until the look is final,
so nobody has walked it with the real player capsule yet, including me. Tell me if
you catch or stick on anything.

Pictures: `previews/phase16_step1/`; with a lamp on the camera to show the
stonework, `previews/phase16_step1_bright/`.

Step 1 walked 2026-11-07: "looks good".

## Step 2: light and mood (built 2026-11-07, walked)

Same place on the board: the Mahaleh, copy `ossuary_test`. Seed 1 and seed 13 are both large.

- **Candles:** single candles in niches, in a seeded niche of a straight passage, never two cells running. They thin out and stop 8 cells past the chamber. Each light stands out in the passage, so it lights the walls and floor and not only its own niche.
- **The shrine:** two stone ledges at the back of the great niche with 16 candles of different heights, the room's only shadowed light outside it and a small glow inside.
- **Colour:** the stone is greyer (bone, not moss), the fill nearly neutral, and the room's tint is stronger. Candlelight warms the stone near each flame and it falls back to cold grey between.
- **Dim, never black:** a fill at most every third cell and in every dead end, fainter past the last candle, where it comes every second cell. This fill has no source you can see, which bends the light rule, and it's the one thing to judge here.
- **Motion:** every flame gutters, its light with it, with an occasional dip. Flames lean away and dim a little as you pass within about 2.4 m (Q5). Threads of dust fall from the vault, more of them past the candles.
- **Fixed on the way:** the vault's sawtooth edge at the walls, a hot spot where a candle's light sat too close to the wall, and a dead end with no light at all.

Lights: about 18 in a 25-cell room, down from 26. One shadowed. Kit test passes; 20 of 20 seeds.

Still not tested: route audit, frame gate, save and resume, map. The guttering and leaning have only been seen as stills; 6 to 7 candles were confirmed running in the capture, but nobody has watched them move yet.

Pictures: `previews/phase16_step2/`.

## Step 3: the niches and biers (built 2026-11-07, walked)

Every niche wall is now filled. Pictures are in `previews/phase16_step3/` (seeds 1 and 2).

- **The niches.** Each 2 m bay gets one piece for its long niche and one for its four
  small ones: the shrouded dead (head at either end), rows and stacks of books, wrapped
  bundles and scrolls, with a few left empty. A niche with a candle keeps clear for it.
- **Tended to forgotten.** Past the chamber the bays turn grey, and by about eight
  cells on nearly all are. Old bodies are sunken and grey, old books dusty, leaning and
  gappy, and old small niches are often empty. Slumping, spilling and bare rock are step 4.
- **The biers.** Each bier room has a stone bier with a plinth and a shrouded body, feet
  to the door. A tended one has a candle at the head, which replaces the room's fill
  light, so the light count doesn't change. A forgotten one has no candle and an old body.
- **Possession hosts (Q2).** Each bier body has a `PossessionHost` marker in the group
  `possession_host`. Nothing uses it yet.
- **The shrine.** The wrapped great book lies on a sloped stone rest, a red cloth runs
  down the steps, and books and bundles stand at the sides. Offerings are step 4.

Layouts and lights are unchanged: the contents roll their own dice. Seed 1 still has 25
cells and 18 lights, and generation still grows in 20 of 20 seeds.

### How it's built

- `tools/kit_r17_goods.py`: 19 new pieces in one palette material (`ossuary_goods`), no
  collision in the niches; only the bier's stone is solid.
- `OssuaryGrammar._dress`: fills the bays with its own dice. `WALLS` lists each piece's
  niche walls.
- Seed 1 has 179 pieces, seed 2 has 146. They are only drawn within 24 m (`near_only`).

### Checked

- Kit test: 10,881 checks, 0 failures.
- GPU captures of the passages, chamber, shrine, a candle's niche, dead ends and biers.

### Not tested yet

- Frame cost of the new pieces, and whether they visibly pop in at 24 m.
- The route past the bier, save/resume and the map (step 5, once the look is final).

### For your walk

- Niche insides stay very dark in the unlit stretches, so the contents only show near a
  candle or fill light.
- The bundles are better but can still look a little like loaves up close.
- The bier candle's light leaves a soft bright patch on the wall behind it.

## Step 4: life and story (walked and reworked 2026-11-07)

Pictures are in `previews/phase16_step4/` (seeds 1, 2 and 3) and
`previews/phase16_step4/forgotten/` (seed 1). `see_*` pictures show one of each new thing.

- **Mourners' traces.** Fresh folded cloth, a bowl of oil, dried flowers and a tray of
  spare candles: one of each before the shrine, others at the foot of the wall in the
  tended stretch, and one at the foot of a tended bier. Nobody is seen (Q4).
- **The slide into ruin.** Past the chamber the old bays start to fall: bodies slid out
  over the sill to the floor, books heaped at the foot of the wall, a torn cloth hanging
  out of a niche. Further on, shrouds are in rags (cloth only, never bones: Q1) and bare
  rock comes through the wall, filling the niches first.
- **The Forgotten version (Q7).** A State setting on the board, Tended or Forgotten.
  Every niche candle is out and nothing is left by mourners. Everything is as far gone
  as the deepest stretch, and the shrine has burnt-down stubs, grey torn cloth and one
  candle still burning. To see it on the Strata Board, walk the `ossuary_forgotten_test`
  copy. It is not in the Forgotten City yet (step 5).
- **Lore books (Q6).** Two per room, from three new books, each alone in a small niche
  on a folded cloth, in the deepest dead ends first. Their texts are placeholders for you
  to replace or approve. A book you already hold doesn't appear again.
- **The candle you light (Q6).** It stands on a dish at the end of the shrine's cloth.
  E lights it. It burns down over 30 minutes of play, then a stub is left that you can
  light again. The time is saved. This needed a new count of seconds played in the save
  (`played_s`), as the save had no running clock.

### Changes outside the room

- `RoomTemplate.restore_world`: a one-of-a-kind item you hold no longer reappears as a
  generated prop. Before this, only shelf books stayed taken.
- `WorldState.played()`: seconds of play, saved with the world.

### Fixed along the way

- Rock: a black ball, then a floating boulder, now a jagged surface rising out of the wall.
- Dried flowers looked like a skeletal hand; the lore book's gilt bands made a cross.
- A flame could miss its guttering when a streamed room placed it late: `os_life` is now
  placed last. Seed 2's count went from 4 back to 5.
- Blender crashed once in `kit_blender.py` line 112 while remaking modules added earlier
  in the same run. A rerun was clean, and it hasn't come back in three builds since.

### Checked

- Kit test on the final build: 11,012 checks, 0 failures.
- `r01_resume_test`: save 6 checks, load 8 checks, 0 failures (the change to taken items).
- In the real game by script: the candle's prompts change when lit; both lore books went
  into the satchel.
- GPU captures, Tended and Forgotten. Generation on the final build: 20 of 20 seeds.

### Not tested yet

- That a lit candle or taken book survives a real restart (step 5's save and resume).
- That the candle burns out: only the start of the burn has been seen.
- The route past rock and heaps, frame cost, and pop-in at 24 m (step 5).
- The Forgotten version in the Forgotten City itself.

### For your walk

- Dust: I only added more dust threads in the Forgotten version. There is no dust lying
  on things, so "dust thickens" is thin. Say if you want it.
- The high rock has a teardrop shape close up.
- The Forgotten shrine's one candle still lights the niche quite fully. It reads well
  from the chamber, but you may want it dimmer.

### Your walk of step 4: six reports, both versions (fixed 2026-11-07, you walked it: looks good)

You walked the tended version and the Forgotten version and asked for light that
explains itself, more drama, and a spookier, colder Forgotten state.

- **Every light now has a source.** The invisible fill lights are gone from the kit,
  and a room can now take less of the area's ambient light
  (`RoomGrammar.ambient_scale`: .8 tended, .85 Forgotten, eased in `area.gd`).
- **New sources.** Oil lanterns on chains (`os_lantern`, every 4th cell and in dead
  ends of the tended part). Past it, and all through the Forgotten state, clumps of
  blue glowcaps at the foot of the walls (`os_glow`, `os_glow_small`, every 2nd cell).
- **More contrast.** Candles, lanterns and the shrine now cast shadows (light types
  `ossuary_candle`, `ossuary_lantern`, `ossuary_shrine`). The shrine's light moved
  inside its niche, so the arch throws a wedge of light into a dark chamber. The bier
  candle's light came down to the flame.
- **Cold in the dark.** The room's tint is now blue-grey, stronger when Forgotten, so
  the flames are the only warm thing.
- **Forgotten only.** Thick knee-high fog in every cell, the throats and the chamber (`ossuary_ground_fog`), up to 8 puddles
  with drips from the vault, and cobwebs across niches (`os_item_web_a`, `_b`). The
  webs also start to appear in the deepest stretch of the tended version.

This changes two lines of the brief at your word: glowing plants are allowed here,
and the Forgotten state has fog.

Checked: kit test 11,030 checks, 0 failures; 20 of 20 seeds; captures of both versions
and your six reported views. Not tested yet: route past the new pieces, frame cost
(fog, more shadowed lights), Forgotten in the Forgotten City.

For your walk: the Forgotten chamber is very dark away from the shrine, and some
Forgotten stretches go close to black. That may be right or may be too much.

Second look, same day: you found the vault lichen hard to read next to the glowing
fungi in other rooms and wanted thicker fog. The lichen is gone; the glowcaps above
are the stack galleries' plant, and their low light glows in the fog. The fog is
strongest where a light reaches it and fades out in the unlit stretches.

## Step 5: live and tested (built 2026-11-07, you walked it: phase complete)

You walked step 4 again and said it looks good, so the room is now in the live recipes
(`tools/make_r17_live.gd`):

- **The Mahaleh, version 10:** tended, off a quarter, in 38 of 40 worlds.
- **The Forgotten City, version 5:** forgotten, off any free door, in 40 of 40 worlds.
  Off the Old City alone it fitted only 8 of 40.

Both rules come last in their recipes, so the room takes no other room's place.

### Tests

| Test | Result |
|---|---|
| Capsule walk: Mahaleh worlds 2 and 5, every dead end out and back | Pass in the Ossuary. One failure each, in the Mahaleh's entrance: a wall warning (`arch_growth` runs into `prop_bh_cave_0_0_0`), not in this room |
| Capsule walk: Forgotten City world 2 | Pass, 72 checks |
| Save in one process, resume in another (`tests/r17_resume_test.gd`, world 2) | Pass, 19 checks: candle still burning, book yours and gone from its niche, the other books left, the map draws the room, the candle burns out and can be lit again |
| Kit test | Pass before going live (11,044 checks); nothing in the kit changed after |

### Frame gate (world 2, Medium, 1080p, walked at 8 m/s)

| In the Ossuary | Limit | Tended | Forgotten |
|---|---|---|---|
| GPU mean / worst | 3 / 4 ms | 0.87 / 2.03 | 0.87 / 3.56 |
| CPU mean / worst | 4 / 8 ms | 1.60 / **18.8** | 1.49 / **10.2** |
| Draw calls | 1,500 | **1,575** | 642 |
| Lights in reach | 50 | 26 | 17 |
| Shadowed lights | 4 | 4 | 3 |

Both areas report FAIL as a whole.

- **Slow frames in the Ossuary:** one frame in each version. The tended one fell on a
  room swap (10 rooms loading, 8 unloading).
- **Draw calls:** over the limit on 805 of 12,394 tended frames.
- **Elsewhere in the areas:** 61 lights in the square and 60 in quarter_1, and a worst
  frame of 44 ms in the Mahaleh entrance and 85 ms in the Forgotten Study. None of
  these are in the Ossuary.
- **Not explained:** the Mahaleh run printed one `Trying to cast a freed object` script
  error. It wasn't traced, and the Forgotten City run didn't print it.

Not tested: other worlds' frames; the room's pop-in at the 24 m goods distance by eye.
