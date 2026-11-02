extends ReachRule
## The hanging chain: friends already up on a place lower themselves over its
## edge, hanging from each other's feet, until the bottom one is low enough for
## someone to scramble up and grab; then everyone below climbs them. So it
## needs friends already there: one more for every hang_height further down.

const NEXT_TO := 1.0
## The most friends a chain is worth checking for.
const MOST_FRIENDS := 8


func add_links(map: ReachMap) -> void:
	var m := map.moves
	# The highest feet you can grab: a leap scramble's top, plus your arms, plus a reach.
	var grab := map.scramble_height(m.leap_height) + m.hang_height + Player.CHAIN_GRAB_REACH
	for from in map.places:
		for to in map.places:
			var rise := to.y - from.y
			if from == to or rise <= 0.0 or ReachMap.gap(from, to) > NEXT_TO:
				continue
			# Each friend hanging puts the lowest feet hang_height further down.
			var friends := ceili((rise - grab) / m.hang_height)
			if friends >= 1 and friends <= MOST_FRIENDS:
				map.add_link(from, to, "hanging chain of %d" % friends, [], 0, friends)
