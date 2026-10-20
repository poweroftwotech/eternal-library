extends SceneTree
## Phase 3 step 3 gate (ENVIRONMENT_PLAN.md 6.5.4): shelf book promotion and
## lore books, in the real reading room (built in memory, never saved).
##   godot --headless --path . --script res://tests/book_test.gd
## Saving is covered by persist_test.

const LORE_SOCKET: String = "Shell/wall_shelfbay_4m/Mesh/M_wall_shelfbay_4m/SOCKET_recess_fill"
const GALLERY_SOCKET: String = "Shell/wall_shelfbay_4m5/Mesh/M_wall_shelfbay_4m/SOCKET_recess_fill"

var failures: PackedStringArray = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func run() -> void:
	check_items()
	check_indices_stable()
	await check_room()
	print("book_test: %d checks, %d failures" % [checks, failures.size()])
	for f: String in failures:
		print("  FAIL ", f)
	quit(1 if not failures.is_empty() else 0)


func check_items() -> void:
	var a: ItemDef = ItemDef.find(&"lore_hollow_index")
	var b: ItemDef = ItemDef.find(&"lore_lamps_remember")
	check(a != null and b != null and a.kind == ItemDef.Kind.LORE and a.unique, "both lore books are unique LORE ItemDefs")
	check(a != null and a.text.length() > 100 and b != null and b.text.length() > 100, "both have text to read")
	var herb: ItemDef = ItemDef.find(&"herb")
	check(herb != null and herb.kind == ItemDef.Kind.INGREDIENT and not herb.unique and herb.stack_max > 1, "camp ingredients are stacking ItemDefs")


## A lore pin changes nothing about the other books: same count before it,
## same transforms except the few it shrinks out of its slot (20 seeds).
func check_indices_stable() -> void:
	var pin := LoreBookPin.new()
	pin.level = 2
	pin.x = 0.1
	pin.item = ItemDef.find(&"lore_hollow_index")
	var stable: bool = true
	var shrunk_ok: bool = true
	for seed_value: int in range(1, 21):
		var plain := ShelfFill.new()
		plain.build(seed_value)
		var with_lore := ShelfFill.new()
		with_lore.lore = [pin]
		with_lore.build(seed_value)
		var n: int = plain.built_transforms.size()
		stable = stable and with_lore.built_transforms.size() == n + 2 and with_lore.lore_index.get(pin.item.id) == n
		var shrunk: int = 0
		for i: int in n:
			if with_lore.built_transforms[i] != plain.built_transforms[i]:
				shrunk += 1
				shrunk_ok = shrunk_ok and with_lore.built_transforms[i].basis.x.length() < 0.01 and plain.book_levels[i] == 2
		shrunk_ok = shrunk_ok and shrunk <= 3
		plain.free()
		with_lore.free()
	check(stable, "a lore pin adds two instances (book, band) at the end, for 20 seeds")
	check(shrunk_ok, "it only shrinks the 1-3 books in its own slot; every other index and transform is unchanged")


func check_room() -> void:
	var room: RoomTemplate = (load("res://rooms/authored/reading_room.tscn") as PackedScene).instantiate()
	root.add_child(room)
	for _i: int in 3:
		await physics_frame
	var report: Dictionary = KitValidateRoom.run(room)
	var lore_errors: Array = Array(report["errors"]).filter(func(e: String) -> bool: return e.begins_with("lore book"))
	check(lore_errors.is_empty(), "Validate Room: R01's lore pins are fine (%s)" % [lore_errors])
	var fill: ShelfFill = fill_of(room, LORE_SOCKET)
	check(fill != null and fill.lore.size() == 1 and fill.lore_index.has(&"lore_hollow_index"), "the entrance recess has the Hollow Index on it")
	var upper: ShelfFill = fill_of(room, GALLERY_SOCKET)
	check(upper != null and upper.lore_index.has(&"lore_lamps_remember"), "the gallery recess has On Lamps That Remember")
	if fill == null:
		room.queue_free()
		return
	var reach: Node = fill.get_children(true).filter(func(c: Node) -> bool: return c is StaticBody3D).front()
	check(reach != null and (reach as StaticBody3D).collision_layer == 2 and (reach as StaticBody3D).collision_mask == 0,
		"the shelf's ray target is on layer 2 only (never blocks movement)")
	# Aim at the lore book's spine.
	var li: int = fill.lore_index[&"lore_hollow_index"]
	var spine: Vector3 = fill.to_global(fill.built_transforms[li].origin + Vector3(0, 0, -fill.built_transforms[li].basis.z.length() * 0.5))
	check(fill.book_at(spine) == li, "aiming at the gilt spine finds the lore book")
	check(fill.prompt_at(spine) == "Pull out The Hollow Index", "the prompt names it (%s)" % fill.prompt_at(spine))
	# An ordinary book on another shelf.
	var bi: int = -1
	for i: int in fill.built_transforms.size():
		if fill.book_levels[i] == 1 and fill.built_transforms[i].basis.x.length() > 0.01:
			bi = i
			break
	var plain_spine: Vector3 = fill.to_global(fill.built_transforms[bi].origin + Vector3(0, 0, -fill.built_transforms[bi].basis.z.length() * 0.5))
	check(fill.prompt_at(plain_spine) == "Pull out a book", "an ordinary book says 'Pull out a book'")
	await process_frame
	await process_frame
	# Pull it: half out, frozen, still on the shelf; its instance is hidden.
	var pulled: Array = []
	fill.pulled.connect(func(b: WorldProp, i: int) -> void: pulled.append([b, i]))
	var book: WorldProp = fill.pull(bi)
	for _i: int in 30:
		await physics_frame
	var out: float = (book.transform.origin - fill.built_transforms[bi].origin).z
	check(pulled.size() == 1 and pulled[0][1] == bi, "pulling emits pulled(book, index)")
	check(fill.hidden.has(bi) and book.freeze, "the shelf instance is hidden, the book is a frozen WorldProp")
	check(absf(out + fill.built_transforms[bi].basis.z.length() * ShelfFill.PULL_OUT) < 0.005, "it sticks %.0f %% out of the shelf" % (-out / fill.built_transforms[bi].basis.z.length() * 100.0))
	check(book.interaction_prompt(Vector3.ZERO) == "Pull off" and book.pull_toward, "a pulled ordinary book says 'Pull off'")
	check(WorldProp.world_mapped_materials(book).is_empty(), "the pulled book's material maps in object space")
	check(book.get_meta("world_id", "") == "reading_room@1/%s#b%d" % [LORE_SOCKET, bi], "the room tracks it by shelf and index (%s)" % book.get_meta("world_id", ""))
	# Pull it off: it comes toward you and lands on the floor.
	var actor := Node3D.new()
	room.add_child(actor)
	actor.global_position = book.global_position + Vector3(1.5, 0, 0)
	actor.global_position.y = 0.0
	book.interact(actor, book.global_position)
	for _i: int in 400:
		await physics_frame
		if book.freeze:
			break
	check(book.freeze and book.global_position.y < 0.3 and book.global_position.x > 0.25, "pulled off, it lands on the hall floor in front of the shelf (%s)" % book.global_position)
	# The lore book: pull, then take.
	var lore: WorldProp = fill.pull(li)
	for _i: int in 30:
		await physics_frame
	check(lore.item != null and lore.interaction_prompt(Vector3.ZERO) == "Take The Hollow Index", "the pulled lore book says 'Take The Hollow Index'")
	check(lore.get_child_count() == 2, "it keeps its gilt band")
	var ws: Node = root.get_node("WorldState")
	lore.interact(actor, lore.global_position)
	await process_frame
	check(ws.call("owns", &"lore_hollow_index"), "taking it puts it in the satchel")
	check(not is_instance_valid(lore) and fill.hidden.has(li), "and it's gone from the shelf")
	check(fill.book_at(spine) != li, "nothing there to pull any more")
	check(str(ws.call("delta", "reading_room@1/%s#lore:lore_hollow_index" % LORE_SOCKET).get("s", "")) == "taken", "the save marks it taken, by its shelf")
	check(not ws.call("revert", "reading_room@1/%s#lore:lore_hollow_index" % LORE_SOCKET), "a janitor can't put back what's in the satchel")
	room.queue_free()
	await process_frame
	# Validate Room: an unpinned lore recess is an error.
	var loose: RoomTemplate = (load("res://rooms/authored/reading_room.tscn") as PackedScene).instantiate()
	var pin := LoreBookPin.new()
	pin.socket = "Shell/wall_shelfbay_4m3/Mesh/M_wall_shelfbay_4m/SOCKET_recess_fill"     # not room-pinned
	pin.item = ItemDef.find(&"lore_lamps_remember")
	loose.lore_books.append(pin)
	root.add_child(loose)
	await process_frame
	var errs: Array = Array(KitValidateRoom.run(loose)["errors"]).filter(func(e: String) -> bool: return e.begins_with("lore book"))
	check(errs.size() == 1, "Validate Room reports a lore book on a recess that isn't pinned to shelves (%s)" % [errs])
	loose.queue_free()
	await process_frame


func fill_of(room: RoomTemplate, socket_path: String) -> ShelfFill:
	var s := room.get_node_or_null(socket_path) as VariantSocket
	if s == null:
		return null
	for n: Node in s.spawned():
		if n is ShelfFill:
			return n as ShelfFill
	return null
