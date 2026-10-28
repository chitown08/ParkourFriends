extends GameTest
## Free-run (hold Shift / right trigger): auto-run where the camera points and
## let the character handle obstacles. Uses the test course (human profile).

const FACE_EAST := -PI / 2
const FACE_SOUTH := PI


func after_each() -> void:
	Settings.free_run_enabled = true
	await super()


func test_runs_where_the_camera_points() -> void:
	await place(Vector3(8, 0.05, 8.5), FACE_WEST)
	await hold(&"free_run", 30)
	var direction := Vector3(player.velocity.x, 0.0, player.velocity.z).normalized()
	expect(direction.dot(Vector3.LEFT) > 0.99, "should run west (camera direction), going %s" % direction)
	expect(player.get_horizontal_speed() > 4.0, "should be running")


func test_letting_go_gives_back_manual_control() -> void:
	await place(Vector3(8, 0.05, 8.5), FACE_WEST)
	await hold(&"free_run", 30)
	await ticks(30)
	expect_near(player.get_horizontal_speed(), 0.0, 0.05, "letting go of free-run should stop you")


func test_slides_under_low_bars() -> void:
	await place(Vector3(12, 0.05, 4), FACE_EAST)
	var visited := await _free_run_until(func() -> bool: return player.global_position.x > 28.0, 240)
	expect(visited.has(&"Slide"), "should slide, went through %s" % [visited.keys()])
	expect(player.global_position.x > 28.0, "should get past all three bars, got to x = %.2f" % player.global_position.x)


func test_jumps_over_a_low_block() -> void:
	# The 1.0 m block of the jump-height test (x = -8..-6, z = 2..4).
	await place(Vector3(-2, 0.05, 3), FACE_WEST)
	var visited := await _free_run_until(func() -> bool: return player.global_position.x < -9.0, 120)
	expect(visited.has(&"Air"), "should jump")
	expect(player.global_position.x < -9.0, "should get past the block without stopping, at %s" % player.global_position)


func test_climbs_a_reachable_ledge() -> void:
	# Ledge Yard: 3.0 m ledge, face at x = -14.5.
	await place(Vector3(-11, 0.05, 0), FACE_WEST)
	var highest := 0.0
	var visited := {}
	for i in 150:
		Input.action_press(&"free_run")
		await ticks(1)
		visited[player.state.name] = true
		highest = maxf(highest, player.global_position.y)
	release_all()
	expect(visited.has(&"Hang") or visited.has(&"Climb"), "should grab the ledge, went through %s" % [visited.keys()])
	expect(highest > 2.9, "should climb on top of the 3 m ledge, highest %.2f" % highest)


func test_jumps_gaps_that_have_a_landing() -> void:
	# Main course: Checkpoint 1 platform, then 2 m and 3 m gaps at height 1.5.
	await place(Vector3(0, 1.55, -22), FACE_NORTH)
	var lowest := 99.0
	for i in 240:
		Input.action_press(&"free_run")
		await ticks(1)
		lowest = minf(lowest, player.global_position.y)
		if player.global_position.z < -37.0 and player.state.name == &"Ground":
			break
	release_all()
	expect(player.global_position.z < -37.0, "should cross the 2 m and 3 m gaps, got to z = %.2f" % player.global_position.z)
	expect(lowest > 1.0, "should never fall into a gap, lowest %.2f" % lowest)


func test_runs_off_an_edge_with_nothing_to_land_on() -> void:
	# The Ledge Yard's far edge (x = -30) drops into the void.
	await place(Vector3(-24, 0.05, 8.5), FACE_WEST)
	var highest := 0.0
	for i in 90:
		Input.action_press(&"free_run")
		await ticks(1)
		highest = maxf(highest, player.global_position.y)
	release_all()
	expect(highest < 0.2, "shouldn't jump at an edge with no landing, highest %.2f" % highest)
	expect(player.global_position.y < -1.0, "should run off the edge, at %s" % player.global_position)


func test_runs_off_the_edge_into_a_wall_run() -> void:
	# Wall Yard: the 11 m gap (z = 30..41) has no landing in jumping range,
	# but running off the edge alongside the wall starts a wall run across it.
	await place(Vector3(3.3, 0.05, 18), FACE_SOUTH)
	player.debug_full_flow = true # Top speed straight away.
	var visited := await _free_run_until(
			func() -> bool: return player.global_position.z > 41.0 and player.state.name == &"Ground", 300)
	expect(visited.has(&"WallRun"), "should wall run, went through %s" % [visited.keys()])
	expect(player.global_position.z > 41.0 and player.global_position.y > -0.1,
			"should land on the far side, at %s" % player.global_position)


func test_manual_jump_still_works() -> void:
	await place(Vector3(8, 0.05, 8.5), FACE_WEST)
	Input.action_press(&"free_run")
	await ticks(10)
	await tap(&"jump")
	await ticks(2) # (Free-run takes off when you let go of jump.)
	expect_state(&"Air")


func test_free_run_can_be_switched_off() -> void:
	Settings.free_run_enabled = false
	await place(Vector3(8, 0.05, 8.5), FACE_WEST)
	await hold(&"free_run", 30)
	expect_near(player.get_horizontal_speed(), 0.0, 0.05, "Shift should do nothing with free-run off")


## Holds free-run until `done` returns true (or `max_ticks` pass).
## Returns the set of states visited along the way.
func _free_run_until(done: Callable, max_ticks: int) -> Dictionary:
	var visited := {}
	Input.action_press(&"free_run")
	for i in max_ticks:
		await ticks(1)
		visited[player.state.name] = true
		if done.call():
			break
	release_all()
	return visited
