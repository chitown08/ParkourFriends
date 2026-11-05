extends GameTest
## Buildings at angles: turned in their lots, leaning, curved (an outline
## pushed up: a prism), with walls that lean out over you, and a flattened
## dome. The checker (game/reach/) works out where you can stand on each and
## whether you can get up its walls, and in the game you can (or can't) as it
## says. Built high above the test course.

const FLOOR_Y := 500.0
const TALL := 7.0

var states_entered: Array[StringName] = []


func before_each() -> void:
	await super()
	player.set_profile(SUPERHUMAN)
	player.state_changed.connect(func(new_state: StringName) -> void: states_entered.append(new_state))
	var ground := _box("AngleGround", main.level, Vector3(0, FLOOR_Y - 0.5, 0), Vector3(240, 1, 240))
	ground.remove_from_group(&"reach_solid")
	# Turned 30° in its lot.
	var turned := _box("Turned", main.level, Vector3(0, FLOOR_Y + TALL / 2.0, -40), Vector3(20, TALL, 14))
	turned.rotation.y = deg_to_rad(30.0)
	# Leaning 6° (toward +z: its top slopes down that way, that wall leans out).
	var leaning := _box("Leaning", main.level, Vector3(40, FLOOR_Y + 3.0, -40), Vector3(16, 8, 16))
	leaning.rotation.x = deg_to_rad(6.0)
	# Leaning 20°: too steep to stand on top.
	var steep := _box("Steep", main.level, Vector3(80, FLOOR_Y + 3.0, -40), Vector3(16, 8, 16))
	steep.rotation.x = deg_to_rad(20.0)
	# Curved, seen from above: a wavy round outline pushed up TALL.
	var outline := PackedVector2Array()
	for i in 48:
		var angle := TAU * i / 48.0
		outline.append(Vector2.from_angle(angle) * (10.0 + 2.5 * sin(3.0 * angle)))
	_upright_prism("Curved", main.level, Vector3(-40, FLOOR_Y, -40), outline, TALL)
	# A flattened dome on a roof (sunk into it: its top 2 m over it).
	var flat := _box("Flat", main.level, Vector3(-80, FLOOR_Y + TALL / 2.0, -40), Vector3(24, TALL, 24))
	var dome := _shape(CSGSphere3D.new(), "Dome", flat, Vector3(-80, FLOOR_Y + TALL - 2.0, -40)) as CSGSphere3D
	dome.radius = 10.0
	dome.radial_segments = 32
	dome.rings = 16
	dome.scale = Vector3(1, 0.4, 1)
	# Walls (facing +x, a pad at the foot of each) leaning out 6° and 25°, and back 25°.
	_wall_prism("Out6", 0.0, deg_to_rad(6.0), TALL)
	_wall_prism("Out25", 40.0, deg_to_rad(25.0), TALL)
	_wall_prism("Back25", 80.0, deg_to_rad(-25.0), 5.0)
	# A mushroom: a narrow trunk, a wide top sticking out 5 m all round.
	var mushroom := _box("Mushroom", main.level, Vector3(-40, FLOOR_Y + 2.0, 40), Vector3(10, 4, 10))
	_box("Cap", mushroom, Vector3(-40, FLOOR_Y + 5.5, 40), Vector3(20, 3, 20))
	await ticks(3) # (CSG builds its collision a moment later.)


# --- The checker ------------------------------------------------------------------------

func test_a_turned_buildings_top() -> void:
	var map := ReachMap.shared(main.level, SUPERHUMAN)
	var tops := _places(map, "Turned")
	var turned := main.level.get_node("Turned") as CSGBox3D
	var area := 0.0
	for spot: ReachMap.Spot in tops:
		expect_near(spot.y, FLOOR_Y + TALL, 0.01, "%s at the top" % spot.name)
		area += spot.area.get_area()
		for corner in _corners(spot.area):
			var local := turned.global_transform.affine_inverse() * Vector3(corner.x, FLOOR_Y + TALL - 0.1, corner.y)
			expect(absf(local.x) <= 10.01 and absf(local.z) <= 7.01, "%s's corner %s is on the roof" % [spot.name, corner])
	expect(area > 0.6 * 280.0, "between them, most of it (%.0f of 280 m²)" % area)
	expect(_linked(map, "AngleGround", "Turned"), "a scramble up its wall")


func test_a_turned_building_is_where_it_is() -> void:
	var map := ReachMap.shared(main.level, SUPERHUMAN)
	var turned := main.level.get_node("Turned") as CSGBox3D
	expect(map.is_solid(turned.global_transform * Vector3(9.5, 0, 6.5)), "near its corner: solid")
	expect(not map.is_solid(turned.global_transform * Vector3(11, 0, 0)), "just past its end: not")
	expect(not map.is_solid(Vector3(-10.5, FLOOR_Y + 3.0, -40 - 9.5)), "in the box round it but not in it: not")


func test_a_leaning_buildings_top_is_strips() -> void:
	var map := ReachMap.shared(main.level, SUPERHUMAN)
	var tops := _places(map, "Leaning")
	var leaning := main.level.get_node("Leaning") as CSGBox3D
	var heights := {}
	for spot: ReachMap.Spot in tops:
		heights[snappedf(spot.y, 0.01)] = true
		var under := leaning.global_transform.affine_inverse() * Vector3(spot.area.get_center().x, spot.y, spot.area.get_center().y)
		expect(under.y > 3.5 and under.y < 4.6, "%s is on its top (%.2f up in it, its top 4)" % [spot.name, under.y])
	expect(heights.size() >= 3, "a few strips, each a little higher (%s)" % [heights.keys()])
	expect(map.is_solid(leaning.global_transform * Vector3(0, 3.5, 7.5)), "it's solid where it leans")
	var reached := map.solve(map.place_named("AngleGround"), 1)
	expect(tops.all(func(spot: ReachMap.Spot) -> bool: return reached.has(spot)), "you can get onto each strip alone")


func test_too_steep_to_stand_on() -> void:
	var map := ReachMap.shared(main.level, SUPERHUMAN)
	expect(_places(map, "Steep").is_empty(), "leaning 20°, its top is no place (you'd slide off)")


func test_the_top_of_a_thin_wall_is_no_place() -> void:
	# A garden wall 1.2 m thick, set at a slight angle: you could walk along
	# its top, but it's too narrow to count as somewhere to stand.
	var wall := _box("Garden", main.level, Vector3(0, FLOOR_Y + 1.5, 80), Vector3(30, 3, 1.2))
	wall.rotation.y = deg_to_rad(1.0)
	await ticks(3)
	var map := ReachMap.shared(main.level, SUPERHUMAN)
	expect(_places(map, "Garden").is_empty(), "no place on top (%s)" % [_places(map, "Garden").map(func(spot: ReachMap.Spot) -> Rect2: return spot.area)])


func test_a_curved_buildings_top_follows_its_curve() -> void:
	var map := ReachMap.shared(main.level, SUPERHUMAN)
	var tops := _places(map, "Curved")
	var curved := main.level.get_node("Curved") as CSGPolygon3D
	var area := 0.0
	for spot: ReachMap.Spot in tops:
		expect_near(spot.y, FLOOR_Y + TALL, 0.01, "%s at the top" % spot.name)
		area += spot.area.get_area()
		for corner in _corners(spot.area):
			var local := curved.global_transform.affine_inverse() * Vector3(corner.x, FLOOR_Y + TALL - 0.1, corner.y)
			expect(Geometry2D.is_point_in_polygon(Vector2(local.x, local.y), curved.polygon) or _near_outline(Vector2(local.x, local.y), curved.polygon),
					"%s's corner %s is on the roof" % [spot.name, corner])
	var whole := absf(_polygon_area(curved.polygon))
	expect(area > 0.7 * whole, "between them, most of it (%.0f of %.0f m²)" % [area, whole])
	expect(_linked(map, "AngleGround", "Curved"), "a scramble up its wall")


func test_a_curved_building_is_solid_only_inside() -> void:
	var map := ReachMap.shared(main.level, SUPERHUMAN)
	# Its outline bulges out at 30° (12.5 m) and in at 90° (7.5 m).
	var middle := Vector3(-40, FLOOR_Y + 3.0, -40)
	expect(map.is_solid(middle + Vector3(cos(PI / 6.0), 0, sin(PI / 6.0)) * 12.0), "in a bulge: solid")
	expect(not map.is_solid(middle + Vector3(0, 0, 1) * 9.0), "in a dip: not")
	expect(not map.is_solid(middle + Vector3(0, TALL, 0)), "nor over its roof")


func test_a_flattened_domes_crown() -> void:
	var map := ReachMap.shared(main.level, SUPERHUMAN)
	var crowns := _places(map, "Flat/Dome")
	expect(not crowns.is_empty(), "the top of a flattened dome is a place")
	for crown: ReachMap.Spot in crowns:
		expect(crown.y > FLOOR_Y + TALL + 1.5 and crown.y <= FLOOR_Y + TALL + 2.01, "%s is near its top (%.2f over the roof)" % [crown.name, crown.y - FLOOR_Y - TALL])
	expect(map.place_named("Flat") != null and is_equal_approx(map.place_named("Flat").area.get_area(), 576.0), "the roof round it is still all a place")
	var reached := map.solve(map.place_named("AngleGround"), 1)
	expect(crowns.all(func(spot: ReachMap.Spot) -> bool: return reached.has(spot)), "you can get up onto it alone")


func test_up_a_wall_leaning_out_a_little_but_not_a_lot() -> void:
	var map := ReachMap.shared(main.level, SUPERHUMAN)
	expect(_linked(map, "Out6Pad", "Out6", true), "leaning out 6°: you can scramble up it")
	expect(not _linked(map, "Out25Pad", "Out25", true), "leaning out 25°: you can't")
	expect(not map.links.any(func(link: ReachMap.Link) -> bool: return link.from.name == "Out25Pad" and link.how.begins_with("leg-up")),
			"not even with a leg-up (a toss still throws you over the top)")
	expect(not _linked(map, "Back25Pad", "Back25", true), "nor leaning back 25° (a steep slope, not a wall)")


func test_no_way_up_a_mushroom_alone() -> void:
	var map := ReachMap.shared(main.level, SUPERHUMAN)
	var cap := map.place_named("Mushroom/Cap")
	expect(cap != null, "its cap is a place")
	expect(not map.solve(map.place_named("AngleGround"), 1).has(cap), "it overhangs all round: no way up it alone")
	expect(map.players_needed(cap, map.place_named("AngleGround")) > 1, "but friends can get you up (a toss)")


# --- In the game ------------------------------------------------------------------------

func test_scramble_up_a_turned_wall() -> void:
	var turned := main.level.get_node("Turned") as CSGBox3D
	var face := turned.global_transform * Vector3(0, -TALL / 2.0, 7.0)
	var out := (turned.global_basis.z * Vector3(1, 0, 1)).normalized()
	expect(await _free_run_until_on(Vector3(face.x, FLOOR_Y + 0.05, face.z) + out * 10.0, -out, FLOOR_Y + TALL),
			"up its angled wall (at %s, via %s)" % [player.global_position, states_entered])


func test_scramble_up_a_curved_wall() -> void:
	# At a bulge (30°), from 10 m out.
	var along := Vector3(cos(PI / 6.0), 0, sin(PI / 6.0))
	expect(await _free_run_until_on(Vector3(-40, FLOOR_Y + 0.05, -40) + along * 22.5, -along, FLOOR_Y + TALL),
			"up its curved wall (at %s, via %s)" % [player.global_position, states_entered])


func test_onto_a_leaning_building() -> void:
	# Up its low side, where it leans out 6°.
	var top: Vector3 = (main.level.get_node("Leaning") as Node3D).global_transform * Vector3(0, 4, 8)
	expect(await _free_run_until_on(Vector3(40, FLOOR_Y + 0.05, top.z + 10.0), Vector3.FORWARD, top.y),
			"up the wall leaning out over you (at %s, via %s)" % [player.global_position, states_entered])


func test_leaning_walls_in_the_game() -> void:
	expect(await _free_run_until_on(Vector3(22.0, FLOOR_Y + 0.05, 34), Vector3.LEFT, FLOOR_Y + TALL),
			"leaning out 6°: up it (at %s, via %s)" % [player.global_position, states_entered])
	expect(not await _free_run_until_on(Vector3(40.0 + 22.0, FLOOR_Y + 0.05, 34), Vector3.LEFT, FLOOR_Y + TALL),
			"leaning out 25°: not (at %s, via %s)" % [player.global_position, states_entered])
	expect(not await _free_run_until_on(Vector3(80.0 + 22.0, FLOOR_Y + 0.05, 34), Vector3.LEFT, FLOOR_Y + 5.0),
			"leaning back 25°: not (at %s, via %s)" % [player.global_position, states_entered])


func test_no_scrambling_up_a_mushroom() -> void:
	expect(not await _free_run_until_on(Vector3(-40, FLOOR_Y + 0.05, 40 + 18.0), Vector3.FORWARD, FLOOR_Y + 6.5),
			"the cap's in the way (at %s, via %s)" % [player.global_position, states_entered])


# --- Helpers ----------------------------------------------------------------------------

## A wall facing +x at x = `x` (12 m along z, from z = 24 to 36), leaning out
## by `lean` (negative: leaning back), `height` tall, with a flat top and a
## pad (a low step, 4 m square) at its foot.
func _wall_prism(prism_name: String, x: float, lean: float, height: float) -> void:
	var shift := height * tan(lean)
	var outline := PackedVector2Array([Vector2(-12, 0), Vector2(0, 0), Vector2(shift, height), Vector2(-12, height)])
	var prism := _shape(CSGPolygon3D.new(), prism_name, main.level, Vector3(x, FLOOR_Y, 36)) as CSGPolygon3D
	prism.polygon = outline
	prism.depth = 12.0
	_box(prism_name + "Pad", main.level, Vector3(x + 2.0, FLOOR_Y + 0.15, 30), Vector3(4, 0.3, 4))


## An outline (x, z, seen from above) pushed up from `at` to `height` above it.
func _upright_prism(prism_name: String, parent: Node, at: Vector3, outline: PackedVector2Array, height: float) -> CSGPolygon3D:
	var prism := _shape(CSGPolygon3D.new(), prism_name, parent, at) as CSGPolygon3D
	# (Its outline's y runs along z; it's pushed out along its -z, which is up.)
	prism.basis = Basis(Vector3.RIGHT, Vector3.BACK, Vector3.DOWN)
	prism.polygon = outline
	prism.depth = height
	return prism


func _free_run_until_on(start: Vector3, along: Vector3, height: float) -> bool:
	await place(start, yaw_for(along))
	states_entered.clear()
	Input.action_press(&"free_run")
	var made_it := false
	for i in 60 * 4:
		await ticks(1)
		if player.state.name == &"Hang":
			Input.action_press(&"jump")
		if player.is_on_floor() and player.global_position.y > height - 0.3:
			made_it = true
			break
	release_all()
	return made_it


func _places(map: ReachMap, prefix: String) -> Array:
	return map.places.filter(func(spot: ReachMap.Spot) -> bool: return spot.name == prefix or spot.name.begins_with(prefix + "#"))


## Whether there's a link from `from` to `to` (or a piece of it: "#2"...); only
## ones you can do on your own if `alone`.
func _linked(map: ReachMap, from: String, to: String, alone := false) -> bool:
	return map.links.any(func(link: ReachMap.Link) -> bool: return link.from.name == from \
			and (link.to.name == to or link.to.name.begins_with(to + "#")) \
			and (not alone or link.helpers_here + link.helpers_there == 0 and link.together <= 1))


static func _corners(r: Rect2) -> Array[Vector2]:
	return [r.position, r.end, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y)]


static func _near_outline(point: Vector2, outline: PackedVector2Array) -> bool:
	for i in outline.size():
		if Geometry2D.get_closest_point_to_segment(point, outline[i], outline[(i + 1) % outline.size()]).distance_to(point) < 0.05:
			return true
	return false


static func _polygon_area(outline: PackedVector2Array) -> float:
	var twice := 0.0
	for i in outline.size():
		twice += outline[i].cross(outline[(i + 1) % outline.size()])
	return twice / 2.0


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

const GENERATOR := preload("res://tools/gen_district.gd")


func test_the_modern_quarter() -> void:
	await _load_district()
	var modern: Array = GENERATOR.STYLE_SHAPES["modern"].filter(func(shape: String) -> bool: return not shape in GENERATOR.STYLE_SHAPES["old"])
	var found := {}
	for b: Node3D in main.level.get_node("Buildings").get_children():
		var shape: String = b.get_meta(&"shape", "")
		if shape in modern:
			found[shape] = found.get(shape, 0) + 1
			expect(b.global_position.x > 0.0 and b.global_position.z > 0.0, "%s (%s) is in the modern quarter (south-east, past the avenues)" % [b.name, shape])
	for shape: String in modern:
		expect(found.has(shape), "there's a %s building (%s)" % [shape, found])
	# And each has somewhere to stand on top (a leaning one not too steep, say).
	var map := ReachMap.shared(main.level, SUPERHUMAN)
	for b: Node3D in main.level.get_node("Buildings").get_children():
		if b.get_meta(&"shape", "") in modern:
			expect(map.places.any(func(spot: ReachMap.Spot) -> bool: return spot.node == b), "%s (%s) has a top you can stand on" % [b.name, b.get_meta(&"shape")])


func test_a_cantilever_leaves_room_under_it() -> void:
	await _load_district()
	expect(not main.level.find_children("Overhang", "CSGBox3D", true, false).is_empty(), "there's a cantilever")
	for overhang: CSGBox3D in main.level.find_children("Overhang", "CSGBox3D", true, false):
		var under := ReachMap._bounds(overhang).position.y
		expect(under >= 7.0, "%s's overhang is %.1f m up (room for the street under it)" % [overhang.get_parent().name, under])
		var tip := ReachMap._bounds(overhang)
		var building := ReachMap._bounds(overhang.get_parent() as CSGShape3D)
		expect(tip.size.x > building.size.x or tip.size.z > building.size.z or not building.encloses(tip), "%s sticks out past its walls" % overhang.get_parent().name)


func _load_district() -> void:
	main.leave_game()
	await ticks(5)
	main.start_solo("rooftop_district")
	await ticks(10)
	player = main.get_node("Players/1")
	player.set_profile(SUPERHUMAN)


func test_buildings_keep_to_their_lots() -> void:
	# (Seen from above: each lot's buildings keep at least an alley from any
	# other lot's. Not the leaning ones, whose feet are sunk under the street,
	# nor cantilevers, which stick out on purpose. A terrace's houses are one lot.)
	await _load_district()
	var lots := {}
	for b: CSGShape3D in main.level.get_node("Buildings").get_children():
		if not b.get_meta(&"shape", "") in ["leaning", "cantilever"]:
			var box := ReachMap._bounds(b)
			var lot := String(b.name).get_slice("_House", 0)
			var footprint := Rect2(box.position.x, box.position.z, box.size.x, box.size.z).grow(GENERATOR.ALLEY / 2.0 - 0.1)
			lots[lot] = (lots[lot] as Rect2).merge(footprint) if lots.has(lot) else footprint
	var overlaps := []
	var names := lots.keys()
	for i in names.size():
		for j in range(i + 1, names.size()):
			if (lots[names[i]] as Rect2).intersects(lots[names[j]]):
				overlaps.append("%s/%s" % [names[i], names[j]])
	expect(overlaps.is_empty(), "no lots' buildings come within an alley of each other: %s" % [overlaps])
