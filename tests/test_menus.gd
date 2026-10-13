extends GameTest
## Pause menu, leaving a game, and camera controls.


func test_pause_key_opens_menu_and_stops_movement() -> void:
	await _press_pause()
	expect(main.is_paused, "Esc should pause")
	expect(main.pause_menu.visible, "pause menu should be showing")
	await hold(&"move_forward", 30)
	expect_near(player.get_horizontal_speed(), 0.0, 0.01, "speed while paused")

	await _press_pause()
	expect(not main.is_paused, "Esc again should resume")
	await hold(&"move_forward", 30)
	expect(player.get_horizontal_speed() > 1.0, "should move again after resuming")


func test_leave_game_returns_to_main_menu() -> void:
	main.set_paused(true)
	main.leave_game()
	await ticks(5)
	expect(main.menu.visible, "main menu should be showing")
	expect(not main.pause_menu.visible, "pause menu should be closed")
	expect(main.players.get_child_count() == 0, "characters should be removed")
	expect(main.local_player == null, "no local player after leaving")

	main.start_solo()
	await ticks(5)
	expect(main.players.get_child_count() == 1, "can start a new game afterwards")


func test_arrow_keys_turn_camera_and_movement_follows() -> void:
	await hold(&"look_left", 30)
	var yaw := player.camera_rig.yaw
	expect(yaw > 0.5, "left arrow should turn the camera left, yaw is %.2f" % yaw)
	await hold(&"move_forward", 30)
	var camera_forward := Vector3.FORWARD.rotated(Vector3.UP, yaw)
	var run_direction := Vector3(player.velocity.x, 0.0, player.velocity.z).normalized()
	expect(run_direction.dot(camera_forward) > 0.99, "forward should follow the camera")


func test_solo_player_is_first_colour() -> void:
	expect(player.color_index == 0, "solo player should get colour 0")


func _press_pause() -> void:
	var event := InputEventAction.new()
	event.action = &"pause"
	event.pressed = true
	Input.parse_input_event(event)
	await ticks(3)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await ticks(3)
