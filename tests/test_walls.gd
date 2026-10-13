extends GameTest
## Wall jumps and wall runs. Mostly in the Wall Yard behind the spawn:
## a chimney (walls at x = -9..-7 and -4..-2, z = 17..23, 7 m tall) and a
## wall-run wall (face at x = 4, z = 26..44) beside an 11 m gap (z = 30..41).

const FACE_SOUTH := PI ## Toward +Z (the Wall Yard).
const FACE_EAST := -PI / 2


func test_wall_run_crosses_the_gap() -> void:
	var visited := await _wall_run_attempt(3.3)
	expect(visited.has(&"WallRun"), "should wall run, went through %s" % [visited.keys()])
	expect(player.global_position.z > 41.0 and player.global_position.y > -0.1,
			"should end up on the landing, ended at %s" % player.global_position)


func test_no_wall_run_when_too_far_from_the_wall() -> void:
	var visited := await _wall_run_attempt(1.5)
	expect(not visited.has(&"WallRun"), "should not wall run 2.5 m away from the wall")
	expect(player.global_position.y < -1.0, "should fall into the gap, ended at %s" % player.global_position)


func test_jumping_off_a_wall_run_keeps_speed() -> void:
	await _start_wall_run()
	expect_state(&"WallRun")
	expect(absf(player.lean) > 0.1, "body should lean while wall running")
	await tap(&"jump")
	expect_state(&"Air")
	expect(player.velocity.x < -5.0, "should push away from the wall (toward -X), vx = %.2f" % player.velocity.x)
	expect(player.velocity.z > player.wall_run_speed - 0.5, "should keep running speed along the wall, vz = %.2f" % player.velocity.z)
	expect(player.velocity.y > 0.0, "should go upward")
	expect(player.lean == 0.0, "lean should reset after leaving the wall")


func test_crouch_drops_off_a_wall_run() -> void:
	await _start_wall_run()
	expect_state(&"WallRun")
	await tap(&"crouch")
	expect_state(&"Air")


func test_wall_run_ends_after_time_limit() -> void:
	await _start_wall_run()
	var run_ticks := 0
	for i in 200:
		await ticks(1)
		if player.state.name != &"WallRun":
			break
		run_ticks += 1
	expect(run_ticks / 60.0 <= player.wall_run_max_time + 0.05,
			"wall run lasted %.2f s, limit is %.2f s" % [run_ticks / 60.0, player.wall_run_max_time])


func test_wall_jump_pushes_away_and_up() -> void:
	# Practice wall on the start pad: face at x = 9.5.
	await place(Vector3(8.5, 0.05, 6), FACE_EAST)
	await tap(&"jump")
	await ticks(8)
	expect(absf(player.velocity.x) < 0.1, "the first jump from the ground is a normal jump")
	await tap(&"jump")
	expect(player.velocity.x < -player.wall_jump_push + 0.5, "should push away from the wall, vx = %.2f" % player.velocity.x)
	expect(player.velocity.y > 0.0, "should go upward")


func test_cannot_wall_jump_the_same_wall_twice() -> void:
	await place(Vector3(8.5, 0.05, 6), FACE_EAST)
	await tap(&"jump")
	await ticks(8)
	await tap(&"jump") # First wall jump: allowed.
	expect(player.velocity.x < -5.0, "first wall jump should push away")
	await ticks(5)
	# You'd normally land before you could get back, so put the player back
	# beside the same wall, still in mid-air, and try again.
	player.global_position = Vector3(8.6, player.global_position.y, 6)
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	await ticks(1)
	expect_state(&"Air")
	expect(not player.find_wall().is_empty(), "test setup: should be right next to the wall")
	await tap(&"jump")
	expect(player.velocity.x > -1.0, "second jump off the same wall should not push away, vx = %.2f" % player.velocity.x)


func test_can_wall_jump_the_same_wall_after_landing() -> void:
	await place(Vector3(8.5, 0.05, 6), FACE_EAST)
	await tap(&"jump")
	await ticks(8)
	await tap(&"jump")
	await ticks(60) # Land.
	await place(Vector3(8.5, 0.05, 6), FACE_EAST)
	await tap(&"jump")
	await ticks(8)
	await tap(&"jump")
	expect(player.velocity.x < -5.0, "after landing the same wall works again, vx = %.2f" % player.velocity.x)


func test_chimney_climb() -> void:
	# Start next to one chimney wall and bounce between the two.
	await place(Vector3(-6.3, 0.05, 20), FACE_WEST)
	await tap(&"jump")
	var highest := 0.0
	for i in 300:
		await ticks(1)
		highest = maxf(highest, player.global_position.y)
		var wall := player.find_wall()
		if player.state.name == &"Air" and player.velocity.y < 3.0 and not wall.is_empty() \
				and player.can_use_wall(wall.normal):
			await tap(&"jump")
	expect(highest > 7.0 - player.ledge_max_height,
			"should climb high enough to grab the top (%.1f m), got %.2f m" % [7.0 - player.ledge_max_height, highest])


# --- Helpers -------------------------------------------------------------------

## Sprints toward the wall-run gap starting at this x, jumps at the edge, and
## keeps holding forward. Returns the set of states visited.
func _wall_run_attempt(start_x: float) -> Dictionary:
	await place(Vector3(start_x, 0.05, 18), FACE_SOUTH)
	Input.action_press(&"sprint")
	Input.action_press(&"move_forward")
	var visited := {}
	var jumped := false
	for i in 300:
		await ticks(1)
		visited[player.state.name] = true
		if not jumped and player.global_position.z > 29.4:
			Input.action_press(&"jump")
			jumped = true
		elif jumped:
			Input.action_release(&"jump")
		if player.global_position.z > 30.5 and (player.state.name == &"Ground" or player.global_position.y < -3.0):
			break
	release_all()
	await ticks(5)
	return visited


## Gets the player into a wall run over the gap and returns while still on the wall.
func _start_wall_run() -> void:
	await place(Vector3(3.3, 0.05, 18), FACE_SOUTH)
	Input.action_press(&"sprint")
	Input.action_press(&"move_forward")
	var jumped := false
	for i in 200:
		await ticks(1)
		if not jumped and player.global_position.z > 29.4:
			Input.action_press(&"jump")
			jumped = true
		elif jumped:
			Input.action_release(&"jump")
		if player.state.name == &"WallRun":
			break
	await ticks(10)
