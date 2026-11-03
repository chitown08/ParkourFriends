extends ReachRule
## Being caught: a friend already at a place catches you falling short of its
## edge (Player.find_catcher()). Your hands only need to come within
## Player.CATCH_OUT of the wall and Player.CATCH_DOWN below the edge, instead of
## grabbing it yourself, so you can jump a little further, or a little higher.
## Tries the same jumps alone as jump.gd, where none of them makes it unaided.


func add_links(map: ReachMap) -> void:
	var m := map.moves
	var flow: Array[StringName] = [&"flow"]
	# [what, how fast you go, how high you jump, what it needs]
	var jumps := [
		["jump", m.run_speed, m.jump_height, [] as Array[StringName]],
		["leap", m.run_speed + m.leap_boost, m.leap_height, [] as Array[StringName]],
		["flow jump", m.flow_speed, m.jump_height, flow],
		["flow leap", m.flow_speed + m.leap_boost, m.leap_height, flow],
	]
	for from in map.places:
		for to in map.places:
			if from == to:
				continue
			var across := ReachMap.gap(from, to)
			if across > 20.0:
				continue
			var rise := to.y - from.y
			var grab := rise - m.ledge_max_height if rise > 0.0 else rise
			var caught := rise - m.hang_height - Player.CATCH_DOWN
			for jump: Array in jumps:
				var unaided := map.air_distance(jump[2], jump[1], grab)
				if unaided >= 0.0 and (across == 0.0 or across + ReachMap.JUMP_MARGIN <= unaided):
					break # A jump does it without help (jump.gd).
				var distance := map.air_distance(jump[2], jump[1], caught)
				if distance >= 0.0 and across + ReachMap.JUMP_MARGIN <= distance + Player.CATCH_OUT:
					map.add_link(from, to, "%s, caught" % jump[0], jump[3], 0, 1)
					break
