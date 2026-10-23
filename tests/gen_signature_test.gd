extends SceneTree
## Regression guard for generator changes (phase-5-design.md 5.6.1): every R02
## gallery comes out module for module as it did before.
##   godot --headless --path . --script res://tests/gen_signature_test.gd [-- record]
## Builds standalone R02 galleries for seeds 1-50 and, for library wing seeds
## 1-10, every generated room of the plan (off the tree, as AreaStreamer
## does), and compares each room's signature (module names, scenes,
## positions, rotations) with tests/results/gen_signatures.txt. `record` rewrites
## that file instead.

const BASELINE: String = "res://tests/results/gen_signatures.txt"
const GRAMMAR: String = "res://gen/grammars/r02_stack_gallery.tres"
const RECIPE: String = "res://gen/recipes/library_wing.tres"

var failures: PackedStringArray = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var now: Dictionary = {}
	for s: int in range(1, 51):
		var g := GeneratedRoom.new()
		g.grammar = load(GRAMMAR)
		g.gen_seed = s
		root.add_child(g)
		now["r02@%d" % s] = signature(g)
		g.free()
	for s: int in range(1, 11):
		Area.seed_override = s
		var area := Area.new()
		area.recipe = load(RECIPE)
		var p: AreaPlan = AreaPlanner.plan(area.recipe, s)
		area.plan = p
		for r: AreaPlan.Room in p.rooms:
			if r.kind != "generated":
				continue
			var room := area.make_room(r) as GeneratedRoom
			room.build_planned_modules()
			now["wing%d/%s" % [s, r.slot_id]] = signature(room)
			room.free()
		area.free()
	Area.seed_override = -1
	if OS.get_cmdline_user_args().has("record"):
		var f: FileAccess = FileAccess.open(BASELINE, FileAccess.WRITE)
		f.store_string(JSON.stringify(now, "\t", true))
		f.close()
		print("gen_signature_test: recorded %d rooms to %s" % [now.size(), BASELINE])
		quit(0)
		return
	var was: Variant = JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
	checks += 1
	if not was is Dictionary:
		failures.append("no baseline at %s (run with -- record first)" % BASELINE)
	else:
		for k: String in was:
			checks += 1
			if not now.has(k):
				failures.append("%s is no longer built" % k)
			elif now[k] != was[k]:
				failures.append("%s changed: %s" % [k, _first_difference(str(was[k]), str(now[k]))])
		for k: String in now:
			if not (was as Dictionary).has(k):
				failures.append("%s is new (not in the baseline)" % k)
	print("gen_signature_test: %d checks, %d failures" % [checks, failures.size()])
	for f: String in failures.slice(0, 20):
		print("  FAIL ", f)
	quit(1 if not failures.is_empty() else 0)


static func _first_difference(a: String, b: String) -> String:
	var la: PackedStringArray = a.split("\n")
	var lb: PackedStringArray = b.split("\n")
	for i: int in maxi(la.size(), lb.size()):
		var x: String = la[i] if i < la.size() else "(none)"
		var y: String = lb[i] if i < lb.size() else "(none)"
		if x != y:
			return "line %d was '%s', now '%s'" % [i + 1, x, y]
	return "same lines"


## module_signature() plus each module's rotation (a wall turned the wrong
## way keeps its origin).
static func signature(g: GeneratedRoom) -> String:
	var lines: PackedStringArray = []
	for m: Node3D in g.modules:
		lines.append("%s %s %s %s" % [m.name, m.scene_file_path.get_file(), m.transform.origin.snappedf(0.01), m.transform.basis.get_euler().snappedf(0.01)])
	lines.sort()
	return "\n".join(lines)
