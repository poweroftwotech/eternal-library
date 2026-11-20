# Progress: residents and their day, phase 21

[Back to the front page](../../../ENVIRONMENT_PLAN.md) ·
[The brief](../phase-21-approval.md)

## Step 1: the body

### First look: standing still (2026-11-18, awaiting your look)

A man and a woman, each with a skeleton, standing at ease. Pictures in
`previews/phase21_step1/`: `row.png` (a door statue, three men, three women,
the bazaar keeper), `row_eye.png` (from where you stand), and for one man and
one woman `*_front`, `*_side`, `*_back`, `*_quarter`, `*_face`, `*_face_q`,
`*_face_s`. Taken at the camp with one plain lamp added.

**What they are.**

- **The man:** a qaba to mid-shin with a lapped front, a trimmed edge and a
  sash; trousers and soft shoes under it; a round felt cap; a beard that can
  be on or off. 1.72 m.
- **The woman:** a long dress with a patterned band over the hem and a sash;
  a headscarf that falls over the shoulders, a line of hair under its edge.
  1.63 m.
- **Faces** are drawn in pixels (eyes two texels high, brows, a mouth) on a
  smooth-shaded head, with a small nose that stands out. Cloth is faceted
  like the statues, with the same 3 cm woven squares.
- **One model, many people:** six sets of clothes (madder red, indigo, undyed
  wool, walnut, turquoise, saffron) and five faces (skin and hair), set per
  person. About 470 points and 18 bones each.

**How it is made.** `tools/resident_body.py` (Blender, headless) builds
`art_src/creatures/man.blend` and `woman.blend` and exports
`actors/models/man.glb`, `woman.glb` and their masks (`*_mask.png`: what
each texel is, not its colour). `shaders/resident.gdshader` colours a person
from the mask; `scripts/actors/resident_body.gd` (`ResidentBody`) is the
body in the game. `tests/resident_capture.gd` takes the pictures.

**What I see wrong in the pictures (to fix after your look).**

- The arms hang stiff and straight, and the hands are plain paddles.
- The sleeves' tops still puff a little above the shoulder.
- The women's faces are plain: the scarf sits like a tight cap, and the face
  is the man's shape with a smaller nose.
- Heads may be a little narrow for the bodies.
- Next to them the old statues look bulkier and darker; the two looks will
  only sit together until step 5 replaces the statues.

**Not done yet in step 1:** walking, sitting, lying asleep; the cost of
twenty in view. Both wait for the still body to be right.

**Checks.** The models import with no errors; the game starts and runs 240
frames headless with no errors. Nothing in the game uses the bodies yet.

### Your look (2026-11-18): the dress should come from ancient Iran

You asked for clothing drawn from Median, Achaemenid, Parthian and Sasanian
dress, with variety, head coverings by class and trade and not for
everyone, and shaped by life underground (damp and cold instead of sun and
sand; clothes that give light).

**Sketches for agreement:** [the costume atlas](../../../design/costume-atlas.html).
What each age gives, ten rules that living underground adds, six men and
six women with where each comes from and who wears it, the same twelve with
the lamps out, how it maps onto the models, and six questions (C1-C6).

The models keep their first-look clothes until the sketches are agreed.
Then: the agreed dress, and the fixes listed above (arms, hands, shoulders,
the women's faces, head width).

**Agreed 2026-11-18: C1-C6 as recommended.** All twelve sketches are the
first set; glow thread a colour per area (gold for the Mahaleh, blue for the
Lower Stacks, violet for the terraces); colour runs backwards; only a lamp
tender's pole lamp casts real light; page-quilted clothes for copyists; the
Mahaleh's trades go on the models first.

### Second look: the agreed dress on the models (2026-11-18, awaiting your look)

Nine of the atlas's twelve outfits are on the bodies: the ones the Mahaleh's
trades need. Pictures in `previews/phase21_step1/`: `row.png`, `row_back.png`,
`row_eye.png` (from where you stand), **`row_dark.png` (the lamp out: what
the glow thread gives)**, and for each outfit `<name>_front`, `_quarter`,
`_back`, `_face`. Left to right in the row:

| | Outfit | Pieces |
|---|---|---|
| M1 | The lane coat | Knee coat, narrow trousers, felt cap, belt lamp and purse; fungus violet |
| M2 | The scholar's robe | Pleated robe with wide sleeves and brass discs, sash, fillet with ribbons, curls at the neck, squared beard; indigo |
| M3 | The merchant's caftan | Crossed caftan with pearl roundels and a rounded hem, full trousers, tall cap, belt things; saffron and madder |
| M4 | The hunter's leathers | Knee coat, hides over the shoulders, bushy hair in a band; moss; no glow |
| M5 | The lamp tender | White coat, sleeved cloak on the shoulders, cap with the lantern globe, mouth cloth |
| W1 | The house dress | Pleated dress with wide sleeves, long braid with glowing ribbon ends, crenellated band; fungus violet |
| W2 | The keeper's veil | Dark dress, band, pale veil down the back; no glow |
| W3 | The bazaar gown | Close gown with pearl roundels and a high belt, shawl, topknot, fillet; madder and saffron |
| W4 | The copyist's jacket | Wrapped quilted jacket, full trousers, pinned braids, belt things; her glow is the Lower Stacks' blue |

**How it works.** Each body is one skeleton with pieces that switch on and
off: 17 for the man, 14 for the woman (garments, legs, cloaks, hair, things
on the head, things at the belt). An outfit is a list of pieces and six
colours (`ResidentBody.OUTFITS`). Glow thread, brass and lanterns are
painted into the same mask as the cloth; glow and lanterns shine by
themselves and light nothing.

**Fixed from the first look.** Shoulders slope and the sleeves no longer
point (a ring across a leaning path had tipped its outer edge up). Elbows
are soft and the weight is on one leg. Hands are smaller and have a thumb.
The woman has her own head shape, hair, lashes and lips. Heads are wider.

**What I see wrong in these pictures.**

- The lantern globe and the brass band flare when a lamp is near.
- The bazaar gown's roundels read as dots more than rings in the dark.
- The wide sleeves are bells at the wrist, not the long hanging wings of
  the sketch; they will need care when the arms move.
- The single-outfit pictures at the camp sometimes have the cauldron or a
  ladle in front; the row pictures are the ones to judge by.
- Not built yet: the ferryman, the terrace worker and the traveller (their
  places get people in step 6); the lamp pole, candle and basket (with the
  animations); pattens, tall boots and the hunter's leggings.

**Checks.** Both models import with no errors; the game starts and runs 240
frames headless with no errors. Nothing in the game uses the bodies yet.

### Third look: they move (2026-11-18, awaiting your walk)

You approved the dress. The bodies now have five animations, a pen in the
zoo, and a first cost measurement.

**Try it:** the Strata Board's **Walk the zoo**, or run the game with
`--room=zoo`. The **People** pen is the last one on the left, at the far end
of the corridor (which is four cells longer now). In it:

- all nine outfits standing along the far wall, breathing;
- a man and a woman walking the length of the pen and back, at two speeds,
  stopping a moment at each end;
- two people sitting on the bench, two cross-legged on cushions, one asleep
  on the bedroll with his eyes shut.

They are not solid yet and know nothing of you: this pen is for looking.

**The animations:** idle, walk, sit on a bench, sit cross-legged on the
floor, asleep on the back. Stills in `previews/phase21_step1/poses/`
(`poses.png`, `poses_above.png`, and one per pose) and of the pen in
`previews/phase21_step1/zoo/`.

**What I see wrong.**

- Sitting cross-legged in a floor-length robe, the skirt folds in sharp
  planes round the knees (the scholar). It reads as cloth from a few metres
  and as broken close up.
- The walk is plain: no weight shift you can feel, and the wide sleeves
  swing as stiff bells.
- Seated hands hover just off the knees.
- Walkers turn on the spot at each end.
- Nobody blinks yet.

**What changed underneath.** A floor-length garment no longer draws legs
under it (never seen, and they poked through when sitting), nor the dark
lining inside its hem. `ResidentBody.play(what, blend, at, rate)`,
`walk_speed()` (the speed at which the feet don't slide). `ResidentPace`
walks someone between two points for the pen. Tests:
`tests/resident_pose_capture.gd`, `tests/resident_zoo_capture.gd` (fails
unless the pen has its 16 people), `tests/resident_cost.gd`.

**The cost of twenty in view** (this machine, 1080p, vsync off, twenty
people walking on the spot in front of you; `tests/resident_cost.gd`):

| Where | Shadows | Draw calls each | CPU each | Whole frame, none → twenty |
|---|---|---|---|---|
| The camp | on | 34 | 0.023 ms | 3.5 → 4.2 ms |
| The camp | off | 5 | 0.014 ms | 3.5 → 3.6 ms |
| The Mahaleh (its start) | on | 5 | 0.008 ms | no change I can measure |
| The camp, forty people | on | 26 | 0.018 ms | 3.5 → 3.7 ms |

- A person is five or six draws (one per piece worn) and about 900
  triangles. Animating them is too small to measure here.
- **Shadows are the cost.** Where many shadowed lights reach them (the
  camp), a person is drawn again for each: 34 draws, so twenty people add
  680 draw calls against a limit of 1,500 a view.
- So the limit on bodies will be set by draw calls, not by skeletons. To
  decide in step 5 with the real Mahaleh: people cast shadows only near you,
  and how many bodies show at once. This machine is far above the base
  machine (RTX 3060), which I have not measured.

**Checks.** The game and the zoo start and run 240 frames headless with no
errors; the zoo capture finds all 16 people.

### The listed faults fixed (2026-11-18, awaiting your walk)

You said: fix what you listed. Done, and in the People pen now:

| Fault | What changed |
|---|---|
| Cross-legged in a long robe folded in sharp planes | **A second floor pose: kneeling, sitting back on the heels** (do-zanu, the formal way). Anyone in a floor-length garment kneels; the skirt tucks under cleanly. People in trousers or a knee coat still sit cross-legged. Each outfit knows which (`ResidentBody.floor_sit()`). In the pen the scholar kneels and the copyist sits cross-legged |
| The walk was plain | The weight now goes over the standing leg: the body shifts a little to that side, the swinging leg's hip drops, the shoulders tip back to stay level, the chest turns more against the hips |
| Seated hands hovered | On the bench and kneeling the hands lie on the thighs; cross-legged they rest on the knees |
| Walkers turned on the spot | They walk the way they face and turn as they go, so they leave each end in a small arc, a little slower through the turn |
| Nobody blinked | Everyone blinks every two to six seconds, each on their own time; sleepers keep their eyes shut |

**Still as it was.** The wide sleeves swing as stiff bells: softening them
needs sleeve bones, which I would rather add once you have seen them move.

**Checks.** The game and the zoo start and run 240 frames headless with no
errors; the pen has its 16 people. The zoo's older animal check
(`tests/zoo_capture.gd --expect`) stops with a script error at its line 53,
and does the same on the committed code: it was written before phase 20's
birds and has not been run since. Not fixed here.

**Step 1 committed 2026-11-18 (59cdc95)** after your "commit and go on".

## Step 2: the bells and one household

### First look (2026-11-18, walked: the bell rings and people keep their hours; committed)

**Try it:** the Strata Board's new **Walk the test lane**, or run the game
with `-- --lane`. You arrive in a one-quarter copy of the Mahaleh (four
homes and a hauz) on a scratch save. The family's home is the deep one on
your right as the lane opens; its door opens with E like any home's.

- **F6** opens the **People** panel (F4 and F5 are the animals'): the time
  as a bell and minutes, Pause, 1x, 10x, 30x, 60x, "Go to bell" 1 to 6, a
  tick for labels over people, and a line for each person saying what they
  are doing and what comes next.
- A good first try: go into the home, press F6, tick the labels, and press
  10x. Then go to bell 6 and watch them go to bed and the lamps go out.

**What you should see.** Two people, a cook and a householder, with names
from the seed (Tahmineh and Kaveh on seed 1):

| Bell | The cook | The householder |
|---|---|---|
| First | Gets up, kneels at the hearth and cooks; they eat at the low table | Gets up a little later, stands at the door, comes in to eat |
| Second | Free time: the door, a seat, or about the room | The same |
| Third | Cooks, then they eat | Free, then eats |
| Fourth | Free time | Free time |
| Fifth | Cooks, they eat, she stands at the door | Eats, free time |
| Sixth | To bed | To bed a little after |

- The hearth burns bright while someone cooks or eats and is banked to a
  low glow otherwise. The home's lamps are lit while anyone is up and go
  out, flames and all, when both are asleep.
- The door opens for whoever walks through it and shuts behind them.
- A bell rings its own number of strokes at each bell, and its name shows
  for a moment. There is a **People and bells** volume in Esc, Controls.
- Each person keeps their own time, a few minutes early or late.

Pictures at five times of day in `previews/phase21_step2/` (inside, the
back room, and the door from the lane).

**What was built.**

| Part | What it is |
|---|---|
| The day | `DayClock`, the autoload "Day": 48 minutes, six bells eight minutes apart, kept in the save. A new world starts just after the first bell |
| The bell | A made sound (`tools/make_sounds.gd`), one stroke; the clock rings as many as the bell's number |
| Spots | `SpotTable`: one table from a prop's file to the spots it gives. A bedroll is a bed, a pouf or cushion a seat (an eating place if a low table is within reach), the home's door and floor are spots, and each old posed figure marks a spot where it stood (the stirring figure is the cook's place at the hearth) |
| A resident | `Resident`: a body, a timetable of bells, and a small mind that finds a spot for what the hour asks, walks there and takes its pose |
| The household | `Residents`, beside the animals' director in an area: gives a family home its two people, hides the old figure, lights and banks the hearth, lights the lamps, opens the door |
| The lane | `gen/recipes/drafts/mahaleh/lane_test.tres` (made by `tools/make_lane_draft.gd`): the Mahaleh as one quarter |
| The panel | `ResidentsPanel`, F6 |

**Checks.**

- **A whole day, run fast with no display** (`tests/resident_day_test.gd`,
  the day report): both slept, both ate three times, the cook cooked three
  times, the longest walk to any spot was 8 seconds of the day, the hearth
  was bright 46% of the day, and the lamps were never lit with both asleep.
  Passes.
- **The clock across two processes** (`tests/day_clock_test.gd`): bells ring
  on time, jumping lands on a bell, pausing holds, days passing leave the
  years alone (so nothing ages or rebuilds), and a freshly started game
  resumes the day where it was saved. 15 checks pass.
- The camp, the lane and the live Mahaleh start and run headless with no
  errors. The live Mahaleh has no people yet (step 5).

**What I see wrong, or have not done.**

- **I cannot hear the bell.** It is made from the overtones of a cast bell,
  but whether it sounds like one, and how loud it sits, is yours to judge.
- **Only the family's home has people.** The scholar's and the hunter's
  keep their figures until step 4, and I have not yet given the scholar a
  bed or the homes their missing things (Q9): that belongs with their
  households.
- **Walks are straight lines** along the way in from the lane to the back
  room, then to the spot: no way-finding, so a path may cut a corner of a
  rug or a table. They are not solid; you can walk through them. Step 3.
- **Getting into bed is a pop:** they walk to the bed and are then lying
  on it. The same for sitting down. No in-between movement yet.
- **Cooking is kneeling at the hearth.** No stirring, eating or reading
  movements yet (step 4).
- The bell is heard the same everywhere, not from a tower.
- Above 20x people skip their walks and are simply at the next place, so
  10x is the fastest speed that still shows them walking.
- Timetables are in code (`Residents.ROUTINES`); the panel edits them in
  step 4.
- With labels on, a label shows through walls: it is a tool, not a look.

**Step 2 committed 2026-11-18 (61b2a79)** after your walk ("the bell rings
and people do take action based on the schedule").

## Step 3: out of the door

### First look (2026-11-18, awaiting your walk)

**Try it:** the Strata Board's **Walk the test lane**, or run the game with
`-- --lane`, as before. The square with the hauz is straight ahead of where
you arrive; the stall is on its far left wall.

- **F6** is the People panel as before. It has a new tick, **Spots and
  ways**, which is also on **F4** (F4 shows the animals' overlay too).
- A good first try: press F6, tick both ticks, press 10x, and stand in the
  square. Then follow one person: the cook (Tahmineh on seed 1) has the
  fullest day.
- Stand in someone's way in the open, and then in a doorway.

**What you should see.** Four people in three homes:

| Who | Their day |
|---|---|
| The cook (family home) | Fetches water from the hauz before each of the three meals, cooks, eats; goes to the stall in the morning; free time at the door, a seat or the hauz |
| The householder (family home) | Keeps the stall between meals; sits at the hauz before bed |
| The scholar | Fetches water, reads at his table most of the day, goes to the stall, stands at his door, sits at the hauz in the evening, sleeps on new bedding by the wall |
| The hunter | Mends at his table, goes to the stall, sits at the hauz twice, fetches water, sleeps on new bedding |

- **They find their way:** round the furniture, through their own doorway
  (the door opens for them and shuts behind), down the lane, round the hauz.
- **The hauz:** someone fetching water kneels at the middle of a straight
  side. People with time to spare sit on the rim at its slanted sides,
  looking out; in the evening three or four sit there together.
- **The stall** (new, on the lane only): its keeper stands at the end of the
  counter; a buyer stands in front of it.
- **You:** they are solid. In the open they step round you. In a doorway
  they stop and wait until you move; the label says "waiting for you" and
  the overlay rings them in red.
- **Each other:** they step round each other. Two who can't pass wait a
  moment, then one goes on.
- **The overlay:** every spot as a coloured ring with its kind and who has
  it now, a yellow line along each walker's way, and in grey the edge of
  where people can walk.

Pictures in `previews/phase21_step3/` (each plain and with the overlay).

**What was built.**

| Part | What it is |
|---|---|
| The walking surface | `WalkMap` (`scripts/actors/walk_map.gd`): made for a room when it is built, from the room's own floors, walls and furniture, with doors left out so a doorway is a way through. For the lane: 3.2 ms on the main thread to read the room, 44 ms on another thread to make it |
| Finding the way | A resident asks the surface for the way to the floor beside its spot, walks it, and takes the last step onto the seat or bed. The floor beside a spot is chosen by walking distance, so a bed in a wall niche is never approached from outside the wall |
| Stepping round | Each step looks for you or another person ahead; a side step is taken if the floor is there, otherwise they wait |
| Solid bodies | Each person has a body on its own collision layer, which yours collides with. Lying down, they have none |
| Shared spots | `SpotTable.scan_commons`: the hauz gives four places for water and four seats on its rim; a stall gives a keeper's place and two buyers' places |
| Beds for small homes | A one-room scholar's or hunter's home now has laid-out bedding by the wall (the quarter's grammar, so the live Mahaleh's small homes have it too) |
| The overlay | `ResidentsOverlay`, F4 or the panel's tick |
| Households | The scholar and the hunter each live alone. The family's two as before |

**Checks.**

- **A whole day, run fast with no display** (`tests/resident_day_test.gd`):
  all four slept; the family ate three times; the cook fetched water three
  times and went to the stall; the householder kept the stall twice; the
  scholar and hunter worked, shopped and sat at the hauz. Nobody took a step
  off the walking surface, everyone ended on their spot, and the longest
  walk was 33 seconds. Passes.
- **You in the way** (`tests/resident_meet_test.gd`, 13 checks): all 49
  spots can be walked to; with you standing on her way in the square the
  cook reaches the hauz and never comes nearer than 0.69 m; with you in his
  doorway the scholar waits 40 seconds and goes when you move; your body is
  stopped by someone standing. Passes.
- **Your own walking** (`tests/area_route_test.gd` on the lane, three
  seeds): you can still walk every lane and into every home with the new
  bedding there. Passes.
- The camp, the lane and the live Mahaleh start and run headless with no
  errors.

**What I see wrong, or have not done.**

- **The stall stands in front of a house front:** there is a door and
  windows on the wall behind it. I placed it by hand on this lane; a quarter
  has no stall of its own. In the Mahaleh the stalls are the bazaar's.
- **The keeper stands at the end of his counter,** not behind it: the kit's
  stall has no way in behind the counter.
- **Nothing is carried.** Fetching water is kneeling at the rim; buying is
  standing at the counter. Jars and baskets come with the work poses in
  step 4.
- **Sitting down and lying down still pop.**
- **The hooded figures standing at doors in the lane are still there,**
  beside the living people. They go in step 5.
- **The scholar and hunter don't eat** (their homes have no seat at a
  table), and a two-room scholar's home still has no bed. Both wait for the
  missing furniture in step 4.
- **Two people who can't pass:** after 2.5 seconds one walks through the
  other. It happened 19 times in the test day, mostly at the family's door.
- **One room only.** The lane is one room, so the surface isn't yet joined
  from room to room. That is needed for the Mahaleh in step 5.
- **Floors are taken as level** within a quarter. A lane with steps would
  need more.
- **At 30x and 60x they skip walks,** as before.
- I have not measured the cost of the surface on a full Mahaleh quarter, or
  the frame cost of four solid, way-finding people (step 5).

**Step 3 committed 2026-11-18 (8aafa4a)** at your "commit and go on".

## Step 4: trades and free time

### First look (2026-11-18, awaiting your walk)

**Try it:** the test lane as before (Strata Board, **Walk the test lane**,
or `-- --lane`). **F6** now has three pages under the clock:

| Page | What it shows |
|---|---|
| **Now** | Everyone and what they are doing |
| **A day** | One person's whole day, a line a block, with the present one marked and what they are doing about it |
| **Timetables** | A trade's timetable as rows: a bell, minutes after it, and what to do. Change a row and everyone of that trade follows at once. **Add a row**, **x** to take one out, **As first written** to undo, **Save** to keep (it writes `gen/people/routines.tres`) |

A good try: open Timetables, choose the lamp tender, change his second
"Tend the lamps" row to the bell you are in, and watch him set out.

**What you should see.** Five people now (the family's home has three):

| Trade | The day | The work looks like |
|---|---|---|
| Cook | Water before each meal, cooks, eats, goes to the stall | Kneels and stirs at the hearth; leans over the rim to fill a jar; carries the jar home; carries a basket back from the stall |
| Stall keeper (was "the householder") | Keeps the stall between meals, the hauz before bed | Hands at the counter, lifting and lowering like scales |
| Lamp tender (new) | A round of the lane's lamps after the first bell and before bed | Stands under each lamp and reaches up to it; the globe on his pole is a real light |
| Scholar | Reads at his table, three meals, water, the stall, the hauz | Book held up, head bent, a page turned now and then |
| Hunter | **Away by day:** leaves the lane after breakfast and comes back at the fourth bell; then the stall, mending, water, the hauz | Draws a thread out and back |
| Ossuary keeper | A timetable only: nobody on the lane has this trade (no ossuary here) | |

- **Everyone eats now:** the hand goes down to the dish and up to the
  mouth. The scholar and the hunter eat where they work.
- **A home has as many people as it has beds.** The deep family home has
  three; a one-room family home has two (the cook and the stall keeper).
- **The old hooded figures in the lane are gone** on the test lane.
- **Beds:** every lived-in home has a place to sleep for everyone in it,
  but the piece I used for the added ones is wrong (see "Stopped" below).

Pictures in `previews/phase21_step4/`: each trade at work, the panel's
three pages, the work poses in a row (`poses/`), and homes at night on
seeds 1 and 2 (`homes/`).

**What was built.**

| Part | What it is |
|---|---|
| Work movements | Twelve new animations on both bodies (`tools/resident_body.py`): reading, mending and eating over each way of sitting; stirring; filling a jar; weighing; reaching to a lamp; walking with something held |
| Things carried | A jar and a basket in the right hand (`ResidentBody.hold_thing`), hanging straight whatever the arm does. Plain shapes, not kit pieces |
| Timetables in a file | `RoutineBook` (`scripts/actors/routine_book.gd`), saved to `gen/people/routines.tres`; `tools/make_routines.gd` writes it afresh |
| The lamp round | The lane's lamps (door lamps, the lamps over the ways out) each give a spot; the tender goes from one to the next |
| Away | The way out of the lane is a spot; whoever goes "away" walks there and is gone until the timetable brings them back |
| The panel | Three pages, the editor |
| Furniture (Q8, Q9) | The quarter's own lists: bedding in the family's front room and one-room home, in the two-room scholar's back room; a third seat at the family's table |

**Checks.**

- **A whole day, run fast** (`tests/resident_day_test.gd`): five people;
  every trade did everything its day asks (the list is in the test), every
  work movement was seen, a jar and a basket were carried, the hunter was
  out of sight while away, nobody stepped off the walking surface. Passes.
- **You in the way** (`tests/resident_meet_test.gd`): 13 checks pass.
- **Your own walking** (`tests/area_route_test.gd` on the lane, five
  seeds): **FAILS, 4 of 79 checks.** On seeds 1, 3, 4 and 5 you cannot walk
  from the family's front room into its back room. See "Stopped" below.
- The camp, the lane, the live Mahaleh and the zoo start headless with no
  errors.

**Stopped: the beds are the wrong piece (your choice needed).**

The route test failed three times running with the same error, so by the
project's rule I stopped fixing and looked for the cause:

```
FAIL mahaleh seed 1: entrance way 3 of 6: out and back (2 of 4, 0 of 5)
FAIL mahaleh seed 3: entrance way 4 of 6: out and back (2 of 4, 0 of 5)
FAIL mahaleh seed 4: entrance way 6 of 7: out and back (2 of 4, 0 of 5)
FAIL mahaleh seed 5: entrance way 5 of 7: out and back (2 of 4, 0 of 5)
```

Asking the physics what your body touches on that leg gives
`prop_qt_item_1_8 (court_contents_bedroll__block)`. The piece I used for
"laid-out bedding" (`court_contents_bedroll`) is not one bed. It is the
caravanserai's whole row of bedding: 3.5 m wide, 1.1 m deep, 0.6 m high,
and solid. I had taken it for a single mattress and never measured it.

- In the family's home it lies across the way to the back room.
- **This is also in step 3, which is committed:** the one-room scholar's
  and hunter's homes have the same 3.5 m row across the back of the room,
  partly through a wall. The route test passed there only because your way
  in stops short of it. The live Mahaleh's small homes have it too.

Two ways to put it right:

| | What | Cost |
|---|---|---|
| **A** (my pick) | A new small kit piece: one laid-out bed (mattress, blanket, bolster, about 0.8 by 1.9 m, not solid), made in Blender through the kit pipeline, used for every added bed | One new piece; the look is right |
| **B** | No new art: use the rolled bedroll the family's bed already has (1.3 by 0.5 m, not solid) as the bed, and hide it while its owner sleeps there | Quick; a sleeper lies on the bare floor |

**What I see wrong, or have not done.**

- **The jar and basket are plain shapes** I made in code, not kit pieces,
  and I could not see the jar clearly in my own pictures (the square is
  dark). Judge them yourself.
- **Nobody sets a jar down or picks one up:** it appears in the hand when
  an errand begins and goes when they are home.
- **The lamp tender only reaches up.** No lamp changes when he tends it,
  and there are only three lamps on this lane he can get under.
- **The one-room family home is tight:** its two beds lie either side of
  the hearth. I have only seen it in one wide picture.
- **The two-room scholar's bed** I have seen only at the edge of a picture.
- **No takht.** Evenings are at the hauz: the lane has no takht.
- **The stall keeper still stands at the end of his counter**, and the
  stall still stands in front of a house front.
- **Sitting down and lying down still pop.**
- **Free time is still a draw** among the door, a seat, the hauz and
  standing about; it has no page in the editor.
- **The panel is on F6,** not F5 as the brief said: F5 is the animals'.
- **Timetables are per trade,** not per person, as agreed; a person's own
  lateness (a few minutes) is shown on the "A day" page but not edited.

### The beds put right (2026-11-19, your choice: B, the rolled bedroll)

- **Every added bed is now the rolled bedroll** (1.3 m long, not solid),
  lying along a side wall. The 3.5 m row of bedding is out of every home,
  the one-room homes of step 3 and the live Mahaleh's included.
- **The roll is gone while its owner sleeps there** and back when they get
  up, as if unrolled. The sleeper lies on the bare floor: there is no
  mattress or blanket to see. The two rolls on the family's bed do the same.
- **Where they lie:** beside the door-side wall of the front room; in a
  one-room family home the cook and the stall keeper lie side by side there.
  The two-room scholar and hunter sleep along a wall of the back room.

**Checks after the change.**

- **Your own walking** (lane, five seeds): 79 checks, 0 failures.
- **A whole day run fast:** passes. **You in the way:** 13 checks pass.
- The live Mahaleh starts headless with no errors. I did not run the route
  test on the live Mahaleh (a roll is not solid, so it cannot stop you).

**What I see in the new pictures** (`previews/phase21_step4/homes/`, taken
at night, so every roll is hidden):

- In the one-room family home the two sleepers touch at the shoulder, and
  the nearer one's feet are close to the hearth.
- The two-room scholar asleep in his back room is not in any picture.
- I have no daytime picture of the rolls lying by the wall.

### Smaller rolls, and a bed laid out under the sleeper (2026-11-19, your report)

You said the bedrolls were huge for the rooms, and that a sleeper should
have the unrolled bed under them.

- **A small roll made for the homes** (`qt_bed_roll`): 0.7 m long and
  0.26 across, where the camp's is 1.3 m and 0.46. Every home's roll is this
  one now, the two on the family's bed too. The camp keeps its own.
- **A laid-out bed** (`qt_bed_laid`): a thin mattress 1.85 by 0.72 m, a
  bolster under the head, a blanket folded at the foot. When someone lies
  down the roll goes and this is under them; when they get up it goes and
  the roll is back.
- Both are kit pieces in `art_src/kit/kit_quarter.blend`, seeded by
  `tools/kit_add_beds.py`. Neither is solid.

**Checks.** Your own walking on the lane, five seeds: 79 checks, 0
failures. A whole day run fast: passes. You in the way: 13 checks pass.
The kit test: 11819 checks, 0 failures. The camp and the live Mahaleh start
headless with no errors.

**What I see wrong, or have not done.**

- **Nobody is under a blanket.** I tried a blanket raised over the sleeper;
  the knee and the hands came through it, so it is folded at the foot.
- **The change is a pop:** roll to bed and back in one frame, like lying
  down itself.
- **In a one-room family home the two beds overlap** by a few centimetres
  along their long sides, and their foot ends are close to the hearth.
- **On the family's raised bed** two mattresses lie on the bed's own; I
  have seen that only at the edge of one picture.
- Pictures (`previews/phase21_step4/homes/`): night for seeds 1 and 2,
  day (`_day`) for the same.

**Step 4 committed 2026-11-19 (e1069a7)** at your word.

## Step 5: the Mahaleh, live

### First look (2026-11-19, awaiting your walk)

**Try it:** the Mahaleh itself (Strata Board, walk the Mahaleh, or
`-- --room=area:mahaleh`). **F6** is the People panel as before; **F4** the
overlay. Come at three times of day (the panel jumps to a bell).

**What you should see.**

- **Every lived-in home in all four quarters has its people** (24 on world
  seed 1): the family's cook and stall keeper, a scholar, a hunter, and one
  lamp tender to a lane. The posed figures in the homes and lanes are gone.
- **People leave their lane.** The surfaces people walk on are joined
  through the doorways between rooms, the square and the alley included.
  - A stall keeper walks to the square's stalls or to a shop in a bazaar and
    keeps it. The posed keeper of that shop steps aside while they do.
  - A cook whose lane has no hauz fetches water from the next lane's.
  - In the evening people sit at a hauz in another lane if theirs has none.
- **Off-stage:** people exist only while their home's room is built. When
  it comes back they are put where the hour has them, with the same names.
- **People %** on the Strata Board (the area's form, under Animals):
  "Homes lived in". 100% is every furnished home; a home left out stands
  dark with its door shut. Deserted quarters have nobody whatever it says.

Pictures in `previews/phase21_step5/`: the people of two quarters in the
morning, by day and at night.

**What was built.**

| Part | What it is |
|---|---|
| People in any area | `Residents` attaches wherever an area's plan has a furnished home and its People setting is over 0 (`AreaRecipe.people`) |
| Ways between rooms | Every built room gets a walking surface; `WalkMap.join` links two rooms' surfaces through the doorway between them, and takes the link away when either room goes |
| The bazaar's shops | Each open shop gives a place to buy and the keeper's place (`Residents._shop_spots`) |
| Rooms going | A room being taken down loses its people, its surface and its joins at once; anyone standing in it from another lane is put back at home |
| The limit on bodies | The 24 nearest are drawn; those past 26 m move their animation every fourth frame |
| The test | `tests/resident_area_test.gd`: walks the quarters, takes their rooms down and brings them back, and checks everyone |

**Checks.**

- **The area test** (world seeds 1, 2 and 3): passes. Every lived-in home
  has its people, nobody stands off the walking surface, and after a room is
  taken down and built again everyone is doing the same thing in the same
  place at the same hour.
- **Cost of their day:** 0.15 ms a frame for 24 people (the limit I set is
  2). A room's surface: 1 to 5 ms on the main thread, 17 to 92 ms off it.
- **A whole day run fast** on the test lane, and **you in the way**: pass.
- **Your own walking on the test lane**, five seeds: 79 checks, 0 failures.
- **Starting up:** the camp, the Mahaleh, the Forgotten City, the Lower
  Stacks, the test lane and the zoo start headless with no errors.
- **Not run:** the frame gate in the Mahaleh (it fails there with or without
  people, as before). **The cost of drawing the bodies is not measured.**

**Three old faults in the animals' code fixed on the way.** The area test
takes rooms down while the animals are still looking them over, which showed
three places (the pigeons' ledges, the cats' soft spots, the water scan and
the room search) that stopped with an error if a room went mid-look. They
now skip what has gone.

**What I see wrong, or have not done.**

- **The bazaar's and the lanes' crowds are still posed figures.** The brief
  says "the statues go". Only the homes' and quarters' figures have gone;
  a bazaar's walkers, talkers and most of its keepers are as they were. They
  have nowhere to sleep, which the brief did not settle.
  **Your answer (2026-11-19): keep them as posed figures for now.**
- **A stall keeper at the square stands in a cell beside the stall and
  weighs at nothing** (one picture). I have not seen one at a bazaar shop.
- **Which shop a keeper keeps depends on which rooms are built** when they
  set out, so it can differ from one visit to the next.
- **Someone in another room when that room is taken down appears at home.**
  It should be out of your sight; I have not seen it happen in view.
- **Everyone in a trade is dressed alike,** so two lanes' lamp tenders at
  one hauz look like twins.
- **A resident shuts their door behind them** even if you opened it.
- **Long walks:** a keeper may walk well over 100 m to a shop. Nobody has
  been watched doing the whole walk; the tests skip walks.
- **The engine's own navigation warning** about overlapping edges where two
  rooms meet is turned off in the project settings; the joins don't use it.
- **The panel has no People amount, new seed or respawn** yet (the brief's
  list for it); the amount is on the Strata Board.

### After the first look: ways that aren't there, and the long walking test (2026-11-19)

- **The engine complained aloud** ("not expect to not find the most
  reachable polygons") whenever someone asked for a way to a place that
  can't be walked to: a hauz on another level, a seat on an island of the
  surface. With every room built at once that was 206 errors in one run.
  `WalkMap.connected` now works out which pieces of each room's surface hang
  together, and which are joined through doorways, and no way is asked for
  unless there is one. The same run now has none.
- **Your own walking through the whole live Mahaleh** (world seed 1, every
  room built at once): **160 checks, 6 failures, and the same 6 with nobody
  living there** (`nopeople`, a new switch on the test). So they are not the
  people's doing. Five are the test's long walks from the entrance, which
  end with the test body thousands of metres down: the entrance is now a
  Bridge Hall and the walk starts over its pit. One is a warning in the
  entrance's own room check. This test was last run on an older layout of
  the Mahaleh; it needs its own fix.
- After the change: the area test (seeds 1 and 3), the whole day, you in the
  way, and the walking test on the test lane (79 checks, 0 failures) pass.

**Step 5 walked 2026-11-19 ("looks good") and committed at your word.** The bazaar and lane crowds stay posed figures for now.
