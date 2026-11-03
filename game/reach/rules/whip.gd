extends ReachRule
## Crack the whip: a line of friends runs at full flow along the edge, the
## leader turns hard, and the one on the end is flung off across a gap, faster
## the longer the line (Player.whip_boost()), with a full leap's lift. The rest of
## the line stays behind.


func add_links(map: ReachMap) -> void:
	var m := map.moves
	var flow: Array[StringName] = [&"flow"]
	for from in map.places:
		for to in map.places:
			if from == to:
				continue
			var across := ReachMap.gap(from, to)
			if across == 0.0 or across > 40.0:
				continue
			var rise := to.y - from.y
			var need := rise - m.ledge_max_height if rise > 0.0 else rise
			for line in range(2, Player.MOST_IN_LINE + 1):
				var distance := map.air_distance(m.leap_height, m.flow_speed * Player.whip_boost(line - 1), need)
				if distance >= 0.0 and across + ReachMap.JUMP_MARGIN <= distance:
					map.add_link(from, to, "whip from a line of %d" % line, flow, line - 1, 0, line)
					break
