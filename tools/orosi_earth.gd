extends SceneTree
## Writes assets/textures/px/persian_orosi_earth.png: the orosi glass with its
## red panes made an earthy brown, for the Light-Well Stair's taghcheh (room
## rework step 6, your walk: the red clashed with the green-gold room).
## Run: --headless --script res://tools/orosi_earth.gd

const SRC: String = "res://assets/textures/px/persian_orosi.png"
const DST: String = "res://assets/textures/px/persian_orosi_earth.png"
const SWAP: Dictionary = {"c8463a": Color("9c6a3e"), "eadfc6": Color("b89a62")}   # red -> umber; near-white -> honey (washed out on your walk)


func _init() -> void:
	var img := Image.load_from_file(SRC)
	var n: int = 0
	for y: int in img.get_height():
		for x: int in img.get_width():
			var k: String = img.get_pixel(x, y).to_html(false)
			if SWAP.has(k):
				img.set_pixel(x, y, SWAP[k])
				n += 1
	img.save_png(ProjectSettings.globalize_path(DST))
	print("orosi_earth: %d pixels recoloured -> %s" % [n, DST])
	quit()
