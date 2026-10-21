class_name StreamSettings
extends Resource
## How an area streams its rooms (phase-4-design.md 8.1.1, Q6). These are the
## Medium preset's values; graphics presets (architecture.md 8.2) will
## override them, so nothing treats them as constants.

## Rooms within this many doorways of the player's room are live.
@export_range(1, 8) var load_radius: int = 2
## A live room further than this many doorways, and out of sight, unloads...
@export_range(1, 8) var unload_radius: int = 3
## ...once it has been that far for this long (no flicker when you pace a doorway).
@export_range(0.0, 120.0, 0.1) var unload_delay_s: float = 10.0
## Room building work per frame, milliseconds (at least one slice runs).
@export_range(0.5, 16.0, 0.1) var build_budget_ms: float = 4.0
## How often the player's room is worked out, seconds.
@export_range(0.05, 2.0, 0.05) var check_interval_s: float = 0.25


static func default() -> StreamSettings:
	var s: StreamSettings = load("res://world/area/stream_settings.tres") as StreamSettings
	return s if s != null else StreamSettings.new()
