# Approval brief: the water's edge and the birds, phase 20

[Back to the front page](../../ENVIRONMENT_PLAN.md) · Status: **APPROVED
as recommended 2026-11-13 (Q1-Q8). Step 1 (sound, the nightingale) built 2026-11-14, awaiting your look; caged nightingale (Q8) moved to step 6.** ·
The animals: [creature atlas](../../design/creature-atlas.html) (plates C03,
C04, C05, C10, C16, C19) ·
What phase 19 built and how: [phase 19 design](phase-19-design.md),
[phase 19 progress](progress/phase-19-creatures.md), [the zoo](progress/zoo.md)

## What you are approving

1. **Sound in the game,** in a small first form: the animals make sounds you
   hear from where they are. Today the game only plays its one music track.
2. **The six animals of phase 20,** as the atlas has them (you approved the
   list with phase 19): the spiny eel, the Luristan newt, the otter, the
   four-eyed dog, the pigeon and the nightingale.
3. **Six steps.** Each one is shown to you first for the look, in the zoo and
   in the real game. Route and frame tests run once, at step 6.

## The six, in one table

| Animal | Where it lives | What it does | How it is made |
|---|---|---|---|
| **Nightingale** | The Garden Court's old pomegranate, figs and roses; the Light-Well's garden; the camp | Perches, hops, flies short arcs, **sings** | Simple, like the bats |
| **Pigeon** | The quarter's pigeon tower, the bazaar dome's eye and beam, caravanserai parapets, Gorge roofs and terraces | Perches in rows, struts and pecks, the flock wheels and comes back | Simple, a flock |
| **Spiny eel** | Holes in the cistern's piers and causeway, the lake's channels | Head out of a hole, slides to another hole, goes in tail first | Simple |
| **Luristan newt** | Wet stone by running water: the Fungus Terraces' cascade and channels, the Light-Well's pool, the Bridge Hall's cave mouths, a wild Garden Court's rills | Sits, walks slowly along the channel floor, slips in | Simple |
| **Otter** | The Lake Landing's harbour and docks | Swims leaving a V, dives, floats on its back, grooms on the steps, sleeps in a moored boat | **Rigged** (a skeleton, like the cat) |
| **Four-eyed dog** | One to each tended ossuary, at the door and in the shrine chamber | Lies at the door, walks to the shrine and back, sits facing the biers | **Rigged** |

## Phase 20, step by step

1. **Sound, and the nightingale.** The game gets separate volumes for music and
   animals, and sounds that come from a place: louder near, quieter far, and
   only the nearest ones play. The sounds are made by a tool in the project,
   as the music already is (Q1). Then the nightingale: it sings in bouts from
   the Garden Court's tree and the roses, flies to a higher perch when you
   come close, and stops singing while you run near it.
   *You try:* the Garden Court, then the camp.
   *Underneath:* how every later sound plays (people, doors, water). The zoo
   gets a garden pen.
2. **Pigeons.** Rows of pigeons on the quarter's tower, on parapets and round
   the bazaar dome's eye; some strut and peck on open ground. Now and then a
   flock wheels round the tower or through the dome's beam and comes back.
   They walk out of your way, and burst up together if you run, with a clap of
   wings. They coo.
   *You try:* a Mahaleh quarter built round the pigeon tower; the bazaar's
   crossing; the Gorge's terraces (Q5).
   *Underneath:* finding ledges to perch on, on the surfaces you can see (the
   geckos taught us that walls' collision sits behind what you see).
3. **The eel and the newt.** Eels in holes under the cistern's water and along
   the lake's channels, sliding between holes and backing in when you come
   close. Newts on wet stone where water runs, freezing, then slipping in when
   you are within two metres.
   *You try:* wade the cistern; the Fungus Terraces' cascade.
   *Underneath:* telling running water from still water, and holes placed on
   the visible stone under the surface. Zoo pens for a stream and a pier.
4. **The otter.** The second animal with a skeleton, from a Blender script like
   the cat's. Shown to you standing still first, against reference pictures you
   choose, before it moves. Then: swimming with a V behind it, diving, floating
   on its back, grooming on the water steps, sleeping in a moored boat. It
   keeps about six metres off and dives if you run. On land it is solid.
   *You try:* the harbour, then a ferry trip to a dock.
5. **The four-eyed dog.** The third skeleton, shown standing first. It lies at
   the ossuary's door, walks the candlelit passage to the shrine and back,
   sits facing the biers, lifts its head as you pass. The first time you come,
   it walks beside you to the shrine and stops where the candles stop (Q6). A
   forgotten ossuary has only its collar (Q7). It is solid.
   *You try:* an ossuary in the Mahaleh, twice; one in the Forgotten City.
6. **Live, saved and tested.** The six join each area's animal table (by world
   seed, as in phase 19); the save remembers each dog's first walk. Tests: the
   frame gate in the rooms the new animals live in, with animals on and off;
   save and resume in two processes; the route audit, because the dog and the
   otter are solid. Committed after your walk.

## The decisions

| | Question | Recommended | Other options |
|---|---|---|---|
| **Q1** | Where the sounds come from | **Made by a tool in the project,** as the music already is: no recordings, nothing downloaded. Any sound can be swapped for a recording later, one file at a time. The nightingale is the hard test; you hear it in step 1 before anything else is made | Real recordings under a free licence, each one you pick (I ask before every download); or recordings you supply |
| **Q2** | Which sounds this phase | **The six new animals, plus a few for phase 19's:** the cat's mew and purr, bats' chitter, rats' squeak, a splash when fish scatter. No room sounds yet (water, fire, drips) | The six only; or room sounds too, which roughly doubles step 1 |
| **Q3** | Volume controls | **Two sliders, Music and Animals, in the Esc menu,** remembered between games | No controls yet |
| **Q4** | How many sounds at once | **The nearest 12 animal sounds, none past 25 m** (the nightingale reaches 30 m). Silence is part of the mood: most rooms should be quiet most of the time | No limit until something is slow |
| **Q5** | Pigeons in the Gorge | **Yes, in step 2:** on roofs and terraces near the walks, in flocks over the mist. The Gorge has its looser frame gate, and a known fault (the animals' sensing misses the Gorge's and camp's collision) is fixed first | The Mahaleh only for now |
| **Q6** | The dog walking you to the shrine | **The first time in each ossuary, remembered in the save;** after that it only lifts its head and watches | Every time you come; or never (it only watches) |
| **Q7** | The forgotten ossuary's dog | **Only its collar, by the door,** as on the plate | A thin, wary dog that keeps its distance |
| **Q8** | A caged nightingale | **Yes, at one bazaar stall in some worlds, singing** | Not this phase |

## What comes after

| Phase | What you get |
|---|---|
| **21. The rare ones** | Wild goats on the Gorge's ledges; the viper; bookworms; the Shadhavar (its horn uses this phase's sound), the Kar fish and the Huma |
| **Then: behaviour** | Health and harm, fleeing and fighting back, the food web, fishing and hunting; the otter stealing from your line; pigeons carrying messages |
| **Then: people, then monsters** | On the same groundwork, now with sound |

## Risks

- **Made sounds can sound cheap.** A nightingale is hard to make well. That is
  why it comes first, and why Q1 has other options if it doesn't convince you.
- **Two more skeletons.** The cat took six looks. This time I start from the
  reference pictures you pick and match their proportions before anything
  else.
- **The Mahaleh is over its frame limit already** (59 lights, streaming
  spikes), with or without animals. The dog and the pigeons live there, so
  their cost is measured in their own rooms, with animals on and off, and the
  area's own problem stays a separate fix.
- **Water has a surface but no depth.** Fish already fade with depth below the
  surface. The otter dives the same way, and eels sit on the stone they are
  placed on, so no depth data is needed.
- **Tests run silent** (dummy audio driver), so the sound limits are checked by
  counting, and by your ear on the walks.

## Not included in phase 20

- Harm, health, feeding, taming, fishing, hunting.
- Room sounds (water, fire, drips, wind), unless Q2 says otherwise.
- The dog seeing you as a spirit; messenger pigeons; the otter and your line.
- Animals crossing between rooms.
- The notebook of animals you have seen (phase 19's Q11 said later).
