class_name ReachRule
extends RefCounted
## One way of getting around, for the ReachMap: looks at the map's spots (and
## the level, for things like drainpipes or rails) and adds links between
## them. Each rule is a script in game/reach/rules/; they're all loaded
## automatically, so a new move or item is a new script there.
##
## Keep rules honest: use the movement profile's numbers (map.moves) and the
## map's helpers (air_distance, scramble_height), and add a calibration test
## that plays the real move for a case either side of the limit.

## How far (from your feet) your middle is: what touches a relic.
const MIDDLE := 0.9


func add_links(_map: ReachMap) -> void:
	pass


## True if, standing on `place` with the target `height` above you (no further
## than `across` away from the place's edge), something lifting your feet to
## `peak` gets you close enough to touch it.
static func touches(place: ReachMap.Spot, target: ReachMap.Spot, peak: float, across := 0.0) -> bool:
	var above := target.y - place.y - MIDDLE
	var off := ReachMap.gap(place, target)
	if off > target.reach + across:
		return false
	return above <= peak + target.reach
