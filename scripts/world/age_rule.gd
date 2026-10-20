@tool
class_name AgeRule
extends Resource
## How one socket set ages with the years (ENVIRONMENT_PLAN.md 6.3, 6.5.6):
## lamps go lit → failing → dark. Only untouched things age, and only ever
## forward along the chain.

## Sockets using this set age by this rule (lamp_state.tres).
@export var socket_set: SocketSet
## Entry labels from new to old ("lit", "failing", "dark").
@export var chain: PackedStringArray = []
## One curve per step after the first: chance (y) that a thing has reached
## that step after x years. Each should be at or below the one before it.
@export var step_chance: Array[Curve] = []


## The chain position a thing reaches after `years`, given its fixed draw `u`
## (0..1): the furthest step whose chance is above u. Monotone in years.
func step_at(years: float, u: float) -> int:
	var step: int = 0
	for k: int in step_chance.size():
		var c: Curve = step_chance[k]
		if c != null and c.sample(clampf(years, c.min_domain, c.max_domain)) > u:
			step = k + 1
	return step
