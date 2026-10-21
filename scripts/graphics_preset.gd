class_name GraphicsPreset
extends RefCounted
## A stand-in for the graphics settings slice (architecture.md 8.2): applies
## the rendering values of a named preset, so the frame gate can measure at
## the base spec's Medium (phase-4-design.md 8.1.8 step 3). `-- --preset=medium`
## in the game; "high" is the project's own settings. Never changes the look's
## art direction, only quality caps.

const PRESETS: Dictionary = {
	"medium": {"shadow_atlas": 4096, "soft_shadows": RenderingServer.SHADOW_QUALITY_SOFT_LOW, "gi_half": true, "msaa": Viewport.MSAA_DISABLED, "fxaa": true},
	"high": {"shadow_atlas": 8192, "soft_shadows": RenderingServer.SHADOW_QUALITY_SOFT_HIGH, "gi_half": false, "msaa": Viewport.MSAA_2X, "fxaa": false},
}


## The preset named on the command line (`--preset=<name>`), or "".
static func requested() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--preset="):
			return arg.trim_prefix("--preset=")
	return ""


## Applies `preset_name` to `viewport` and the renderer. Returns false for an unknown name.
static func apply(viewport: Viewport, preset_name: String) -> bool:
	if not PRESETS.has(preset_name):
		return false
	var p: Dictionary = PRESETS[preset_name]
	viewport.positional_shadow_atlas_size = p["shadow_atlas"]
	viewport.msaa_3d = p["msaa"]
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if p["fxaa"] else Viewport.SCREEN_SPACE_AA_DISABLED
	RenderingServer.positional_soft_shadow_filter_set_quality(p["soft_shadows"])
	RenderingServer.gi_set_use_half_resolution(p["gi_half"])
	return true
