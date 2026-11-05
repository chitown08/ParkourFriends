extends GameTest
## Awnings (levels/awning.gd): springy shop awnings along the old town's
## street fronts, to bounce from one to the next down a street.

const GENERATOR := preload("res://tools/gen_district.gd")
const STONE := preload("res://materials/stone.tres")

var bounces := 0


func before_each() -> void:
	await super()
	main.leave_game()
	await ticks(5)
	main.start_solo("rooftop_district")
	await ticks(10)
	player = main.get_node("Players/1")
	player.set_profile(SUPERHUMAN)
	player.launched_off_ramp.connect(func() -> void: bounces += 1)


func test_awnings_along_old_town_shop_fronts() -> void:
	var awnings := _awnings()
	expect(awnings.size() >= 20, "awnings about the old town, %d" % awnings.size())
	for awning in awnings:
		expect(absf(awning.global_position.y - GENERATOR.AWNING_TOP) < 0.01, "%s: a storey up" % awning.name)
		var owner_name := str(awning.name).get_slice("_Awning", 0) # (A building, or a row of houses: its parts.)
		var parts: Array = main.level.get_node("Buildings").get_children().filter(func(n: Node) -> bool: return n.name == owner_name or n.name.begins_with(owner_name + "_"))
		expect(not parts.is_empty() and owner_name.begins_with("Block") and parts.all(func(n: Node) -> bool: return (n as CSGShape3D).material != STONE),
				"%s: on an old-town building, not a stone one" % awning.name)
	expect(_rows().any(func(row: Array) -> bool: return row.size() >= 3), "some in a row of three or more, to bounce along")
	for row: Array in _rows():
		for i in range(1, row.size()):
			var gap: float = (row[i] as Awning).global_position.distance_to((row[i - 1] as Awning).global_position) - (row[i] as Awning).size.x
			expect(gap <= 1.0, "%s: next to the last in its row, a gap of %.1f m (any bounce lands on one)" % [row[i].name, gap])


func test_land_on_one_and_bounce() -> void:
	var awning := _awnings()[0]
	var top := awning.global_position + awning.out_of_wall() * awning.size.y / 2.0
	# Standing on it: a bounce.
	await place(top + Vector3.UP * 0.1, yaw_for(awning.out_of_wall()))
	var peak := await _peak(60)
	expect(peak > top.y + Awning.BOUNCE * 0.9, "standing on it bounces you up %.1f m" % (peak - top.y))
	# Dropping onto it from high: a bigger bounce (but not as high as you came from).
	await place(top + Vector3.UP * 12.0, yaw_for(awning.out_of_wall()))
	peak = await _peak(150, top.y + 1.0)
	expect(peak > top.y + Awning.BOUNCE + 1.0 and peak < top.y + Awning.MOST_BOUNCE + 0.3, "dropping 12 m onto it bounces you %.1f m" % (peak - top.y))


func test_bounce_down_a_street() -> void:
	var row: Array = _rows().filter(func(r: Array) -> bool: return r.size() >= 3)[0]
	var first: Awning = row[0]
	var along: Vector3 = ((row[1] as Awning).global_position - first.global_position).normalized()
	await place(first.global_position + first.out_of_wall() * first.size.y / 2.0 - along * 1.5 + Vector3.UP * 0.1, yaw_for(along))
	bounces = 0
	Input.action_press(&"move_forward")
	var lowest := INF
	for i in 60 * 3:
		await ticks(1)
		lowest = minf(lowest, player.global_position.y)
	release_all()
	var travelled := (player.global_position - first.global_position).dot(along)
	expect(bounces >= 3, "bounced from awning to awning, %d bounces" % bounces)
	expect(lowest > GENERATOR.AWNING_TOP - 0.5, "without coming down to the street (lowest %.1f m)" % lowest)
	expect(travelled > 2.0 * GENERATOR.AWNING_SPACING - 1.0, "%.0f m along the street" % travelled)


func test_you_can_get_onto_every_awning_from_the_street() -> void:
	var map := ReachMap.shared(main.level, SUPERHUMAN)
	var ground := map.place_named("Ground")
	for awning in _awnings():
		var on := map.place_under(awning.global_position + awning.out_of_wall() * awning.size.y / 2.0 + Vector3.UP * 0.3)
		expect(on != null and map.links.any(func(l: ReachMap.Link) -> bool: return l.from == ground and l.to == on), "%s: up onto it from the street" % awning.name)


func test_a_bounce_gets_you_onto_a_wall_this_high_and_no_higher() -> void:
	# The checker's rule (game/reach/rules/awning.gd) and the game agree: a
	# block just within a bounce and a grab of an awning, and one a bit higher.
	var reach := ReachMap.build(Node.new(), SUPERHUMAN).scramble_height(Awning.BOUNCE) + SUPERHUMAN.ledge_max_height # (Bounce, scramble, grab.)
	for case: Array in [[reach - 0.5, true], [reach + 1.0, false]]:
		var rise: float = case[0]
		var root := Node3D.new()
		main.level.add_child(root)
		var awning := Awning.new()
		awning.size = Vector2(5.0, 2.2)
		root.add_child(awning)
		awning.global_position = Vector3(0.0, 504.4, 0.0)
		var block := CSGBox3D.new()
		block.size = Vector3(4.0, rise, 4.0)
		block.use_collision = true
		root.add_child(block)
		block.global_position = Vector3(4.6, 504.4 + rise / 2.0, 1.5) # (Just along from it.)
		var wall := CSGBox3D.new() # (And the wall it's on.)
		wall.size = Vector3(20.0, 20.0, 1.0)
		wall.use_collision = true
		root.add_child(wall)
		wall.global_position = Vector3(0.0, 500.0, -0.5)
		await ticks(3)
		var map := ReachMap.build(root, SUPERHUMAN)
		var on := map.place_under(Vector3(0.0, 504.7, 1.1))
		var top := map.place_under(Vector3(4.6, 600.0, 1.5))
		var linked := map.links.any(func(l: ReachMap.Link) -> bool: return l.from == on and l.to == top and l.how == "awning")
		expect(linked == case[1], "the checker: a block %.1f m over it %s" % [rise, "is in reach" if case[1] else "isn't"])
		await place(Vector3(-1.0, 504.5, 1.1), yaw_for(Vector3.RIGHT))
		Input.action_press(&"move_forward")
		var made := false
		for i in 60 * 3:
			await ticks(1)
			if player.state.name == &"Hang":
				await tap(&"jump") # (Grabbed its edge: pull up.)
			if player.is_on_floor() and player.global_position.y > 504.4 + rise - 0.3:
				made = true
				break
		release_all()
		expect(made == case[1], "in the game: a block %.1f m over it %s, at %s" % [rise, "is in reach" if case[1] else "isn't", player.global_position])
		root.free()
		await ticks(3)


## The highest your feet get over the next `frames` (counting only once you've
## come down below `under`, if given: after a drop).
func _peak(frames: int, under := INF) -> float:
	var highest := -INF
	var counting := under == INF
	for i in frames:
		await ticks(1)
		if player.global_position.y < under:
			counting = true
		if counting:
			highest = maxf(highest, player.global_position.y)
	return highest


func _awnings() -> Array[Awning]:
	var found: Array[Awning] = []
	for node in main.level.get_node("Awnings").get_children():
		found.append(node as Awning)
	return found


## Awnings in a row along the same wall, each next to the last.
func _rows() -> Array:
	var rows := []
	for awning in _awnings():
		var row: Array = []
		for r: Array in rows:
			var last: Awning = r.back()
			if last.global_basis.z.is_equal_approx(awning.global_basis.z) and last.global_position.distance_to(awning.global_position) < GENERATOR.AWNING_SPACING + 0.1:
				row = r
		if row.is_empty():
			rows.append([awning])
		else:
			row.append(awning)
	return rows
