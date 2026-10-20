extends SceneTree
## Writes world/strata/stratum1_age.tres once (ENVIRONMENT_PLAN.md 6.5.6); after
## that, tune the curves in the Inspector. Refuses to overwrite unless --force.
##   godot --headless --path . --script res://tools/seed_age_rules.gd [-- --force]


func _initialize() -> void:
	var path: String = AgeRules.STRATUM1
	if ResourceLoader.exists(path) and not OS.get_cmdline_user_args().has("--force"):
		print("seed_age_rules: %s exists; pass --force to rewrite it" % path)
		quit()
		return
	var lamps := AgeRule.new()
	lamps.socket_set = load("res://kit/sockets/lamp_state.tres")
	lamps.chain = PackedStringArray(["lit", "failing", "dark"])
	# Chance a lamp has started failing / gone dark after x years untended.
	lamps.step_chance = [
		curve([Vector2(0, 0), Vector2(2, 0.12), Vector2(5, 0.35), Vector2(15, 0.7), Vector2(40, 0.92), Vector2(60, 0.97)]),
		curve([Vector2(0, 0), Vector2(5, 0.08), Vector2(12, 0.35), Vector2(30, 0.8), Vector2(40, 0.88), Vector2(60, 0.95)])]
	var rules := AgeRules.new()
	rules.rules = [lamps]
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err: Error = ResourceSaver.save(rules, path)
	print("seed_age_rules: ", "wrote " + path if err == OK else "FAILED " + error_string(err))
	quit()


func curve(points: Array[Vector2]) -> Curve:
	var c := Curve.new()
	c.min_domain = 0.0
	c.max_domain = points[-1].x
	for p: Vector2 in points:
		c.add_point(p, 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	return c
