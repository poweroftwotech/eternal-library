# Phase 8 design: the gorge redesigned (direction C)

[Back to the front page](../../ENVIRONMENT_PLAN.md) · Brief: [phase-8-approval.md](phase-8-approval.md) ·
Progress: [phase 8](progress/phase-8-gorge-redesign.md) · Look: [`design/gorge-art-direction.html`](../../design/gorge-art-direction.html)

Technical detail behind the brief. Code comments cite these section numbers.

## 8.1 What changes and what stays

The gorge's banks are built by `GorgeGrammar` from tiers (notched rectangles
of 4 m bays, 2–3 storeys), and each tier face picks a module per bay by hash
(`_facade()`). That is the cause of the busy, illogical look. Phase 8 keeps
the **tiers** (they also drive walk planning, frontage slots, keep-out and
the Overlook's west arch: `solid_at`, `ground_at`, `keep_out`,
`tools/gorge_frontage.gd`, `bake_overlook.gd`) and replaces **what stands on
them**: a tier becomes a terrace with houses, carved rooms, a monument or a
garden on it, composed per building, not per bay. Keeping the tier outlines
means no frontage, link or visibility re-bake is forced by the restyle.

## 8.2 The Persian kit

`tools/kit_add_persian.py` → `art_src/kit/kit_persian.blend` →
`tools/export_kit.bat kit_persian.blend` → `kit/modules/persian/` (45 modules,
family `persian`). General pieces any room or area can use; the gorge adds
only the rules that arrange them.

| Group | Modules |
|---|---|
| House walls (edge, one storey) | `persian_wall_{plaster,lime}`, `_window`, `_window_dark`, `_door` |
| Monument walls | `persian_wall_brick`, `_arcade`, `_arcade_dark`, `_orosi`; `persian_plinth`, `persian_crown` (+ `_corner`) |
| Roofs | `persian_parapet` (+ `_lime`, `_corner`), `persian_roof` (cell, walkable) |
| Monuments | `persian_portal` (3 cells, 16 m), `persian_dome` (on a 6 m drum), `persian_minaret` (25 m), `persian_windcatcher` |
| Carved | `persian_carved_door` (+ `_dark`), `persian_carved_window` (+ `_dark`), `persian_iwan_great`, `persian_rock_path` |
| Garden, water | `persian_pool`, `persian_fountain`, `persian_channel`, `persian_bed`, `persian_bed_fungal`, `persian_pomegranate`, `persian_spillway`, `persian_spillway_great` |
| Fungi | `persian_fungus_giant_6`, `_9`, `persian_fungus_small`, `persian_fungus_cluster`, `persian_fungus_jelly`, `persian_glowmoss` |
| Light | `persian_lumen_post` (LIGHT_lumen), `persian_lamp_bracket` (LIGHT_lantern) |

**Construction rules** (learned in step 1):
- Openings are built from boxes round the opening, not booleans
  (`opened()`): below the foot, either side, and the crown over the arch.
- No concave n-gons: an arch's crown, a ring round an arch and a frame's
  spandrels are built from convex pieces (`crown_strips`, `arch_band`,
  `spandrels`). Exported as one face, a crown got a sliver triangle across
  its springing.
- Carved pieces are thick (1.4–8 m) so they bury in the rock; **the rock must
  stay behind their front face** (in step 1's gallery, a cliff in front of
  them hid them). The bank grammar pushes them proud of the local rock.

**Materials** (pixel maps from `tools/pixel_materials_ext.gd` `persian()`;
library in `kit/materials/`): `persian_brick`, `persian_banai` (diamond
lattice of glazed bricks), `persian_plaster` and `_lime` (kahgel),
`persian_stone`, `persian_rock_dressed`, `persian_tile` (faience),
`persian_dome_tile`, `persian_wood`, `persian_soil`, `persian_fungus_cap`,
`persian_fungus_stalk`, `persian_mirror` (metallic aineh-kari), cards
`persian_lattice`, `persian_flowers`, `persian_glowmoss`, `persian_strands`,
uv maps `persian_orosi`, `persian_gills`. Hand-written glows:
`emit_orosi`, `emit_glowmoss`, `emit_strands`, `emit_gills`,
`emit_fungus_jelly`, `emit_interior` (dim, for carved rooms), and
`emit_lumen` / `emit_window_warm` from `PxMaterial.EMIT_COLORS`.

**Tile in four places only** (Q2): portal frame and spandrels, crown frieze,
dome drum and shell, minaret bands. No module puts tile anywhere else.

## 8.3 The town rules (step 2)

A new `PersianTown` grammar (planned: `scripts/gen/persian_town.gd`) runs per
tier face instead of `_facade()`:
1. Split the face into **buildings** of 1–3 bays; each picks a type (house,
   carved, monument front, garden) with weights by height (carved grows
   toward the roof, Q5 about a third) and by distance to the Overlook.
2. A house repeats one opening along its face: plaster or lime, windows lit
   by a cluster noise (lit windows mean someone lives there), a door on the
   storey that meets a terrace, a parapet on its roof, sometimes a
   windcatcher, pots or a carpet.
3. At most one monument per view: portal, arcade, crown, dome behind.
4. Every deck has a route: a stair (`chasm_stair_flight`) or rock path to
   the deck above, a door onto it.
5. Gardens on the widest decks, by light (8.4).
6. Module names keep a prefix in `GorgeScenery.REMOVABLE` (add `persian_`
   facade prefixes there) so batches still clear behind galleries.

## 8.4 Light decides what grows

`lightAt(p)` in the rules: **sun** under a `LightShaft`
(`scripts/world/light_shaft.gd`, a shadowless spot whose beam shows in the
volumetric fog plus a cone of haze) or near the sanctum's glow; **gem** within
a lumen stone's radius; otherwise **dark**. Sun and gem places get
`persian_bed`, cypress (`gorge_cypress_*`), `persian_pomegranate`; dark places
get `persian_bed_fungal`, giant and jelly fungi, glow moss on the rock.
Light profiles in `tools/kit_import.gd`: `lumen` (warm white, 14 m) and
`fungus` (teal, 5 m), neither casting shadows.

## 8.5 Great falls

`GreatFall` (`scripts/world/great_fall.gd`, @tool): two bent ribbons (core and
a wider veil, about 900 triangles), a mist `FogVolume`, a shadowless spray
light. `shaders/great_fall.gdshader`: an opaque core whose streaks speed up
as the water falls (sqrt of the fall distance), two noise layers half a cell
apart (one layer banded across the sheet), a ragged lower third, a bright lip;
`fog_disabled` (volumetric fog's depth slices banded the arcing sheet) with
its own distance haze (`fog_tint`, `fog_far`). It pours from a
`persian_spillway_great`'s `ANCHOR_fall`.

## 8.6 Budget

Step 1's gallery (every piece, 17 vignettes' worth) draws about 20,000
triangles and 150 draw calls in its widest view at under 1.2 ms GPU on the
RTX 5090. Bank 1's numbers are measured in step 2 with the frame gate and
`tests/report_capture.gd` from the Overlook; middle-distance merging
(step 4) only if needed.

## 8.7 The camp's front (step 3)

What you see of "the camp" from the gorge is not in `rooms/camp/camp.tscn`:
the pishtaq is `vista_cliff.gd` `iwan()` / `iwan_dressing()`, the loggia rock
`vista_cliff.gd` L149-163, the balcony terrace `vista.gd`
`build_balcony()` / `balcony_details()`, all baked into
`rooms/baked/gorge/generated.scn`, and the facades round it
`GorgeGrammar.cliff(FACADES)` in `cliff.scn`. Step 3 rebuilds these from the
Persian kit (portal, arcade, crown, parapets, a lumen-lit terrace garden) and
re-bakes; the camp interior is unchanged.
