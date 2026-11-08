# Approval brief: the Orosi Scriptorium (R08), phase 17

[Back to the front page](../../ENVIRONMENT_PLAN.md) · Status: **approved 2026-11-07 as recommended (all Q1-Q8); step 1 done** ·
Room type: [R08](../../design/room-atlas.html#R08) in the room atlas ·
How a room gets its feel: [room character](room-character.md)

## What this does, in one paragraph

The Library's copying hall, where books are written out by hand. You come in at
the dim end, among low copy desks with small lamps where copyists kneel at
their work. The hall is one tall storey of pale plaster with rows of small
arched niches and a dark timber ceiling. The far wall is made of tall orosi
windows (Persian lattice sashes filled with coloured glass). Behind them is a
garden of glowing lumen-moss, so the glass glows, and it throws patches of red,
gold and blue across the carpets and the desks near it. It is the hushed,
precious room, and it is where the game can ask who copied a book, and whether
you can trust the copy.

## The room's character (proposed; agree it before building)

This starts from the atlas brief. The changes are marked.

| Line | Proposed |
|---|---|
| **Feel** | Studious, precious, hushed |
| **Tint** | **No tint of its own; the colour comes from the glass** (change: the atlas says "jewel colours" without saying how). The plaster stays a warm cream, so the red, gold and blue patches are the only strong colour in the room. A room-wide tint would muddy them |
| **Light** | **Two halves, never mixed** (change: the atlas has desk lamps everywhere). The far half is lit only by the glass, with the coloured patches on the floor. The near half is lit by small lamps on the desks. Following the rule that no flame stands beside natural glow, no lamp sits within a bay of the glass. The doorway end stays dark |
| **Landmark** | The great orosi wall, three tall windows, glowing |
| **Motion** | Dust drifting through the coloured light, with the patches shifting a little as the moss behind the glass brightens and dims |
| **Life** | Copyists kneeling at their desks, still, as the scholars in the Hypostyle Stacks are. Open books, ink, reed pens, scroll piles, cushions. Copies you can read, each naming who copied it (Q5) |
| **Story** | **Work in progress near the lamps, abandoned copies near the glass:** desks by the door busy and tidy, then a desk with a copy left half done, then desks under dust (change: the atlas leaves where this happens open). A Forgotten version comes with it (Q7) |

### Neighbours

The Scriptorium belongs in the Grand Study (Q6). There it would sit beside the
Reading Rooms (warm amber), the stack galleries (blue), the Hypostyle Stacks
(red) and the Gardens (daylight white). The near, lamplit end must not feel
like a second Reading Room. Two things keep them apart: the Scriptorium's lamps
are small and low on the desks (no tall lamps on furniture), and the glass at
the far end shows from the doorway.

The red hall is the closest in colour. The Scriptorium's red is one of three
glass colours in patches, on cream plaster, not a red room, so the change across
the doorway should still be clear. If you think it isn't, the glass palette can
avoid red when the neighbour is the hall (Q3).

## What you'd get

- **The hall:** 12 m wide (three of the game's 4 m cells), one storey about
  6.2 m high, as in the atlas. Three to five cells long by seed (Q2), so 12 to
  20 m. A carpeted floor, niche walls, and a dark beamed ceiling.
- **The orosi wall:** three tall windows across the far end, each a wooden
  lattice holding coloured glass in a radiating pattern. The middle one is the
  widest. It reuses the orosi glass shader from the light-well and adds new
  window pieces.
- **The coloured floor light:** each window has a spotlight carrying a picture
  of its own glass pattern (Godot calls this a projector), so the patches really
  match the windows they come from. The camp's skylight already uses one. This
  is the room's hardest question, so step 1 tries it first.
- **The moss garden behind the glass:** you see it only as glow and soft shapes
  through the glass, not as a place to walk (Q4).
- **Doors:** the entry in the near wall, and side doors in the long walls where
  the area needs to go on. Never through the orosi wall.
- **Built in walked parts,** as the character guide asks, with captures at each
  part. Route and frame tests once the look is final.

## The steps

1. **The orosi wall and its light.** The window pieces in a new
   `kit_scriptorium.blend`, the glass, the moss glow behind, and the coloured
   patches on a plain floor, in a small test room. You judge whether the
   patches read as stained glass light and whether the glass looks precious.
   Nothing else is built until this works.
2. **The hall.** Plaster niche walls, the timber ceiling, carpets, the
   generator with its lengths and side doors, in a test copy of the Grand Study
   on the Strata Board. You walk the bare hall with the glass at the end.
3. **Desks, copyists and lamps.** Copy desks with their rahl, books, ink and
   cushions, the kneeling copyists, the desk lamps in the near half, the dust in
   the light.
4. **Life and story.** The gradient from busy to abandoned, the copies you can
   read with their copyists' names (Q5), the moss brightening and dimming, the
   Forgotten version (Q7).
5. **Live and tested.** The room grows in its area (Q6), with route audit, frame
   gate, save and resume, and the map. Committed after your walk; the atlas marks
   it as in the game.

## Decisions

| | Question | Recommended | Other options |
|---|---|---|---|
| **Q1** | Hand-built or generated? | **Generated, but from a fixed plan:** a small generator whose shape is always the same hall with the glass at the end, and only the length, desks, doors and glass palette change by seed. A hand-built scene can't be grown in an area today, which is why the Reading Room became generated | Hand-built, as the atlas says: one fixed room, placed only where an area names it, and the area code would need to learn to grow scenes |
| **Q2** | How long is the hall? | **Three to five cells by seed** (12 to 20 m). Three is the atlas's room; five gives the busy-to-abandoned walk more room | Always three cells: the atlas's square hall, cheapest, but the story then has only one desk row to happen in |
| **Q3** | Which glass colours? | **Three palettes by seed,** as the atlas draws: ruby and cobalt, saffron and green, and the full spectrum. Next to the red hall, it picks a palette without ruby | One fixed palette, the full spectrum, so every scriptorium looks the same and the landmark is always recognisable |
| **Q4** | Can you go into the moss garden behind the glass? | **No, not now.** It is seen only through the glass. That keeps the glass the landmark and keeps the cost down | A small walkable garden behind the windows, through a side door: a second room inside the room, which is more to build and to light |
| **Q5** | What can you do here? | **Read copies left on the desks.** Each is a lore book that names its copyist, and two copies of the same text can disagree in one word (the home notes already hint at this). It needs no new system, and it starts the trust theme without deciding the rules | Look only, for now. Or a first trust system (copyists who can be trusted or not), which belongs in the game design, not in a room phase |
| **Q6** | Where does it grow? | **The Grand Study, on a test copy** (`gen/recipes/drafts/grand_study/scriptorium_test.tres`), off the hall or a reading room. That area is your library and studies theme | The Lower Stacks. Or its own new area |
| **Q7** | Is there a Forgotten version? | **Yes,** a State setting (Tended, Forgotten), for the Forgotten Wing: no copyists, every lamp out, desks under dust and fallen pages, the moss dimmer so the glass glows faintly. The one bright thing left in a dead room | Leave it for later |
| **Q8** | Do the windows' patches move? | **Slowly, with the moss:** its glow swells and fades over half a minute or so, and the patches with it. Cheap, and it gives the light a living source | Still, which is safest for the frame time. Or patches that drift across the floor, which looks like a moving sun and doesn't suit a light underground |

## Risks

- **The coloured patches.** A projector spotlight shows its picture on every
  surface it reaches, and without a shadow it shines through the desks onto the
  floor below them. One shadowed light per window would cost three of the four
  shadows the budget allows. My plan is to shadow the middle window only and
  keep the other two short and soft. Step 1 shows whether that looks right.
  *Step 1 found:* a shadowless projector light is drawn out of place in Godot
  4.7, so all three window lights now cast shadows, kept out of the shadow budget
  (it stays four for other lamps). See the progress log.
- **Coloured beams in the dust.** Godot's fog doesn't take the projector's
  picture, so a beam in the air would be one colour, not the pattern. If plain
  coloured beams look wrong, there are no beams, only dust in the light.
- **Too like the Reading Room** at the near end. See Neighbours; step 3 is where
  to judge it.
- **Too bright.** Backlit glass is easy to make glow too much. The glass should
  read as lit from behind, not as a lamp. Step 1 is where to judge this.
- **Lights.** Three window lights, a dim moss glow behind them, and maybe 6 to 8
  small desk lamps: about 12 in the room. That fits the 50 in reach with the
  Grand Study's neighbours, though the area's short galleries have already gone
  over it once.
- **Fit.** A 12 m wide hall up to 20 m long, with nothing built behind its far
  wall but the garden's thin space. I haven't tested how often it fits. Step 2
  gives the numbers.

## Not included

- A trust or reputation system for copyists (Q5).
- Copying a book yourself.
- Moving copyists, or sound, which you put later in the project.
- A walkable moss garden (Q4).
- Changes to the Reading Room, the hall or the galleries.
