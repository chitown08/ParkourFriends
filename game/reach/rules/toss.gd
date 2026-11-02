extends ReachRule
## A friend tosses you (they stay behind): up to toss_height, forward at
## toss_forward_speed, and you can grab an edge at the top. Also reaches relics
## above a place. (Mid-air tosses chained between several friends aren't
## counted yet: they'd reach higher still.)

const MAX_GAP := 12.0


func add_links(map: ReachMap) -> void:
	var m := map.moves
	for from in map.places:
		for to in map.places:
			var across := ReachMap.gap(from, to)
			if from == to or across > MAX_GAP:
				continue
			var rise := to.y - from.y
			var need := rise - m.ledge_max_height if rise > 0.0 else rise
			var distance := map.air_distance(m.toss_height, m.toss_forward_speed, need)
			if distance >= 0.0 and across + ReachMap.JUMP_MARGIN <= distance:
				map.add_link(from, to, "toss", [], 1)
		for target in map.targets:
			if touches(from, target, m.toss_height):
				map.add_link(from, target, "toss", [], 1)
