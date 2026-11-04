extends ReachRule
## Launch roofs (levels/ramp.gd): slide (or leap) off the lip at top speed and
## you fly up to the highest launch, and on as far as that flight carries you;
## a friend launching with you can toss you near the top for more (they don't
## get there themselves).


func add_links(map: ReachMap) -> void:
	# The best launch: full speed, plus sliding or a readied leap (not both:
	# a leap is readied on your feet, not in a slide).
	var launch := Ramp.MAX_LAUNCH + maxf(Ramp.SLIDE_BONUS, Ramp.LEAP_BONUS)
	# Off the lip as fast as you can go: sliding down the roof.
	var speed := maxf(map.moves.flow_speed, map.moves.slide_max_speed)
	for ramp: Ramp in map.level.find_children("*", "Ramp", true, false):
		var lip := ramp.global_position + Vector3.UP * ramp.height
		var roof := map.place_under(lip + ramp.global_basis.z * 2.0)
		if roof == null:
			continue
		for target in map.targets:
			var above := target.y - MIDDLE - lip.y
			var away := Vector2(target.middle().x - lip.x, target.middle().z - lip.z).length() - target.reach
			if above <= launch + target.reach:
				# As far as you fly before coming down past it.
				if away <= map.air_distance(launch, speed, minf(above, launch)):
					map.add_link(roof, target, "launch roof")
			elif above <= launch + map.moves.toss_height + target.reach:
				if away <= map.air_distance(launch, speed, launch):
					map.add_link(roof, target, "launch roof + toss", [], 1)
