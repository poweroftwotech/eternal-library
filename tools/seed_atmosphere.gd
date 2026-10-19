extends SceneTree
## Creates the atmosphere profiles if they don't exist yet (phase 1 step 4).
##   godot --headless --path . --script res://tools/seed_atmosphere.gd
## After that, tune kit/atmosphere/*.tres in the Inspector.
##   prototype_v011.tres  the prototype's v0.11 numbers (art_direction.gd applies it)
##   reading_room.tres    R01: lantern-lit hall, denser haze, a little more ambient

const DIR: String = "res://kit/atmosphere/"


func _initialize() -> void:
	var made: PackedStringArray = []
	DirAccess.make_dir_recursive_absolute(DIR)
	if not ResourceLoader.exists(DIR + "prototype_v011.tres"):
		ResourceSaver.save(AtmosphereProfile.new(), DIR + "prototype_v011.tres")
		made.append("prototype_v011.tres")
	if not ResourceLoader.exists(DIR + "reading_room.tres"):
		var p := AtmosphereProfile.new()
		p.background_color = Color("080b0e")
		p.exposure = 1.05
		p.ambient_energy = 0.3
		p.fog_density = 0.012
		ResourceSaver.save(p, DIR + "reading_room.tres")
		made.append("reading_room.tres")
	print("seed_atmosphere: ", "created " + ", ".join(made) if not made.is_empty() else "nothing to do")
	quit()
