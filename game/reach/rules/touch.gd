extends ReachRule
## Relics you can touch from a place: walk into one hovering over it, or jump
## (or leap) up to one above it.


func add_links(map: ReachMap) -> void:
	for target in map.targets:
		for from in map.places:
			if touches(from, target, map.moves.leap_height):
				map.add_link(from, target, "touch")
