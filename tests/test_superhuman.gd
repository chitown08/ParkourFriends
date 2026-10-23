extends GameTest
## The superhuman movement profile and flow (momentum). Runs in Old Town, which
## has long streets to build up speed in.

## A long clear street: from the plaza west toward the Shops (wall at x = -60).
const STREET_START := Vector3(0, 0.35, 57)


func before_each() -> void:
	main = MAIN_SCENE.instantiate()
	add_child(main)
	main.start_solo("old_town")
	await ticks(5)
	player = main.get_node_or_null("Players/1")
	expect(player != null, "the game should have created a player")
	if player:
		player.set_profile(SUPERHUMAN)


func test_superhuman_jump_is_about_3_m() -> void:
	await ticks(20)
	var start_y := player.global_position.y
	var highest := start_y
	Input.action_press(&"jump")
	for i in 60:
		await ticks(1)
		highest = maxf(highest, player.global_position.y)
	expect_near(highest - start_y, 3.0, 0.15, "superhuman jump height")


func test_flow_builds_from_run_speed_to_top_speed() -> void:
	await place(STREET_START, FACE_WEST)
	Input.action_press(&"move_forward")
	await ticks(15)
	expect_near(player.get_horizontal_speed(), 10.0, 1.0, "starting run speed")
	await ticks(roundi(player.flow_build_time * 60))
	expect_near(player.flow, 1.0, 0.01, "flow after running for 3 s")
	expect_near(player.get_horizontal_speed(), 15.0, 0.2, "top speed")


func test_crashing_into_a_wall_drains_flow() -> void:
	await place(Vector3(-40, 0.35, 57), FACE_WEST)
	player.flow = 1.0
	Input.action_press(&"move_forward") # Straight into the Shops wall (x = -60).
	await ticks(120)
	expect(player.global_position.x > -60.0, "test setup: should be stopped by the wall")
	expect_near(player.flow, 0.0, 0.01, "flow after crashing into a wall")


func test_jumping_keeps_flow() -> void:
	await place(STREET_START, FACE_WEST)
	player.flow = 1.0
	Input.action_press(&"move_forward")
	await ticks(10)
	await tap(&"jump")
	await ticks(20)
	expect_state(&"Air")
	expect(player.get_horizontal_speed() > 14.0, "should keep top speed in the air, %.2f" % player.get_horizontal_speed())
	expect(player.flow > 0.95, "a jump shouldn't break your flow, flow %.2f" % player.flow)


func test_buddy_gets_your_profile() -> void:
	await press_event(&"call_buddy")
	await ticks(5)
	expect(main.buddy.profile == player.profile, "the buddy should use your movement profile")


func test_switching_to_the_human_profile() -> void:
	player.set_profile(HUMAN)
	expect_near(player.jump_height, 1.7, 0.01, "human jump height")
	expect_near(player.run_speed, 6.0, 0.01, "human run speed")
	player.set_profile(SUPERHUMAN)
	expect_near(player.jump_height, 3.0, 0.01, "back to superhuman")
