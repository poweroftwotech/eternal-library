extends SceneTree
## Headless: refresh kit wrapper scenes and kit/catalog.tres after an export.
##   godot --headless --path . --script res://tools/kit_catalog.gd
## (tools/export_kit.bat runs this for you; the Kit dock has the same button.)

func _initialize() -> void:
	var builder := KitCatalogBuilder.new()
	builder.build()
	var failed: bool = false
	for line: String in builder.log_lines:
		print("kit_catalog: ", line)
		failed = failed or line.begins_with("ERROR")
	quit(1 if failed else 0)
