# Phase 20 progress: the water's edge and the birds

Brief: [phase-20-approval.md](../phase-20-approval.md), approved as recommended
2026-11-13 (Q1-Q8).

## Step 1: sound, and the nightingale (committed 0c97287, 2026-11-14)

### Sound

- **Where sounds come from.** All of them are made in the project by
  `tools/make_sounds.gd` (Q1). Nothing is recorded or downloaded. It writes 29
  WAVs to `assets/sounds/` in about a second:
  - the nightingale: 12 song phrases (piu whistles, jug notes, trills, buzz
    runs) and 2 alarm calls;
  - small wing beats;
  - the cat's mews and a looping purr;
  - bats' chitter;
  - rats' squeaks and scurry;
  - fish splashes.

  To make them again:

  `godot --headless --audio-driver Dummy --path . --script res://tools/make_sounds.gd [-- stem ...]`

  then run `--import`.
- **The sound system** (`scripts/audio/sound.gd`, autoload `Sound`):
  - two buses, Music and Animals, with a light reverb on Animals;
  - at most 12 animal voices at once (Q4); when all are busy, a nearer sound
    takes the farthest voice;
  - nothing is heard past 25 m, except the nightingale's song (30 m).
- **Volume sliders (Q3).** Esc → Controls has a Music and an Animals slider.
  They are kept in `user://settings.cfg`. The old mute key now sets the Music
  volume.
- **Phase 19 animals heard (Q2):**
  - the cat mews when startled or when it first notices you, and purrs within
    1.8 m when resting;
  - rats squeak and scurry when they bolt;
  - bats chitter and beat their wings as they take off;
  - fish splash when they scatter (at most once every 1.6 s per pool).
- **Test:** `tests/sound_test.gd` checks buses, clips, reach, the voice limit,
  voice stealing and mute, then saves the volumes in one process and reads them
  back in a fresh one. It passes.

### The nightingale

- **Model:** `scripts/actors/bird_body.gd`, a small model built in code
  (16 cm). Warm brown above, grey-buff below, a rufous tail, pale eye rings.
  The wings open and beat; the beak opens and the head lifts when it sings.
- **Behaviour:** `scripts/actors/bird_band.gd`.
  - **Perches.** It perches on the branches of garden trees and shrubs, and
    pecks among the flowers. Perches are found from the plant meshes:
    branches first, at most 90 per room. Each perch needs room above and
    round it, and must not be inside anything solid. That rules out a crown
    poking into the camp's shelves, which happened, and halved the camp's
    perches.
  - **Song.** Bouts of 6 to 16 phrases, one singer at a time. The second bird
    answers.
  - **Moving.** It hops, flies to another perch on an arc, cocks its tail and
    turns its head toward you.
  - **Startled.** Come within 3 m and it gives an alarm call, beats its wings
    and flies up and away.
- **Where it lives:**
  - kept gardens (the Garden Court R07 and the Light-Well R09): one or two
    birds;
  - the camp's tree: one bird;
  - the zoo's new "Kept garden" pen;
  - forgotten gardens: none.
- **F4** rings each perch and labels each bird's state.
- **Cost:** the perch scan is 5.5 ms in the camp (3 ms before the solid
  check); the worst room scan is 15 ms in the camp. The frame gate at step 6
  will say whether that needs splitting up.
- **Not built yet:** the caged nightingale at a bazaar stall (Q8). It moves
  to step 6 with the animal tables, since it depends on the world seed.

### Pictures (`previews/phase20_step1/`)

| Picture | What it shows |
|---|---|
| `zoo_garden_close`, `zoo_garden_sing` | The model, perched and singing |
| `zoo_garden_fly` | In flight |
| `gardens_well_close` | On a rail planter in the Light-Well, among the glowing caps |
| `grand_study_Gardens_1_room`, `camp_all_room` | Each room with F4 on |

**Caveat:** the close shots in the camp and the Grand Study garden show branches
or trunk. Tree trunks have no collision, so the capture camera can't avoid
them. Walking it shows the bird better.

### Walk 1 (2026-11-14, 4 reports: sound)

| Report | What changed |
|---|---|
| The fish splash sounds like a chirp and a slap | Remade from water noise only: a soft low "thup", a wet rush and a fizz of drops, darkened. The sine "drops" (the chirp) and the sharp 3.5 kHz burst (the slap) are gone. |
| The cat's meow doesn't sound real; it sounds like "Wow!" | Remade by its vowels, "m-ee-ah-ow": three mouth formants move from a closed hum through a bright "ee", an open "ah" and a round "ow". The pitch arches up and down, the fundamental is weak and the energy sits at 1-3 kHz. The old meow began on a low, closed formant (a "w") with a strong fundamental. The purr is unchanged. |
| The nightingale isn't muffled by walls | Every animal sound now checks for walls between you and it, every 0.1 s. Behind one it is 12 dB quieter and muffled above 900 Hz, eased in and out. The last 0.6 m at the animal's end is ignored, so its own perch or ledge doesn't count. |

**Listen 2 (2026-11-14):**
- **The meow** was better but should be higher. It is now about a third
  higher (830 to 1060 Hz) and its vowels sit 12% higher, as from a smaller
  mouth.
- **The splash** still sounded like a loud slap. It is rebuilt with no impact
  at all: water swept aside, swelling in over 40-70 ms, its band rising as
  the tail flicks. Then a soft slosh and a light trickle, darkened. It is
  also made at half the loudness of the other sounds.

**Listen 3 (2026-11-14):** the splash was "completely off base", so it is
rethought from how water makes sound. Most of it is air: each pocket the fish
pulls under rings once as it closes. That ring is a short note that rises
and dies within tens of milliseconds, its pitch set by the bubble's size
(van den Doel's bubble model). The splash is now:
- one larger bubble for the "plop";
- a scatter of smaller "bloops" after it;
- a soft wash of water under them.

The earlier tries were noise shaped by hand.

**Listen 4 (2026-11-14):** "closer, sounds much better, but too soft". The
splash is now as loud as the other sounds (it was at half), with a second big
bubble and a fuller wash in the plop. In the game it plays 4 dB louder at the
goldfish pools and 5 dB louder for the barb schools, and carries 2 m further.
You: "sounds ok".

- `tools/spectrogram.gd` draws a spectrogram PNG of a sound, to check by eye
  what can't be heard headless.
- `tests/sound_test.gd` has three new checks: behind a wall, in the open, and
  a wall moving away. All pass in both processes.

### You try

1. Walk the zoo and go to the Kept garden pen. Walk up slowly, then quickly.
2. A Garden Court: Grand Study → Gardens.
3. The camp's tree.
4. Esc → Controls: the Music and Animals sliders.

## Step 2: pigeons (built 2026-11-14, not committed)

Pigeons (C16, the rock dove) live in flocks of 6 to 12. They sit in rows on
ledges you can see from the floor, and some strut and peck on open ground.
- **Ledges** (`PigeonFlock.LedgeScan`, run a few at a time inside the
  animals' 1 ms budget) are flat tops with a drop of at least 2.2 m past the
  edge, room to stand, nothing in front, and seen from where you stand.
- **Wheeling:** now and then the flock takes off and circles, then settles
  again: once every 60 to 150 s. How it circles depends on the room:
  - in a quarter it circles round the pigeon tower just over its rim, or over
    the top of the tower when the court is too tight (the zoo pen);
  - in a bazaar, inside the dome's drum;
  - with no room to circle, they flutter from ledge to ledge.
- **You and the flock:** walk close and they step out of your way. Run within
  7 m, or come within 0.9 m, and they burst up together with a clap of
  wings.
- **Sound:** they coo (three notes, a flutter on the middle one).
  `tools/make_sounds.gd` makes the coos and two wing sounds: a loud clap for
  an alarm and a softer one for a wheel.
- **The model** (`PigeonBody`) is made in code from the nightingale's parts.
  It has three poses (wings folded, up, down), so a whole flock draws in three
  calls. It is blue-grey with dark wing bars and tail band, a green and purple
  neck, orange eyes and pink feet.
- **Where:** bazaars (R04), squares (R05) and quarters (R06), one flock a
  room. In the Gorge (Q5), up to 3 flocks on the ledges you can see from the
  walks, where they crowd most. The Gorge's animal level no longer shrinks a
  flock below 6.
- **The zoo:** a new "Pigeon tower" pen, with the quarter's tower in a tall
  court, a cornice and daylight. F4 shows each flock's perches, its circle,
  and what the birds are doing.

Probe (`tests/pigeon_probe.gd`):
- Mahaleh: 12 birds in every bazaar, square and quarter. Two of the nine
  rooms have no room to circle (bazaar_3, quarter_4).
- The Gorge: 3 flocks of 6 from 116 ledges.
- The zoo: 6 birds.
- Finding ledges costs at most 3.5 ms in one frame (the same as before
  pigeons).

The headless gate passes. `tests/fauna_test.gd` passes across two processes
(it now counts any band, not only cats).

**Caveat:** in `previews/phase20_step2/` the camera often ends up inside
things that have no collision (the tower, the bazaar dome, Gorge walls), so
most close-ups are useless. Walking it is the real check.

### You try

1. The zoo → the "Pigeon tower" pen. Walk up to the birds on the ground,
   then run at them. Wait a minute or two to see them circle.
2. A Mahaleh quarter with the pigeon tower (quarter_1 in v10).
3. A bazaar crossing: birds round the dome.
4. The Gorge's walks: flocks on nearby roofs and terraces.

**Walk 1 (2026-11-14):** "mostly looks good". One report: the circling
birds kept bobbing up and down. The flight height was tied to the wingbeat
clock, so each bird bobbed 0.6 m at about 8 m/s. Now:
- each bird rises and falls 0.5 m once round the circle, at 1.2 m/s at most;
- it joins the circle level with where it came in (within 3 cm);
- it banks into the turn, the inside wing down, about 30 to 35°.

Step 2 committed (b3fe4c6, 2026-11-14).

## Step 3: the eel and the newt (built 2026-11-14, not committed)

**The spiny eel** (C03, 60 cm, `EelHoles`, `EelBody`,
`shaders/creature_eel.gdshader`):
- It lives in holes in stone under still water at least 30 cm deep, in water
  of at least 10 m2.
- Holes are found from where the fish can swim: level rays near the floor
  meet a wall. A hole is kept only where the stone is at least 0.62 m thick
  (the eel's body goes into it) and the water in front is open. Up to 10
  holes, 0.9 m apart; each is drawn as a ragged dark disc.
- At rest it lies in the hole with only its head out, swaying a little.
- Every 25 to 70 s it slides out along the bottom to another hole, turns
  round in front of it, and backs in tail first until only its head shows.
- When you come within 1.8 m (3 m if you're moving) it draws in, and looks
  out again 4 to 9 s after you leave.
- The model is a mottled brown tube with a pale belly, a dark line through
  the eye, a long snout and a fin along its back that runs into the tail. A
  wave runs down its whole body as it swims.
- 1 to 3 eels per body of water, one per 3 holes.

**The Luristan newt** (C04, 13 cm, `NewtBank`, `GroundBody.newt_mesh`):
- It lives only by running water, flowing at 0.08 m/s or faster: the Fungus
  Terraces' channels and well, and the camp stream. The cistern and the lake
  count as still.
- Its spots are the stone just past the water's edge, about level with the
  surface, and the floor of shallows 10 to 25 cm deep.
- It sits 5 to 18 s, then walks slowly to a spot within 1.3 m.
- When you come within 4 m it freezes. Within 2 m it slips into the water,
  down to the bottom, and is gone. It comes back somewhere along the bank 25
  to 50 s later, away from you.
- It is black with white spots on its flanks, a narrow orange stripe down
  its back, orange legs, and a tall flattened tail. It wriggles as it walks,
  like the gecko.
- 2 to 5 newts per stream.

**A fix underneath:** the water scan skipped level channels (water material
`plane = 1`, as in the Fungus Terraces' channels). Now only falls
(`plane = 2`) are left out. So fish can now live in those channels too, if
they are deep enough.

**The zoo** has two new pens at the end of the corridor (now 20 cells long):
- "Running stream": a cave room with a channel, a shelf of shallows, stone
  banks and a dim fungus glow. 5 newts, 40 spots, 19 of them in the
  shallows.
- "Flooded piers": water 0.8 m deep with a causeway across it to walk on and
  two stone piers. 3 eels, 10 holes.

The old "Dark cistern" pen gets 3 eels too.

**Probe** (`tests/shore_probe.gd`):
- the Gardens' two cisterns: eels in all four bodies of water that are big
  enough (1 or 2 eels each, 2 to 8 holes);
- the camp stream: 3 newts, all on the bank.

The Fungus Terraces aren't in the current world's live areas, so they
haven't been probed (they grow in 17 of 40 worlds).

**Checks:** the headless gate passes, and `tests/fauna_test.gd` passes
across two processes (29 checks, the new kinds included).

**Caveat:** eels are dark in dark water. Through 1.4 m of the cistern water
they were nearly invisible, so the zoo's pier pen is 0.8 m deep. The holes
themselves hardly show. The F4 overlay shows the notes but has no labels yet
for what each eel or newt is doing.

**Look 1 (2026-11-14):** you asked for bioluminescence on the eels. Each eel
now has a row of glowing teal dots down each side and a few along its back,
with a slow pulse running down the body that brightens and quickens when it
swims. It lights nothing round it (emission only, no light, no cost). The
colour is the def's `glow_colour`, so it can follow the area's fungus later.

**Look 2 (2026-11-14):** you wanted the newt "brighter, colourful, sort of
poison dart frogs". It is now:
- glossy blue-black (a wet clearcoat sheen);
- vivid orange along its back, down its sides, on its belly and legs;
- three cream-yellow bands (head, shoulder, middle);
- its orange and cream parts glow a little of themselves (`colour_glow`
  0.35), so it stands out in a dim cave without lighting anything.

`creature_crawler.gdshader` gained `gloss` and `colour_glow` for this; both
are 0 for the rat and the gecko, so they are unchanged.

**Walk 1 (2026-11-14):** one report: no newts at the Gardens' Fungus
Terrace. Its channels were turned down with "0 wet spots" for three reasons:
- The water sounding keeps clear of walls, so a narrow channel has no
  sounded places to start from. Newts now start from random points on the
  water's surface itself.
- The terrace rows' collision is a flat slab 0.1 to 0.9 m over their
  channels, so rays never reach the bed you see. Newts now ask the visible
  meshes of the piece the ray hit (`NewtBank._seen_down`), leaving out the
  water, the falls and the fungus.
- A bank may now stand up to 0.5 m over the water (a kerb).

At most 2 newt groups go in one room (the terraces have about ten channel
pieces). The probe now finds 2 groups of 8 in each of the Gardens' two
terraces, about 40 spots each, half in the shallows. Captured: they sit on
the channel edges and beside the cascade.

You: "looks good". Step 3's look is approved.

### You try

1. The zoo → "Running stream". Walk up to a newt slowly, stop at about 3 m,
   then go closer.
2. The zoo → "Flooded piers". Stand on the causeway and wait for an eel to
   change holes, then step toward one in its hole.
3. The camp stream (newts on the bank).
4. A Gardens cistern: wade in.
