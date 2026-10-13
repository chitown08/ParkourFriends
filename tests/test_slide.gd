extends GameTest
## Crouching, sliding, slide-jumps. Mostly in the Slide Yard (x = 10..40):
## low bars at x = 18, 22, 26 (lane z = 2..6), and a slope from x = 22 to 34
## (lane z = -7..-3) ending in an 8 m gap at x = 40.

const FACE_EAST := -PI / 2 ## Toward +X (the Slide Yard).


func test_crouch_walks_slowly_and_shrinks() -> void:
	Input.action_press(&"crouch")
	Input.action_press(&"move_forward")
	await ticks(60)
	expect_state(&"Crouch")
	expect(player.is_crouched, "body should be crouched")
	expect_near(player.get_horizontal_speed(), player.crouch_speed, 0.05, "crouch walk speed")
	Input.action_release(&"crouch")
	await ticks(10)
	expect_state(&"Ground")
	expect(not player.is_crouched, "should stand back up")


func test_slide_boosts_then_slows_into_crouch() -> void:
	# A long clear strip along the back of the start pad (z = 8.5), heading west.
	await place(Vector3(8, 0.05, 8.5), FACE_WEST)
	Input.action_press(&"sprint")
	Input.action_press(&"move_forward")
	await ticks(40)
	Input.action_press(&"crouch")
	await ticks(2)
	expect_state(&"Slide")
	var start_speed := player.get_horizontal_speed()
	expect(start_speed > player.sprint_speed + 0.5, "slide should start faster than a sprint, got %.2f" % start_speed)
	await ticks(30)
	expect(player.get_horizontal_speed() < start_speed - 1.0, "slide should slow down on flat ground")
	for i in 200:
		await ticks(1)
		if player.state.name == &"Crouch":
			break
	expect_state(&"Crouch")
	release_all()
	await ticks(10)
	expect_state(&"Ground")


func test_walking_speed_crouches_instead_of_sliding() -> void:
	Input.action_press(&"move_forward")
	await ticks(3) # Barely moving yet.
	Input.action_press(&"crouch")
	await ticks(2)
	expect_state(&"Crouch")


func test_slide_under_low_bars() -> void:
	await place(Vector3(12, 0.05, 4), FACE_EAST)
	Input.action_press(&"sprint")
	Input.action_press(&"move_forward")
	var visited := {}
	for i in 150:
		await ticks(1)
		if player.global_position.x > 15.0:
			Input.action_press(&"crouch")
		visited[player.state.name] = true
		if player.global_position.x > 28.0:
			break
	expect(visited.has(&"Slide"), "should have slid")
	expect(player.global_position.x > 27.0, "should get past all three bars, got to x = %.2f" % player.global_position.x)


func test_standing_run_is_blocked_by_low_bar() -> void:
	await place(Vector3(12, 0.05, 4), FACE_EAST)
	Input.action_press(&"sprint")
	await hold(&"move_forward", 90)
	expect(player.global_position.x < 17.8 - player.body_radius + 0.1,
			"should be stopped by the first bar, got to x = %.2f" % player.global_position.x)


func test_cannot_stand_up_under_a_bar() -> void:
	# Crouch-walk from between two bars to underneath the second one.
	await place(Vector3(19.5, 0.05, 4), FACE_EAST)
	Input.action_press(&"crouch")
	Input.action_press(&"move_forward")
	for i in 120:
		await ticks(1)
		if player.global_position.x >= 22.0:
			break
	Input.action_release(&"move_forward")
	await ticks(10)
	Input.action_release(&"crouch")
	await ticks(10)
	expect_state(&"Crouch")
	expect(player.is_crouched, "should stay crouched under the bar")

	# Walking out from under it lets you stand.
	await hold(&"move_forward", 40)
	await ticks(5)
	expect_state(&"Ground")
	expect(not player.is_crouched, "should stand once clear of the bar")


func test_slope_slide_and_jump_clears_8m_gap() -> void:
	await place(Vector3(19, 3.05, -5), FACE_EAST)
	Input.action_press(&"sprint")
	Input.action_press(&"move_forward")
	var top_speed := 0.0
	var jumped := false
	for i in 240:
		await ticks(1)
		if player.global_position.x > 21.0:
			Input.action_press(&"crouch")
		top_speed = maxf(top_speed, player.get_horizontal_speed())
		if not jumped and player.global_position.x > 39.3:
			Input.action_press(&"jump")
			jumped = true
		if jumped and player.state.name == &"Ground":
			break
	release_all()
	await ticks(10)
	expect(top_speed > player.sprint_speed + 2.0, "slope should speed the slide up, top speed %.2f" % top_speed)
	expect(player.global_position.x > 48.0 and player.global_position.y > -0.1,
			"should land on the far side, ended at %s" % player.global_position)


func test_sprint_jump_cannot_clear_8m_gap() -> void:
	await place(Vector3(33, 0.05, -5), FACE_EAST)
	Input.action_press(&"sprint")
	Input.action_press(&"move_forward")
	var jumped := false
	for i in 120:
		await ticks(1)
		if not jumped and player.global_position.x > 39.3:
			Input.action_press(&"jump")
			jumped = true
	release_all()
	expect(player.global_position.y < -1.0, "a plain sprint-jump should fall short, ended at %s" % player.global_position)


func test_slide_jump_keeps_speed_in_the_air() -> void:
	await place(Vector3(8, 0.05, 8.5), FACE_WEST)
	Input.action_press(&"sprint")
	Input.action_press(&"move_forward")
	await ticks(40)
	Input.action_press(&"crouch")
	await ticks(3)
	await tap(&"jump")
	await ticks(10)
	expect_state(&"Air")
	expect(not player.is_crouched, "should stand up to jump")
	expect(player.get_horizontal_speed() > player.sprint_speed + 0.5,
			"should keep slide speed in the air, got %.2f" % player.get_horizontal_speed())
