extends ReachRule
## Awnings (levels/awning.gd): landing on one (getting onto it is the jump
## rule's) bounces you up: onto (or to grab the edge of) anything near it within
## its bounce (or scrambling up a wall from the top of it, as from a jump).
## Counted at its least bounce (from a standing start: the higher
## bounce of a big drop only helps).

## How far (from above) what you bounce onto can be from it.
const REACH := 2.5


func add_links(map: ReachMap) -> void:
	for awning: Awning in map.level.find_children("*", "Awning", true, false):
		var on := map.place_under(awning.global_position + awning.out_of_wall() * awning.size.y / 2.0 + Vector3.UP * 0.3)
		if on == null or absf(on.y - awning.global_position.y) > 0.3:
			continue
		for to in map.places:
			var rise := to.y - on.y
			if to != on and rise > 0.0 and rise <= map.scramble_height(Awning.BOUNCE) + map.moves.ledge_max_height and ReachMap.gap(on, to) <= REACH:
				map.add_link(on, to, "awning")
