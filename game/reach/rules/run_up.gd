extends ReachRule
## Running up a slope (ReachMap.Slope: steeper than you'd stand around on, no
## steeper than ReachMap.RUN_SLOPE), from a place at its foot to one at its
## top, and back down it. Along the slope itself, so no jump's path to clear.


func add_links(map: ReachMap) -> void:
	for slope in map.slopes:
		var met := map.places_at(slope)
		for low in met:
			for high in met:
				if high.y > low.y + ReachMap.SLOPE_STEP:
					map.add_link(low, high, "run up", [], 0, 0, 0, false)
					map.add_link(high, low, "run down", [], 0, 0, 0, false)
