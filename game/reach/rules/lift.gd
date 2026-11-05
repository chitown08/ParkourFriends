extends ReachRule
## Lifts (levels/lift.gd): a hoist or a gondola takes you from the ground at
## its foot up to the roof at its top, alone. (A friend on a hoist's
## counterweight only gets you there faster.)


func add_links(map: ReachMap) -> void:
	for lift: Lift in map.level.find_children("*", "Lift", true, false):
		var foot := map.place_under(lift.rider_top(0.0) + Vector3.UP * 0.5)
		var wall_top := lift.global_transform * Vector3(0.0, lift.height, 0.0)
		var roof := map.place_under(wall_top - lift.out_of_wall() * 1.0 + Vector3.UP * 0.5)
		if foot != null and roof != null and absf(roof.y - wall_top.y) < 0.3:
			map.add_link(foot, roof, lift.kind, [], 0, 0, 0, false)
