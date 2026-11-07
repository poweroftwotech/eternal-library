# Approval brief: the Grand Bazaar (R04), phase 15

[Back to the front page](../../ENVIRONMENT_PLAN.md) · Status: **approved 2026-11-06 as recommended; all five steps done, committed 2026-11-07** ·
Room type: [R04](../../design/room-atlas.html#R04) in the room atlas ·
How a room gets its feel: [room character](room-character.md)

## What this does, in one paragraph

The first place in the Library that feels like a town's centre. A great tiled
dome stands over a crossing, with daylight falling through its eye and coloured
glass in its tall arches. Covered shop streets run off it under brick vaults.
Each street is lined with arched shops, one trade to a shop: rugs stacked to the
ceiling, walls of copper, hanging lamps, books, spices in mounds. It is golden
and crowded at the dome, and quieter and dustier toward the ends of the rows.
The streets and shops are generated, so every bazaar is different.

## The room's character (proposed; agree it before building)

This starts from the atlas brief. The changes are marked.

| Line | Proposed |
|---|---|
| **Feel** | Busy, colourful, rich, the heart of a settlement |
| **Tint** | **Saffron gold.** It comes from daylight on yellow brick, so it is brighter and yellower than the Reading Room's amber lamps and the caravanserai's orange firelight |
| **Light** | **Daylight from above and lamps inside the shops** (change: no lantern strings, which belong to the caravanserai, as we decided for the quarter). A broad beam through the dome's eye, smaller beams through round eyes in the street vaults, a warm lamp inside each open shop. Coloured glass high up throws patches of colour on the floor |
| **Landmark** | The domed crossing (chaharsu): patterned tile and brick, an eye of light, tall arches of red, blue and yellow glass, as in the Tabriz photo |
| **Motion** | Pennants and hanging cloth stirring, steam from food stalls, dust in the beams |
| **Life** | Shops by trade, each with its keeper. Walk into the open ones. People crowd the crossing. A board of rumours to read |
| **Story** | **Crowded and bright at the crossing; shutters, dust and empty hooks toward the row ends.** The dark ends also suit the rule that doorway ends stay dark. A deserted version comes with it (Q6) |

### Neighbours

The Mahaleh would put the bazaar beside the alleys (blue), the gardens (white),
the quarters (dusky rose) and the Bridge Hall (silver mist). None of these is
gold, and all are quieter. The change that matters most is coming out of a dim,
close quarter into the height and colour of the bazaar. The closest colours are
the Reading Room and the caravanserai, so the bazaar should not sit next to
either if we can help it.

## What you'd get

- **The crossing:** 16 × 16 m (change: the atlas says 12 m). The dome rises about
  18 m. The extra size lets an 8 m street meet the crossing on its centre, and
  gives the dome the scale it has in the photo.
- **The streets:** two to four off the crossing, each 4 to 6 bays long (16-24 m)
  (change: the atlas says up to 20 bays, which is 80 m and very unlikely to fit an
  area). 8 m wide between the shop fronts, with about 6 m left to walk once goods
  spill out. Two storeys: shops below, a blind arcade of coloured glass above.
- **The roof:** brick arches across the street with a small dome in each bay,
  an eye in about every third one (change: the atlas draws a plain barrel vault.
  This follows your Tabriz and Kerman photos, Q3).
- **The shops:** 4 × 4 m arched rooms, about half of them open and half shuttered
  (Q1). Seven trades: rugs, copper, lamps, books, spices, curiosities and food
  stalls (Q4).
- **The middle of the crossing:** a fountain or a storyteller's platform, chosen
  by seed, with the rumour board on a pier nearby.
- **Pennants** on lines across the street, as in the Kerman photo, and hanging
  cloth at the rug shops.
- **On the map:** the crossing, the streets and the open shops.
- **Built in walked parts,** as the character guide asks, with captures at each
  part. Route and frame tests once the look is final.

## The steps

1. **The crossing and one street.** New pieces in a `kit_bazaar.blend`: the dome,
   street bays, empty shops, the generator. In a test copy on the Strata Board. You
   can walk the bare space and judge its scale and the dome.
2. **Light and mood.** The beams, coloured glass and its patches on the floor, shop
   lamps, the tint. You can judge the gold, and the balance of light and shadow.
3. **The shops.** Goods, counters and awnings for each trade, shutters, pennants.
   You can walk into each trade.
4. **Life and story.** Keepers and crowd, food stall steam, the rumour board, the
   gradient toward the row ends, and the deserted version (Q6).
5. **Live and tested.** The bazaar grows in its area (Q7), with route audit, frame
   gate, save and resume, and the map. Committed after your walk; the atlas marks
   it as in the game.

## Decisions

| | Question | Recommended | Other options |
|---|---|---|---|
| **Q1** | Which shops can you walk into? | **About half: every open shop,** with no load, as with the homes. Shuttered ones give the rows rhythm and save cost | Every shop (more goods to draw, and no shutters for the story to use); or only two or three, with the rest as shallow fronts (cheaper, but it feels like scenery) |
| **Q2** | What can you do in a shop? | **Look around for now.** The game has no trading yet, so keepers stand at their counters and goods are dressing. The sockets for owner and stock are kept ready | Build simple trading first, as its own phase: a much bigger job than a room, and it needs prices and an economy we haven't designed |
| **Q3** | Which roof for the streets? | **Brick arches with a small dome per bay,** like your photos: it gives each bay its own pool of light | The atlas's plain tiled barrel vault: simpler and cheaper, but less like the references |
| **Q4** | Which trades? | **The atlas's six plus food stalls** (the steam needs them). All seven in every bazaar for now | Add Library trades now, such as a fungus seller stocked from the Terraces. The atlas's mix by faction and stratum waits for those systems either way |
| **Q5** | How busy is it? | **A dense crowd of still figures at the crossing, thinning along the rows,** as with the scholars and the quarter's people. You put moving people and sound later in the project, so "busy" comes from crowding, goods, cloth and steam for now | Simple figures that amble along set paths. This would help the feel the most, but it is new work that every later room would want too |
| **Q6** | Is there a deserted version? | **Yes,** a State setting (Lived in, Deserted) as on the quarter, for the Forgotten City: stalls bare, cloth in rags, glass broken in places, the beams still falling | Leave it for later |
| **Q7** | Where does it grow? | **The Mahaleh,** off an alley, on a test copy (`gen/recipes/drafts/mahaleh/bazaar_test.tres`). The town's market belongs with its homes. One bazaar per area | Its own new area, as part of your themed areas rework |
| **Q8** | Can you climb to the upper storey? | **Not in this version.** The upper arcade is seen from below, like the quarter's roofs | A walkway round the crossing, as in your Tabriz photo: a fine view of the dome, but more routes to test. It could be added later without rebuilding |

## Risks

- **Cost.** This is likely to be the most expensive interior so far, because its
  character is lots of small goods. The quarter already went just over the
  draw-call limit (1,580 against 1,500) with far fewer. Each shop's goods would be
  merged into a few meshes and only drawn nearby, as with the homes' furniture.
- **Lights.** About 30 in a four-street bazaar: the dome, the street eyes, and one
  per open shop with a short reach. Shuttered shops have none. Neighbouring rooms
  add to the count in reach, so it could pass the limit of 50 at the crossing.
- **Fit.** A four-street bazaar is up to 64 × 64 m and the dome is tall. Two
  streets in a line is about 16 × 64 m. Streets will shorten or drop to fit, and
  step 1 gives the first numbers. I haven't yet tested how often it fits.
- **It may not feel busy.** Still figures and no sound are the weakest part of
  this brief. A crowded market with nobody moving could feel frozen, which is why
  Q5 offers the alternative.
- **Coloured patches on the floor.** A coloured light projector is the obvious way,
  but a projector on the garden's sun blacked out its light and we never found out
  why. I'd use painted light patches (decals) instead, so they won't move with
  the sun; the Library's sun doesn't move anyway.
- **The gold could read as the Reading Room's amber.** Step 2 is where to judge it.

## Not included

- Buying and selling, prices, money (Q2).
- Figures that move or talk; voices and crowd sound (Q5).
- Shops changing hands on a return visit. The sockets will be ready, the clock
  comes later.
- Trades by faction or stratum.
- The Tea House (R14), which could later sit in a shop lot.
- The walkway above the shops (Q8).
