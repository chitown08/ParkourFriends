extends ReachRule
## Leg-ups: friends brace at the foot of a wall (each extra one on the shoulders
## of the last), someone runs in, steps up to the top one's hands and is
## launched leg_up_height up the wall into a scramble. Those bracing stay
## behind (a hanging chain from the top can bring them up after).

## Places this close (from above) count as side by side.
const NEXT_TO := 1.0


func add_links(map: ReachMap) -> void:
	var m := map.moves
	for from in map.places:
		for to in map.places:
			var rise := to.y - from.y
			if from == to or rise <= 0.0 or ReachMap.gap(from, to) > NEXT_TO:
				continue
			for braced in range(1, Player.MOST_BRACED + 1):
				if rise <= map.scramble_height(hands(braced) + m.leg_up_height) + m.ledge_max_height:
					map.add_link(from, to, "leg-up from %d" % braced, [], braced)
					break


## How high the top friend's hands are with `braced` friends in the stack.
static func hands(braced: int) -> float:
	return Player.BRACE_HANDS + (braced - 1) * Player.BRACE_SHOULDERS
