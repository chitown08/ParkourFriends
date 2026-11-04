extends ReachRule
## Scrambling up a wall too tall to grab from a jump: from a place right next
## to something taller, jump (or leap) into its wall, run up it and grab the top.
## (Not up a wall leaning out over you: see ReachMap.wall_up().)

## Places this close (from above) count as side by side.
const NEXT_TO := 1.0


func add_links(map: ReachMap) -> void:
	var m := map.moves
	for from in map.places:
		for to in map.places:
			var rise := to.y - from.y
			if from == to or rise <= 0.0 or ReachMap.gap(from, to) > NEXT_TO:
				continue
			if rise > map.scramble_height(m.leap_height) + m.ledge_max_height or not map.wall_up(from, to, rise):
				continue # (Too tall, or it leans out over you.)
			if rise <= map.scramble_height(m.jump_height) + m.ledge_max_height:
				map.add_link(from, to, "scramble")
			else:
				map.add_link(from, to, "leap scramble")
