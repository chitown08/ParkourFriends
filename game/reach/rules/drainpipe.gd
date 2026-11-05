extends ReachRule
## Climbing a drainpipe (levels/drainpipe.gd), or scaffolding (levels/
## scaffold.gd, climbed the same way), to the roof at its top: from the ground
## at its foot; or grabbing it from a jump, from somewhere across from it (a
## lower roof next door) with its face in reach (a running jump, or a readied
## leap) at a height you can hold on at.


func add_links(map: ReachMap) -> void:
	var m := map.moves
	var jumps := [["jump", m.run_speed, m.jump_height], ["leap", m.free_run_speed + m.leap_boost, m.leap_height]]
	for pipe: Drainpipe in map.level.find_children("*", "Drainpipe", true, false):
		var foot := map.place_under(pipe.point_at(pipe.global_position.y + 0.5))
		var wall := Vector3(pipe.global_position.x, pipe.top() + 0.5, pipe.global_position.z) # (Its foot is against the wall.)
		var roof := map.place_under(wall - pipe.out_of_wall() * 1.0)
		var how := "scaffolding" if pipe is Scaffold else "drainpipe"
		map.add_link(foot, roof, how)
		if roof == null:
			continue
		# Where you can grab it: along its face (just the pipe, for a pipe).
		var out := pipe.out_of_wall()
		var across := Vector3(out.z, 0.0, -out.x)
		var side: float = (pipe as Scaffold).width / 2.0 - Scaffold.SIDE_IN if pipe is Scaffold else 0.0
		var lowest := pipe.global_position.y + 0.5 # (Where you can hold on: see Player.find_drainpipe().)
		var highest := pipe.top() - 1.0
		for from in map.places:
			if from == foot or from == roof or from.y < lowest:
				continue
			for along: float in ([-side, 0.0, side] if side > 0.0 else [0.0]):
				var grab := pipe.point_at(0.0) + across * along
				var edge := ReachMap._closest_in(from.area, Vector2(grab.x, grab.z))
				var away := Vector2(grab.x, grab.z) - edge
				if away.dot(Vector2(out.x, out.z)) > -0.01:
					continue # (Behind its face: from its own roof, or round the side.)
				# You grab it at your height when you get there, down to `highest`.
				var rise := minf(0.0, highest - from.y)
				var done := false
				for jump: Array in jumps:
					var distance := map.air_distance(jump[2], jump[1], rise)
					if away.length() + ReachMap.JUMP_MARGIN > distance + m.pipe_grab_reach:
						continue
					var at := from.y + ReachMap.PATH_MIDDLE + maxf(rise, 0.0)
					if map.segment_clear(Vector3(edge.x, at, edge.y), Vector3(grab.x, at, grab.z) + out * 0.5):
						map.add_link(from, roof, "%s (grabbed from a %s)" % [how, jump[0]], [], 0, 0, 0, false)
						done = true
						break
				if done:
					break
