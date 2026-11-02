extends ReachRule
## The glider (items/abilities/glide.gd): from any place, glide down to a lower
## one, about five metres forward for every metre down. Needs &"glider".


func add_links(map: ReachMap) -> void:
	var glide: Script = load("res://items/abilities/glide.gd")
	var per_metre_down: float = glide.SPEED / glide.SINK_SPEED
	for from in map.places:
		for to in map.places:
			var drop := from.y - to.y
			if from != to and drop > 0.0 and ReachMap.gap(from, to) + ReachMap.JUMP_MARGIN <= drop * per_metre_down:
				map.add_link(from, to, "glide", [&"glider"])
