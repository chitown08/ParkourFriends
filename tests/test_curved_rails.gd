extends GameTest
## Grind rails of any shape (levels/grind_rail.gd with a `curve`): bends,
## coaster dips, flat wires and moving rails. Built in code over a big floor
## high above the test course.

const FLOOR_Y := 200.0
const RAIL_Y := 210.0

var states_entered: Array[StringName] = []


func before_each() -> void:
	await super()
	player.set_profile(SUPERHUMAN)
	player.state_changed.connect(func(new_state: StringName) -> void: states_entered.append(new_state))
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(400, 1, 400)
	floor_body.add_child(shape)
	main.level.add_child(floor_body)
	floor_body.global_position = Vector3(0, FLOOR_Y - 0.5, 0)


func test_you_follow_a_bend() -> void:
	# Downhill, swinging 90 degrees from north round to east.
	var rail := _rail([Vector3(0, 0, 0), Vector3(0, -2, -12), Vector3(10, -4, -20), Vector3(24, -6, -20)])
	await _drop_onto(rail, 1.0)
	var furthest_off := 0.0
	var last_along := 0.0
	for i in 60 * 4:
		await ticks(1)
		if player.state.name != &"Grind":
			break
		last_along = rail.closest_distance(player.global_position)
		var on := rail.point_at_distance(last_along)
		furthest_off = maxf(furthest_off, player.global_position.distance_to(on))
	expect(last_along > rail.length() - 2.0, "you should ride it to the end, got %.1f of %.1f m" % [last_along, rail.length()])
	expect(furthest_off < GrindRail.RAIL_RADIUS + 0.05, "and stay on it round the bend, at most %.2f m off" % furthest_off)
	expect(player.velocity.normalized().dot(Vector3.RIGHT) > 0.9, "flung off the end heading east, the way it ends, going %s" % player.velocity)


func test_a_coaster_dip_speeds_you_up_then_slows_you() -> void:
	# Down 6 m and back up 4 m: you coast out of the far end, slower than at the bottom.
	var rail := _rail([Vector3(0, 0, 0), Vector3(0, -6, -14), Vector3(0, -6, -18), Vector3(0, -2, -32)])
	await _drop_onto(rail, 0.5)
	var fastest := 0.0
	var at_bottom := 0.0
	var leaving := 0.0
	for i in 60 * 6:
		await ticks(1)
		if player.state.name != &"Grind":
			break
		var speed := player.velocity.length()
		fastest = maxf(fastest, speed)
		leaving = speed
		if player.global_position.y < RAIL_Y - 5.5:
			at_bottom = speed
	expect(player.state.name == &"Air" and player.global_position.z < -30.0, "you should coast up and off the far end, at %s in %s" % [player.global_position, player.state.name])
	expect(at_bottom > 9.0 and fastest >= at_bottom - 0.5, "fastest down in the dip, %.1f m/s there" % at_bottom)
	expect(leaving < at_bottom - 3.0, "and slower by the time you leave the rise, %.1f m/s (%.1f at the bottom)" % [leaving, at_bottom])


func test_a_valley_too_deep_to_coast_out_of_rolls_you_back() -> void:
	var rail := _rail([Vector3(0, 0, 0), Vector3(0, -6, -12), Vector3(0, -6, -16), Vector3(0, 0, -28)])
	await _drop_onto(rail, 4.0)
	var turned := 0
	var last_sign := 0.0
	for i in 60 * 8:
		await ticks(1)
		expect(player.state.name == &"Grind", "you shouldn't get out of the valley without pushing, %s at %s" % [player.state.name, player.global_position])
		if player.state.name != &"Grind":
			return
		var going := signf(player.velocity.z)
		if going != 0.0 and last_sign != 0.0 and going != last_sign:
			turned += 1
		if going != 0.0:
			last_sign = going
	expect(turned >= 2, "you should roll back and forth in it, turned %d time(s)" % turned)


func test_push_along_a_flat_wire() -> void:
	var rail := _rail([Vector3(0, 0, 0), Vector3(0, 0, -40)])
	await _drop_onto(rail, 20.0, false)
	await ticks(30)
	expect(player.velocity.length() < 0.5, "landing still on a flat wire, you stay put, going %.1f m/s" % player.velocity.length())
	player.camera_rig.yaw = FACE_NORTH
	await hold(&"move_forward", 60)
	expect_state(&"Grind")
	expect_near(-player.velocity.z, player.grind_climb_speed, 0.3, "pushing along it gets you going")
	await hold(&"move_back", 90)
	expect(player.velocity.z > player.grind_climb_speed - 0.3, "pushing the other way turns you round, going %s" % player.velocity)


func test_a_moving_rail_carries_you() -> void:
	var rail := _rail([Vector3(0, 0, 0), Vector3(0, 0, -40)])
	await _drop_onto(rail, 20.0, false)
	var start := player.global_position
	for i in 120:
		rail.global_position += Vector3.RIGHT * 3.0 / 60.0 # A trolley line sliding east at 3 m/s.
		await ticks(1)
	expect_state(&"Grind")
	expect_near(player.global_position.x - start.x, 6.0, 0.2, "you should move east with the rail")
	expect(player.global_position.distance_to(rail.point_at_distance(rail.closest_distance(player.global_position))) < 0.15, "still on it")


func test_land_anywhere_along_a_curve() -> void:
	var rail := _rail([Vector3(0, 0, 0), Vector3(0, -2, -12), Vector3(10, -4, -20), Vector3(24, -6, -20)])
	var spot := rail.point_at_distance(rail.length() * 0.6)
	await place(spot + Vector3.UP * 3.0, FACE_NORTH)
	expect(&"Grind" in states_entered, "you should land on it where you drop, went through %s" % [states_entered])
	expect_near(rail.closest_distance(player.global_position), rail.length() * 0.6, 3.0, "about where you dropped")


## A smooth rail through `points` (relative to (0, RAIL_Y, 0)).
func _rail(points: Array) -> GrindRail:
	var curve := Curve3D.new()
	for i in points.size():
		var before: Vector3 = points[maxi(i - 1, 0)]
		var after: Vector3 = points[mini(i + 1, points.size() - 1)]
		var handle := (after - before) / 6.0 # Catmull-Rom-ish: smooth through each point.
		curve.add_point(points[i], -handle, handle)
	var rail := GrindRail.new()
	rail.curve = curve
	main.level.add_child(rail)
	rail.global_position = Vector3(0, RAIL_Y, 0)
	return rail


## Drops you onto `rail` `along` metres from its start (moving with it, if `going`).
func _drop_onto(rail: GrindRail, along: float, going := true) -> void:
	release_all()
	states_entered.clear()
	player.global_position = rail.point_at_distance(along) + Vector3.UP * 0.3
	player.velocity = rail.direction_at(along) * 2.0 if going else Vector3.ZERO
	player.change_state(&"Air")
	player.reset_physics_interpolation()
	for i in 30:
		await ticks(1)
		if player.state.name == &"Grind":
			return
	expect(false, "should land on the rail, %s at %s" % [player.state.name, player.global_position])
