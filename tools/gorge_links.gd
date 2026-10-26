extends SceneTree
## Solves every link the near network could have, once (phase-6-design.md
## 5.7.5, phase 6 step 4).
##   godot --headless --path . --script res://tools/gorge_links.gd
## Writes gen/gorge/links.res (GorgeLinks): for every pair of connectors on
## two frontage slots (a ledge's front at each bay, its ends at each bay
## boundary that leaves two bays for it) and from the Overlook's corner to
## the far cliff, facing each other within ChasmLink.MAX_TURN, a whole number
## of storeys apart with room for the flights: ChasmLink's solve, kept if it
## stands (with its boxes, which the planner checks against what it has
## planned). Re-run after editing gen/gorge/frontage.tres or the Overlook.

const OUT: String = "res://gen/gorge/links.res"
const RECIPE: String = "res://gen/recipes/gorge.tres"


func _initialize() -> void:
	var t0: int = Time.get_ticks_msec()
	GorgeBackdrop.load_baked()      # the walks keep clear of the backdrop's masses (ChasmLink._clear)
	var recipe: AreaRecipe = load(RECIPE)
	var net: GorgeNetwork = recipe.network
	recipe.network = null
	var p: AreaPlan = AreaPlanner.plan(recipe, 1)
	recipe.network = net
	var from: AreaPlan.Room = p.room(net.main_from)
	var main_id: String = "%s:%s" % [net.main_from, net.main_connector]
	var conns: Dictionary = {main_id: from.connectors[net.main_connector]["xf"]}
	for slot: FrontageSlot in net.frontage.slots:
		for k: int in slot.width:
			conns["%s:F:%d" % [slot.id, k]] = GorgeLinks.slot_connector(net.frontage, "%s:F:%d" % [slot.id, k])
		for k: int in range(0, slot.width - 1):
			conns["%s:L:%d" % [slot.id, k]] = GorgeLinks.slot_connector(net.frontage, "%s:L:%d" % [slot.id, k])
		for k: int in range(2, slot.width + 1):
			conns["%s:R:%d" % [slot.id, k]] = GorgeLinks.slot_connector(net.frontage, "%s:R:%d" % [slot.id, k])
	var ids: Array = conns.keys()
	var overlook: Array[AABB] = []
	for r: AreaPlan.Room in p.rooms:
		if r.slot_id == net.main_from:
			for b: AABB in r.blockers:
				var a: AABB = b.abs()
				if a.size.x > .3 and a.size.y > .3 and a.size.z > .3:
					overlook.append(a.grow(-.1))
	var links := GorgeLinks.new()
	links.fixed = {main_id: conns[main_id]}
	var tried: int = 0
	var whys: Dictionary = {}
	for i: int in ids.size():
		for j: int in range(i + 1, ids.size()):
			var a: String = ids[i]
			var b: String = ids[j]
			var sa: String = GorgeLinks.slot_of(a)
			var sb: String = GorgeLinks.slot_of(b)
			if sa == sb:
				continue
			if sa == "" or sb == "":
				var other: String = sb if sa == "" else sa
				if net.frontage.slot(other).cliff != net.main_cliff:
					continue
				if sb == "":       # the Overlook's end first
					var t: String = a
					a = b
					b = t
			var xa: Transform3D = conns[a]
			var xb: Transform3D = conns[b]
			if AreaNetwork._pair_cost(xa, xb) < 0.0:
				continue
			tried += 1
			net.chasm.avoid = overlook
			net.chasm.side_offsets = [0.0, .9, -.9]
			net.chasm.clears_dressing = true
			var lk: Dictionary = ChasmLink.join(net.chasm, xa, xb, hash([a, b]) & 0x7fffffff)
			net.chasm.avoid = []
			net.chasm.side_offsets = [0.0]
			net.chasm.clears_dressing = false
			if not lk["ok"]:
				var w: String = str(lk["why"]).split(" (")[0].split(" at ")[0]
				whys[w] = int(whys.get(w, 0)) + 1
				continue
			var boxes: Array[AABB] = []
			for box: AABB in lk["boxes"]:
				boxes.append((lk["xf"] as Transform3D) * box)
			var to: Vector3 = xb.origin - xa.origin
			links.entries.append({"a": a, "b": b, "length": lk["length"], "drop": roundi((xa.origin.y - xb.origin.y) / 4.0),
				"turn_a": absf(rad_to_deg(ChasmLink._turn(-xa.basis.z, Vector3(to.x, 0, to.z)))), "boxes": boxes})
	var err: Error = ResourceSaver.save(links, OUT)
	print("gorge_links: %d connectors, %d pairs solved, %d links stand (%s) in %.0f s -> %s (%s)" % [ids.size(), tried,
		links.entries.size(), whys, (Time.get_ticks_msec() - t0) / 1000.0, OUT, error_string(err)])
	quit(0 if err == OK else 1)
