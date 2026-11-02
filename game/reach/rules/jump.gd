extends ReachRule
## Running jumps between places, and dropping down: across a gap, down to
## anything lower, or up onto (or grabbing the edge of) something higher. Tries
## a running jump, then a readied free-run leap, then a jump at full flow
## (which needs a run-up: "flow"). Also covers climbing onto something right
## next to you that a jump and a ledge grab reach.

## Gaps wider than this aren't worth checking (nothing jumps them).
const MAX_GAP := 20.0


func add_links(map: ReachMap) -> void:
	var m := map.moves
	# [what, how fast you go, how high you jump, what it needs]
	var jumps := [
		["jump", m.run_speed, m.jump_height, [] as Array[StringName]],
		["leap", m.run_speed + m.leap_boost, m.leap_height, [] as Array[StringName]],
		["flow jump", m.flow_speed, m.jump_height, [&"flow"] as Array[StringName]],
		["flow leap", m.flow_speed + m.leap_boost, m.leap_height, [&"flow"] as Array[StringName]],
	]
	for from in map.places:
		for to in map.places:
			if from == to:
				continue
			var across := ReachMap.gap(from, to)
			if across > MAX_GAP:
				continue
			var rise := to.y - from.y
			for jump: Array in jumps:
				# Going up, your hands only need to reach the edge (a ledge grab).
				var need := rise - m.ledge_max_height if rise > 0.0 else rise
				var distance := map.air_distance(jump[2], jump[1], need)
				if distance >= 0.0 and (across == 0.0 or across + ReachMap.JUMP_MARGIN <= distance):
					map.add_link(from, to, jump[0] if rise > 0.0 or across > 0.0 else "drop", jump[3])
					break
