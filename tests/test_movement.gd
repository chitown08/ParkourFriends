extends GameTest
## Running, jumping, checkpoints and respawning.


func test_spawns_on_the_ground() -> void:
	await ticks(30)
	expect_state(&"Ground")
	expect_near(player.global_position.y, 0.0, 0.05, "spawn height")


func test_run_and_sprint_speeds() -> void:
	Input.action_press(&"move_forward")
	await ticks(60)
	expect_near(player.get_horizontal_speed(), player.run_speed, 0.05, "run speed")
	Input.action_press(&"sprint")
	await ticks(30)
	expect_near(player.get_horizontal_speed(), player.sprint_speed, 0.05, "sprint speed")
	release_all()
	await ticks(30)
	expect_near(player.get_horizontal_speed(), 0.0, 0.05, "speed after letting go")


func test_full_jump_height() -> void:
	var start_y := player.global_position.y
	var highest := start_y
	Input.action_press(&"jump")
	for i in 60:
		await ticks(1)
		highest = maxf(highest, player.global_position.y)
	expect_near(highest - start_y, player.jump_height, 0.15, "full jump height")
	expect_state(&"Ground")


func test_short_hop_is_lower() -> void:
	var start_y := player.global_position.y
	var highest := start_y
	await tap(&"jump")
	for i in 60:
		await ticks(1)
		highest = maxf(highest, player.global_position.y)
	expect(highest - start_y < player.jump_height * 0.6,
			"short hop should be well under a full jump, got %.2f m" % (highest - start_y))


func test_can_jump_onto_1_5m_block() -> void:
	await place(Vector3(-2, 0.05, 0), FACE_WEST)
	await run_and_jump(4.6, Vector3.LEFT)
	await ticks(20)
	expect_near(player.global_position.y, 1.5, 0.05, "height after jumping onto 1.5 m block")


func test_sprint_clears_5m_gap() -> void:
	await place(Vector3(0, 1.55, -42.3), FACE_NORTH)
	Input.action_press(&"sprint")
	await run_and_jump(44.7)
	Input.action_press(&"move_forward")
	await ticks(20)
	release_all()
	await ticks(20)
	expect(player.global_position.z < -50.0 and player.global_position.y > 1.4,
			"should land on Checkpoint 2 platform, ended at %s" % player.global_position)


func test_checkpoint_and_fall_respawn() -> void:
	await place(Vector3(0, 1.55, -24), FACE_NORTH)
	expect(player.respawn_position.is_equal_approx(Vector3(0, 1.5, -24)), "checkpoint 1 should be set")
	player.global_position = Vector3(10, 1.5, -40) # Over the void.
	await ticks(120)
	expect(player.global_position.distance_to(Vector3(0, 1.5, -24)) < 0.5,
			"should respawn at checkpoint 1, ended at %s" % player.global_position)


func test_respawn_button() -> void:
	await place(Vector3(5, 0.05, -5), FACE_NORTH)
	await tap(&"respawn")
	await ticks(5)
	expect(player.global_position.distance_to(player.respawn_position) < 0.1, "R should return to respawn point")
