extends ReachRule
## Pipes (levels/pipe.gd): big round tubes. You can walk through one, end to
## end (a glass tube joins two towers' roofs), and run round the inside of it,
## going fast enough (Pipe.loop_speed()), to touch what's up its walls or on
## its ceiling.


func add_links(map: ReachMap) -> void:
	for pipe: Pipe in map.level.find_children("*", "Pipe", true, false):
		# The places just outside each end, level with its floor.
		var ends: Array[ReachMap.Spot] = [
			map.place_under(pipe.surface_point(0.0, 0.0) - pipe.along_direction() + Vector3.UP * 0.5),
			map.place_under(pipe.surface_point(pipe.length, 0.0) + pipe.along_direction() + Vector3.UP * 0.5),
		]
		var floor_y := pipe.surface_point(0.0, 0.0).y
		for i in 2:
			if ends[i] != null and absf(ends[i].y - floor_y) > 0.6:
				ends[i] = null # Not level with it: you'd have to climb in (other rules).
		if ends[0] != null and ends[1] != null:
			map.add_link(ends[0], ends[1], "pipe")
			map.add_link(ends[1], ends[0], "pipe")
		# Round the inside: free-running, or only at full flow, or not at all.
		var needs: Array[StringName] = []
		if map.moves.free_run_speed < pipe.loop_speed():
			if map.moves.flow_speed < pipe.loop_speed():
				continue
			needs = [&"flow"]
		for target in map.targets:
			var at := pipe.locate(target.middle())
			if at.x < 0.0 or at.x > pipe.length:
				continue
			# Your middle goes round this far from the tube's middle line.
			if absf(at.z - (pipe.radius - MIDDLE)) > target.reach:
				continue
			for end in ends:
				if end != null:
					map.add_link(end, target, "pipe loop", needs)
