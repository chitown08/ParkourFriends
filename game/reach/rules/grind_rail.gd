extends ReachRule
## Grind rails: land on one from the place at its top and ride it down to the
## place at its bottom; push (or hop) back up it. Relics hanging over a rail
## are touched on the way past.


func add_links(map: ReachMap) -> void:
	for rail: GrindRail in map.level.find_children("*", "GrindRail", true, false):
		var bottom := map.place_under(rail.bottom() + Vector3.DOWN * 0.2 + Vector3.UP * 0.5)
		# The top's roof is where you jump on from: just behind the rail's start.
		var way_in := (rail.top() - rail.point_at(0.05))
		var top := map.place_under(rail.top() + Vector3(way_in.x, 0.0, way_in.z).normalized() * 2.0 + Vector3.UP * 1.0)
		map.add_link(top, bottom, "grind rail")
		map.add_link(bottom, top, "grind rail (up)")
		for target in map.targets:
			var along := rail.point_at(rail.closest_t(target.middle()))
			if along.distance_to(target.middle()) <= target.reach + MIDDLE + GrindRail.RAIL_RADIUS:
				map.add_link(top, target, "grind rail")
