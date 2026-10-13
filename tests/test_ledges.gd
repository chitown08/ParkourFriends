extends GameTest
## Ledge grabbing, hanging, shimmying, climbing and vaulting (mostly in the
## Ledge Yard, whose wall faces are at x = -14.5).


func test_vaults_over_2m_block() -> void:
	await place(Vector3(-2, 0.05, -3), FACE_WEST)
	await run_and_jump(4.4, Vector3.LEFT)
	expect_state(&"Climb")
	await ticks(30)
	expect_near(player.global_position.y, 2.0, 0.05, "height after vaulting 2 m block")


func test_vaults_over_2_5m_ledge() -> void:
	await place(Vector3(-11, 0.05, 5), FACE_WEST)
	await run_and_jump(12.6, Vector3.LEFT)
	expect_state(&"Climb")
	await ticks(30)
	expect_near(player.global_position.y, 2.5, 0.05, "height after vaulting 2.5 m ledge")


func test_hang_and_climb_3m_ledge() -> void:
	await place(Vector3(-11, 0.05, 0), FACE_WEST)
	await run_and_jump(12.6, Vector3.LEFT)
	await ticks(30)
	expect_state(&"Hang")
	expect_near(player.global_position.y, 3.0 - player.hang_height, 0.05, "hanging height")
	await tap(&"jump")
	await ticks(40)
	expect_state(&"Ground")
	expect_near(player.global_position.y, 3.0, 0.05, "height after climbing up")


func test_hang_on_3_8m_ledge_and_let_go() -> void:
	await place(Vector3(-11, 0.05, -5), FACE_WEST)
	await run_and_jump(12.6, Vector3.LEFT)
	await ticks(30)
	expect_state(&"Hang")
	await tap(&"crouch")
	await ticks(60)
	expect_state(&"Ground")
	expect_near(player.global_position.y, 0.0, 0.05, "height after letting go")


func test_pull_back_lets_go() -> void:
	await place(Vector3(-11, 0.05, -5), FACE_WEST)
	await run_and_jump(12.6, Vector3.LEFT)
	await ticks(30)
	await hold(&"move_back", 30)
	expect(player.state.name != &"Hang", "pulling back should let go")


func test_cannot_grab_5_5m_wall() -> void:
	await place(Vector3(-11, 0.05, -9), FACE_WEST)
	await run_and_jump(12.6, Vector3.LEFT)
	await ticks(60)
	expect_state(&"Ground")
	expect_near(player.global_position.y, 0.0, 0.05, "should stay on the ground")


func test_jumping_straight_onto_block_does_not_grab() -> void:
	# Standing right next to the 1.5 m block and jumping should land on top,
	# not get caught in a hang or vault.
	await place(Vector3(-5.5, 0.05, 0), FACE_WEST)
	Input.action_press(&"move_forward")
	Input.action_press(&"jump")
	var states := {}
	for i in 50:
		await ticks(1)
		states[player.state.name] = true
	release_all()
	expect(not states.has(&"Hang"), "should not hang from a 1.5 m block")


func test_shimmy_stops_at_blocker_and_wall_end() -> void:
	# Shimmy wall: face at x = -25, runs z = -8..8; blocker post at z = -8..-7.
	await place(Vector3(-21.5, 0.05, 0), FACE_WEST)
	await run_and_jump(23.1, Vector3.LEFT)
	await ticks(30)
	expect_state(&"Hang")
	await hold(&"move_right", 300)
	expect_state(&"Hang")
	expect_near(player.global_position.z, -7.0 + player.body_radius, 0.1, "stopped by blocker")
	await hold(&"move_left", 600)
	expect_state(&"Hang")
	expect_near(player.global_position.z, 8.0, 0.1, "stopped at wall end")
