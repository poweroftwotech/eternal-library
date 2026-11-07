# Room character: how a room gets its own feel

[Back to the front page](../../ENVIRONMENT_PLAN.md) · Written 2026-11-04,
after the rework of every built room (room rework steps 1-8,
[progress](progress/room-rework.md)) · Room types and their proposed
characters: [the room atlas](../../design/room-atlas.html)

Every room should feel like a different place. Walking through a doorway
should change the light, the colour, the sound and what people do there.
The kit pieces are shared on purpose, so a room's character can't come
from its walls. It comes from what this page lists.

This page collects what the eight rework steps taught, mostly from your
walks and reports. [ART_DIRECTION.md](../../ART_DIRECTION.md) still holds
the look every room shares (texel density, palette, grade). This page is
about what makes one room unlike the next.

## 1. Every room gets a character brief before it is built

Before any kit work, write the room's brief in its atlas plate. Agree it
with you the way the stacks rework was agreed. It has seven lines:

| Line | Question it answers | Example (the Stack Galleries) |
|---|---|---|
| **Feel** | Three or four words for the mood | Hushed, neglected, slightly spooky, never dangerous |
| **Tint** | The room's colour, eased in as you enter (`mood_tint`) | Blue, growing with distance from the door |
| **Light** | Which kind of light, and where it comes from | Pier sconces near the door; torches and candles further in; glowing fungus far out |
| **Landmark** | The one thing you remember the room by | A taghcheh wall of niches; a reading corner |
| **Motion** | What moves or sounds | Drips into puddles, low fog |
| **Life** | Who uses it, and what you can do there | Keepers at work near the door; cook, forage and rest in the alcoves |
| **Story** | How the room changes across its length or over time | Tended near the door, abandoned far out |

Each line should differ from the rooms likely to sit beside it (section 4).

## 2. Light

Light is the strongest tool, and every rework walk came back to it.

- **Every light has a visible source.** A flame, a lamp, a glowing plant, a
  shaft of daylight. Coloured light needs a reason you can see: the stacks'
  blue comes from glowcaps at the pier feet, the cistern's teal from its
  plants.
- **One family of light per room.** The cistern is lit only by plants. The
  light-well has no lanterns: only its beam and glowing vines. The Reading
  Room uses oil lamps on its furniture. The Hypostyle Stacks has red-fire
  lanterns and sunbeams. Don't mix every kind in one place.
- **Pools of light with shadow between them.** Keep reach short and keep
  the glare: a bright source that lights only its own bay. Too many lights
  flatten a room ("want a good balance of light and shadows").
- **No flames beside natural glow.** Where a plant, fungus or root glows, no
  lamp or torch stands within a bay of it, so the plant shines through.
- **The ceiling is darker than the walls.** Fills sit low (about 1.3 m), not
  under the vault; a bright vault looks unnatural.
- **Never pitch black.** Dim is fine; a stretch where you can see nothing is
  not. Dark between pools, never black.
- **Doorway ends stay dark,** so the next room's light bleeds in through the
  doorway and announces the change. Don't put a lamp right at a door.
- **Ornament is lit by lamps, not self-lit.** Patterns glow because a lamp
  is near them.
- **Budget:** at most 50 lights within reach at once, at most 4 with
  shadows. A room's character must fit that. Fewer, better-placed lights
  beat many dim ones (the hall's fix in step 7).

## 3. Colour and mood

- **Each room has one tint** (`mood_tint` on its grammar or template),
  eased in as you walk in and out. Taken so far:

  | Room | Colour | Where it comes from |
  |---|---|---|
  | R01 Reading Room | Warm amber | Oil lamps on the furniture |
  | R02 Stack Galleries | Blue, growing with distance | Glowing fungus |
  | R03 Hypostyle Stacks | Red | Red carpet, red-fire lanterns |
  | R04 Grand Bazaar | Saffron gold | Beams through the vault eyes, coloured glass, a different lamp colour for each trade |
  | R05 Caravanserai | Warm firelight | Lanterns, hearths |
  | R06 Domicile Quarter | Rose clay at dusk, muted | Rose plaster walls, cool air in the lanes, warmth only at the windows |
  | R09 Light-Well Stair | Green-gold, pulled to white | Daylight through vines |
  | R11 Cistern Archive | Teal | Glowing plants and roots |
  | R10 Chasm Spans | Daylight and mist | The gorge's sky |

  R02, R03 and R09 set a `mood_tint`; the others take their colour from
  their lights alone.

  A new room picks a colour not in this table, or the same hue at a clearly
  different strength and source. The atlas proposes one per room.
- **Materials can carry mood:** wet stone (darker, glossier) in the
  light-well and stacks; orosi glass that catches glints; dust greying the
  books in abandoned stretches.
- **Slightly spooky is allowed, danger is not.** The far stacks are eerie
  (fog, cobwebs, roots, quiet) but nothing threatens. Keep that line unless
  a room's purpose says otherwise (the Ossuary is the one room that may lean
  further).

## 4. Neighbours must differ

The areas join rooms in chains. A doorway between two rooms that look alike
is a missed moment.

- Before building, look at which rooms the area plans will put next to the
  new one. Make sure at least the tint and the light family change across
  each doorway.
- Big and small, bright and dark, busy and quiet should alternate. After the
  narrow blue stacks, the open red hall feels larger than it is.

## 5. One landmark, one bit of life

- **A landmark per room** is what you navigate and remember by: the hauz
  and takht in the hall, the beam in the light-well, the sealed vault door
  in the cistern, a taghcheh in each gallery. A generated room places at
  least one, early in its grammar, so the rest works around it.
- **Rooms are lived in.** Working niches make a room more than a corridor:
  cook at a hearth, gather from a garden bed, read at a low table, sit in a
  nook. People's traces (a keeper's cart, a mug, a book left open) say the
  place is used.
- **Persian everyday life, not European furniture:** floor seating (toshak,
  poshti, kilim poufs), low reading tables with a rahl, brass sini trays,
  carpets picked by seed, taghcheh niches, hauz and takht.
- **Plants grow by light:** gardens under daylight or lamps; glowing plants
  where there is no light.

## 6. Story in space

- **A gradient across the room:** the stacks go from tended to abandoned
  with distance; shelves tidy, then gapped and leaning, then bare or
  collapsed. A room that changes as you walk through it feels bigger and
  older.
- **Remind the player where they are:** the Library is carved into rock. Let
  it show through: cave rock in a broken recess, roots through the vault,
  water seeping in.
- **Time passes:** sockets that swap dressing (lamp states, plants, damage)
  let a revisited room show its age.

## 7. Layout keeps its promises

- Furniture never blocks a doorway line or the main route. Keep the lines
  between doors clear; no freestanding obstacles down the middle of a
  walking hall (the hall's wall cases, step 4).
- Ornament and props stay inside their slots; Validate Room and the route
  tests catch overlaps.

## 8. How a room's character is built

1. Write the seven-line brief (section 1) on the room's atlas plate, as
   **proposed**; agree it with you.
2. Build in walked parts: structure and landmark, then light, then mood
   (tint, motion, materials), then life and story. Show captures for each
   part; you walk the ones that matter.
3. No route or frame tests during look iterations; run them once the look
   is final (they take an hour or more).
4. When it is done, the plate's brief changes from **proposed** to **in the
   game**, and the tint table above gets the room's line.
