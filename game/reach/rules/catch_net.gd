extends ReachRule
## Catch nets (levels/catch_net.gd): landing in one (dropping onto it is the
## jump rule's) bounces you back up to the roof over it, in at the wall.

## How far (from above) the roof's edge can be from the net.
const REACH := 1.0


func add_links(map: ReachMap) -> void:
	for net: CatchNet in map.level.find_children("*", "CatchNet", true, false):
		var on := map.place_under(net.global_position + net.out_of_wall() * net.size.y / 2.0 + Vector3.UP * 0.5)
		if on == null:
			continue
		for roof in map.places:
			var rise := roof.y - on.y
			if rise > 0.0 and rise <= net.rise + map.moves.ledge_max_height and ReachMap.gap(on, roof) <= REACH:
				map.add_link(on, roof, "catch net")
