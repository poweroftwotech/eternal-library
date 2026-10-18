extends SceneTree
## 16x16 pixel-art inventory icons (ART_DIRECTION.md backlog 6).
##   godot --headless --path . --script res://tools/pixel_icons.gd
## Writes assets/ui/icon_<name>.png. hud.gd shows them at 3x with nearest
## filtering and falls back to the old SVGs when a PNG is missing.

const OUT: String = "res://assets/ui/"

const PALETTE: Dictionary = {
	"o": "1a120c",                                   # outline
	"3": "4a2f1c", "5": "8a5a36", "4": "c49a6c",      # mushroom cap
	"6": "b8a684", "7": "e8dcc0",                     # stems, pale root
	"a": "c8a06a", "b": "e6c88c",                     # amberroot
	"g": "3e5a22", "G": "6a8a34", "L": "9ab84c",      # greens
	"p": "8a4a8a", "P": "c07ac0",                     # herb flowers
	"r": "6a2418", "R": "9c3a22", "y": "c8913f", "c": "efe0b8",  # journal
}

const ICONS: Dictionary = {
	"mushroom": [
		"................",
		".....oooooo.....",
		"...oo555555oo...",
		"..o5554455555o..",
		".o555555555445o.",
		".o544555555555o.",
		"o55555555555555o",
		"o33333333333333o",
		".oooo677776oooo.",
		"....o677776o....",
		"....o677776o....",
		"....o677766o....",
		"....o677766o....",
		"...o66777766o...",
		"...oooooooooo...",
		"................"],
	"root": [
		"..........o.o...",
		".........oLoLo..",
		"........oGLGLo..",
		".......ooGGGo...",
		"......obbooo....",
		".....obbaao.....",
		"....obbaao......",
		"....obaaoo......",
		"...obaaao.......",
		"...obaao........",
		"..obaao.........",
		"..oaao..........",
		".oaao...........",
		".oao............",
		".oo.............",
		"................"],
	"herb": [
		"......oPo.......",
		".....oPpPo..oo..",
		"......oGo..oPPo.",
		"..oo...g...oppo.",
		".oLGo..g..o.oo..",
		".oGGGo.g.oLo....",
		"..ooGGog.GGo....",
		"....oogg.go.....",
		".......goo..oo..",
		"..oo...g...oLGo.",
		".oLGo..g..oGGo..",
		"..oGGGog.oGGo...",
		"...ooGgg.Goo....",
		"......og.o......",
		".......g........",
		".......o........"],
	"journal": [
		"................",
		"..oooooooooooo..",
		"..oRRRRRRRRRRco.",
		"..oRrrrrrrrrRco.",
		"..oRryyyyyyrRco.",
		"..oRryRRRRyrRco.",
		"..oRryRyyRyrRco.",
		"..oRryRyyRyrRco.",
		"..oRryRRRRyrRco.",
		"..oRryyyyyyrRco.",
		"..oRrrrrrrrrRco.",
		"..oRRRRRRRRyyyo.",
		"..oRRRRRRRRyRyo.",
		"..orrrrrrrryyyo.",
		"..oooooooooooo..",
		"................"],
}

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for icon_name: String in ICONS:
		var rows: Array = ICONS[icon_name]
		var image: Image = Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
		for y: int in range(16):
			var row: String = rows[y]
			for x: int in range(mini(16, row.length())):
				var key: String = row[x]
				if PALETTE.has(key):
					image.set_pixel(x, y, Color(PALETTE[key]))
		image.save_png(ProjectSettings.globalize_path(OUT + "icon_%s.png" % icon_name))
	print("wrote %d icons to %s" % [ICONS.size(), OUT])
	quit()
