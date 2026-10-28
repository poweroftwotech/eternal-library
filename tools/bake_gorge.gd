extends SceneTree
## Bakes the gorge from kit pieces (phase-6-design.md 5.7.2, phase 6 step 1).
##   godot --headless --path . --script res://tools/bake_gorge.gd [-- --no-cull]
## Writes, all yours to edit afterwards (re-baking overwrites them):
##   rooms/baked/gorge/bank_1.scn .. bank_8.scn, sanctum.scn, aqueducts.scn
##       GorgeGrammar's kit pieces, one scene per part of the gorge, each piece
##       its own instance;
##   rooms/baked/gorge/generated.scn
##       what stays generated, made once now by the gorge's own code
##       (vista.gd with its architecture switched off): the cavern, mist,
##       cascades, the far enclosure, the rock-cut stair and lamassu, the cliff
##       and loggia, the balcony, the lights (the lamp clusters from the kit's
##       lamps), the aqueducts' waterfalls and bank 4's rotunda, merged by
##       material as the camp merges its own;
##   rooms/baked/gorge/environment.tres
##       the camp's environment (fog, glow, grade) with the gorge's MOOD over it;
##   rooms/baked/gorge.tscn
##       the scene the Gorge area adds: the environment, the generated part,
##       the kit parts under a KitBatcher (drawn in batches when it loads), and
##       a PlayerSpawn on the balcony facing the gorge;

const OUT_DIR: String = "res://rooms/baked/gorge/"
const MAIN: String = "res://rooms/baked/gorge.tscn"
const ROOT_ROOM: String = "res://rooms/gorge/overlook.tscn"
## Pieces no player can see (tools/gorge_visibility.gd), left out unless
## `-- --no-cull` (which the visibility tool needs: it looks at all of them).
const HIDDEN: String = "res://gen/gorge/hidden_pieces.json"
var hidden: Dictionary = {}
var culled: int = 0
const LAYOUT: String = "res://gen/gorge/gorge_layout.tres"
## A kit piece's height over its origin, for the rock's clearance (a storey
## and a crown's merlons; the deck pieces are thinner).
const PIECE_TOP: float = 5.0
## The overlook (capture.gd vista_concept): where you stand (your feet), what
## you face.
const EYE: Vector3 = Vector3(-1, 2.25, -27.45)
const FACING: Vector3 = Vector3(5, -22, -178)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var t0: int = Time.get_ticks_usec()
	if OS.get_cmdline_user_args().has("--rebatch"):
		var parts: Array = ["bank_1", "bank_2", "bank_3", "bank_4", "bank_5", "bank_6", "bank_7", "bank_8", "sanctum", "aqueducts", "cliff"]
		print("bake_gorge: rebatched %s" % rebatch(parts.filter(func(p: String) -> bool: return ResourceLoader.exists(OUT_DIR + p + ".scn"))))
		print("bake_gorge: %d pieces" % save_pieces())
		quit()
		return
	if not OS.get_cmdline_user_args().has("--no-cull") and FileAccess.file_exists(HIDDEN):
		for k: String in (JSON.parse_string(FileAccess.get_file_as_string(HIDDEN)) as Dictionary).get("hidden", []):
			hidden[k] = true
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(ROOT_ROOM.get_base_dir())
	var environment: Environment = gorge_mood(camp_environment())
	ResourceSaver.save(environment, OUT_DIR + "environment.tres")
	# The kit parts.
	var layout: GorgeLayout = load(LAYOUT)
	var grammar := GorgeGrammar.new()
	var parts: Dictionary = {}
	for i: int in layout.banks.size():
		var b: PackedFloat32Array = layout.banks[i]
		parts["bank_%d" % (i + 1)] = grammar.bank(Vector2(b[0], b[1]), b[2], b[3], b[4], int(b[5]))
	parts["sanctum"] = grammar.sanctum(layout.sanctum)
	var aqueducts: Array[Dictionary] = []
	for i: int in layout.aqueducts.size():
		var a: PackedFloat32Array = layout.aqueducts[i]
		if layout.walked.has(i) or layout.removed.has(i):
			continue          # a walkable span takes its place (phase 6 Q9)
		var falls: Array[int] = []
		for k: int in range(6, a.size()):
			falls.append(int(a[k]))
		aqueducts.append_array(grammar.aqueduct(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]), falls, [not layout.open_ends.has(i * 2), not layout.open_ends.has(i * 2 + 1)]))
	parts["aqueducts"] = aqueducts
	# The near cliff round the loggia, a cliff village in the Persian look
	# (phase 8 step 3; walked only: the camp's view never turns round to it).
	var cliff_script: GDScript = load("res://scripts/vista_cliff.gd")
	parts["cliff"] = PersianTown.new(grammar).cliff(cliff_script.FACADES, cliff_script.FACE_Z - .3)
	var counts: Dictionary = {}
	var extras: Array[Dictionary] = []
	var lamps := PackedVector3Array()
	for part: String in parts:
		counts[part] = save_part(part, parts[part], extras, lamps)
	# The rock keeps clear of the kit's pieces (Cavern.kit_floor): each piece's
	# origin plus PIECE_TOP, the highest per cell.
	var floor_grid: Dictionary = {}
	var cell: float = load("res://scripts/cavern.gd").FLOOR_CELL
	for part: String in parts:
		for p: Dictionary in parts[part]:
			if p.has("xf"):
				var at: Vector3 = (p["xf"] as Transform3D).origin
				var k := Vector2i(floori(at.x / cell), floori(at.z / cell))
				floor_grid[k] = maxf(float(floor_grid.get(k, -INF)), at.y + float(p.get("top", PIECE_TOP)))     # tall pieces say how tall (PersianTown)
	load("res://scripts/cavern.gd").set("kit_floor", floor_grid)
	# The generated part.
	var generated: Node3D = await generate(layout, extras, lamps)
	var generated_count: int = generated.find_children("*", "VisualInstance3D", true, false).size()
	save_scene(generated, OUT_DIR + "generated.scn")
	generated.free()
	# The batched kit, the scene the area adds, and its root room.
	var batched: Dictionary = rebatch(parts.keys())
	save_main()
	var pieces: int = save_pieces()
	print("bake_gorge: %s; %d unseen left out; generated %d visuals; %d lamps; batched %s; %d pieces; %.1f s -> %s" % [counts, culled, generated_count, lamps.size(), batched, pieces, (Time.get_ticks_usec() - t0) / 1000000.0, MAIN])
	quit()


## The camp's environment (the gorge has only ever been seen through it): the
## code-built camp's after every pass, as the camp's bake saved it (phase 7).
func camp_environment() -> Environment:
	var camp: Node = (load("res://rooms/camp/camp.tscn") as PackedScene).instantiate()
	var env: WorldEnvironment = camp.find_children("*", "WorldEnvironment", false, false)[0]
	var environment: Environment = env.environment.duplicate(true)
	camp.free()
	return environment


## The gorge's own mood over the camp's environment (your call, 2026-10-27:
## see further down the chasm, and more contrast between lit and unlit, an
## "HDR" look without more bloom or black shadows). The camp keeps its own.
const MOOD: Dictionary = {
	"fog_density": 0.0009,              # camp 0.0012
	"fog_height_density": 0.007,        # camp 0.015: the white floor 60 m down
	"volumetric_fog_density": 0.002,    # camp 0.003
	"volumetric_fog_ambient_inject": 0.12,   # camp 0.22: unlit haze darker
	"ambient_light_energy": 0.09,       # camp 0.22: shadows darker (0.13 at the first look)
	"ssao_intensity": 2.6,              # camp 2.2
	"tonemap_exposure": 1.08,           # camp 0.97: lit faces brighter
	"adjustment_contrast": 1.16,        # camp 1.06
	"glow_hdr_threshold": 1.05,         # camp 0.95: no more bloom for the brighter lights
	"sdfgi_energy": 0.75,               # camp 1.0: less even bounce into the shade
}
## The mist volumes (vista.gd mist) are this much thinner in the gorge, and
## the low mist floor (Cavern, GorgeMistFloor) sits this much lower.
const MIST_SCALE: float = 0.55
const MIST_DROP: float = 20.0
## The light: the vault's even bounce weaker; local lights (lamps, lumen
## stones, fungus glow: reach under LOCAL_REACH) brighter, the big fill
## lights (mist, rims) dimmer; both more so by the camp, banks 1 to 4 (your
## second look: more contrast there, the far banks' natural light about as it
## was); and the far end of the sightline (the far hall, the sanctum's key,
## past FAR_Z) brighter: it is the view's focal glow.
const BOUNCE_SCALE: float = 0.6
const LOCAL_REACH: float = 40.0
const NEAR_Z: float = -185.0
const NEAR_LOCAL: float = 1.6
const NEAR_FILL: float = 0.6
## Fill lights above this (the vault's rims) keep their light: the rock overhead
## is the box art's.
const RIM_Y: float = 20.0
const FAR_LOCAL: float = 1.25
const FAR_FILL: float = 1.0
const FAR_Z: float = -205.0
const FAR_SCALE: float = 1.3


func gorge_mood(environment: Environment) -> Environment:
	for k: String in MOOD:
		environment.set(k, MOOD[k])
	return environment


## The mood's mist and light under `node` (the generated part's).
func gorge_mood_lights(node: Node) -> void:
	for fog: Node in node.find_children("*", "FogVolume", true, false):
		var m: FogMaterial = (fog as FogVolume).material as FogMaterial
		if m != null:
			m.density *= MIST_SCALE
		if fog.name == "GorgeMistFloor":
			(fog as FogVolume).position.y -= MIST_DROP
	for n: Node in node.find_children("*", "Light3D", true, false):
		var l: Light3D = n as Light3D
		var reach: float = (l as OmniLight3D).omni_range if l is OmniLight3D else ((l as SpotLight3D).spot_range if l is SpotLight3D else INF)
		var near: bool = l.global_position.z > NEAR_Z
		if l is DirectionalLight3D:
			l.light_energy *= BOUNCE_SCALE
		elif l.global_position.z < FAR_Z and reach >= 90.0:
			l.light_energy *= FAR_SCALE
		elif reach < LOCAL_REACH:
			l.light_energy *= NEAR_LOCAL if near else FAR_LOCAL
		else:
			l.light_energy *= NEAR_FILL if near and l.global_position.y < RIM_Y else FAR_FILL


## One part's kit pieces as their own scene; collects its generated extras
## (waterfalls and their troughs, the rotunda, lights) and lamps for the
## generated part.
func save_part(part: String, placements: Array[Dictionary], extras: Array[Dictionary], lamps: PackedVector3Array) -> int:
	var holder := Node3D.new()
	holder.name = part.to_pascal_case()
	var scenes: Dictionary = {}
	var placed: int = 0
	for p: Dictionary in placements:
		if not p.has("scene"):
			extras.append(p)
			continue
		var path: String = p["scene"]
		if path.ends_with("gorge_lamp.tscn"):
			lamps.append((p["xf"] as Transform3D).origin)
		elif path.contains("gorge_pavilion"):
			lamps.append((p["xf"] as Transform3D) * Vector3(0, 3.0, 0))
		elif path.ends_with("persian_lamp_bracket.tscn"):     # its lantern, under the arm
			lamps.append((p["xf"] as Transform3D) * Vector3(0, -0.3, 0.75))
		# Unseen (gorge_visibility.gd): left out, its lamp's light kept above.
		if hidden.has("%s@%s" % [path.get_file().get_basename(), (p["xf"] as Transform3D).origin.snapped(Vector3.ONE * .01)]):
			culled += 1
			continue
		if not scenes.has(path):
			scenes[path] = load(path)
		var node: Node3D = (scenes[path] as PackedScene).instantiate()
		node.transform = p["xf"]
		node.name = "%s_%d" % [path.get_file().get_basename(), placed]
		holder.add_child(node)
		node.owner = holder
		placed += 1
	for n: Node in holder.find_children("*", "VisualInstance3D", true, false):
		(n as VisualInstance3D).layers = 2     # the gorge's light layer, as vista.gd's
	save_scene(holder, OUT_DIR + part + ".scn")
	holder.free()
	return placed


## Runs the gorge's own code with its architecture switched off, plus the
## extras the kit parts asked for, into a node of its own.
func generate(layout: GorgeLayout, extras: Array[Dictionary], lamps: PackedVector3Array) -> Node3D:
	var vista_script: GDScript = load("res://scripts/vista.gd")
	var seeds := PackedInt32Array()
	for b: PackedFloat32Array in layout.banks:
		seeds.append(int(b[5]))
	vista_script.skip_banks = seeds
	vista_script.skip_bridges = true
	vista_script.skip_sanctum_tiers = true
	vista_script.walkable_overlook = true     # the balcony opens onto the stair (step 2)
	vista_script.extra_lamps = lamps
	var owner: Node3D = load("res://scripts/gorge_host.gd").new()
	owner.name = "Generated"
	root.add_child(owner)
	owner.art = load("res://scripts/asset_factory.gd").new(owner)
	var vista: Object = vista_script.new(owner, owner.art)
	owner.vista = vista
	vista.build()
	owner.art.render_layer = 2
	var cores: Dictionary = {}
	for p: Dictionary in extras:
		if p.has("fall"):         # a great fall (PersianTown, phase-8-design.md 8.5)
			var fall := GreatFall.new()
			fall.name = "GreatFall"
			fall.width = p["width"]
			fall.height = p["height"]
			fall.arc_out = p.get("arc", 3.0)
			fall.mist = p.get("mist", true)
			fall.seed_value = float(owner.get_child_count())
			owner.add_child(fall)
			fall.transform = p["fall"]
		elif p.has("shaft"):      # a shaft of natural light (phase-8-design.md 8.4)
			var shaft := LightShaft.new()
			shaft.name = "LightShaft"
			shaft.height = p["height"]
			shaft.radius = p["radius"]
			shaft.energy = p.get("energy", 9.0)
			shaft.haze = p.get("haze", 0.14)     # the gallery's 0.035 default barely showed at gorge distances
			owner.add_child(shaft)
			shaft.position = p["shaft"]
		elif p.has("material"):   # a tier's core (GorgeGrammar): its own node, below
			if not cores.has(p["material"]):
				cores[p["material"]] = []
			(cores[p["material"]] as Array).append(p)
		elif p.has("stone"):      # a waterfall's trough (ChasmGrammar.TROUGH), merged with the rest
			owner.art.box(Vector3.ZERO, p["size"], load(p.get("stone_material", "res://kit/materials/gorge_sandstone.tres"))).transform = p["stone"]
		elif p.has("trough_water"):     # the water running out along it to the lip
			var water := PlaneMesh.new()
			water.size = p["size"]
			var plane: MeshInstance3D = owner.art.mesh_node(water, Vector3.ZERO, load("res://kit/materials/cistern_water.tres"))
			plane.transform = p["trough_water"]
			plane.set_meta("dynamic", true)     # its own material, not merged
		elif p.has("rotunda"):
			vista.rotunda(p["rotunda"], p["radius"], p["height"])
		elif p.has("light"):
			owner.light(p["light"], p["color"], p["energy"], p["range"])
	gorge_mood_lights(owner)
	owner.art.render_layer = 1
	owner.art.flush_batches()
	owner.art.merge_static_geometry()
	await process_frame
	# The merge hides what it merged; those copies aren't needed in the bake.
	var merged: Array = owner.find_children("*", "MeshInstance3D", true, false).filter(func(m: Node) -> bool: return not (m as MeshInstance3D).visible)
	for i: int in merged.size():
		if is_instance_valid(merged[i]):     # nested ones (a kit piece's) went with their parent
			(merged[i] as Node).free()
	owner.add_child(tier_cores(cores))
	# A plain node: the host's script isn't wanted in the saved scene.
	var out := Node3D.new()
	out.name = "Generated"
	for c: Node in owner.get_children():
		owner.remove_child(c)
		out.add_child(c)
	owner.queue_free()
	adopt(out, out)
	return out


## The tiers' cores (GorgeGrammar: behind the facades, phase 6 step 6), one mesh
## per stone, in a node of their own: GorgeBackdrop leaves it out (they're
## inside the tiers, which the network's keep-out already covers).
func tier_cores(cores: Dictionary) -> Node3D:
	var holder := Node3D.new()
	holder.name = "TierCores"
	for material: String in cores:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for p: Dictionary in cores[material]:
			var box := BoxMesh.new()
			box.size = p["size"]
			st.append_from(box, 0, p["stone"])
		var mi := MeshInstance3D.new()
		mi.name = material
		mi.mesh = st.commit()
		mi.material_override = load("res://kit/materials/%s.tres" % material)
		mi.layers = 2     # the gorge's light layer
		holder.add_child(mi)
	return holder


## Makes `owner` the owner of everything under `node` that a saved scene must
## hold: not the insides of instanced scenes (the lamassu), which load from
## their own files.
func adopt(node: Node, owner: Node) -> void:
	for c: Node in node.get_children():
		c.owner = owner
		if c.scene_file_path == "":
			adopt(c, owner)


## The kit parts batched (KitBatcher) into kit_batched.scn: the area loads 64
## MultiMeshes, not 61,000 pieces. Edit a part's scene, then rebatch
## (`-- --rebatch`).
func rebatch(parts: Array) -> Dictionary:
	var kit := KitBatcher.new()
	kit.name = "Kit"
	kit.batch_on_ready = false
	kit.render_layers = 2     # the gorge's light layer, as vista.gd's
	kit.chunk_size = 128.0    # the busier meshes culled per region, distant regions on their LODs (phase 6 step 6; phase 8's budget check: 300, was 1500)
	kit.chunk_min = 300
	kit.detail_range = 110.0  # lamps, balusters, figures: near only
	root.add_child(kit)
	for part: String in parts:
		kit.add_child((load(OUT_DIR + part + ".scn") as PackedScene).instantiate())
	var stats: Dictionary = kit.batch()
	for c: Node in kit.get_children():
		if not c is MultiMeshInstance3D:
			c.free()     # what's left of the pieces: anchors, kept for the walkable steps
		else:
			c.owner = kit
	root.remove_child(kit)
	save_scene(kit, OUT_DIR + "kit_batched.scn")
	kit.free()
	return stats


func save_main() -> void:
	var main := Node3D.new()
	main.name = "Gorge"
	var env := WorldEnvironment.new()
	env.name = "Environment"
	env.environment = load(OUT_DIR + "environment.tres")
	main.add_child(env)
	env.owner = main
	var generated: Node3D = (load(OUT_DIR + "generated.scn") as PackedScene).instantiate()
	main.add_child(generated)
	generated.owner = main
	var kit: Node = (load(OUT_DIR + "kit_batched.scn") as PackedScene).instantiate()
	main.add_child(kit)
	kit.owner = main
	var spawn := Marker3D.new()
	spawn.name = "PlayerSpawn"
	main.add_child(spawn)
	spawn.owner = main
	spawn.transform = Transform3D(Basis.looking_at(Vector3(FACING.x - EYE.x, 0, FACING.z - EYE.z)), EYE)
	save_scene(main, MAIN)
	main.free()


## The scenery again as small scenes (phase 9, one continuous world): the
## generated part's and the batched kit's children PIECE_SIZE at a time, so
## an area can build its scenery one piece a frame in the background
## (Area.background; built whole, the merged meshes stalled the frame for
## 70-200 ms). A kit piece is a KitBatcher of its own, which puts its batches'
## transforms back when it enters the tree. Listed in PIECES. Returns how many.
const PIECES: String = "res://rooms/baked/gorge/pieces.tres"
const PIECE_DIR: String = "res://rooms/baked/gorge/pieces/"
const PIECE_SIZE: int = 20


func save_pieces() -> int:
	DirAccess.make_dir_recursive_absolute(PIECE_DIR)
	for f: String in DirAccess.get_files_at(PIECE_DIR):
		DirAccess.remove_absolute(PIECE_DIR + f)
	var list := PlacePieces.new()
	list.environment = load(OUT_DIR + "environment.tres")
	for part: Array in [["generated", OUT_DIR + "generated.scn"], ["kit", OUT_DIR + "kit_batched.scn"]]:
		var whole: Node = (load(part[1]) as PackedScene).instantiate()
		if part[0] == "kit":
			list.module_bounds = GorgeScenery.module_bounds(whole)
		var kids: Array[Node] = whole.get_children()
		for i: int in range(0, kids.size(), PIECE_SIZE):
			var holder: Node3D = Node3D.new()
			if part[0] == "kit":
				var batcher := KitBatcher.new()
				batcher.batch_on_ready = false
				holder = batcher
			holder.name = "%s_%d" % [part[0], i / PIECE_SIZE]
			for c: Node in kids.slice(i, i + PIECE_SIZE):
				whole.remove_child(c)
				holder.add_child(c)
				adopt_all(c, holder)
			var path: String = PIECE_DIR + "%s_%03d.scn" % [part[0], i / PIECE_SIZE]
			save_scene(holder, path)
			holder.free()
			(list.generated if part[0] == "generated" else list.kit).append(path)
		whole.free()
	ResourceSaver.save(list, PIECES)
	return list.generated.size() + list.kit.size()


## Makes `owner` the owner of `node` and of everything under it a saved scene
## must hold (as adopt, from the node itself).
func adopt_all(node: Node, owner: Node) -> void:
	node.owner = owner
	if node.scene_file_path == "":
		adopt(node, owner)



func save_scene(node: Node, path: String) -> void:
	var scene := PackedScene.new()
	var err: Error = scene.pack(node)
	if err == OK:
		err = ResourceSaver.save(scene, path)
		# Something outside Godot (a scanner or indexer) sometimes holds a
		# just-written file for a moment: try again before giving up.
		for attempt: int in 5:
			if err != ERR_CANT_OPEN and err != ERR_FILE_CANT_OPEN and err != ERR_FILE_CANT_WRITE:
				break
			OS.delay_msec(400)
			err = ResourceSaver.save(scene, path)
	if err != OK:
		push_error("bake_gorge: could not save %s (%s)" % [path, error_string(err)])
