# Art direction: closing the gap to the concept (start here)

**Target image:** `design/Campfire in the Eternal Library.png` (AI-generated concept).
**Baseline:** `design/Eternal_Library_Campfire_v0.8.png` (the engine before v0.11).
**Current milestone:** v0.11, "pixel materials + light hierarchy", started 2026-10-17.

Aim to match how the concept *reads*: the texel scale, the brightness order,
the warm/cool split and the prop density. Pixel-perfect parity is not the goal.
The concept's lighting looks path-traced, so real-time Forward+ will
approximate it.

---

## 1. Diagnosis (why v0.8–v0.10 didn't look like the concept)

| # | Gap | Evidence |
|---|-----|----------|
| 1 | Textures were too fine and too smooth to read as pixel art | Legacy maps are 256 px Perlin-like gradients (sandstone has about 2,900 colours) at about 130 texels/m. The concept is about 32 texels/m, with each texel one flat colour from a small palette. |
| 2 | No light hierarchy | Mean luminance (0–255) in the concept vs v0.8: garden 101 vs 64, left foreground 44 vs **13**, whole frame 56 vs 41. Glow threshold was 1.5 at intensity 0.45, so nothing bloomed. |
| 3 | Hero props are code primitives | Box logs, ball stew, thin brick piers. Ten iterations of procedural GDScript have plateaued. |
| 4 | Composition | The concept camera sits low and close on the hearth. It has bookcase + ivy + lantern on the left and a bedroll + pack on the right. |
| 5 | HUD style | The concept uses mono caps, diamond-ended hairlines, `— 1 —` slot numbers, a `+` crosshair and an `[E] Cook` prompt next to it. |
| 6 | Misleading previews | Captures waited 12 frames on software Vulkan (llvmpipe), so volumetric fog and SSIL had not converged. |

## 2. The rules (keep these when adding anything)

1. **32 texels per metre on every surface.** World-mapped materials use
   `uv1_scale = 32 / tile_size`. UV-mapped assets (lathe pottery, the rug
   plane, future Blender meshes) must be unwrapped and painted at the same
   density. One texel is about 3 cm.
2. **Palette-limited albedo.** Use 6–10 colours per material and quantise with
   light ordered dithering. Bake shape into the albedo: mortar joints, a
   one-texel lit bevel at top/left and a shadow bevel at bottom/right, chips
   and motifs. Albedo stays fairly neutral; the lights supply warmth.
3. **Filtering:** `NEAREST_WITH_MIPMAPS_ANISOTROPIC`. Import pixel maps
   *lossless* with mipmaps and `detect_3d/compress_to=0`. VRAM compression
   smears palette colours.
4. **Brightness hierarchy:** garden (hero) > fire/lanterns (bloom) > firelit
   foreground > teal archive. Never let the foreground go black. Measure it
   (section 4).
5. **Grade:** teal shadows, amber highlights (split-tone curve in
   `art_direction.gd`), saturation ×1.12.
6. **Lighting is modern, texels are retro.** Detail comes from light, haze and
   bloom, not from higher-resolution textures.

## 3. What v0.11 changed

| File | Change |
|------|--------|
| `tools/pixel_materials.py` | **New.** Generates 23 pixel-art materials (albedo + per-texel normal + roughness) into `assets/textures/px/` with a `manifest.json`. Generators: `ashlar`, `flagstones`, `mottled`, `mosaic`, `iron`, `wood`, `bark`, `pottery`, `kilim`. Run `python tools/pixel_materials.py`. |
| `assets/textures/px/*.png.import` | Lossless, mipmapped, no 3D VRAM compression; normal maps are flagged. If you add a material, run the editor import once, then apply the same edits (see section 6). |
| `scripts/asset_factory.gd` | `USE_PIXEL_MATERIALS` (set `false` to A/B against v0.10). `apply_pixel_maps()` swaps in px maps, enforces texel density and sets anisotropic nearest filtering. Legacy maps are untouched. |
| `scripts/art_direction.gd` | **New.** Final look pass: AgX tonemap, exposure, ambient, glow levels, split-tone LUT, garden key light (energy, aim, haze), lightwell glow, fire and ember bloom, left-foreground fill, texel-density enforcement on duplicated materials. **Every tuning number is a constant at the top of the file.** `USE_SDFGI` toggles real bounce light. |
| `scripts/world.gd` | Calls `art_direction.gd` after `organic.build()` and before merging and atmosphere. |
| `scripts/atmosphere.gd` | Fire, garden energy and aim come from light metadata (`base_energy`, `aim`) instead of hard-coded 2.75 / 26.0 / aim point. |
| `scripts/hud.gd` | Concept-style HUD: non-antialiased monospace via SystemFont (Consolas on Windows). Drop an OFL pixel font at `assets/fonts/ui.ttf` to override. Uses a container-based header, a `Rule` class (hairline + diamonds), numbered slots with corner counts, a `+` crosshair and an `[E] …` prompt beside it. |
| `scripts/main.gd` | Spawn and field of view now match the concept framing. |
| `tests/capture.gd` | New `concept` mode (camera framed like the concept). Settle frames default to 90 (third user arg overrides). |
| `tools/compare_concept.py` | **New.** Region luminance and warmth vs the concept, plus a side-by-side/overlay sheet. |
| `tools/capture_concept.bat` | **New.** One double-click renders the `concept` and `garden` views on the real GPU and runs the comparison. |
| `project.godot` | Anisotropic filtering 8× (level 3); version 0.11.0. |

## 4. Verification status (be honest about this)

- PASS: headless import, a 240-frame headless run and `tests/playtest.gd`
  (43 gameplay checks) on Godot 4.6.1 Linux. No script errors.
- Visual check so far was **Compatibility renderer only** (software GL in the
  cloud). It validates textures, framing and HUD. It does **not** validate
  volumetric fog, SSIL, glow or the Forward+ lighting balance. The cloud
  container cannot run Vulkan.
- **GPU tuning pass done (2026-10-17, Godot 4.7.2 Forward+, RTX 5090).**
  All six regions are within ±15% of the concept (table below). Headless
  240-frame run is clean, and `tests/playtest.gd` passes all 43 checks on 4.7.2.
  - The first GPU capture rendered every px surface **white**: the
    `assets/textures/px` imports had never run on this machine. Always run
    `godot --headless --import` first; `capture_concept.bat` now does.
  - Python isn't installed on the dev machine, so `tests/compare_concept.gd`
    is a Godot port of `compare_concept.py` (same regions and ±15% gate):
    `godot --headless --script res://tests/compare_concept.gd -- <capture.png>`.
  - Constants changed (old → new): `EXPOSURE` 1.25 → 1.0,
    `GARDEN_KEY_ENERGY` 42 → 17, `GARDEN_KEY_COLOR` ffe1ad → fff1d6,
    `GARDEN_FOG_ENERGY` 2.4 → 1.3, `GARDEN_HAZE_SCALE` 3 → 2,
    `LIGHTWELL_GLOW` 5 → 3.5, `FIRE_ENERGY` 4.2 → 1.6, `EMBER_GLOW`
    4.5 → 2.6, fire bounce 1.3 → 0.5, back-gallery light 3.2 → 2.0 (more
    neutral colour), left fills ×1.12, and a new `archive_fill()` teal light
    (`ARCHIVE_FILL_ENERGY` 1.6).

| region | concept | v0.11 GPU (before → after) |
|---|---|---|
| whole frame | 56 | 90 → **64** |
| garden (hero) | 100 | 181 → **108** |
| hearth + pot | 69 | 117 → **73** |
| left foreground | 44 | 46 → **40** |
| right archive | 41 | 39 → **38** |
| rug / right floor | 51 | 76 → **50** |

- **Warmth pass done (2026-10-17).** The split-tone mid/highlight stops are
  now neutral (amber lean removed, teal shadows kept). The garden key, back
  and crown lights, garden haze, fog albedo and lightwell glass shifted to
  green-neutral. `AMBIENT_COLOR` changed 6f8a8c → 5a86a6, the archive fill is
  blue (2c74e6, energy 2.1), the back-gallery light dropped 2.0 → 1.7 and the
  left fill went 1.8 → 2.0. Luminance still passes in all six regions.

| region | warmth (R−B) concept | before → after | luminance ratio |
|---|---|---|---|
| whole frame | 35 | 51 → **42** | 1.14 |
| garden (hero) | 17 | 48 → **20** | 1.08 |
| hearth + pot | 70 | 86 → **79** | 1.04 |
| left foreground | 47 | 56 → **56** | 0.89 |
| right archive | −29 | −6 → **−18** | 0.88 |
| rug / right floor | 50 | 55 → **55** | 0.97 |

  The archive gap that remains is **framing, not colour**. Our camera puts
  the warm stone pier inside the archive box (x 0.81–0.90), where the
  concept shows open blue archway, so bluer light only turns the shelves
  cyan. This closes with the recomposition work (backlog 5). Left foreground
  luminance (0.89) and archive luminance (0.88) are close to the lower
  bound, so don't lower `EXPOSURE` further. SDFGI is still untried.
- **After the material pass (backlog 2):** whole frame 1.14, garden 1.09,
  hearth 1.03, left 0.88, archive 0.87, rug 0.98, so all six regions still
  pass. Headless 240-frame run clean, playtest 43/43, geometry audit 29/29.

Luminance targets from the concept (0–255), with the v0.8 baseline in brackets:
whole frame 56 [41] · garden 100 [64] · hearth + pot 70 [63] · left foreground
44 [13] · right archive 41 [38] · rug / right floor 52 [18]. The concept is warm
everywhere except the archive (red minus blue: about +50 foreground, −29
archive).

## 5. Backlog (in order of value per effort)

1. ~~Tune lighting on GPU~~ (luminance and warmth done, see section 4).
   Remaining: try `USE_SDFGI = true`, then re-run the gate.
2. ~~Cover the remaining materials in pixel style~~ **Done 2026-10-17**
   (18 materials, generated by `tools/pixel_materials_ext.gd`, which runs in
   Godot without Python):
   - World triplanar at 32 texels/m: `mushroom`, `root` (ring grooves),
     `fruit_skin`, `pomegranate`, `cut_fruit` (seed specks), `copper`
     (verdigris specks), `brass` (no longer flat colour), `vine`, `cloth`
     (wool weave), `linen` (striped bedroll weave, no longer the rug map),
     `book_leather`, `pages`, `stack_atlas` (2 m book wall: shelf every
     0.5 m, 1–3-texel spines) and `exterior_faience` (cobalt/turquoise
     tesserae).
   - `gorge_pier` and `gorge_background` duplicate `exterior_faience` and
     `stack_atlas`, so they inherit the px maps; `enforce_texel_density`
     resets their scale to 32 texels/m.
   - Foliage cards: `ivy_leaf`, `tree_leaf` (16×16), `leaf` (8×16), `fern`
     (16×32), using 5 greens, a lit top-left rim and a midrib. **Exception to
     rule 1:** cards are 0.10–0.21 m wide, so at 32 texels/m a leaf would be
     about 5 texels and unreadable. They are authored at about 64 texels/m.
     The `card` mapping keeps each material's tint, alpha scissor and
     backlight.
   - `book_leather` is multiplied by each book's vertex colour, so its map
     keeps the legacy mean (≈151,124,92) at low contrast. A brighter, neutral
     first attempt bleached the archive books cyan and made the grain bridge
     across neighbouring books.
   - Still on legacy maps: `soup` (flat), the far-vista `gorge_books` alpha
     shelves, tapestries, `wing_relief`, `library_facade`, `lit_window`, and
     the flame/steam/dapple effect cards.
3. ~~Architecture massing~~ **Done 2026-10-18.**
   - Arch dimensions now live in one place, `world.arch_specs`
     (`[pose, radius, spring, rise, thickness]`); `benchmark_pass.masonry()`
     and `interior_pass` (surrounds, imposts, arch vine) read it. Springing
     dropped 3.0 → 2.6 m and rise went 4.5 → 5.0 (garden) and 3.65 → 4.1
     (archive), so both apexes are visibly pointed. Jamb face stones and
     imposts follow the springing. The existing mosaic spandrels now show.
   - The piers are sandstone ashlar (no longer plaster), and the narrow
     0.55 m tile strip is gone.
   - New `scripts/arch_pass.gd` (after `camp_composition`). The centre pier
     (the concept's hero pier) gets projecting base, impost and cornice
     courses, a raised limestone frame, and a full-height inset `mosaic`
     panel (0.78 × 5.6 m) with brass fillets. Ivy clumps run along both arch
     heads (t 0.45–1.0), strands hang into the openings, and strands trail
     down the pier edges.
   - The centre-pier tapestry moved to the camp's back wall (the playtest
     needs at least 6 framed hangings).
   - The left and right piers are already covered by full-height shelving
     (`library_dressing`), so only the centre pier gets a panel.
   - Gate: all six regions pass. Playtest 43/43, geometry audit 29/29.
   - **Exit leak fixed (2026-10-18):** headless runs sometimes ended with
     `ERROR: 2 resources still in use at exit` (pre-existing, 1/10 without
     `arch_pass` and up to 4/6 with it). Verbose showed the looping music's
     Ogg playback still held by the audio thread at quit. `main.gd` now
     skips `audio.play()` when `DisplayServer.get_name() == "headless"`; the
     stream still loads, so the music tests apply. The 240-frame gate is now
     clean in 10 of 10 runs. (Stopping and nulling the stream in
     `_exit_tree` did not help.)
   - `tests/atmosphere_test.gd` hearth-flicker bounds are now relative to
     the tuned `FIRE_ENERGY`. The old absolute `low > 1.5` assumed a base of
     2.75 and had been failing since the luminance pass cut it to 1.6. All
     9 checks pass (energy 1.26–1.97).
4. **In progress (2026-10-18): fire logs and stew done.** Blender 5.2.2 LTS
   (portable: `C:\projects\blender-5.2.2-windows-x64\blender-5.2.2-windows-x64\blender.exe`)
   runs `tools/build_props.py` headlessly →
   `assets/models/{fire_logs,stew}.glb`. Surfaces carry material *names*
   (`bark`, `log_end`, `char`, `stew`); `asset_factory.model()` splits the
   surfaces and swaps in the px materials, so props stay world-triplanar at
   32 texels/m and merge normally. Export must use `export_materials="EXPORT"`
   (PLACEHOLDER drops the names) and needs a UV layer for tangents. The
   hearth ring's front stone was removed so a log shows through, like the
   concept. `GARDEN_KEY_ENERGY` went 17 → 15 to keep the whole frame inside
   ±15%. Next: cauldron, ladle, lantern, bowls, bedroll/pack as meshes, and
   particle flames.
   Original brief: **Hero props as authored meshes** (Blender → glTF in `assets/models/`,
   textures painted at 32 texels/m): cauldron + stew surface, fire logs,
   lantern, three ingredient bowls (mushrooms, roots, herbs), bedroll,
   leather backpack, ladle, cup, book stacks, bookcase with ladder. Keep
   procedural generation for repeated clutter. Replace the hex-box logs and
   the ball stew first; they read worst. Fire: GPUParticles3D flipbook flames,
   embers and soft steam.
5. ~~Recompose the camp to the concept~~ **Done 2026-10-17** in the new
   `scripts/camp_composition.gd` (runs after `benchmark_pass`, before
   `organic`). Placements come from `tests/frame_probe.gd`, which casts
   concept screen landmarks onto our floor from the `concept` camera:
   `godot --headless --script res://tests/frame_probe.gd -- u,v,y ...`.
   - Removed all six camp jars (`world.gd`, `benchmark_pass.gd`,
     `set_dressing.gd`).
   - Left side: a bookcase angled to camera (2.4 × 4.5 m) at (−6.1, 1.7),
     with a ladder and hanging ivy; a lantern on a book stack; and a
     turquoise planter with a leafy shrub (solid collision).
   - The rug moved back to `world.rug_center` (2.0, 4.9); the fringe and the
     flat under-rug paving follow it. The striped bedroll, a leather pack
     (solid), a blanket roll and the copper cup sit on the rug where the
     concept puts them.
   - Archive: three clusters of blue glowing mushrooms, each with a small
     cyan light. Glow emission is 1.1, because 2.4 bloomed into blobs.
   - Gate after recomposition: all six regions pass (whole 1.15 and archive
     0.86 sit at the edges). Playtest 43/43, geometry audit 29/29, headless
     run clean.
   - Not done: the concept's tall mosaic column at the lower-left edge. Our
     provision slab fills that spot, and a column there landed off-frame, so
     it would need the slab reworked first. The stream and cascade through
     the arch are also missing, because the pot hides that part of the
     garden from this camera. Left-foreground warmth is now 68 vs the
     concept's 47, mostly from the two lanterns; trim
     `LANTERN_FLAME_GLOW` if it reads too orange.
6. **HUD polish:** a real OFL pixel font (VT323 or Silkscreen, about 100 KB)
   at `assets/fonts/ui.ttf`, and pixel-art item icons in place of the SVGs.

## 6. How-to

- **Regenerate pixel maps:** `python tools/pixel_materials.py`, then open the
  editor once to import. For *new* files, edit each
  `assets/textures/px/<name>.png.import`: `mipmaps/generate=true`,
  `detect_3d/compress_to=0`, and `compress/normal_map=1` for `_normal`.
- **Regenerate part-2 maps (no Python):**
  `godot --headless --path . --script res://tools/pixel_materials_ext.gd`,
  then `godot --headless --path . --import`. The import files for the
  current set are already flagged; new names need the same three edits.
  Its `manifest_ext.json` is merged over `manifest.json` by `asset_factory.gd`.
- **A/B the old look:** set `USE_PIXEL_MATERIALS = false` in
  `asset_factory.gd` and/or comment out the `art_direction.gd` line in
  `world.gd`.
- **Capture:** double-click `tools\capture_concept.bat`, or run
  `godot --path . --script res://tests/capture.gd -- <abs.png> concept 120`.
- **Compare:** `python tools/compare_concept.py previews/concept_v011.png`.
