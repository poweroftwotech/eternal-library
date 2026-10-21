class_name StatsOverlay
extends CanvasLayer
## Live performance and streaming stats, top right (F3, or Esc → Controls &
## settings). Frame times are measured every frame; the text refreshes four
## times a second. Budgets are the base spec's (architecture.md 8.2): a value
## over its budget turns amber.
##
## Layout: CanvasLayer → MarginContainer (top right) → PanelContainer →
## VBoxContainer of labels and a frame-time graph (AGENTS.md section 3).

const SETTINGS_PATH: String = "user://settings.cfg"
const REFRESH_S: float = 0.25
## Seconds of frames the averages and worst frame cover.
const WINDOW_S: float = 2.0
## Base-spec budgets per view (architecture.md 8.2).
const BUDGET_DRAWS: int = 1500
const BUDGET_TRIS: int = 3000000
const BUDGET_VRAM_MB: float = 6144.0
const OK_COLOUR := Color("cfc8b0")
const OVER_COLOUR := Color("e8a14a")
const HEAD_COLOUR := Color("dfbd7b")
## Panel text width and font size.
const WIDTH: float = 380.0
const FONT_SIZE: int = 15

## The area to report streaming for (null: none, e.g. the camp).
var area: Area
## The HUD's theme, so the panel matches it.
var ui_theme: Theme

var _lines: Dictionary = {}       # key -> Label
var _graph: FrameGraph
var _stream_box: VBoxContainer
var _times: Array[float] = []     # recent frame times, ms
var _stamps: Array[int] = []      # their end times, usec
var _last: int = 0
var _refresh: float = 0.0


func _ready() -> void:
	layer = 5
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	margin.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 18)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ui_theme != null:
		margin.theme = ui_theme
	add_child(margin)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.045, 0.05, 0.78)
	style.border_color = Color("7c724f")
	style.set_border_width_all(1)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.custom_minimum_size.x = WIDTH
	panel.add_child(box)
	_heading(box, "PERFORMANCE  ·  F3")
	for k: String in ["fps", "frame", "cpu", "gpu"]:
		_line(box, k)
	_graph = FrameGraph.new()
	box.add_child(_graph)
	for k: String in ["draws", "tris", "vram"]:
		_line(box, k)
	_stream_box = VBoxContainer.new()
	_stream_box.add_theme_constant_override("separation", 2)
	box.add_child(_stream_box)
	_heading(_stream_box, "STREAMING")
	for k: String in ["room", "rooms", "live", "work", "cost", "wear"]:
		_line(_stream_box, k)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_last = Time.get_ticks_usec()


## Whether the stats were left on last time (user://settings.cfg).
static func saved_visible() -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(SETTINGS_PATH) == OK and bool(cfg.get_value("debug", "show_stats", false))


static func save_visible(on: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("debug", "show_stats", on)
	cfg.save(SETTINGS_PATH)


func _heading(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", FONT_SIZE)
	l.add_theme_color_override("font_color", HEAD_COLOUR)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)


func _line(parent: Control, key: String) -> void:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", FONT_SIZE)
	l.add_theme_color_override("font_color", OK_COLOUR)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = WIDTH
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	_lines[key] = l


func _show(key: String, text: String, over: bool = false) -> void:
	var l: Label = _lines[key]
	l.text = text
	l.add_theme_color_override("font_color", OVER_COLOUR if over else OK_COLOUR)


func _process(delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var ms: float = (now - _last) / 1000.0
	_last = now
	_times.append(ms)
	_stamps.append(now)
	while not _stamps.is_empty() and now - _stamps[0] > int(WINDOW_S * 1000000.0):
		_stamps.pop_front()
		_times.pop_front()
	_graph.push(ms)
	if not visible:
		return
	_refresh -= delta
	if _refresh > 0.0:
		return
	_refresh = REFRESH_S
	_update_text()


func _update_text() -> void:
	var mean: float = _times.reduce(func(a: float, b: float) -> float: return a + b, 0.0) / maxf(_times.size(), 1)
	var worst: float = _times.max() if not _times.is_empty() else 0.0
	_show("fps", "fps %d" % roundi(Performance.get_monitor(Performance.TIME_FPS)))
	_show("frame", "frame %.2f ms avg · %.2f worst (%.0f s)" % [mean, worst, WINDOW_S], worst > 16.7)
	_show("cpu", "cpu  process %.2f · physics %.2f ms" % [Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	var vp: RID = get_viewport().get_viewport_rid()
	_show("gpu", "gpu  %.2f ms · render cpu %.2f ms" % [RenderingServer.viewport_get_measured_render_time_gpu(vp),
		RenderingServer.viewport_get_measured_render_time_cpu(vp)])
	var draws: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var tris: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var vram: float = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	_show("draws", "draw calls %d / %d · objects %d" % [draws, BUDGET_DRAWS, int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))], draws > BUDGET_DRAWS)
	_show("tris", "triangles %.0f k / %.0f k" % [tris / 1000.0, BUDGET_TRIS / 1000.0], tris > BUDGET_TRIS)
	_show("vram", "video memory %.0f / %.0f MB" % [vram, BUDGET_VRAM_MB], vram > BUDGET_VRAM_MB)
	var st: AreaStreamer = area.streamer if area != null and is_instance_valid(area) else null
	_stream_box.visible = st != null
	if st == null:
		return
	_show("room", "you are in %s" % st.player_room)
	_show("rooms", "live: %s" % ", ".join(_live_slots(st)))
	_show("live", "live %d of %d · seals %d · built %d · unloaded %d" % [st.live_count(), area.plan.rooms.size(), st.seals.size(), st.stats["loads"], st.stats["unloads"]])
	var job: String = "building %s (%s)" % [st._job["slot"], st._job["stage"]] if not st._job.is_empty() else "idle"
	_show("work", "%s · queued %d · leaving %d" % [job, st.queue.size(), st._leaving.size()])
	_show("cost", "streaming %.1f ms now · %.1f worst / %.1f budget" % [st.stats["last_frame_ms"], st.stats["max_frame_ms"], st.settings.build_budget_ms],
		float(st.stats["max_frame_ms"]) > st.settings.build_budget_ms * 1.5)
	_show("wear", "floor wear %s · last region %.0f ms (thread)" % ["drawing" if FloorWear.busy() else "idle", FloorWear.last_region_ms])


func _live_slots(st: AreaStreamer) -> PackedStringArray:
	var out: PackedStringArray = []
	for r: AreaPlan.Room in area.plan.rooms:
		if st.is_live(r.slot_id):
			out.append(r.slot_id.replace("stack_gallery_", "sg_").replace("reading_room", "r01"))
	return out


## The last frames as bars, with lines at 8.3 ms (120 fps) and 16.7 ms (60 fps).
class FrameGraph extends Control:
	const FRAMES: int = 120
	const TOP_MS: float = 25.0
	var samples: Array[float] = []

	func _init() -> void:
		custom_minimum_size = Vector2(WIDTH, 44)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func push(ms: float) -> void:
		samples.append(ms)
		if samples.size() > FRAMES:
			samples.pop_front()
		if is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
		var w: float = size.x / FRAMES
		for i: int in samples.size():
			var ms: float = samples[i]
			var h: float = minf(ms / TOP_MS, 1.0) * size.y
			var colour := Color("5fb3b0") if ms <= 8.3 else (Color("e2c587") if ms <= 16.7 else Color("e8674a"))
			draw_rect(Rect2(i * w, size.y - h, maxf(w - 0.5, 1.0), h), colour)
		for line: float in [8.3, 16.7]:
			var y: float = size.y - line / TOP_MS * size.y
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(1, 1, 1, 0.25), 1.0)
