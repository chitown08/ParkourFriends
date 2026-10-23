extends GameTest
## The receiving end of a toss, tried with one player by calling apply_toss()
## directly (as if a friend had tossed you). The real two-player version is in
## test_toss_network.gd. Toss Yard towers: 5.5 m (x = -22..-18, z = 12..16)
## and 8.5 m (x = -27..-23, z = 26..30).

const FACE_SOUTH := PI


func test_solo_jump_cannot_reach_the_low_tower() -> void:
	await place(Vector3(-20, 0.05, 19), FACE_NORTH)
	Input.action_press(&"move_forward")
	Input.action_press(&"jump")
	await ticks(120)
	expect(player.global_position.y < 1.0, "a solo jump shouldn't get up the 5.5 m tower, at %s" % player.global_position)


func test_ground_toss_reaches_the_low_tower() -> void:
	await place(Vector3(-20, 0.05, 17.5), FACE_NORTH)
	Input.action_press(&"move_forward") # Push toward the wall to grab the top.
	player.apply_toss(player.toss_velocity(FACE_NORTH))
	expect_state(&"Air")
	if await _wait_for_state([&"Hang", &"Climb"], 90):
		release_all()
		await ticks(40)
	expect_near(player.global_position.y, 5.5, 0.1, "height after being tossed up the low tower")


func test_ground_toss_cannot_reach_the_high_tower() -> void:
	await place(Vector3(-25, 0.05, 24.5), FACE_SOUTH)
	Input.action_press(&"move_forward")
	player.apply_toss(player.toss_velocity(FACE_SOUTH))
	await ticks(120)
	expect(player.global_position.y < 1.0, "a ground toss shouldn't reach the 8.5 m tower, at %s" % player.global_position)


func test_midair_toss_reaches_the_high_tower() -> void:
	await place(Vector3(-25, 0.05, 24.5), FACE_SOUTH)
	Input.action_press(&"move_forward")
	Input.action_press(&"jump") # A full, held jump: a short hop isn't high enough.
	await ticks(20) # Near the top of the jump.
	player.apply_toss(player.toss_velocity(FACE_SOUTH))
	expect(await _wait_for_state([&"Hang", &"Climb"], 90), "should grab the top of the 8.5 m tower")
	await ticks(10) # Let the hand-hold settle into place.
	expect(player.global_position.y > 8.5 - player.hang_height - 0.1, "should be up at the top, at %s" % player.global_position)


func test_can_only_be_tossed_once_per_air_time() -> void:
	player.apply_toss(player.toss_velocity(FACE_NORTH))
	await ticks(10)
	var vy := player.velocity.y
	player.apply_toss(player.toss_velocity(FACE_NORTH))
	expect(player.velocity.y <= vy, "a second toss in the same air time should do nothing")
	await ticks(90) # Land.
	expect_state(&"Ground")
	player.apply_toss(player.toss_velocity(FACE_NORTH))
	expect(player.velocity.y > 10.0, "after landing you can be tossed again")


func test_unlimited_juggling_when_limit_is_off() -> void:
	player.limit_tosses_per_air = false
	player.apply_toss(player.toss_velocity(FACE_NORTH))
	await ticks(10)
	player.apply_toss(player.toss_velocity(FACE_NORTH))
	expect(player.velocity.y > 10.0, "with the limit off, a second toss works mid-air")


func test_toss_stands_you_up_from_a_crouch() -> void:
	Input.action_press(&"crouch")
	await ticks(5)
	expect(player.is_crouched, "test setup: should be crouched")
	player.apply_toss(player.toss_velocity(FACE_NORTH))
	expect_state(&"Air")
	expect(not player.is_crouched, "a toss should stand you up")


func test_toss_with_nobody_around_does_nothing() -> void:
	expect(not player.try_toss(), "no one to toss in solo")
	await tap(&"toss")
	expect_state(&"Ground")


## Waits up to `max_ticks` for the player to enter one of `states`.
func _wait_for_state(states: Array[StringName], max_ticks: int) -> bool:
	for i in max_ticks:
		await ticks(1)
		if player.state.name in states:
			return true
	return false
