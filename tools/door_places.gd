extends SceneTree
## Which Gorge frontage slots could take a door into a new area (phase 10
## step 3): each slot not yet a door place is given a door of its own, beside
## the stratum's doors, and the Gorge is planned for world seeds 1-N; a slot
## whose door every seed's network reaches, with the plan checking clean, is a
## candidate. Read-only: pick from what it prints and set door_place = true on
## those slots in gen/gorge/frontage.tres, then re-bake the Gorge.
##   godot --headless --path . --script res://tools/door_places.gd [-- worlds=20]

func _initialize() -> void:
	var worlds: int = 20
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("worlds="):
			worlds = a.trim_prefix("worlds=").to_int()
	var recipe: AreaRecipe = load(StratumPlan.current().path_of("gorge"))
	var base: StratumPlan = StratumPlan.current()
	var rows: Array = []
	var t0: int = Time.get_ticks_msec()
	for s: FrontageSlot in recipe.network.frontage.slots:
		if s == null or s.door_place:
			continue
		var trial: StratumPlan = base.duplicate(true)
		trial.links.append({"a": "gorge", "b": "door_trial", "kind": StratumPlan.DOOR, "at": s.id})
		StratumPlan.use(trial)
		var reached: int = 0
		var clean: int = 0
		var ledges: int = 0
		for w: int in range(1, worlds + 1):
			var p: AreaPlan = AreaPlanner.plan_world(recipe, w)
			if not p.threshold("door_trial").is_empty():
				reached += 1
			if p.check().is_empty():
				clean += 1
			ledges += p.rooms.filter(func(r: AreaPlan.Room) -> bool: return r.kind == "ledge").size()
		rows.append([s.id, s.bank, s.cliff, s.storey(), s.width, reached, clean, float(ledges) / worlds])
		print("door_places: %s bank %d %s storey %d width %d: reached %d/%d, clean %d/%d, ledges %.1f" % [
			s.id, s.bank, s.cliff, s.storey(), s.width, reached, worlds, clean, worlds, float(ledges) / worlds])
	StratumPlan.drop_cache()
	print("door_places: %d slots in %.0f s" % [rows.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	quit()
