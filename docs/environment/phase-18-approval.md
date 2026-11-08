# Approval brief: the Lake Landing (R20), phase 18, revised

[Back to the front page](../../ENVIRONMENT_PLAN.md) · Status: **revised 2026-11-08 after walk 1 and APPROVED as recommended 2026-11-08 (with your R1: all docks in one scene, chosen by the destination's theme).** Step 1 (the harbour) walked 6 times, look approved 2026-11-08. Step 2 (one trip through the fog, the Mahaleh dock) built 2026-11-08, waiting for your ride. The first version was approved 2026-11-08 (Q3: landing doors sealed) and steps 1-4 were built to it; this revision replaces the one great cavern with small dock chambers joined by fog channels (your idea) ·
Room type: [R20](../../design/room-atlas.html#R20) in the room atlas ·
How a room gets its feel: [room character](room-character.md) ·
Reference pictures: `design/reference images/caves/` (Ali-Sadr cave, Hamadan)

## What changes, in one paragraph

The lake is no longer one great cavern you see across. It becomes a **home
harbour**: a low, natural cave chamber shaped after the Ali-Sadr pictures,
with the quay, pier, boathouses and hearth terrace you've already walked, and
one or two **channels** leading out into the dark. You board the ferry, choose
where to go, and it poles you out into a channel. The channel fills with fog
until there is nothing to see but fog. Under the fog, the boat is moved to
another dock in the same scene, one of a few **dock styles** kept far apart,
the one that suits your destination's theme (or a plain default). The fog
thins and the boat, with you standing where you stood, comes out of that
dock's channel and noses into its stage. No load, no loading screen, no
170 m room. A dock is a look, not a place: its sign and its door are set for
the destination you chose, so any exit can lead to **any destination**.

## Why

- **Your walk 1 notes:** the cavern looked "too open and tall" and unnatural.
  The reference pictures show the opposite: roofs 3-8 m over the water,
  leaning layered rock, passages that always lead on into the dark.
- **Unlimited destinations.** A cavern you see across can only hold the
  landings that fit round its shore. Docks reached through the fog can be
  anywhere.
- **Cheaper.** Only the dock you are at is live: a chamber 30-50 m across with
  low roofs, instead of a 170 m cavern drawn whole.
- **Any exit to any destination.** A dock is a look, chosen to suit the
  destination; its sign and door are set when you choose where to go.

## What stays, what goes

| Stays (carried into the new shape) | Goes |
|---|---|
| The quay, water steps, wading shelf, pier and pier head, boathouses, boardwalk, moored boats, lanterns with their gold streaks on the water | The 170 x 160 m cavern, its roof dips and the 18 rock stacks (they were placed to dodge open-water routes) |
| The hearth terrace and the three fishing spots | The ferry's Bezier routes across open water |
| The ferry, ferryman, the ride standing on the deck, the bell | Seeing the far landings as lit points across the water |
| The four landings' dressing: the Mahaleh's house front, the Gardens / Forgotten City / dark grottos, sealed doors (your Q3) | |
| Glowing mushroom colonies, mist, wading, the boat-texture fix | |

## The room's character (revised lines only)

| Line | Revised |
|---|---|
| **Feel** | Low, close, winding; the cave always goes on round the next bend |
| **Tint** | **Warm layered limestone where the lanterns reach** (cream to ochre, as in the pictures); the dark beyond them stays indigo. Teal mushroom light only in the dark side passages and the channels, never beside a lantern |
| **Landmark** | Still the quay and its lantern pier, now under a low rock roof, with the channel mouths beyond: a lantern on a post at each one |
| **Motion** | Water lapping, boats rocking, lanterns swaying, fog breathing in and out of the channel mouths, the lantern boat rowing out of one channel and into another |
| **Story** | Each channel mouth has a painted board naming where it goes. **One channel has no lantern and its mouth is half flooded:** a place you can't go yet (the old dark landing's job) |

## The steps

1. **The harbour after the pictures.** The quay chamber reshaped: low layered
   roof (about 4-12 m), leaning sheets of rock, flowstone masses, undercut
   waterline, boulders and ledges, the quay and its pieces placed into it, two
   channel mouths (one lit, one dark and flooded). Warm limestone under the
   lanterns. Look first: you walk it. No ferry trips yet.
2. **One trip through the fog.** A channel piece (about 30 m, bending out of
   sight) at each end, the fog that swallows the boat, the move to the other dock underneath,
   the boat coming out of the far fog with you on deck at the same spot, and
   mooring at the Mahaleh dock. You ride it both ways.
3. **Every dock.** A dock chamber kit piece (a small cave chamber, a stage, a
   channel mouth), and from it the Mahaleh, Gardens and Forgotten City docks
   with their existing dressing; the ferry table (destinations, names, dock
   scenes) the ferryman reads; the bell calling the empty ferry out of the
   fog; the lantern boat. You ride to each.
4. **Life and dressing** carried over and checked in the new places: the
   fisher, mushrooms, mist, hearth, fishing spots, moored boats by seed.
5. **Live and tested.** As before: the harbour behind its Gorge door, on the
   map and the Strata Board (the docks as places, the ferry lines dotted
   between them), route audit, save and resume across processes, frame gate.
   Committed after your walk.

## Decisions

| | Question | Recommended | Other options |
|---|---|---|---|
| **R1** | Where do the docks live? | **Your idea: one ferry scene holding the home harbour and a few dock styles far apart** (town dock with the Mahaleh front, garden grotto, ruin grotto, dark flooded dock, a plain default cave dock). A dock is a look, not a place: the trip moves the boat under the fog to the dock styled for the destination, so nothing loads and any exit can lead to any destination. Only the dock you are at is shown and lit | Each dock its own scene, loaded under the fog (my first version): no limit on styles, but a load every trip and docks tied to places |
| **R1b** | Which style for a destination? | **The one whose themes match the destination's theme, else the default; where several match, one picked by world seed and destination, then fixed,** so coming back to a place shows the same dock | A random style every trip (a place's dock would change each visit) |
| **R1c** | The same style twice in a row? | **Each dock has two channel mouths:** you leave by one and arrive by the other, and the dock is re-dressed (sign, lanterns, door target) for the destination under the fog | One mouth: you'd come back out where you went in |
| **R2** | How is the trip hidden? | **Fog:** as the boat enters the channel, a fog bank thickens round it and the light falls until there is only fog; the boat is moved to the arrival dock; its channel's fog thins as the boat comes out. About 8-10 s out, a moment held in the fog, about 10 s in. **Darkness** for the flooded channel later (no lantern, the light simply goes) | A plain fade to black, as doors use: quicker to build, but a cut |
| **R3** | Where are you on arrival? | **On the same spot of the deck, facing the same way.** The boat's pose and yours relative to it are carried across the move | Standing in the middle of the deck, facing the bow: simpler, but a small jump |
| **R4** | Saving during a trip? | **Before the fog: you resume at the dock you left. In or after the fog: at the dock you were going to,** on its stage. No save on the deck itself, as now | Always resume where you boarded |
| **R5** | The destinations | **A ferry table** (a resource listing each destination: name, theme, whether it is open). The destination is set when you choose it at the ferryman; the arrival dock's door targets it. An area's exit door into the ferry scene lands you at the dock styled for that area. The ferryman offers the open ones. This phase: the Mahaleh, Gardens and Forgotten City docks, doors sealed (your Q3) | Destinations written into the ferry's code |
| **R6** | The look of the rock | **Warm layered limestone under the lanterns, as in the pictures,** dark indigo beyond; a new rock material with sloping bands, used for the harbour and docks only | Keep the cave rock used elsewhere, only reshaped (less work, less like the pictures) |
| **R7** | Can the dock chamber go elsewhere later? | **Yes: built as a kit piece,** so a later phase can put a dock inside an area (a canal in the Mahaleh, say) and add it to the ferry table. This phase uses it only in lake scenes | Hand-built docks, one by one |

Unchanged from the first brief: Q1 (a place of its own, a door from the
Gorge), Q3 (doors sealed), Q4 (ride standing), Q5 (wading), Q7 (painted
streaks), Q8 (no Forgotten lake).

## Risks

- **Matching the two ends of the fog.** The boat leaves one scene and arrives
  in another; the speed, the sway, the fog's colour and your place on the
  deck must match, or the cut shows. Step 2 is one trip only, to get this
  right before building more docks.
- **Many docks in one scene.** Each hidden dock must cost nothing: hidden, its
  lights off, its collision off. Only the dock you are at (and the harbour,
  if you are in it) is live. The scene grows by a small chamber per style.
- **Natural rock that reads in the dark.** The pictures are brightly lit
  show-cave photos; ours is lantern-lit. Step 1 is the look question: warm
  rock where lanterns are, so the shapes read, without lighting everything.

## Not included

- Rowing or steering your own boat; swimming; fishing as an activity.
- Doors from the docks into areas (sealed, your Q3).
- Docks inside areas (R7 makes them possible later).
- Sound.
