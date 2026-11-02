extends ReachRule
## Air vents (levels/air_vent.gd): blown straight up from the ground, then
## grab the edge of a roof within reach of the top.

## How far (from above) a roof's edge can be from the vent's middle.
const REACH := 3.0


func add_links(map: ReachMap) -> void:
	for vent: AirVent in map.level.find_children("*", "AirVent", true, false):
		var foot := map.place_under(vent.global_position + Vector3.UP * 0.5)
		var spot := ReachMap.Spot.new()
		spot.area = Rect2(vent.global_position.x, vent.global_position.z, 0.0, 0.0)
		for roof in map.places:
			var rise := roof.y - vent.global_position.y
			if rise > 0.0 and rise <= vent.rise + map.moves.ledge_max_height and ReachMap.gap(spot, roof) <= REACH:
				map.add_link(foot, roof, "air vent")
