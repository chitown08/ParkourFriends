extends ReachRule
## The glider (items/abilities/glide.gd): from any place, glide down to a lower
## one, about five metres forward for every metre down, up to MAX_GLIDE away
## (further: glide there in hops, landing on the way). Needs &"glider".

## The furthest glide it checks (from above, metres): about six seconds'
## gliding. (From downtown's tops you could glide most of the way across
## the district; checking every one of those paths took most of a minute.)
const MAX_GLIDE := 100.0


func add_links(map: ReachMap) -> void:
	var glide: Script = load("res://items/abilities/glide.gd")
	var per_metre_down: float = glide.SPEED / glide.SINK_SPEED
	for from in map.places:
		for to in map.places:
			var drop := from.y - to.y
			if from == to or drop <= 0.0:
				continue
			var across := ReachMap.gap(from, to)
			if across <= MAX_GLIDE and across + ReachMap.JUMP_MARGIN <= drop * per_metre_down:
				map.add_link(from, to, "glide", [&"glider"])
