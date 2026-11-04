extends ReachRule
## Running jumps between places, and dropping down: across a gap, down to
## anything lower, or up onto (or grabbing the edge of) something higher. Tries
## a running jump, then a readied free-run leap, then a jump at full flow
## (which needs a run-up: "flow"), then the same at full flow in a pack: a
## pack drafting goes a little faster (Player.drafting()), so a bigger pack
## clears a longer gap, all together. Also covers climbing onto something
## right next to you that a jump and a ledge grab reach.

## Gaps wider than this aren't worth checking (nothing jumps them).
const MAX_GAP := 20.0
## Grabbing an edge from a jump, your hands meet the wall this far (metres)
## under where they reach (see ReachMap.wall_up()).
const GRAB_FACE := 1.5


func add_links(map: ReachMap) -> void:
	var m := map.moves
	var flow: Array[StringName] = [&"flow"]
	# [what, how fast you go, how high you jump, what it needs, how many go together]
	var jumps := [
		["jump", m.run_speed, m.jump_height, [] as Array[StringName], 0],
		["leap", m.free_run_speed + m.leap_boost, m.leap_height, [] as Array[StringName], 0],
		["flow jump", m.flow_speed, m.jump_height, flow, 0],
		["flow leap", m.flow_speed + m.leap_boost, m.leap_height, flow, 0],
	]
	for pack in range(2, Player.MOST_DRAFTING + 2):
		var speed := m.flow_speed * Player.drafting(pack - 1)
		jumps.append(["flow jump in a pack of %d" % pack, speed, m.jump_height, flow, pack])
		jumps.append(["flow leap in a pack of %d" % pack, speed + m.leap_boost, m.leap_height, flow, pack])
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
					if rise > jump[2] and not map.wall_up(from, to, m.ledge_max_height + GRAB_FACE):
						continue # (Grabbing the edge: not under a wall leaning out over you. A higher jump might clear it.)
					map.add_link(from, to, jump[0] if rise > 0.0 or across > 0.0 else "drop", jump[3], 0, 0, jump[4])
					break
