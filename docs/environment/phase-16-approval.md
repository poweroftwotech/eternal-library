# Approval brief: the Ossuary of Books (R17), phase 16

[Back to the front page](../../ENVIRONMENT_PLAN.md) · Status: **approved 2026-11-07 as recommended (all Q1-Q8); all five steps done and walked, phase complete** ·
Room type: [R17](../../design/room-atlas.html#R17) in the room atlas ·
How a room gets its feel: [room character](room-character.md)

## What this does, in one paragraph

The Library's burial place, where it lays its ruined books and its dead side by
side. You leave a normal door, go down a short rock throat, and find yourself in
low, narrow passages cut into pale stone, both walls honeycombed with niches.
Long niches hold the shrouded dead, small ones above hold crumbling books and
cloth-wrapped bundles, and from the corridor you often can't tell which is
which. Near the entry someone still lights a candle here and there and leaves
small offerings. Deeper in, the candles stop. The passages branch and end, so
every ossuary is different. It is the spookiest room in the game, and nothing in
it can hurt you.

## The room's character (proposed; agree it before building)

This starts from the atlas brief. The changes are marked.

| Line | Proposed |
|---|---|
| **Feel** | Eerie, reverent, the spookiest room, yet not horror |
| **Tint** | *Changed at your walk of step 4: cold blue-grey in the dark, stronger when Forgotten.* **Bone grey-green.** It comes from the stone, not from a light (change: the atlas draws brown rock in green haze). Pale limestone with a grey-green mineral bloom gives the candles something to light, and warm flame against cold stone is the room's look. It is far paler and greyer than the cistern's teal or the light-well's green-gold |
| **Light** | *Changed at your walk of step 4: candles, hung lanterns and glowcaps, every light with a visible source.* **Single candles in tended niches, and nothing else.** One family, short reach, long dim stretches between them. Dim, never black, as the light rules ask. No glowing plants or fungus anywhere |
| **Landmark** | **The shrine:** a larger niche in a small chamber where the passages meet, the only place with many candles, surrounded by offerings. It is the brightest spot in the room and the one you find your way back to |
| **Motion** | *Changed at your walk of step 4: the Forgotten state has ground fog and drips.* Candles guttering, dust falling in thin threads from the vault (change: no fog, which is the stack galleries' signature) |
| **Life** | Mourners' traces: fresh cloth, a bowl, dried flowers, a tray of spare candles left on the floor. Nobody is seen. Biers carry the dead who will be possession hosts later |
| **Story** | **Tended near the entry, forgotten deeper in.** Candles thin out and stop, cloth greys, dust thickens, niches slump and spill, and bare rock breaks through. A Forgotten version comes with it (Q7) |

### Neighbours

In the Mahaleh the ossuary would sit beside the quarters (dusky rose), the
bazaars (saffron gold) or the alleys (blue). All of those are larger and warmer,
so going from a town's noise into these low passages should be a real change.

The room most like it is the far end of the stack galleries, which also has
candles, gloom and neglect. Four things keep them apart: the ossuary is much
lower and narrower, its stone is pale, it has no fog and no blue, and its walls
hold niches, not shelves. It should still not open straight off a gallery if we
can help it.

## What you'd get

- **The passages:** 2.2 m wide with a low rock vault about 2.9 m high, as in the
  atlas. Each of the game's 4 m grid cells holds two of the atlas's 2 m bays.
  That leaves about 0.9 m of rock each side for the niches.
- **The plan:** a tree of passages rather than one corridor, about 12 to 24 cells
  (50 to 100 m of passage, Q3), with branches, dead ends and the shrine chamber
  at a junction. All on one storey.
- **The entry:** one or two cells of rough cave passage from the area's door,
  narrowing into the low corridors (the Bridge Hall's cave pieces, or a tighter
  version if they feel too wide). You feel the ceiling come down.
- **The niches, changed from the atlas:** each 2 m bay has one long niche at the
  bottom for the dead and four small ones above for books and bundles. The atlas
  has six small niches, but at 0.75 m wide and 0.6 m deep a body can't lie in
  one. Real catacombs cut their long niches along the wall for this reason.
- **The biers, moved from the atlas:** the plate draws a bier in the middle of
  the passage. That leaves 0.65 m each side for a player 0.64 m wide, and it
  breaks our rule about nothing standing on the route. Biers stand in side bays
  and dead-end chambers instead, candle at the head.
- **Built in walked parts,** as the character guide asks, with captures at each
  part. Route and frame tests once the look is final.

## The steps

1. **The passages and the shrine chamber.** New pieces in a `kit_ossuary.blend`,
   the generator, empty niches, the pale stone. In a test copy on the Strata
   Board. You can walk the bare space and judge how low and narrow it feels, and
   how lost you get.
2. **Light and mood.** Candles, the tint, guttering, falling dust. You can judge
   the room's hardest question: dark enough to be eerie, yet never black.
3. **The niches and biers.** Books, bundles, the shrouded dead, the shrine
   dressed. You can see the niche walls as they will really look.
4. **Life and story.** Offerings, the gradient from tended to forgotten, the
   Forgotten version (Q7), what you can do here (Q6).
5. **Live and tested.** The room grows in its area (Q8), with route audit, frame
   gate, save and resume, and the map. Committed after your walk; the atlas marks
   it as in the game.

## Decisions

| | Question | Recommended | Other options |
|---|---|---|---|
| **Q1** | How openly are the dead shown? | **Shrouds only.** Wrapped bodies and bundles, with the cloth sunken and grey deep in. The room's idea is that a book and a body are laid out alike, and shrouds keep that doubt alive. It also stays clear of Halloween skulls | Dry, tidy bones in the forgotten stretches, as a real ossuary has. The name supports it, but it pulls the room toward a European catacomb and toward horror |
| **Q2** | What about the possession hosts? | **Bodies on biers, marked in the scene as future hosts, with no interaction yet.** Possession isn't built at all, so there is nothing to connect them to | Build a placeholder prompt now: it would have to be thrown away when the real system is designed |
| **Q3** | How big is it? | **12 to 24 cells, chosen by seed.** Large enough to lose your way, small enough that the dark stretches stay tense | Smaller, 8 to 12 cells: cheaper, easier to fit, more a crypt than a catacomb. Or larger, 30 or more: a real labyrinth, but the walls get repetitive and it won't often fit |
| **Q4** | Do we see any mourners? | **No, only their traces.** A fresh candle with nobody near it is eerier than a figure, and it spares us another still person | One still figure kneeling at the shrine, near the entry end only, by seed |
| **Q5** | Does anything react to you? | **Only the candles:** the nearest flame leans and dips as you pass, as if you had stirred the air. Small and cheap, and it makes the place feel aware of you without threatening you | Candles going out behind you, which is much stronger but crosses into horror. Or nothing at all |
| **Q6** | What can you do here? | **Take a few lore books, and light a candle at the shrine.** The book system exists. Lighting a candle is new but small, it is saved, and it burns out as time passes. It is the one act that suits the place, and it gives you a mark of your own on a return visit | Look only, for now. Or let you light a candle at any niche, which means more lights to budget |
| **Q7** | Is there a Forgotten version? | **Yes,** a State setting (Tended, Forgotten) as on the quarter and bazaar, for the Forgotten City: every niche dark, cloth in rags, but one candle still burning at the shrine, and nobody to say who lit it | Leave it for later |
| **Q8** | Where does it grow, and does it lead anywhere? | **The Mahaleh, off a quarter, on a test copy** (`gen/recipes/drafts/mahaleh/ossuary_test.tres`): a town needs somewhere for its dead, and the candles need living people. **With a far door,** because both the Mahaleh and the Forgotten City allow no dead-end rooms today. I would add it to your v9 recipe without rerunning the old live tools, or you can add it on the board as you did with the deserted bazaar | Its own new area, as part of your themed areas rework. Or no far door: a true end of the line, which suits the room but means changing the recipe's dead-end limit |

## Risks

- **Dark enough but never black.** The brief asks for long dark stretches, and the
  light rules forbid a stretch where you can't see. This is the main risk, and
  step 2 is where to judge it. Pale stone helps, because the same dim light shows
  more on it.
- **Repetition.** Niche walls for 50 to 100 m could look like one texture. The
  mix of niche contents, side bays, slumped stretches and rock breaking through
  has to carry this. Step 3 will show it.
- **Cost.** A 20-cell room has about 400 niches, which is too many to place one
  by one. I would merge each bay's contents into a few mesh variants and keep
  only the books you can take as separate props. Lights should be low: my
  estimate is 8 to 15 candles and one shadowed light at the shrine, with a short
  reach. Bays that have no candle can hold unlit ones at almost no cost.
- **Fit.** I haven't tested how often it fits. The room is one storey and its
  corridors need a cell of rock between them, so a 24-cell tree may want around
  40 × 32 m. Step 1 gives the first numbers.
- **The test walk.** The route audit is used to rooms with one main line. A tree
  with dead ends needs its own list of stops so that every branch gets walked.
- **Too like the far galleries.** See Neighbours; step 2 is where to judge it.

## Not included

- Possession, spirit form, or anything else from the death system (Q2).
- Moving mourners or keepers. Sound, which you put later in the project.
- The atlas's rare tomb chamber. The shrine is the landmark for now, and a tomb
  could be added later as a chamber on the same tree.
- Anything dangerous. Nothing attacks, chases or traps you.
- The Prison Cells, which the atlas would make from these niches at room scale.
- Spirit Anchor Shrines (R18), which are a separate room.
