@tool
class_name AgeRules
extends Resource
## A stratum's aging rules (ENVIRONMENT_PLAN.md 6.5.6), world/strata/*.tres.
## Phase 3 has one rule (lamps); recesses and growth come later.

@export var rules: Array[AgeRule] = []

const STRATUM1: String = "res://world/strata/stratum1_age.tres"


func rule_for(set: SocketSet) -> AgeRule:
	if set == null:
		return null
	for r: AgeRule in rules:
		if r != null and r.socket_set != null and r.socket_set.resource_path == set.resource_path:
			return r
	return null


static func default() -> AgeRules:
	return load(STRATUM1) as AgeRules if ResourceLoader.exists(STRATUM1) else AgeRules.new()
