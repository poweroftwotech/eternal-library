# Approval brief: the Domicile Quarter (R06), phase 14

[Back to the front page](../../ENVIRONMENT_PLAN.md) · Status: **agreed in outline 2026-11-05, on hold until you have given each area its theme (homes and gardens, food and farming, scholars and study, and so on). Q7 (where it grows) and the neighbours are settled after that** ·
Room type: [R06](../../design/room-atlas.html#R06) in the room atlas ·
How a room gets its feel: [room character](room-character.md)

## What this does, in one paragraph

The first place in the Library where people simply live. A small neighbourhood
(mahalleh) of narrow lanes between rose-clay houses of uneven height, under a
dark cavern roof. Rooms bridge the lanes overhead (sabats), washing and
embroidered cloth hang across them, and a small pool sits at a crossing. The
lanes are dim; the light comes from windows and open doors. A few homes can be
walked into, each dressed by who lives there. Further from the middle the
houses empty out. The lanes and houses are generated, so every quarter is
different.

## The room's character (proposed; agree it before building)

This starts from the atlas brief. The changes are marked.

| Line | Proposed |
|---|---|
| **Feel** | Homely, close, everyday |
| **Tint** | **Rose clay at dusk, muted** (change: sharper than the atlas). The colour is in the walls, a new rose plaster, and the lanes are dim and slightly cool. The warmth is only at the windows. This keeps it apart from the saturated red of the Hypostyle Stacks and the orange of the caravanserai |
| **Light** | Lit windows and open doorways, with a lamp by some doors (change: no lantern strings, which are the caravanserai's). Pools of warm light on the lane in front of a home, dim between them. The cavern roof stays dark |
| **Landmark** | A small hauz at a lane crossing under a sabat, its lit window shining on the water |
| **Motion** | Washing and hung cloth stirring, cooking smoke from a few roofs and doorways, ripples on the hauz |
| **Life** | People at their doors and on their steps (static figures, as with the scholars and workers). Homes dressed by who lives there. Cook at a hearth, rest, read a note left out |
| **Story** | Lived-in at the middle, emptier toward the edge: shutters closed, windows dark, doors ajar on bare rooms, cloth gone to rags, plants getting in |

### Neighbours

The quarter can open off the Stack Galleries (blue), the Hypostyle Stacks
(red), the cistern (teal), the light-well (green-gold), the Bridge Hall
(silver mist), the Garden Court (white) or the terraces (violet). The risk is
the warm rooms, which is why the tint is muted and the lanes dim: after the
bright red hall, the quarter should feel small, quiet and close.

## What you'd get

- **The lanes:** about 3.4 m wide, with a few turns and crossings, so you lose
  sight of the far end. Houses of one to three storeys with uneven heights and
  fronts that step in and out. One to two sabats overhead, one over the hauz.
  Steps at a lane's end up to a higher door.
- **The size:** the seed picks about 28 × 20 m or 40 × 28 m (7 × 5 or 10 × 7
  bays).
- **New pieces at house scale** (Q3): narrower fronts, lower storeys and small
  doors, so the lanes feel close. The Gorge's houses are built on 4 m storeys
  and bays, which is too regular and too big for this.
- **Homes to enter** (Q1, Q2): three to five per quarter, 1 × 2 or 2 × 2 bays
  (the atlas's 2 × 3 is too big to fit several). The other doors are shut.
- **Above:** a dark rock roof, with small lit windows of terraced houses far up
  its walls, drawn as a backdrop you can't reach.
- **On the map:** the lanes, the open homes and the hauz.
- **Built in walked parts,** as the character guide asks, with captures at each
  part. Route and frame tests once the look is final.

## The steps

1. **Lanes and houses.** New pieces in a `kit_quarter.blend`, the rose plaster,
   the generator for lanes and lots, the sabats and the hauz, the cavern above.
   In a test copy on the Strata Board. You can walk the lanes; doors don't open
   yet.
2. **Light and mood.** Window glow, door lamps and their pools of light, the
   tint, cloth and washing, smoke. You can judge the feel of the lanes.
3. **The homes.** Doors that open, the small interiors, and the four kinds of
   household (Q4). You can walk into each kind.
4. **Life and story.** Figures, working hearths, notes, the lived-in to
   abandoned gradient, and the Forgotten Wing's state (Q6).
5. **Live and tested.** The quarter grows in the areas (Q7), with route audit,
   frame gate, save and resume, and the map. Committed after your walk; the atlas
   marks it as in the game.

## Decisions

| | Question | Recommended | Other options |
|---|---|---|---|
| **Q1** | How do you enter a home? | **Walk straight in.** The homes are part of the quarter, so there is no load, and a lit window really looks into the room behind it. This changes the atlas, which says interiors are built on entry | A door that loads a separate small place: allows more homes, but adds a pause at every door and the inside won't match the window |
| **Q2** | How many homes open? | **Three to five per quarter.** Enough to explore; each can be dressed with care and costs one or two lights | Every door opens (far more rooms to build and light); or just one |
| **Q3** | Which house pieces? | **A new set at house scale,** using the Gorge's plaster and timber but with lower storeys and narrower fronts. The lanes are the room, so they need to feel right up close | Reuse the Gorge's pieces: quicker, but regular and oversized at 3.4 m |
| **Q4** | Who lives there? | **The atlas's four: scholar, family, hunter, abandoned.** Their things tell you who they are | Add more, such as a weaver or a potter, in a later pass |
| **Q5** | How far do side stories go? | **Traces only, plus a short note to read in some homes** (placeholder text, using the lore books). Figures don't talk yet | Leave out notes; or wait for a dialogue system |
| **Q6** | Does the quarter differ by area? | **Lived-in in the Lower Stacks, mostly deserted in the Forgotten Wing,** with one or two homes still lit. It reuses the same gradient, as the garden's wild state did | The same everywhere |
| **Q7** | Where does it grow? | **Grown last off any free door,** as the terraces were, costing other rooms nothing. A fit sweep reports how many worlds get one. If that is too few, I'll show you the count before changing anything | Grown earlier for more worlds, which moves other rooms; or an area of its own behind a spare Gorge door, so it is always there |
| **Q8** | Can you climb above the lanes? | **Not in this version.** Sabats and roofs are seen from below; the only climb is the steps to the higher door | A stair to a roof terrace, or a sabat you can enter (more routes to test) |

## Risks

- **Fit.** This is a wide room, and rooms grown last get what space is left.
  The smaller size is there for that; the sweep in step 5 gives the number.
- **Lights.** Many lit windows could break the 50-light limit, so most windows
  glow without casting real light. Only open homes, door lamps and the hauz get
  real lights. The Lower Stacks' area gate already fails elsewhere (58 lights in
  the caravanserai at seed 3), so a quarter near it has little room.
- **Many small pieces.** Lots of small fronts and props could cost draw calls;
  the frame gate at the end of step 5 will show it. The batching already used
  for the Gorge is the first thing to try.
- **Organic lanes on a grid.** The usual room rules are too coarse for lanes, so
  this generator places pieces directly, as the terraces do. The risk is
  awkward joins at turns and crossings, which your first walk will show.

## Not included

- Figures that move or talk; quests.
- Homes that change with the world clock (revisiting years later). The sockets
  will be ready, the clock comes later.
- Reaching roofs and sabats (Q8).
- Voices and neighbourhood sound.
- The Tea House (R14, which can later sit inside a lot) and shops.
