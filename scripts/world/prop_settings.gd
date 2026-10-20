@tool
class_name PropSettings
extends Resource
## Tuning shared by every WorldProp and Shards (ENVIRONMENT_PLAN.md 6.5.1),
## in world/props/prop_settings.tres.

## Awake props allowed at once; past it, the oldest sleeping one freezes again.
@export_range(1, 512) var active_budget: int = 48
## Seconds a prop must lie still before it freezes again.
@export_range(0.1, 10.0, 0.1) var sleep_refreeze_s: float = 2.0
## Speed lost in one physics step that breaks a breakable prop (m/s, with
## spin counted at the prop's half height). A prop's own break_speed wins.
@export_range(0.1, 20.0, 0.1) var default_break_speed: float = 3.0
## Speed an E push gives the prop at the point you aim at (m/s).
@export_range(0.1, 10.0, 0.1) var push_speed: float = 1.8
## Walking into a prop: the share of the gap between your speed and the
## prop's that each physics step closes, and the mass above which a prop
## stops getting easier to shove (heavier props move less).
@export_range(0.0, 1.0, 0.01) var bump_share: float = 0.35
@export_range(0.1, 100.0, 0.1) var bump_mass_cap: float = 8.0
## Angular damping on props and shards. Godot has no rolling resistance, so
## without it a vase on its side or a curved shard rocks and rolls for ages.
@export_range(0.0, 10.0, 0.1) var roll_damp: float = 2.0
## Shards fly out from the break point at up to this speed (m/s).
@export_range(0.0, 5.0, 0.05) var shard_scatter: float = 0.6


static func default() -> PropSettings:
	var path: String = "res://world/props/prop_settings.tres"
	return load(path) as PropSettings if ResourceLoader.exists(path) else PropSettings.new()
