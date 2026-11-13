# The zoo: a test place for animals

[Back to the front page](../../../ENVIRONMENT_PLAN.md)

Asked for 2026-11-13, after phase 19: a quick way to reach every animal, see
where it spawns and how it behaves, and tune it. Agreed in three steps:

1. **The zoo and a way in** (built 2026-11-13, below).
2. **An overlay** (not built): where animals can spawn, where they were
   refused and why, what each is doing; in the zoo and in real areas.
3. **A tuning panel** (not built): change an animal's settings in the game,
   respawn at once, save to its data file. Needs the behaviour values that
   are fixed in code today moved into the data files.

## Step 1: the zoo

**Get there:** the Strata Board's **Walk the zoo** button, or run the game
with `--room=zoo`. It is not part of the world and nothing in it is saved.

A corridor with six pens, three a side, each 12 m square with a sign over
its door. Each pen is a room of its own to the animals' director, with a
room type and a state, so the game's real placement rules run unchanged.
Every animal is at its usual number (the "common" level).

| Pen | Conditions | Built for | Also turns up (the rules, working) |
|---|---|---|---|
| Tended pool | Lit hauz, 45 cm deep; counts as a Garden Court | Goldfish (9) | Loose moths (14: the Garden Court's) |
| Dark cistern | 1.5 m of dark water, a 5 m roof, a faint fungus glow | Cave barbs (20) | Bats (22: the roof is high and dark) |
| Lamp wall | Ten burning lamps on open flat walls | Moths (14), geckos (7) | |
| Rock vault | 9 m natural rock roof, no flame | Bats (25), glowworms (486) | |
| Lived-in room | Three rugs, four cushions, a bench, a bedroll, walked lanes, a small hauz, two lamps | Cats (2) | Goldfish (3), geckos (4) |
| Forgotten room | Abandoned state, long bare walls | Rats (4) | |

**How it is made.** `scripts/world/zoo_room.gd` (`ZooRoom`) builds it in code
from plain boxes in the kit's materials plus a few kit props, on the world's
4 m cells; the scene `rooms/test/zoo.tscn` is only its root. A pen is a row
in `PENS` and a `_pen_<id>` function of a dozen lines, so a new animal gets
a pen by adding both. `Fauna` asks a place for `fauna_pens()` and treats
each as a room (it used to know only areas and one-room places).

**Check.** `tests/zoo_capture.gd` counts each pen's animals (headless) and
with a display writes pictures to `previews/zoo/`; `--expect` fails unless
every pen holds the animals it is for. Passes.

**Known limits.** The vault is nearly black, as the bats' rule wants, so
the bats themselves can hardly be seen until step 2's overlay. The lamps
are plain brackets, not kit lamps. The pens are bare boxes: they prove the
rules, not the look of a real room.

## Step 2: the overlay (built 2026-11-13)

**F4** turns it on and off anywhere in the game, the zoo and real areas
alike (or start with `--fauna-overlay`). It only reads; it changes nothing.

- **Markers** where the placement rules looked: green a place taken, red a
  roof refused, amber a burning lamp, grey a light that is no flame, teal a
  fungus glow, yellow a cat's rest spot, blue still water or a fish-watching
  place, orange a rat run and its holes; thin green lines are the ways a
  cat can walk.
- **Look at a marker** and the bottom of the screen says what it is and,
  kind by kind, why it was taken or refused: "Bat: no, a lamp burns 4.2 m
  away (needs 10 m of dark)", "Geckos: none, the wall by it is not open to
  the room".
- **Look at none** and it sums up the room you stand in: who lives there
  and how many, and for every other kind the reason it does not ("Cat:
  nothing soft to lie on", "Rat: only in forgotten rooms").
- **Over each animal:** what it is doing (a cat's "resting (sit, 21 s
  more)", a rat's "in its hole (4 s)", a gecko's "clinging", "Bats:
  hanging"), with a red ring at the distance you startle it and, for cats,
  a pale ring at the distance it looks at you.

`scripts/world/fauna_overlay.gd`. `Fauna` now keeps each live room's
finished scan (`found`) for it, and records what became of every lamp for
geckos (`GeckoWall.why`) and which flames have moths (`MothSwarm.used`).

Checked in stills in the zoo (`tests/zoo_capture.gd --overlay`) and in the
Mahaleh. **Limits:** fish, moths and glowworms have no label each (too
many); labels of animals close together overlap; the reasons for a rat run
or a cat spot that was *refused* are not kept, only the room's summary.

## Step 3: the tuning panel (built 2026-11-13)

**F5** in the zoo opens and closes it; the mouse is freed while it is open.
`scripts/world/zoo_panel.gd`.

- **Pick an animal** and its settings are sliders: length, group sizes,
  the distance you startle it at, speeds, and the ones of its habitat (the
  share of lamps, the least roof height, how dark, soft things per cat, how
  far a cat looks, how far a gecko climbs ...). Move one and the whole zoo
  is placed again a quarter of a second later.
- **Amount here:** 0 to 300% of the usual number of the picked animal, in
  the zoo only. **New seed** places everything again another way;
  **Respawn** the same way.
- **Triggers:** Ignore me (stand as close as you like), Slow motion (a
  quarter speed), Overlay (as F4), Startle all, Lamps out / lit.
- **Save to its file** writes the picked animal's settings to
  `actors/defs/<kind>.tres`, which the game reads. **Undo changes** puts
  back what the file had. Leaving the zoo drops whatever was not saved.

**Values moved out of code into the animals' files** so they can be tuned:
a cat's walking and trotting speeds (its `speed`), its size (its
`length_m`; the model is 50 cm), `look_radius`, `crowd_radius`; a rat's and
a gecko's `safe_radius`; a gecko's `climb` and `wall_reach`. Nothing
changed in value.

`Fauna` gained `respawn()`, `startle_all()`, `ignore_player`, `amounts` and
`seed_bump`.

**Test:** `tests/zoo_panel_test.gd` passes (10 checks): sliders give 20
rats, amount 0 gives no geckos, cats twice as long, Startle all startles
the cats, Undo restores, rats come out beside you with Ignore me on, Save
writes the file (the test then puts it back). The zoo still fills, and the
camp and Mahaleh still have their cats.

**Limits.** Colours, the cat's coats and timings such as how long a cat
sleeps are not on the panel. Putting lamps out only removes geckos; moths
stay until a respawn. Saving rewrites the whole file in Godot's own layout.

## Walk 1 of the zoo: 7 reports (2026-11-13)

| Report | What changed |
|---|---|
| Carpets flicker against the floor (lived-in room) | The zoo's rugs sit 1.2 cm over the floor. Only the zoo placed them in the floor |
| Goldfish, cave barbs, cats: a size range, not one size | Each already drew a size per animal, but narrowly. Wider now: goldfish 7 to 19 cm (was 9 to 16), cave barbs 60 to 150% of their length (was 80 to 120), cats 51 to 78 cm (was 59 to 70). The panel's Length slider is now two, **Smallest** and **Largest** (m), for every animal |
| Rats only ever stick to the walls | A rat that stops to sniff now leaves the wall half the time and crosses the open floor, noses about, goes on to another spot or back to the wall; startled out there, it bolts straight across for its hole. It only goes where the floor is open (checked every half metre along its run, up to 5 m out). Panel: **How often it leaves the wall**. Measured in the zoo: rats spent more frames out in the room than on the wall, up to 3.4 m out |
| Bats can't be seen in the dark and barely move at rest | They have a dull lift of their own now (it lights nothing), three in ten are on the wing under the roost (was one in ten) and fly a wider, deeper circle, and hanging ones turn, sway more, and now and then stretch their wings and fold them. Panel: **Shows in the dark**, **Share on the wing at rest** |
| Glowworms read as a static fungus | Each worm lets its thread down and reels it in in its own time, the threads sway, waves of brightening cross the colony, and now and then one flares and hauls its line up fast (a catch). The threads are a little brighter |

`CreatureDef.roam` is new (rats: how often they leave the wall; bats: the
share on the wing). `tests/zoo_panel_test.gd` and `zoo_capture --expect`
pass. The moving parts (glowworms, bats stretching, rats crossing) were
checked by numbers and stills, not watched.

## Walk 2 of the zoo: 10 reports (2026-11-13)

| Report | What changed |
|---|---|
| Most creatures have no shadows, so they don't sit in the room (cats, geckos named) | Cats, rats and geckos now have a shadow under them: a patch of dark texels thinning to its edge, on the floor or, for a gecko, on its wall. It is drawn, not cast: small animals still cast no real shadows (most lamps cast none). `shaders/creature_shadow.gdshader` (cat) and inside `creature_crawler.gdshader` (rat, gecko) |
| Goldfish and cave barbs don't look under the water | They are drawn over the surface so they read; the water never touched them. Now the deeper a fish is, the more it takes the water's colour and the fainter it is; bands of light move over its back; its outline wavers; it has no shine of its own. A little fainter overall (goldfish 0.62 from 0.8, barbs 0.5 from 0.55) |
| A school of barbs turns as one stiff object | The shoal no longer turns as a whole. When it changes its way each fish turns about its own middle in its own time, the leaders first, over about two seconds |
| Bats should fly now and then when idle, not some always | Every bat takes its turn: it drops off its place, flies a loop or two under the roost and comes back, about three tenths of its time (panel: **Share of its time on the wing**) |
| Bats look unnaturally lit; try a dim blue or indigo | Their own lift is a dim indigo now, not a pale grey |
| "Why are there moths here?" (the tended pool) | The pen counted as a Garden Court, which has loose moths. It counts as a plain court now: goldfish only |
| "Why are there bats here?" (the dark cistern) | Its roof was high and dark enough for them. The roof is 3 m now: cave barbs only |

`tests/zoo_closeups.gd` takes a close picture of each animal
(`previews/zoo/close/`). `zoo_capture --expect` passes: every pen holds only
what it is for, plus the lived-in room's goldfish and geckos. Motion (bats'
flights, the school's turn, the water's waver) was not watched in play.

## Walk 3 of the zoo: 7 reports (2026-11-13)

| Report | What changed |
|---|---|
| Animate the pool and cistern water, to judge the fish under in-game water | The zoo now runs the water's clock (nothing did there), so both waters ripple and glint as in an area. The tended pools' water (`hauz_water`) had no clock in the real game either; an Area runs it now |
| Fish swimming backwards or sideways (cave barbs) | Walk 2's fish-by-fish turn was too slow: the shoal was already going the new way while the last fish still faced the old one. A turn now passes through the school in 0.7 s (was 2.2), starts at a smaller change of way, and the fish are far less staggered |
| Shadows too sharp or "horrible" (geckos, cats, rats); try a soft blob | The dithered patches are gone. Each animal has a soft dark blob, fading smoothly to nothing (`scripts/actors/blob_shadow.gd`, `shaders/creature_shadow.gdshader`). **Rats and geckos: working. Cats: not drawing (below)** |
| Bats look unlit; they need shading | Each wing panel is shaded by how it is turned as it beats, the body darker than the membrane, paler toward the wing tips. Still their own indigo; no lamp reaches a roost |

**Open: the cat's shadow does not draw.** The same blob that shows under
geckos and rats draws nothing in the lived-in room: not under a cat, not
as a test quad lifted 30 cm into the air, not as a child of the zoo itself.
Four attempts (a mesh, a MultiMesh, drawn before and after other
see-through things, with its own bounds) all drew nothing there. Cause not
found. Two ways on: a Decal per cat (the engine projects it; a different
path), or find what in that room stops see-through quads (its pool's
water, which reads the screen, and its rugs are the suspects).

**Cat shadows (2026-11-13):** the user sees them in play. Only the test's
pictures failed to show them, so the "open" note above is closed; why the
test's camera misses them is not known and not chased.

## Walk 4 of the zoo: 2 reports (2026-11-13)

| Report | What changed |
|---|---|
| The school is one object moved about; the fish don't swim individually, which is why they go backwards and sideways as a group | True, and walk 2's and 3's shader turn never even ran. `FishSchool` now swims every fish itself: the school's middle drifts from place to place as before, and each fish steers to its own place in the shoal, always moving the way it faces, turning at its own rate, speeding up when it has fallen behind, idling in a small circle when it is in place, and turning away from your legs when you wade. Measured over a minute in the zoo: no fish ever moved off its own heading, and none strayed more than 26 cm from its place |
| Rats don't turn smoothly; they snap | A rat now turns toward the way it is going at up to 9 radians a second (a quarter turn in under 0.2 s), not at once |

The fish's shader lost the unused turn code. Cost: 20 fish a school steered
on the CPU each frame; the zoo's tick is still under 0.1 ms.

## Walk of the real game: 3 reports (2026-11-13)

The zoo's look was approved ("looks good"); the user tuned several animals
on the panel and saved them (their values in `actors/defs/` are kept).

| Report | Cause | What changed |
|---|---|---|
| No goldfish in the Overlook's pool (the Gorge) | Three things. The pool is part of the Gorge's scenery, not of any room, and only rooms were scanned. The Overlook counts as a chasm span, which goldfish were kept out of. And in the Gorge and the camp the floors are on collision layer 9, which the water and roof scans did not look at | An area's scenery is now scanned as a room of its own, for still water only (`Fauna._queue_scenery`); goldfish are allowed in chasm spans; `HabitatScan` looks on both layers. The Gorge has 19 goldfish in its scenery pools on world seed 1 (its level there is scarce) |
| No goldfish in the Grand Bazaar's fountain | Two things. Its water is one surface of the fountain's own mesh, along with the falling jet, so it did not read as a flat pool. And the fountain's collision is one solid block over the whole basin, so every depth check found a lid | The scan keeps the level part of such a surface. A pool that sounds as all covered by its own piece is sounded again by what you see of that piece, its collision left out (`HabitatScan._seen_point`): fish keep off the rim and the column. Bazaars 1 and 4 have 4 goldfish each |
| What stops glowworms on the dark ceiling over the town (the Domicile Quarter) | There is no ceiling there. Nothing is over the quarter within 80 m: the dark is open sky-black, not a cavern roof, and glowworms hang only from natural rock they can find. The roofs the scan did find in the quarter (131) are all built | Nothing changed. To have them, the quarter needs a cavern roof (scenery), or glowworms need a rule for "open dark overhead" at some height: a design choice |

Cave barbs are kept out of scenery pools. `tests/fish_count.gd` lists the
fish place by place.

**Not fixed:** entering the Gorge, finding the scenery's water takes one
long frame (25 to 38 ms, once): the scenery's nodes are listed in a single
go. The camp, Grand Study, Gardens and zoo are unchanged.

**Decided 2026-11-13:** the dark over the Domicile Quarter stays empty (no glowworms there).
