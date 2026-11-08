# Progress: the Orosi Scriptorium (R08), phase 17

[Back to the front page](../../../ENVIRONMENT_PLAN.md) · [Approval brief](../phase-17-approval.md)

## Step 4: life and story (built 2026-11-08, walked: looks good)

Walk it from the Strata Board, in the Grand Study:

- copy `scriptorium_test`, Walk this seed: the tended scriptorium;
- copy `scriptorium_forgotten`, Walk this seed: the Forgotten version.

Seeds 1, 2 and 5 are four, three and five bays long. On a desk, look at the
copy and press E to read it.

Pictures: `previews/phase17_step4/`. Tended, seeds 1, 2 and 5:
`r08_hall_<seed>_door|middle|side|up|back|copyist|far.png` (`far` is the last
row's desk close up, under dust). Forgotten, seeds 1 and 5:
`r08_hall_forgotten_<seed>_<view>.png`.

- **Busy to abandoned.** Walking from the door to the glass:
  - the lamplit rows are busy: copyists at most desks (four in five), the
    copies under way;
  - the first row past the lamps is left half done. The cushions are pushed
    back, the pens and a sheet lie on the floor, and at most one copyist is
    still at work;
  - beyond it, the desks are under dust: grey dust over the desk, the pages and
    the cushion, more sheets on the floor, and a cobweb from the book stand.
- **Copies you can read** (Q5). Every desk has a copy; E reads it.
  - The title names the text and whose hand it is in, from ten copyists.
  - All the desks in a row copy the same text, and the desks beside each other
    disagree in one word. For example, one says a book in the dark is "only
    paper", the next that it is "still a book".
  - A busy copy breaks off with the ink still wet. A copy left half done stops
    mid-line, long dry. A dusty one is finished and signed but was never
    collected.
  - Six texts and ten names, all placeholders for you to replace or approve.
- **The moss breathes** (Q8). The glow behind the glass swells and fades over
  about half a minute, and the glass, its coloured patches, its glow on the hall
  and the moss light swell with it, about a fifth either way. The desk lamps'
  flames flicker.
- **The Forgotten version** (Q7) is the room's State setting on the board
  (Tended or Forgotten).
  - No copyists, and every desk is under dust.
  - The lamps are cold: still on the desks, with no flame.
  - The moss is at 40%, so the glass glows faintly over a dark hall.
  - It goes into the Forgotten Wing in step 5.

### For you to judge

- Where it turns: the abandoned part starts at the first row past the lamps.
  Earlier, later?
- The dust: too grey, not enough? The cobwebs?
- The copies' texts and the copyists' names (placeholders).
- The swell: enough to notice, too much?
- The Forgotten hall: too dark?

### Pieces

- `tools/kit_add_r08.py`: `sc_copy_desk_left`, `sc_copy_desk_dust`,
  `sc_copy_desk_dust_lamp` (`copy_desk(lamp, state)`); the dust material
  `sc_dust` (`tools/pixel_materials_ext.gd -- scriptorium`, `kit/materials/sc_dust.tres`).
- `scripts/world/scriptorium_copy.gd` (`ScriptoriumCopy`, the texts and names),
  module `gen/modules/sc_copy.tscn`.
- `scripts/gen/scriptorium_life.gd` (`ScriptoriumLife`: the swell and the lamp
  flicker), module `gen/modules/scriptorium_life.tscn`; the glass shader's
  `swell` instance uniform.
- `ScriptoriumGrammar`: the story in `_place_desks`, `forgotten` and the State
  setting; `tools/make_r08_rules.gd` writes 20 rules and both test copies.
- `tests/r08_hall_capture.gd -- <out dir> [seeds] [draft]` (new `far` view).

### Checked

- Seed 5: all 20 copies are found by the look ray from in front of their desks,
  and their texts disagree as above.
- The swell moves the window lights (tended about 9.7 to 10.0 over 8 s; the
  Forgotten version at 40%).

No route, frame or save tests yet (step 5).

## Step 3: desks, copyists and lamps (built 2026-11-08, walked: looks good; committed 010cfce)

Walk it the same way: the Strata Board, the Grand Study, copy
`scriptorium_test`, Walk this seed. Try a few seeds (1, 2 and 5 are four, three
and five bays long).

Pictures: `previews/phase17_step3/`, seeds 1, 2 and 5:
`r08_hall_<seed>_door|middle|side|up|back|copyist.png` (`copyist` is one
kneeling figure close up).

- **The desks:** rows of low copy desks on the rugs, two each side of the
  aisle, a row every 3 m from 3 m inside the door to at least 1.2 m short of the
  glass. Each desk has a rahl (the crossed book stand) holding an open exemplar,
  the half-written copy and fresh sheets, an ink pot, a pen box and pen, a pile
  of scrolls beside it and a termeh cushion to kneel on.
- **The copyists:** robed and hooded, kneeling at the desks and facing the
  glass. Most bend over the copy writing; about one in three sits up reading a
  sheet. Most desks near the door have one, about a third of the far desks do
  (step 4 turns this into the busy-to-abandoned walk).
- **The lamps:** a small brass oil lamp with a flame on the aisle-side desk of
  each row in the near half only, so the door end is lamplit and the far half
  is lit only by the glass. No lamp within a bay of the glass. Four lamps in a
  four-bay hall, six in a five-bay one.
- **Dust:** faint motes drifting in front of the glass. They take the light
  they float in, so they show in the coloured patches and fade in the dark.

### Fixed before your walk

- The copyists' robes used a hanging-cloth material that is see-through in
  places, so only the hoods showed. They now use the solid robe cloth the
  Fungus Terraces' workers wear.
- The first dust was too bright (specks showed against the dark ceiling);
  it's now smaller and fainter.

### For you to judge

- The desks: how closely packed? Too regular?
- The copyists: how many, and do the kneeling figures read well?
- The lamps: is the door end bright enough, too bright?
- The dust: visible enough, too much?

### Pieces

- `tools/kit_add_r08.py`: `sc_copy_desk`, `sc_copy_desk_lamp` (with the
  `LIGHT_desk__copy` marker), `sc_copyist_write`, `sc_copyist_read` (rev 2).
- `ScriptoriumGrammar._place_desks`; rules `sc:desk`, `sc:desk_lamp`,
  `sc:copyist_write`, `sc:copyist_read` in `tools/make_r08_rules.gd`.
- `OrosiWallSetup._dust()` (the `dust` switch).

### Not tested yet

The pictures show no errors. No route, frame or save tests yet (step 5). The
desk rows stand on cell centres, so the route audit may need those cells marked
as blocked; that's checked in step 5.

## Step 2: the hall (built 2026-11-08, walked: looks good; committed e500fd7)

The bare hall, grown by its generator. Walk it from the Strata Board: the Grand
Study, copy `scriptorium_test`, Walk this seed
(`gen/recipes/drafts/grand_study/scriptorium_test.tres`: the scriptorium is the
first room, with the door back to the Gorge in its entry, and two short stack
galleries off its side doors). Try a few seeds: the length and the glass change.

Pictures: `previews/phase17_step2/`, five views for seeds 1 (four cells, saffron
and green), 2 and 11 (three cells, ruby and cobalt):
`r08_hall_<seed>_door|middle|side|up|back.png`.

- **The hall:** 12 m wide, 6.4 m high, three to five 4 m bays long by seed (Q2).
  The orosi wall closes the far end; the glass palette is picked by seed (Q3).
- **The walls:** cream lime plaster. Each bay has two small pointed niches at
  chest height and a wide one above them (the atlas's taqcheh), a dark wood
  cornice under the ceiling and a low wood skirting.
- **Doors:** the entry in the middle of the near wall, and a door in the second
  bay of each long wall when the area can grow there, each in the kit's 3 m
  arch with a wood frame and a small niche over it. Never through the glass.
- **The ceiling:** dark timber planks with three beams across each bay.
- **The floor:** the kit's stone, with grand rugs (one design per room, by
  seed) down either side of a bare aisle; the window light falls on them.
- **Behind the glass:** the moss garden, kept out of the area: two cells deep and
  three storeys high behind the far wall, not walked and not on the map.
- **Lights:** the step 1 five (the three window lights with shadows, the glow,
  the moss). Nothing else yet, so the door end is dark (the desk lamps are step 3).

### For you to judge

- The walls: are the niches the right size and number? Too plain?
- The ceiling and the cornice: dark enough, too dark?
- The rugs: the grand rugs either side of an aisle, or one carpet wall to wall?
- The hall's length: three to five bays feel right?

### Pieces

- `tools/kit_add_r08.py`: `sc_niche_wall_4m`, `sc_door_wall_4m`, `sc_ceiling_12m`.
- `scripts/gen/scriptorium_grammar.gd` (`ScriptoriumGrammar`).
- `tools/make_r08_rules.gd` writes `gen/modules/sc_orosi.tscn` (the wall, the
  garden and the glass setup; the palette comes from the generator),
  `gen/rules/r08_scriptorium.tres`, `gen/grammars/r08_scriptorium.tres` and
  the test draft.
- `OrosiWallSetup` takes its palette from the module's `palette` meta.
- `tests/r08_hall_capture.gd -- <out dir> [seed,seed,...]` takes the pictures.

### Not tested yet

The layout check passes (no unreachable or unmarked cells) and the pictures
show no errors. No route, frame or save tests yet (step 5), and the scriptorium
only grows as the test copy's first room, so how often it fits off other rooms
is still to measure (step 5). The palette doesn't yet avoid ruby next to the
red hall (Q3); that comes when it grows next to it.

## Step 1: the orosi wall and its light (built 2026-11-08, walked and committed 2026-11-08)

A small test room. Walk it from the Strata Board: the Grand Study, copy
`scriptorium_glass`, Walk this seed (`gen/recipes/drafts/grand_study/scriptorium_glass.tres`,
just this room, with the door back to the Gorge in its doorway). Or straight from
the command line:

```bash
cd /c/projects && ./Godot_v4.7.2-stable_mono_win64_console.exe --path C:/projects/eternal-library -- --room=res://rooms/test/scriptorium_glass.tscn
```

Pictures: `previews/phase17_step1/`, five views for each of the three palettes
(`r08_<palette>_door|middle|floor|close|back.png`).

- **The wall:** 12 m of plaster with three tall pointed orosi windows, the middle
  one widest (3.2 m, 5.15 m tall). Each has a wooden sash (a frame round the
  arch, a transom where the arch springs, two mullions and a meeting rail) over
  pixel-art glass: diamond panes in rings in the lower sash, a sunburst in the head.
- **Three palettes,** chosen by seed later: ruby and cobalt, saffron and green,
  the full spectrum.
- **The coloured light:** each window has a light standing high over the moss
  garden, aimed through it, carrying a picture of that window as seen from the
  light. On the floor and desks the patches are the window's own panes: the sash
  lands close under the window and the sunburst stretches from about 2 m to 5.5 m
  into the hall, as light from a high source through a tall window would. All three
  window lights cast shadows (the desks throw them).
- **The glow on the hall:** one soft light low in front of the middle window,
  tinted with the palette's colours, so the far end is dim rather than black and
  the walls near the glass take its colour.
- **The moss garden behind:** a narrow rock slot with warm glowing moss and a
  lumen stone up where the window lights stand. The glass lets a little through,
  so it shows only faintly.
- **Lights:** five (three window lights, the glow, the moss's own fill). Three with
  shadows (the window lights; they stay out of the shadow budget, see below).

### Stand-ins (not what the room will look like)

The long walls are the kit's brick, the ceiling is plain planks and beams, and
the desks are plain boxes. The plaster niche walls, the timber ceiling and real
desks come in steps 2 and 3. There are no desk lamps yet, so the door end is dark.

### For you to judge

- Do the patches read as stained-glass light? Too strong, or not strong enough?
- Does the glass look precious, or too bright and flat?
- Which palette, if any, you'd drop.
- Should you see more of the moss garden through the glass?

### Found on the way

- Godot's spot light falloff setting works backwards from what its name suggests:
  a small value keeps the light even across the cone. The window lights use 0.05.
- Godot spreads a spot light's picture across the light's whole cone, so each
  light's cone is opened just wide enough to take in its window's corners.
- **Fixed after your walks** (reports 2026-11-08_00-42-40 and 00-49-34 to
  00-50-10, a coloured patch that appeared, vanished and followed you): Godot 4.7
  doesn't keep a shadowless spot light's picture in place. It was drawn with
  placement left over from earlier frames, so the same spot showed a different
  patch (or none) depending on where you had just been. Now every window light
  casts shadows, always (`OrosiGlass.apply` marks them `shadow_always`, and
  `LightBudget` leaves those out of its ranking so a far one never loses its
  shadow). Checked by walking your steps in three different orders: the same
  picture each time. Cost: GPU 1.0-1.2 ms on those views. The window lights also
  lost their highlights (glass light is diffuse); that alone didn't fix it.

### Pieces

- `tools/kit_add_r08.py` writes `art_src/kit/kit_scriptorium.blend`:
  `sc_orosi_wall` (rev 2), `sc_moss_garden`.
- `scripts/gen/orosi_glass.gd` (`OrosiGlass`): the glass patterns and palettes,
  each window light's picture and cone, and `apply()` to put a palette on a wall.
  `scripts/gen/orosi_wall_setup.gd` applies one when a room starts.
- `tools/r08_glass.gd` draws the glass, its materials and the light pictures
  (run after exporting the kit, then import). `shaders/sc_orosi_glass.gdshader`.
- Light profiles `orosi`, `orosi_bounce`, `lumenmoss` in `tools/kit_import.gd`.
- `tools/build_r08_test.gd` builds `rooms/test/scriptorium_glass.tscn`;
  `tests/r08_glass_capture.gd -- <out dir> [palette|all]` takes the pictures.

### Not tested yet

Only a headless run of the test room (no errors) and the GPU pictures. There are
no route, frame or save tests for a test room; they come with the real hall.
