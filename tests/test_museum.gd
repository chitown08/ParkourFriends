extends GameTest
## The museum in the rooftop district (tools/gen_district.gd: MUSEUM_*): a
## round hall with a flattened dome on it, and curved terraces round it you
## run up from the street.

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


func test_the_museum_is_in_its_block() -> void:
	var museum := main.level.get_node_or_null("Buildings/Museum") as CSGShape3D
	expect(museum != null, "there's a museum")
	if museum == null:
		return
	expect(museum.get_meta(&"shape", "") == "museum", "marked as the museum")
	var names: Array = GENERATOR.MUSEUM_TERRACES.map(func(terrace: Array) -> String: return terrace[0])
	for part: String in names + ["Dome"]:
		expect(museum.has_node(part), "it has its %s" % part)
	var block := _block_rect()
	for part: CSGShape3D in [museum] + museum.find_children("*", "CSGShape3D", true, false):
		var box := ReachMap._bounds(part)
		expect(block.grow(0.1).encloses(Rect2(box.position.x, box.position.z, box.size.x, box.size.z)), "its %s keeps to its block (%s in %s)" % [part.name, box, block])


func test_its_slopes_can_be_run_up() -> void:
	for terrace: Array in GENERATOR.MUSEUM_TERRACES:
		var steepest: float = GENERATOR.terrace_steepest(terrace)
		expect(steepest <= ReachMap.RUN_SLOPE - 3.0, "%s's slope is %.0f° at its steepest: you can run up it" % [terrace[0], steepest])
		expect(steepest > ReachMap.STAND_SLOPE + 10.0, "and it is a slope (%.0f°)" % steepest)


func test_up_it_alone() -> void:
	var map := ReachMap.shared(main.level, SUPERHUMAN)
	var ground := map.place_named("Ground")
	var alone := map.solve(ground, 1)
	var places := map.places.filter(func(spot: ReachMap.Spot) -> bool: return spot.name.begins_with("Museum"))
	expect(places.size() >= 6, "the hall, its dome and each terrace have tops (%d)" % places.size())
	var gallery: Array = GENERATOR.MUSEUM_TERRACES[0]
	expect(map.is_solid(_hall() + Vector3(0, 0.2, gallery[3] - 0.5)), "the gallery's foot is solid, right out at the front of its curve")
	for spot: ReachMap.Spot in places:
		expect(alone.has(spot), "%s (%.0f m up): you can get there alone" % [spot.name, spot.y])
	for way: Array in [["Ground", "Museum/Gallery"], ["Museum/Gallery", "Museum/Upper"], ["Ground", "Museum/WestWing"], ["Ground", "Museum/EastWing"]]:
		expect(_run_up(map, way[0], way[1]), "run up from %s to %s" % way)
	expect(map.links.any(func(link: ReachMap.Link) -> bool: return link.how == "run up" and link.from.name.begins_with("Museum") \
			and not "/" in link.from.name and link.to.name == "Museum/Dome"), "and up the dome from the hall's roof")


func test_running_up_it_from_the_street() -> void:
	# Straight at the hall from the road round the district: up the gallery,
	# across its top and up the upper terrace, to the foot of the hall.
	var hall := _hall()
	var upper: Array = GENERATOR.MUSEUM_TERRACES[1]
	await place(hall + Vector3(0, 0.05, GENERATOR.MUSEUM_TERRACES[0][3] + 10.0), yaw_for(Vector3.FORWARD))
	states_entered.clear()
	Input.action_press(&"move_forward")
	var top: float = upper[5] + upper[6]
	var made_it := false
	for i in 60 * 8:
		await ticks(1)
		if player.is_on_floor() and player.global_position.y > top - 0.3:
			made_it = true
			break
	release_all()
	expect(made_it, "up both terraces to %.0f m (at %s, via %s)" % [top, player.global_position, states_entered])


func test_running_up_the_dome() -> void:
	var hall := _hall()
	await place(hall + Vector3(GENERATOR.MUSEUM_HALL.x - 0.4, GENERATOR.MUSEUM_HALL.y + 0.05, 0), yaw_for(Vector3.LEFT))
	states_entered.clear()
	Input.action_press(&"move_forward")
	var crown: float = GENERATOR.MUSEUM_HALL.y + GENERATOR.MUSEUM_DOME.y - GENERATOR.MUSEUM_DOME_SINK
	var made_it := false
	for i in 60 * 3:
		await ticks(1)
		if player.is_on_floor() and player.global_position.y > crown - 0.3:
			made_it = true
			break
	release_all()
	expect(made_it, "up the dome to its crown (at %s, via %s)" % [player.global_position, states_entered])


# --- Helpers ----------------------------------------------------------------------------

## The hall's middle, at street level.
func _hall() -> Vector3:
	var at := (main.level.get_node("Buildings/Museum") as Node3D).global_position
	return Vector3(at.x, 0.0, at.z)


## The museum's block, from above (as the generator lays out blocks).
func _block_rect() -> Rect2:
	var starts: Array[float] = []
	var at := 0.0
	for i in GENERATOR.BLOCKS:
		starts.append(at)
		at += GENERATOR.BLOCK + (GENERATOR.AVENUE if i == GENERATOR.AVENUE_AFTER else GENERATOR.STREET)
	var plaza_middle: float = starts[GENERATOR.AVENUE_AFTER] + GENERATOR.BLOCK + GENERATOR.AVENUE / 2.0
	var block: Vector2i = GENERATOR.MUSEUM_BLOCK
	return Rect2(starts[block.x] - plaza_middle, starts[block.y] - plaza_middle, GENERATOR.BLOCK, GENERATOR.BLOCK)


## Whether there's a "run up" link from `from` to `to` (or a piece of either).
func _run_up(map: ReachMap, from: String, to: String) -> bool:
	return map.links.any(func(link: ReachMap.Link) -> bool: return link.how == "run up" \
			and (link.from.name == from or link.from.name.begins_with(from + "#")) \
			and (link.to.name == to or link.to.name.begins_with(to + "#")))
