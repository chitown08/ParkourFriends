extends GameTest
## The skyline: the futuristic quarter of the rooftop district
## (tools/gen_district.gd: SKYSCRAPERS): skyscrapers on podiums, sky lifts,
## spiral ramps, and glass bridges high over the avenues.

const GENERATOR := preload("res://tools/gen_district.gd")

var states_entered: Array[StringName] = []


func before_each() -> void:
	await super()
	main.leave_game()
	await ticks(5)
	main.start_solo("rooftop_district")
	await ticks(10)
	player = main.get_node("Players/1")
	player.set_profile(SUPERHUMAN)
	player.state_changed.connect(func(new_state: StringName) -> void: states_entered.append(new_state))


func test_the_skyline_is_across_the_boulevard() -> void:
	var old_town := _old_town()
	for spec: Array in GENERATOR.SKYSCRAPERS:
		var sky := _skyscraper(spec)
		expect(sky != null, "there's a skyscraper in block %s" % spec[0])
		if sky == null:
			continue
		expect(sky.get_meta(&"shape", "") == "skyscraper", "%s is marked a skyscraper" % sky.name)
		var podium := sky.get_parent() as CSGShape3D
		var block := ReachMap._bounds(podium)
		expect(block.position.x >= old_town.end.x + GENERATOR.AVENUE - 0.1,
				"%s is east of the old town, across the boulevard (%.0f, the old town ends at %.0f)" % [podium.name, block.position.x, old_town.end.x])
		var area := Rect2(block.position.x, block.position.z, block.size.x, block.size.z)
		for part: CSGShape3D in podium.find_children("*", "CSGShape3D", true, false):
			var box := ReachMap._bounds(part)
			expect(area.grow(0.1).encloses(Rect2(box.position.x, box.position.z, box.size.x, box.size.z)), "its %s keeps to its block" % part.name)
	var ground := ReachMap._bounds(main.level.get_node("Street/Ground"))
	expect(ground.end.x > ReachMap._bounds(_skyscraper(GENERATOR.SKYSCRAPERS.back()).get_parent()).end.x + 10.0, "and the street runs on under it")


func test_skyscrapers_are_tall_and_the_spire_tallest() -> void:
	var spire := 0.0
	for spec: Array in GENERATOR.SKYSCRAPERS:
		var top: float = (spec[2] as Array).back()[1] * GENERATOR.STOREY
		expect(top >= 70.0, "block %s's skyscraper is %.0f m tall" % [spec[0], top])
		spire = maxf(spire, top)
	expect(spire >= 120.0, "the spire is %.0f m tall" % spire)
	for b: Node in main.level.get_node("Buildings").get_children():
		if b is CSGShape3D and not b.name.begins_with("Podium"):
			expect(ReachMap._bounds(b).end.y < spire - 40.0, "%s is well under the spire" % b.name)


func test_a_spiral_is_no_steeper_than_you_can_run_up() -> void:
	for spec: Array in GENERATOR.SKYSCRAPERS:
		if spec[1] != "spiral":
			continue
		var stage: Array = spec[2][0]
		var from := GENERATOR.FUTURE_PODIUM * GENERATOR.STOREY
		var faces: int = GENERATOR.spiral_faces([stage[0], from, stage[1] * GENERATOR.STOREY])
		var steepness := rad_to_deg(atan((stage[1] * GENERATOR.STOREY - from) / faces / (2.0 * stage[0])))
		expect(faces <= 3, "%s's spiral goes round at most three walls (%d): then a level walk" % [spec[0], faces])
		expect(steepness <= GENERATOR.SPIRAL_STEEPEST and steepness > ReachMap.STAND_SLOPE + 5.0, "it's a slope you can run up, %.0f°" % steepness)


func test_a_spiral_ends_in_a_level_walk_beside_the_terrace() -> void:
	var map := ReachMap.build(main.level, SUPERHUMAN)
	for spec: Array in GENERATOR.SKYSCRAPERS:
		if spec[1] != "spiral":
			continue
		var sky := _skyscraper(spec)
		var stage: Array = spec[2][0]
		var faces: int = GENERATOR.spiral_faces([stage[0], GENERATOR.FUTURE_PODIUM * GENERATOR.STOREY, stage[1] * GENERATOR.STOREY])
		var walk := _places(map, "%s/%s_Ramp%d" % [sky.get_parent().name, sky.name, faces + 1])
		var terrace := _terrace_named(map, "%d%d" % [spec[0].x, spec[0].y])
		expect(walk.size() == 1, "%s's spiral ends in a level walk (%d places)" % [sky.name, walk.size()])
		if walk.size() != 1:
			continue
		expect_near(walk[0].y, terrace[0].y, 0.05, "%s: level with the terrace" % sky.name)
		expect(maxf(walk[0].area.size.x, walk[0].area.size.y) >= 2.0 * stage[0] - 1.0, "%s: all along its wall (%s)" % [sky.name, walk[0].area])
		expect(terrace.any(func(spot: ReachMap.Spot) -> bool: return ReachMap.gap(spot, walk[0]) < 0.1), "%s: right beside the terrace" % sky.name)


func test_up_every_skyscraper_alone_each_its_own_way() -> void:
	var map := ReachMap.build(main.level, SUPERHUMAN)
	var alone := map.solve(map.place_named("Ground"), 1)
	for spec: Array in GENERATOR.SKYSCRAPERS:
		var sky := _skyscraper(spec)
		var podium := str(sky.get_parent().name)
		var stages: Array = [sky.name] + range(2, (spec[2] as Array).size() + 1).map(func(i: int) -> String: return "%s_%d" % [sky.name, i])
		for stage: String in stages:
			var tops := _places(map, "%s/%s" % [podium, stage])
			expect(not tops.is_empty() and tops.all(func(spot: ReachMap.Spot) -> bool: return alone.has(spot)),
					"%s's %s: you can get up there alone (%d tops)" % [podium, stage, tops.size()])
		var terrace := _places(map, "%s/%s" % [podium, sky.name])
		var up_from_podium := func(how: String) -> bool:
			return map.links.any(func(link: ReachMap.Link) -> bool:
				return link.how == how and link.from.name.begins_with(podium) and not link.from.name.contains("/") and link.to in terrace)
		match spec[1]:
			"lift": expect(up_from_podium.call("air vent"), "%s: a sky lift from its podium up to its terrace" % sky.name)
			"spiral":
				expect(not up_from_podium.call("air vent"), "%s: no lift from its podium" % sky.name)
				expect(map.links.any(func(link: ReachMap.Link) -> bool:
					return link.how == "run up" and link.to in terrace), "%s: up its spiral onto its terrace" % sky.name)
			"bridges":
				var ways_in := map.links.filter(func(link: ReachMap.Link) -> bool:
						return link.to in terrace and not link.from.name.begins_with(podium + "/") and link.from.y < link.to.y - 1.0 \
							and not link.from.name.begins_with("Bridge") and not (link.how == "run up" and link.from.name.contains("/Sky")))
				expect(ways_in.is_empty(), "%s: the only way in is across a bridge (level, or up a sloping one from another terrace) (%s)" % [sky.name, ways_in.map(func(link: ReachMap.Link) -> String: return "%s from %s" % [link.how, link.from.name])])
		# And a sky lift from each terrace up to the next stage.
		for i in range(1, stages.size()):
			expect(map.links.any(func(link: ReachMap.Link) -> bool:
				return link.how == "air vent" and link.from.name.begins_with("%s/%s" % [podium, stages[i - 1]]) and link.to.name.begins_with("%s/%s" % [podium, stages[i]])),
				"%s: a sky lift from its %s up to its %s" % [sky.name, stages[i - 1], stages[i]])


func test_glass_bridges_join_the_terraces() -> void:
	var map := ReachMap.build(main.level, SUPERHUMAN)
	var bridges: Array = main.level.get_node("Bridges").get_children()
	expect(bridges.size() == 7, "a bridge between each two skyscrapers side by side (%d)" % bridges.size())
	for bridge: CSGBox3D in bridges:
		expect(bridge.material == load("res://materials/glass.tres"), "%s is glass" % bridge.name)
		var ends := str(bridge.name).trim_prefix("Bridge").split("_")
		var a := _terrace_named(map, ends[0])
		var b := _terrace_named(map, ends[1])
		var level := is_equal_approx(a[0].y, b[0].y)
		var how := "touch" if level else "run up"
		var walk := func(from: Array, to: Array) -> bool:
			return map.links.any(func(link: ReachMap.Link) -> bool: return link.from in from and str(link.to.name).begins_with(str(bridge.name))) \
				and map.links.any(func(link: ReachMap.Link) -> bool: return str(link.from.name).begins_with(str(bridge.name)) and link.to in to) \
				or map.links.any(func(link: ReachMap.Link) -> bool: return link.from in from and link.to in to)
		expect(walk.call(a, b) and walk.call(b, a), "across %s both ways (%s)" % [bridge.name, how])


func test_run_up_a_spiral_onto_the_terrace() -> void:
	var spec: Array = GENERATOR.SKYSCRAPERS.filter(func(s: Array) -> bool: return s[1] == "spiral")[0]
	var sky := _skyscraper(spec)
	var middle := sky.global_position
	var half: float = spec[2][0][0]
	var top: float = spec[2][0][1] * GENERATOR.STOREY
	var out: float = half + GENERATOR.SPIRAL_WIDTH / 2.0
	# Clockwise from its north-east corner, then in onto the terrace.
	var way := [Vector2(out, out), Vector2(-out, out), Vector2(-out, -out), Vector2(0.0, -half + 2.0)]
	await place(Vector3(middle.x + out, GENERATOR.FUTURE_PODIUM * GENERATOR.STOREY + 0.05, middle.z - out + 1.0), yaw_for(Vector3.BACK))
	states_entered.clear()
	Input.action_press(&"move_forward")
	var next := 0
	var made_it := false
	for i in 60 * 30:
		var at := Vector2(player.global_position.x - middle.x, player.global_position.z - middle.z)
		if next < way.size() - 1 and at.distance_to(way[next]) < 1.5:
			next += 1
		var heading: Vector2 = way[next] - at
		player.camera_rig.yaw = yaw_for(Vector3(heading.x, 0.0, heading.y))
		await ticks(1)
		if player.is_on_floor() and player.global_position.y > top - 0.3 and absf(at.x) < half and absf(at.y) < half:
			made_it = true
			break
	release_all()
	expect(made_it, "round and up the spiral onto the terrace at %.0f m (at %s, %d of the way, via %s)" % [top, player.global_position, next, states_entered.slice(-8)])


func test_a_sky_lift_carries_you_to_the_top() -> void:
	var spire: Array = GENERATOR.SKYSCRAPERS.filter(func(s: Array) -> bool: return (s[2] as Array).size() == 3)[0]
	var sky := _skyscraper(spire)
	var lift := main.level.get_node("AirVents/%s_Lift3" % sky.name) as AirVent
	var top: float = spire[2][2][1] * GENERATOR.STOREY
	await place(lift.global_position + Vector3(0, 0.5, 1.0), yaw_for(Vector3.FORWARD)) # (The terrace is narrow.)
	Input.action_press(&"move_forward") # Onto it, pushing toward the wall.
	var highest := -INF
	for i in 60 * 8:
		await ticks(1)
		highest = maxf(highest, player.global_position.y)
		if player.state.name == &"Hang":
			Input.action_press(&"jump") # Pull up.
		if player.is_on_floor() and player.global_position.y > top - 0.2:
			break
	release_all()
	expect(player.global_position.y > top - 0.2, "up the sky lift onto the spire's top, %.0f m (at %s, highest %.1f)" % [top, player.global_position, highest])


func test_run_up_a_sloping_glass_bridge() -> void:
	var map := ReachMap.build(main.level, SUPERHUMAN)
	var bridge: CSGBox3D
	for b: CSGBox3D in main.level.get_node("Bridges").get_children():
		if absf(b.global_basis.z.normalized().y) > 0.05:
			bridge = b
			break
	expect(bridge != null, "a bridge slopes")
	if bridge == null:
		return
	var along := bridge.global_basis.z.normalized()
	if along.y < 0.0:
		along = -along
	# (Its top's middle line, from its low end to its high one.)
	var surface := bridge.global_position + bridge.global_basis.y.normalized() * bridge.size.y / 2.0
	var low := surface - along * bridge.size.z / 2.0
	var high := surface + along * bridge.size.z / 2.0
	var flat := Vector3(along.x, 0.0, along.z).normalized()
	await place(low - flat * 3.0 + Vector3.UP * 0.05, yaw_for(flat))
	states_entered.clear()
	Input.action_press(&"move_forward")
	var made_it := false
	for i in 60 * 12:
		await ticks(1)
		if player.is_on_floor() and player.global_position.y > high.y - 0.3:
			made_it = true
			break
	release_all()
	expect(made_it, "up %s to %.0f m (at %s, via %s)" % [bridge.name, high.y, player.global_position, states_entered.slice(-8)])


# --- Helpers ----------------------------------------------------------------------------

func _skyscraper(spec: Array) -> CSGShape3D:
	var block: Vector2i = spec[0]
	return main.level.get_node_or_null("Buildings/Podium%d%d/Sky%d%d" % [block.x, block.y, block.x, block.y]) as CSGShape3D


## The old town, from above (every building but the skyline's).
func _old_town() -> AABB:
	var box := AABB()
	var first := true
	for b: Node in main.level.get_node("Buildings").get_children():
		if b is CSGShape3D and not b.name.begins_with("Podium"):
			box = ReachMap._bounds(b) if first else box.merge(ReachMap._bounds(b))
			first = false
	return box


## The places called `name` or pieces of it (`name#2`...).
func _places(map: ReachMap, name: String) -> Array:
	return map.places.filter(func(spot: ReachMap.Spot) -> bool: return spot.name == name or spot.name.begins_with(name + "#"))


## The terrace of the skyscraper in block "xy" (its first stage's top).
func _terrace_named(map: ReachMap, block: String) -> Array:
	return _places(map, "Podium%s/Sky%s" % [block, block])
