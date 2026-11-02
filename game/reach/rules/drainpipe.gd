extends ReachRule
## Climbing a drainpipe (levels/drainpipe.gd) from the ground at its foot to
## the roof at its top.


func add_links(map: ReachMap) -> void:
	for pipe: Drainpipe in map.level.find_children("*", "Drainpipe", true, false):
		var foot := map.place_under(pipe.point_at(pipe.global_position.y + 0.5))
		var roof := map.place_under(pipe.point_at(pipe.top() + 0.5) - pipe.out_of_wall() * 1.0)
		map.add_link(foot, roof, "drainpipe")
