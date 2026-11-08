# Progress: the Orosi Scriptorium (R08), phase 17

[Back to the front page](../../../ENVIRONMENT_PLAN.md) · [Approval brief](../phase-17-approval.md)

## Step 2: the hall (built 2026-11-08, walked 2026-11-08: looks good)

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
