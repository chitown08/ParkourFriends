extends GameTest
## Inside buildings: rooms cut out of a building (child boxes that subtract,
## named "Room..."; doorways and windows too). The checker (game/reach/) knows
## a room's floor is a place, and that walls and ceilings are in the way unless
## there's an opening. Built high above the test course: a hollow building
## (its room's floor 7 m up, a 6 m doorway in its south wall) with a roof the
## same height as that floor across an alley to the south, and another to the
## east (no doorway that side).

const FLOOR_Y := 200.0


func before_each() -> void:
	await super()
	player.set_profile(SUPERHUMAN)
	var floor_box := _box("InteriorGround", Vector3(0, FLOOR_Y - 0.5, -20), Vector3(120, 1, 120))
	floor_box.remove_from_group(&"reach_solid")
	var hollow := _box("Hollow", Vector3(0, FLOOR_Y + 7, -30), Vector3(20, 14, 20))
	_hole(hollow, "Room", Vector3(0, FLOOR_Y + 10, -30), Vector3(19, 6, 19))
	_hole(hollow, "DoorSouth", Vector3(0, FLOOR_Y + 9.25, -20), Vector3(6, 4.5, 1.6))
	_box("SouthRoof", Vector3(0, FLOOR_Y + 3.5, -8), Vector3(20, 7, 16))
	_box("EastRoof", Vector3(22, FLOOR_Y + 3.5, -30), Vector3(16, 7, 20))
	await ticks(3) # (CSG builds its collision a moment later.)


func test_a_rooms_floor_is_a_place() -> void:
	var map := ReachMap.shared(main.level, SUPERHUMAN)
	var room := map.place_named("Hollow/Room")
	expect(room != null, "the room's floor is a place")
	if room:
		expect_near(room.y, FLOOR_Y + 7.0, 0.01, "at the bottom of the room")
	expect(map.place_named("Hollow/DoorSouth") == null, "(a doorway isn't a place)")


func test_in_through_a_doorway_not_through_a_wall_or_the_ceiling() -> void:
	var map := ReachMap.shared(main.level, SUPERHUMAN)
	expect(_linked(map, "SouthRoof", "Hollow/Room"), "from the roof across the alley, in through the doorway")
	expect(not _linked(map, "EastRoof", "Hollow/Room"), "not from the east: there's a wall")
	expect(not _linked(map, "Hollow/Room", "Hollow"), "and not up through the ceiling onto the roof")
	expect(not _linked(map, "Hollow", "Hollow/Room"), "nor down through it")
	expect(_linked(map, "Hollow/Room", "SouthRoof"), "back out the way you came")
	expect(_linked(map, "SouthRoof", "InteriorGround"), "and off the edge of a roof, down to the ground")


func test_a_wall_between_two_roofs_is_in_the_way() -> void:
	var map := ReachMap.shared(main.level, SUPERHUMAN)
	expect(_linked(map, "SouthRoof", "EastRoof"), "test setup: the two roofs the same height, 6 m apart, across the corner")
	_box("TallWall", Vector3(12, FLOOR_Y + 15, -14), Vector3(1, 30, 30)) # Between them.
	await ticks(3)
	map = ReachMap.shared(main.level, SUPERHUMAN)
	expect(not _linked(map, "SouthRoof", "EastRoof"), "with a tall wall between them, no way across")


func test_no_room_overhead_no_jumping_up() -> void:
	# A ledge a storey up from a block, with a low ceiling over the block (and
	# not quite to its edge): you can't jump up from under it.
	_box("UnderCeiling", Vector3(63, FLOOR_Y + 1.5, 1.5), Vector3(6, 3, 3))
	_box("UpperBlock", Vector3(69, FLOOR_Y + 3.25, 1.5), Vector3(6, 6.5, 3))
	await ticks(3)
	var map := ReachMap.shared(main.level, SUPERHUMAN)
	expect(_linked(map, "UnderCeiling", "UpperBlock"), "test setup: up a storey, no ceiling: fine")
	_box("LowCeiling", Vector3(62.15, FLOOR_Y + 6.0, 1.5), Vector3(8.3, 1, 7))
	await ticks(3)
	map = ReachMap.shared(main.level, SUPERHUMAN)
	expect(not _linked(map, "UnderCeiling", "UpperBlock"), "a ceiling over where you'd jump from: no")


func test_run_in_through_the_doorway_for_real() -> void:
	await place(Vector3(0, FLOOR_Y + 7.05, -4), FACE_NORTH)
	player.debug_full_flow = true
	Input.action_press(&"free_run")
	var inside := false
	for i in 60 * 4:
		await ticks(1)
		var at := player.global_position
		if player.is_on_floor() and absf(at.y - (FLOOR_Y + 7.0)) < 0.3 and at.z < -21.0:
			inside = true
			break
	release_all()
	player.debug_full_flow = false
	expect(inside, "free-run across the alley and in through the doorway, onto the room's floor (at %s)" % player.global_position)


func _linked(map: ReachMap, from: String, to: String) -> bool:
	return map.links.any(func(link: ReachMap.Link) -> bool: return link.from.name == from and link.to.name == to)


func _box(box_name: String, at: Vector3, size: Vector3) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.name = box_name
	box.size = size
	box.use_collision = true
	box.add_to_group(&"reach_solid")
	main.level.add_child(box)
	box.global_position = at
	return box


## Cuts a hole called `hole_name` out of `building`, `size` big, centred at `at`.
func _hole(building: CSGBox3D, hole_name: String, at: Vector3, size: Vector3) -> void:
	var hole := CSGBox3D.new()
	hole.name = hole_name
	hole.size = size
	hole.operation = CSGShape3D.OPERATION_SUBTRACTION
	building.add_child(hole)
	hole.global_position = at


# --- In the rooftop district ------------------------------------------------------------

func test_climb_up_through_the_hatch_onto_a_towers_roof() -> void:
	await _load_district()
	var tower := _buildings_with("Hatch")[0]
	var platforms := _platforms(tower)
	var roof_y := tower.global_position.y + tower.size.y / 2.0
	var last: CSGBox3D = platforms.back()
	expect_near(last.global_position.y + last.size.y / 2.0, roof_y, 0.01, "the last step comes up through the hatch, level with the roof")
	expect(await _climb(platforms[platforms.size() - 2], last), "climbing onto it: on %s's roof (at %s)" % [tower.name, player.global_position])

func test_climb_from_one_platform_to_the_next() -> void:
	await _load_district()
	var platforms := _platforms(_buildings_with("Hatch")[0])
	expect(await _climb(platforms[0], platforms[1]), "up onto the next one (at %s)" % player.global_position)

func test_a_towers_doorways_are_clear_inside() -> void:
	await _load_district()
	for tower in _buildings_with("Hatch"):
		for door: CSGBox3D in tower.get_children().filter(func(hole: Node) -> bool: return hole.name.begins_with("Door")):
			var inside := AABB(door.global_position - door.size / 2.0, door.size).grow(2.0)
			inside.position.y = 0.0
			inside.size.y = 2.5
			for platform: CSGBox3D in _platforms(tower):
				var box := AABB(platform.global_position - platform.size / 2.0, platform.size)
				expect(not box.intersects(inside), "%s's %s is blocked by %s" % [tower.name, door.name, platform.name])


func test_run_through_a_warehouse_from_door_to_door() -> void:
	await _load_district()
	var hall: CSGBox3D = null
	for b in _buildings_with("DoorN0"):
		if not b.has_node("Hatch") and b.has_node("DoorS0"):
			hall = b
			break
	expect(hall != null, "there's a warehouse")
	var south: Vector3 = hall.get_node("DoorS0").global_position
	var north: Vector3 = hall.get_node("DoorN0").global_position
	# Back out from the door (as far as the street or alley there leaves room for).
	var outside := player.raycast(Vector3(south.x, 1.0, south.z + 1.0), Vector3(south.x, 1.0, south.z + 7.5))
	var back := 6.0 if outside.is_empty() else minf(6.0, outside.position.z - south.z - 1.5)
	var start := Vector3(south.x, 0.05, south.z + back)
	await place(start, yaw_for(Vector3(north.x - start.x, 0, north.z - start.z))) # Facing the far door.
	player.debug_full_flow = true
	Input.action_press(&"free_run")
	var out := false
	for i in 60 * 8:
		await ticks(1)
		if player.global_position.z < north.z - 3.0:
			out = true
			break
	release_all()
	player.debug_full_flow = false
	expect(out, "in the south door, through the hall and out the north (at %s)" % player.global_position)


func test_run_through_a_top_floor_and_out_the_other_side() -> void:
	await _load_district()
	var b := _buildings_with("OpeningS0").filter(func(it: CSGBox3D) -> bool: return it.has_node("OpeningN0"))[0] as CSGBox3D
	var room: CSGBox3D = b.get_node("Room")
	var floor_y := room.global_position.y - room.size.y / 2.0
	var south: Vector3 = b.get_node("OpeningS0").global_position
	await place(Vector3(south.x, floor_y + 0.05, south.z - 2.0), FACE_NORTH) # Just inside the south opening.
	Input.action_press(&"move_forward")
	var north_wall := b.global_position.z - b.size.z / 2.0
	var out := false
	for i in 60 * 12: # (Some are 60 m deep.)
		await ticks(1)
		if player.global_position.z < north_wall - 0.5:
			out = true
			break
	release_all()
	expect(out, "straight through and out the north side (at %s)" % player.global_position)


## Free-runs along platform `from` (from its far end) toward `to`, the next
## one up; true if you end up on top of it.
func _climb(from: CSGBox3D, to: CSGBox3D) -> bool:
	var way := to.global_position - from.global_position
	var along := Vector3(signf(way.x), 0, 0) if absf(way.x) > absf(way.z) else Vector3(0, 0, signf(way.z))
	var length := absf((from.size * along).length())
	var start := Vector3(from.global_position.x, from.global_position.y + from.size.y / 2.0 + 0.05, from.global_position.z) - along * (length / 2.0 - 1.0)
	return await _free_run_until_on(start, along, to.global_position.y + to.size.y / 2.0)


## Free-runs from `start` along `along` (holding it); true once you're on
## the floor at `height` or above.
func _free_run_until_on(start: Vector3, along: Vector3, height: float) -> bool:
	await place(start, yaw_for(along))
	player.debug_full_flow = true
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
	player.debug_full_flow = false
	return made_it


func _load_district() -> void:
	main.leave_game()
	await ticks(5)
	main.start_solo("rooftop_district")
	await ticks(10)
	player = main.get_node("Players/1")
	player.set_profile(SUPERHUMAN)


## The district's buildings with a hole called `hole_name`.
func _buildings_with(hole_name: String) -> Array[CSGBox3D]:
	var found: Array[CSGBox3D] = []
	for b in main.level.get_node("Buildings").get_children():
		if b is CSGBox3D and b.has_node(hole_name):
			found.append(b)
	return found


## A tower's platforms, bottom to top.
func _platforms(tower: CSGBox3D) -> Array:
	var found: Array = main.level.get_node("Interiors").get_children().filter(func(node: Node) -> bool: return node.name.begins_with(tower.name + "_Platform"))
	found.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.y < b.global_position.y)
	return found
