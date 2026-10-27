extends SceneTree
## GPU pictures of the Persian kit gallery (phase 8 step 1). Needs a display,
## not --headless; run `godot --headless --import` first.
##   godot --path . --resolution 1600x900 --script res://tests/persian_gallery_capture.gd -- <out dir> [view,view]
## Writes gallery_<view>.png and prints draw calls, triangles and GPU time
## per view.

const SCENE: String = "res://rooms/test/persian_gallery.tscn"
const VIEWS: Dictionary = {   # name: [eye, target, fov]
	"houses": [Vector3(-44, 4, 18), Vector3(-44, 5, -3), 62.0],
	"window": [Vector3(-46.5, 6.2, 2.0), Vector3(-46.0, 6.0, -2.0), 40.0],
	"door": [Vector3(-49.5, 1.8, 2.5), Vector3(-50.0, 1.4, -2.0), 48.0],
	"monument": [Vector3(0, 7, 36), Vector3(0, 9, 0), 66.0],
	"portal": [Vector3(0, 2.5, 13), Vector3(0, 7, 0), 62.0],
	"carved": [Vector3(28, 6, 14), Vector3(27, 6.5, -4), 60.0],
	"iwan": [Vector3(45, 4, 28), Vector3(45, 5.5, 0), 66.0],
	"iwan_close": [Vector3(45, 2.2, 9), Vector3(45, 4.5, -3), 70.0],
	"dark": [Vector3(73, 4, 22), Vector3(73, 3.5, 1), 68.0],
	"dark_low": [Vector3(70, 1.6, 12), Vector3(68, 4, -2), 72.0],
	"fall": [Vector3(-75, 9, 26), Vector3(-75, 13, -4), 66.0],
	"wide": [Vector3(0, 22, 75), Vector3(0, 6, -4), 72.0],
}
const SETTLE: int = 90


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "res://previews/p8_step1"
	var names: Array = VIEWS.keys()
	if args.size() > 1 and not args[1].begins_with("--"):
		names = args[1].split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out) if out.begins_with("res://") else out)
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(scene)
	var cam := Camera3D.new()
	scene.add_child(cam)
	cam.current = true
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	for i: int in 30:
		await process_frame
	for view: String in names:
		var v: Array = VIEWS[view]
		cam.fov = v[2]
		cam.look_at_from_position(v[0], v[1], Vector3.UP)
		for i: int in SETTLE:
			await process_frame
		var img: Image = root.get_viewport().get_texture().get_image()
		var path: String = "%s/gallery_%s.png" % [out, view]
		img.save_png(ProjectSettings.globalize_path(path) if path.begins_with("res://") else path)
		var vp: RID = root.get_viewport().get_viewport_rid()
		print("%-11s draws %5d  objects %5d  triangles %8d  gpu %.2f ms" % [view,
			RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
			RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),
			RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
			RenderingServer.viewport_get_measured_render_time_gpu(vp)])
	quit()
