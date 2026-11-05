extends GameTest
## Launchers (levels/launcher.gd): orange ramps you run up and fly off, higher
## the faster you hit them. A straight wall ramp and a curved quarter-pipe, on
## a big floor high above the test course.

const FLOOR_Y := 200.0

var ramp: Launcher
var pipe: Launcher


func before_each() -> void:
	await super()
	player.set_profile(SUPERHUMAN)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(400, 1, 400)
	body.add_child(shape)
	main.level.add_child(body)
	body.global_position = Vector3(0, FLOOR_Y - 0.5, 0)
	ramp = Launcher.new()
	main.level.add_child(ramp)
	ramp.global_position = Vector3(0, FLOOR_Y, -10) # Runs north, up to 5 m.
	pipe = Launcher.new()
	pipe.curved = true
	main.level.add_child(pipe)
	pipe.global_position = Vector3(40, FLOOR_Y, -10)
	await ticks(3)


func test_free_run_up_a_wall_ramp_and_it_throws_you_up_and_on() -> void:
	var peak := await _run_at(ramp, true)
	var expected := FLOOR_Y + ramp.height + ramp.max_rise
	expect(peak > expected - 1.5, "at full speed it throws you high: %.1f m above the floor (about %.1f)" % [peak - FLOOR_Y, expected - FLOOR_Y])
	expect(player.global_position.z < ramp.global_position.z - ramp.length - 5.0, "and on, past the top")


func test_a_quarter_pipe_throws_you_mostly_up() -> void:
	var launched := []
	player.launched_off_ramp.connect(func() -> void: launched.append(player.velocity))
	var peak := await _run_at(pipe, true)
	var lip := pipe.launch_point()
	expect(peak > FLOOR_Y + lip.y + pipe.max_rise - 1.5, "it throws you way up: %.1f m" % (peak - FLOOR_Y))
	expect(not launched.is_empty(), "test setup: launched")
	if launched:
		var v: Vector3 = launched[0]
		expect(v.y > 2.0 * Vector2(v.x, v.z).length(), "mostly up: %s" % v)


func test_too_slow_no_launch() -> void:
	var peak := await _run_at(ramp, false)
	expect(peak < FLOOR_Y + ramp.height + 1.5, "walking up it, you just walk up it: top %.1f m" % (peak - FLOOR_Y))


func test_the_checker_knows_a_wall_ramp_gets_you_onto_a_roof() -> void:
	# A building beside the ramp's top: 10 m tall, its wall along the ramp.
	var box := CSGBox3D.new()
	box.name = "LauncherBuilding"
	box.size = Vector3(10, 10, 20)
	box.use_collision = true
	main.level.add_child(box)
	box.global_position = Vector3(-6.6, FLOOR_Y + 5.0, -20) # Its east wall 1.6 m west of the ramp's middle.
	var floor_box := CSGBox3D.new()
	floor_box.name = "LauncherFloor"
	floor_box.size = Vector3(200, 1, 200)
	floor_box.use_collision = true
	main.level.add_child(floor_box)
	floor_box.global_position = Vector3(0, FLOOR_Y - 0.5, 0)
	await ticks(3)
	var map := ReachMap.shared(main.level, SUPERHUMAN)
	var how := []
	for link in map.links:
		if link.from.name == "LauncherFloor" and link.to.name == "LauncherBuilding":
			how.append(link.how)
	expect("launcher" in how, "from the street, the launcher gets you up: %s" % [how])



func test_a_wall_ramp_really_gets_you_onto_the_roof() -> void:
	var box := CSGBox3D.new()
	box.size = Vector3(10, 10, 20)
	box.use_collision = true
	main.level.add_child(box)
	box.global_position = Vector3(-6.6, FLOOR_Y + 5.0, -20) # Its east wall alongside the ramp.
	await ticks(3)
	await place(ramp.global_position + Vector3(0, 0.05, 25.0), FACE_NORTH)
	player.debug_full_flow = true
	Input.action_press(&"free_run")
	var on_roof := false
	var launches := []
	player.launched_off_ramp.connect(func() -> void: launches.append(true))
	for i in 60 * 6:
		await ticks(1)
		if not launches.is_empty() and Input.is_action_pressed(&"free_run"):
			# In the air: steer for the wall (west, on your left).
			Input.action_release(&"free_run")
			player.camera_rig.yaw = FACE_WEST
			Input.action_press(&"move_forward")
		if player.state.name == &"Hang":
			await tap(&"jump")
		if player.is_on_floor() and player.global_position.y > FLOOR_Y + 9.9:
			on_roof = true
			break
	release_all()
	player.debug_full_flow = false
	expect(not launches.is_empty(), "launched off the ramp")
	expect(on_roof, "and up onto the 10 m roof beside it, at %s" % player.global_position)


var _furthest_z := 0.0


## Runs north at `launcher` from 25 m back (free-running, or walking slowly);
## returns the highest you got.
func _run_at(launcher: Launcher, fast: bool) -> float:
	await place(launcher.global_position + Vector3(0, 0.05, 25.0), FACE_NORTH)
	_furthest_z = player.global_position.z
	if fast:
		player.debug_full_flow = true
		Input.action_press(&"free_run")
	else:
		Input.action_press(&"move_forward")
		Input.action_press(&"crouch") # (Slowly.)
	var peak := -INF
	for i in 60 * 5:
		await ticks(1)
		peak = maxf(peak, player.global_position.y)
		_furthest_z = minf(_furthest_z, player.global_position.z)
	release_all()
	player.debug_full_flow = false
	return peak
