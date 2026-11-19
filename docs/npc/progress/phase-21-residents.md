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
