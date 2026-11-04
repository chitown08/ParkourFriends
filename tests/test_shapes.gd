extends GameTest
## Buildings that aren't plain boxes: round ones (a cylinder), a dome on a
## roof, a tier set back on top of a building, a courtyard cut down through
## one. The checker (game/reach/) knows where you can stand on each and what's
## in the way; and in the game you get onto them as it says. Built high above
## the test course, each two storeys tall (7 m: a scramble from the ground).

const FLOOR_Y := 300.0
const STOREYS := 7.0

var states_entered: Array[StringName] = []


func before_each() -> void:
	await super()
	player.set_profile(SUPERHUMAN)
	player.state_changed.connect(func(new_state: StringName) -> void: states_entered.append(new_state))
	var ground := _shape(CSGBox3D.new(), "ShapeGround", main.level, Vector3(0, FLOOR_Y - 0.5, -50))
	(ground as CSGBox3D).size = Vector3(200, 1, 200)
	ground.remove_from_group(&"reach_solid")
	# Round: 8 m across... in radius.
	var rotunda := _shape(CSGCylinder3D.new(), "Rotunda", main.level, Vector3(0, FLOOR_Y + STOREYS / 2.0, -30)) as CSGCylinder3D
	rotunda.radius = 8.0
	rotunda.height = STOREYS
	rotunda.sides = 32
	# A shallow dome on a roof (its middle 6 m under the roof: its top 2 m over it).
	var domed := _box("Domed", main.level, Vector3(40, FLOOR_Y + STOREYS / 2.0, -30), Vector3(20, STOREYS, 20))
	var dome := _shape(CSGSphere3D.new(), "Dome", domed, Vector3(40, FLOOR_Y + STOREYS - 6.0, -30)) as CSGSphere3D
	dome.radius = 8.0
	dome.radial_segments = 32
	dome.rings = 16
	# A tier two storeys tall set back 4 m on top.
	var stepped := _box("Stepped", main.level, Vector3(-40, FLOOR_Y + STOREYS / 2.0, -30), Vector3(20, STOREYS, 20))
	_box("Tier", stepped, Vector3(-40, FLOOR_Y + STOREYS * 1.5, -30), Vector3(12, STOREYS, 12))
	# A courtyard right through the middle.
	var yard := _box("Yard", main.level, Vector3(0, FLOOR_Y + STOREYS / 2.0, -80), Vector3(24, STOREYS, 24))
	var courtyard := _box("Courtyard", yard, Vector3(0, FLOOR_Y + STOREYS / 2.0, -80), Vector3(10, STOREYS + 2.0, 10))
	courtyard.operation = CSGShape3D.OPERATION_SUBTRACTION
	await ticks(3) # (CSG builds its collision a moment later.)


func test_a_round_buildings_top_is_a_place() -> void:
	var map := ReachMap.build(main.level, SUPERHUMAN)
	var tops := map.places.filter(func(spot: ReachMap.Spot) -> bool: return spot.name.begins_with("Rotunda"))
	expect(tops.size() == 2, "two rectangles crossed, says %s" % [tops.map(func(spot: ReachMap.Spot) -> String: return spot.name)])
	var area := 0.0
	for spot: ReachMap.Spot in tops:
		expect_near(spot.y, FLOOR_Y + STOREYS, 0.01, "%s at the top" % spot.name)
		area += spot.area.get_area()
		for corner in [spot.area.position, spot.area.end, Vector2(spot.area.position.x, spot.area.end.y), Vector2(spot.area.end.x, spot.area.position.y)]:
			expect(corner.distance_to(Vector2(0, -30)) <= 8.01, "%s's corner %s is on the roof" % [spot.name, corner])
	expect(area > 0.5 * PI * 64.0, "between them, most of it (%.0f of %.0f m²)" % [area, PI * 64.0])


func test_a_round_building_is_round() -> void:
	var map := ReachMap.build(main.level, SUPERHUMAN)
	expect(map.is_solid(Vector3(7.5, FLOOR_Y + 3.0, -30)), "just inside its wall: solid")
	expect(not map.is_solid(Vector3(6.5, FLOOR_Y + 3.0, -23.5)), "but its square's corner isn't")
	expect(not map.is_solid(Vector3(0, FLOOR_Y + STOREYS + 0.5, -30)), "nor over its roof")


func test_onto_a_round_roof_and_off_it() -> void:
	var map := ReachMap.build(main.level, SUPERHUMAN)
	expect(_linked(map, "ShapeGround", "Rotunda"), "a scramble up its wall")
	expect(_linked(map, "Rotunda", "ShapeGround"), "and down")


func test_a_domes_crown_is_a_place() -> void:
	var map := ReachMap.build(main.level, SUPERHUMAN)
	var crown := map.place_named("Domed/Dome")
	expect(crown != null, "the top of the dome is a place")
	if crown:
		expect_near(crown.y, FLOOR_Y + STOREYS + 2.0 - ReachMap.DOME_CROWN, 0.01, "a little under its very top")
		expect(crown.area.get_area() >= ReachMap.MIN_PLACE_AREA, "big enough to stand on")
	var roof := map.place_named("Domed")
	expect(roof != null and is_equal_approx(roof.area.get_area(), 400.0), "the roof round it is all still a place (you run up the dome from it)")
	expect(map.place_named("Domed#2") == null, "in one piece")
	expect(_linked(map, "Domed", "Domed/Dome"), "up onto the dome")
	expect(_linked(map, "Domed/Dome", "Domed"), "and back down")
	expect(map.is_solid(Vector3(40, FLOOR_Y + STOREYS + 1.5, -30)), "the dome's solid")
	expect(not map.is_solid(Vector3(46, FLOOR_Y + STOREYS + 1.5, -36)), "round, not square")


func test_a_tier_on_top() -> void:
	var map := ReachMap.build(main.level, SUPERHUMAN)
	var tier := map.place_named("Stepped/Tier")
	expect(tier != null and is_equal_approx(tier.y, FLOOR_Y + 2.0 * STOREYS), "the tier's top is a place")
	var pieces := map.places.filter(func(spot: ReachMap.Spot) -> bool: return spot.name == "Stepped" or spot.name.begins_with("Stepped#"))
	var area := 0.0
	for spot: ReachMap.Spot in pieces:
		area += spot.area.get_area()
		expect(not spot.area.intersects(Rect2(-46, -36, 12, 12)), "%s isn't under the tier" % spot.name)
	expect_near(area, 400.0 - 144.0, 0.1, "the roof round the tier is")
	expect(_linked(map, "Stepped", "Stepped/Tier"), "a scramble from the roof up onto the tier")


func test_a_courtyard_down_through() -> void:
	var map := ReachMap.build(main.level, SUPERHUMAN)
	var area := 0.0
	for spot: ReachMap.Spot in map.places.filter(func(s: ReachMap.Spot) -> bool: return s.name == "Yard" or s.name.begins_with("Yard#")):
		area += spot.area.get_area()
		expect(not spot.area.has_point(Vector2(0, -80)), "%s doesn't cover the courtyard" % spot.name)
	expect_near(area, 576.0 - 100.0, 0.1, "the roof round it is a place")
	expect(not map.is_solid(Vector3(0, FLOOR_Y + 3.0, -80)), "the courtyard's open")
	expect(map.is_solid(Vector3(9, FLOOR_Y + 3.0, -80)), "the building round it isn't")


func test_a_round_tower_in_the_way() -> void:
	_box("WestRoof", main.level, Vector3(-60, FLOOR_Y + 3.5, -100), Vector3(16, 7, 4))
	_box("EastRoof", main.level, Vector3(-38, FLOOR_Y + 3.5, -100), Vector3(16, 7, 4))
	await ticks(3)
	var map := ReachMap.build(main.level, SUPERHUMAN)
	expect(_linked(map, "WestRoof", "EastRoof"), "test setup: 6 m apart, a jump")
	var tower := _shape(CSGCylinder3D.new(), "Chimney", main.level, Vector3(-49, FLOOR_Y + 15, -100)) as CSGCylinder3D
	tower.radius = 2.9
	tower.height = 30.0
	await ticks(3)
	map = ReachMap.build(main.level, SUPERHUMAN)
	expect(not _linked(map, "WestRoof", "EastRoof"), "with a tall round chimney in the gap (and the roofs too narrow to go round it), no way across")


# --- In the game ------------------------------------------------------------------------

func test_scramble_up_a_round_wall() -> void:
	expect(await _free_run_until_on(Vector3(0, FLOOR_Y + 0.05, -14), Vector3.FORWARD, FLOOR_Y + STOREYS),
			"up the curved wall onto the roof (at %s, via %s)" % [player.global_position, states_entered])


func test_run_up_a_dome() -> void:
	await place(Vector3(40, FLOOR_Y + STOREYS + 0.05, -21.5), FACE_NORTH)
	Input.action_press(&"move_forward")
	var highest := -INF
	for i in 60 * 3:
		await ticks(1)
		if player.is_on_floor():
			highest = maxf(highest, player.global_position.y)
	release_all()
	expect(highest > FLOOR_Y + STOREYS + 2.0 - ReachMap.DOME_CROWN - 0.2, "running up and over the top (highest %.2f above the roof)" % (highest - FLOOR_Y - STOREYS))


func test_climb_onto_a_tier() -> void:
	expect(await _free_run_until_on(Vector3(-40, FLOOR_Y + STOREYS + 0.05, -21), Vector3.FORWARD, FLOOR_Y + 2.0 * STOREYS),
			"from the roof up onto the tier (at %s, via %s)" % [player.global_position, states_entered])


func _free_run_until_on(start: Vector3, along: Vector3, height: float) -> bool:
	await place(start, yaw_for(along))
	states_entered.clear()
	Input.action_press(&"free_run")
	var made_it := false
	for i in 60 * 4:
		await ticks(1)
		if player.state.name == &"Hang":
			Input.action_press(&"jump")
		if player.is_on_floor() and player.global_position.y > height - 0.2:
			made_it = true
			break
	release_all()
	return made_it


func _linked(map: ReachMap, from: String, to: String) -> bool:
	return map.links.any(func(link: ReachMap.Link) -> bool: return link.from.name == from and link.to.name == to)


func _box(box_name: String, parent: Node, at: Vector3, size: Vector3) -> CSGBox3D:
	var box := _shape(CSGBox3D.new(), box_name, parent, at) as CSGBox3D
	box.size = size
	return box


## Adds `shape` (named `shape_name`) to `parent` at `at`: on its own, solid
## (with collision, in the reach_solid group); in another, added into it.
func _shape(shape: CSGShape3D, shape_name: String, parent: Node, at: Vector3) -> CSGShape3D:
	shape.name = shape_name
	if not parent is CSGShape3D:
		shape.use_collision = true
		shape.add_to_group(&"reach_solid")
	parent.add_child(shape)
	shape.global_position = at
	return shape


# --- In the rooftop district ------------------------------------------------------------

func test_the_district_has_each_shape() -> void:
	await _load_district()
	var count := {}
	for b in main.level.get_node("Buildings").get_children():
		if b.has_meta(&"shape"):
			count[b.get_meta(&"shape")] = count.get(b.get_meta(&"shape"), 0) + 1
	for shape: String in load("res://tools/gen_district.gd").SHAPE_MIN:
		expect(count.get(shape, 0) > 0, "there should be a %s building, %s" % [shape, count])
	expect(main.level.find_children("*", "CSGCylinder3D", true, false).filter(func(node: Node) -> bool: return node.get_parent().name == &"Buildings").size() > 0, "and a rotunda")
	expect(main.level.find_children("Dome", "CSGSphere3D", true, false).size() > 1, "and domes")


func test_you_can_get_onto_every_part_of_every_shape() -> void:
	await _load_district()
	var map := ReachMap.build(main.level, SUPERHUMAN)
	var spawn := map.place_under(main.level.get_node("SpawnPoint").global_position + Vector3.UP)
	var alone := map.solve(spawn, 1)
	var missing := []
	for b in main.level.get_node("Buildings").get_children():
		if not b.has_meta(&"shape"):
			continue
		for spot in map.places.filter(func(s: ReachMap.Spot) -> bool: return s.name.begins_with(str(b.name) + "/") or s.name.begins_with(str(b.name) + "#") or s.name == b.name):
			if not alone.has(spot):
				missing.append(spot.name)
	expect(missing.is_empty(), "you can get onto every part of each shape alone (each tier, dome, roof...): %s" % [missing])


func test_run_in_through_a_courtyards_arch() -> void:
	await _load_district()
	var b: CSGBox3D = main.level.get_node("Buildings").get_children().filter(func(node: Node) -> bool: return node.get_meta(&"shape", "") == "courtyard")[0]
	var arch: CSGBox3D = b.get_children().filter(func(node: Node) -> bool: return node.name.begins_with("Arch"))[0]
	var yard: CSGBox3D = b.get_node("Courtyard")
	var inward := yard.global_position - arch.global_position
	inward = Vector3(signf(inward.x), 0, 0) if absf(inward.x) > absf(inward.z) else Vector3(0, 0, signf(inward.z))
	var depth := absf((arch.size * inward).length())
	var start := Vector3(arch.global_position.x, 0.05, arch.global_position.z) - inward * (depth / 2.0 + 2.0)
	await place(start, yaw_for(inward))
	Input.action_press(&"free_run")
	var in_yard := false
	var yard_area := AABB(yard.global_position - yard.size / 2.0, yard.size)
	for i in 60 * 3:
		await ticks(1)
		if yard_area.has_point(player.global_position + Vector3.UP):
			in_yard = true
			break
	release_all()
	expect(in_yard, "through the arch into the courtyard (at %s)" % player.global_position)


func _load_district() -> void:
	main.leave_game()
	await ticks(5)
	main.start_solo("rooftop_district")
	await ticks(10)
	player = main.get_node("Players/1")
	player.set_profile(SUPERHUMAN)


func test_run_up_the_biggest_dome() -> void:
	await _load_district()
	var domes: Array = main.level.find_children("Dome", "CSGSphere3D", true, false)
	domes.sort_custom(func(a: CSGSphere3D, b: CSGSphere3D) -> bool: return a.radius > b.radius)
	var dome: CSGSphere3D = domes[0]
	var b := dome.get_parent() as CSGShape3D
	var roof := ReachMap._bounds(b).end.y
	var top := dome.global_position.y + dome.radius
	# From the roof a little way out from its foot, running at the middle.
	var foot := sqrt(dome.radius * dome.radius - pow(roof - dome.global_position.y, 2.0))
	await place(dome.global_position + Vector3(0, roof - dome.global_position.y + 0.05, foot + 2.0), FACE_NORTH)
	Input.action_press(&"move_forward")
	var highest := -INF
	for i in 60 * 4:
		await ticks(1)
		if player.is_on_floor():
			highest = maxf(highest, player.global_position.y)
	release_all()
	expect(highest > top - ReachMap.DOME_CROWN - 0.2, "running up %s's dome (radius %.1f) to the top (highest %.2f, top %.2f)" % [b.name, dome.radius, highest, top])


func test_a_lying_down_cylinder_has_no_top() -> void:
	# (Like a pipe: it isn't a round roof.)
	var log_shape := _shape(CSGCylinder3D.new(), "Log", main.level, Vector3(-60, FLOOR_Y + 3.0, -60)) as CSGCylinder3D
	log_shape.radius = 3.0
	log_shape.height = 20.0
	log_shape.rotation = Vector3(PI / 2.0, 0, 0)
	await ticks(3)
	var map := ReachMap.build(main.level, SUPERHUMAN)
	expect(not map.places.any(func(spot: ReachMap.Spot) -> bool: return spot.name.begins_with("Log")), "no place on top of it")
