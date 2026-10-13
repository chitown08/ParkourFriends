extends GameTest
## The solo practice buddy: G calls it, E tosses it, Q makes it toss you.

const FACE_SOUTH := PI


func test_call_buddy_appears_in_front() -> void:
	await press_event(&"call_buddy")
	var buddy: Player = main.buddy
	expect(buddy != null, "G should create the buddy")
	if buddy == null:
		return
	await ticks(30)
	expect(buddy.is_bot, "buddy should be a bot")
	var expected := player.global_position + Vector3.FORWARD * 1.5
	expect(Vector2(buddy.global_position.x - expected.x, buddy.global_position.z - expected.z).length() < 0.1,
			"buddy should stand 1.5 m in front, it's at %s" % buddy.global_position)
	expect(buddy.state.name == &"Ground", "buddy should be standing on the ground")
	expect(main.local_player == player, "you should still be the local player")
	expect(main.hud.player == player, "the HUD should still follow you")
	expect(player.camera_rig.get_node("SpringArm3D/Camera3D").current, "your camera should still be in use")


func test_calling_again_moves_the_buddy() -> void:
	await press_event(&"call_buddy")
	await place(Vector3(5, 0.05, -5), FACE_WEST)
	await press_event(&"call_buddy")
	await ticks(10)
	expect(main.players.get_child_count() == 2, "there should still be just one buddy")
	expect(main.buddy.global_position.distance_to(Vector3(3.5, 0.0, -5)) < 0.2,
			"buddy should move in front of you again, it's at %s" % main.buddy.global_position)


func test_toss_the_buddy() -> void:
	await press_event(&"call_buddy")
	await ticks(20)
	await tap(&"toss")
	expect(main.buddy.state.name == &"Air", "buddy should be launched")
	expect(main.buddy.velocity.y > 5.0, "buddy should fly upward, vy = %.2f" % main.buddy.velocity.y)


func test_buddy_tosses_you() -> void:
	await press_event(&"call_buddy")
	await ticks(20)
	await press_event(&"buddy_toss_me")
	expect_state(&"Air")
	expect(player.global_position.y > 1.0, "you should be flying, at %s" % player.global_position)


func test_buddy_cannot_toss_you_from_far_away() -> void:
	await press_event(&"call_buddy")
	await place(Vector3(0, 0.05, 0), FACE_NORTH) # 4.5 m from the buddy.
	await press_event(&"buddy_toss_me")
	expect_state(&"Ground")


func test_buddy_midair_toss_reaches_the_high_tower() -> void:
	# The buddy stands between you and the 7.5 m tower (face at z = 26).
	await place(Vector3(-25, 0.05, 23), FACE_SOUTH)
	await press_event(&"call_buddy")
	await ticks(20)
	Input.action_press(&"move_forward")
	Input.action_press(&"jump") # Full jump...
	await ticks(18)
	await press_event(&"buddy_toss_me") # ...and get tossed near the top of it.
	var grabbed := false
	for i in 90:
		await ticks(1)
		if player.state.name in [&"Hang", &"Climb"]:
			grabbed = true
			break
	expect(grabbed, "should grab the top of the 7.5 m tower, ended at %s" % player.global_position)


func test_buddy_respawns_where_it_was_called() -> void:
	await press_event(&"call_buddy")
	await ticks(20)
	var spot: Vector3 = main.buddy.global_position
	main.buddy.global_position = Vector3(0, -20, 0) # Below the kill height.
	await ticks(5)
	expect(main.buddy.global_position.distance_to(spot) < 0.2, "buddy should come back to where it was called")


func test_buddy_ignores_checkpoints() -> void:
	await press_event(&"call_buddy")
	await ticks(10)
	var buddy_respawn: Vector3 = main.buddy.respawn_position
	main.buddy.global_position = Vector3(0, 1.6, -24) # Checkpoint 1.
	await ticks(20)
	expect(main.buddy.respawn_position == buddy_respawn, "a checkpoint shouldn't move the buddy's return point")
	expect(player.respawn_position != Vector3(0, 1.5, -24), "the buddy shouldn't set *your* checkpoint")
