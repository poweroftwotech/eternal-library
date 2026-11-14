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
