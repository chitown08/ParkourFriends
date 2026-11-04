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
	var map := ReachMap.build(main.level, SUPERHUMAN)
	var room := map.place_named("Hollow/Room")
	expect(room != null, "the room's floor is a place")
	if room:
		expect_near(room.y, FLOOR_Y + 7.0, 0.01, "at the bottom of the room")
	expect(map.place_named("Hollow/DoorSouth") == null, "(a doorway isn't a place)")


func test_in_through_a_doorway_not_through_a_wall_or_the_ceiling() -> void:
	var map := ReachMap.build(main.level, SUPERHUMAN)
	expect(_linked(map, "SouthRoof", "Hollow/Room"), "from the roof across the alley, in through the doorway")
	expect(not _linked(map, "EastRoof", "Hollow/Room"), "not from the east: there's a wall")
	expect(not _linked(map, "Hollow/Room", "Hollow"), "and not up through the ceiling onto the roof")
	expect(not _linked(map, "Hollow", "Hollow/Room"), "nor down through it")
	expect(_linked(map, "Hollow/Room", "SouthRoof"), "back out the way you came")


func test_a_wall_between_two_roofs_is_in_the_way() -> void:
	var map := ReachMap.build(main.level, SUPERHUMAN)
	expect(_linked(map, "SouthRoof", "EastRoof"), "test setup: the two roofs the same height, 6 m apart, across the corner")
	_box("TallWall", Vector3(12, FLOOR_Y + 15, -14), Vector3(1, 30, 30)) # Between them.
	await ticks(3)
	map = ReachMap.build(main.level, SUPERHUMAN)
	expect(not _linked(map, "SouthRoof", "EastRoof"), "with a tall wall between them, no way across")


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
