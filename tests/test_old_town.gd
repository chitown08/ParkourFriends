extends GameTest
## The Old Town world (first slice). Mostly checks that the ledge-block routes
## up each building really can be climbed solo, using a little climbing robot
## that follows the zig-zag blocks the way a player would.


func before_each() -> void:
	main = MAIN_SCENE.instantiate()
	add_child(main)
	main.start_solo("old_town")
	await ticks(5)
	player = main.get_node_or_null("Players/1")
	expect(player != null, "the game should have created a player")


func test_spawns_on_the_plaza() -> void:
	await ticks(30)
	expect(main.level.name == &"OldTown", "Old Town should be loaded, got %s" % main.level.name)
	expect_state(&"Ground")
	expect(player.global_position.distance_to(Vector3(0, 0.3, 38)) < 0.2, "should stand at the spawn, at %s" % player.global_position)


func test_menu_default_world_is_old_town() -> void:
	main.leave_game()
	await ticks(5)
	main.start_solo() # Whatever the menu has selected.
	await ticks(5)
	expect(main.level != null and main.level.name == &"OldTown", "the menu should default to Old Town")


func test_climb_shops() -> void:
	await _climb(Vector3(-40, 0, 30), Vector3(0, 0, 1), Vector3(1, 0, 0), 1, 6.0)


func test_climb_block_with_three_ledges() -> void:
	await _climb(Vector3(-46, 0, -12), Vector3(0, 0, 1), Vector3(1, 0, 0), 3, 12.0)


func test_climb_glider_roof() -> void:
	await _climb(Vector3(35, 0, -6), Vector3(0, 0, 1), Vector3(-1, 0, 0), 4, 15.0)


func test_climb_offices() -> void:
	await _climb(Vector3(54, 0, -55), Vector3(0, 0, 1), Vector3(1, 0, 0), 8, 25.0)


func test_climb_clock_tower() -> void:
	await _climb(Vector3(-5, 0, -34), Vector3(1, 0, 0), Vector3(0, 0, 1), 13, 40.0)


func test_bridge_pillar_needs_a_toss() -> void:
	# Alone: jumping at the 6 m pillar (x = 94..98) from the bridge stub gets nowhere.
	await place(Vector3(92.5, 0.05, -10), _yaw_for(Vector3.RIGHT))
	Input.action_press(&"move_forward")
	Input.action_press(&"jump")
	await ticks(90)
	release_all()
	await ticks(10)
	var on_stub := player.state.name == &"Ground" and absf(player.global_position.y) < 0.2 \
			and player.global_position.x > 82.0 and player.global_position.x < 94.0
	expect(on_stub, "should still be standing on the bridge stub, unable to climb the pillar, at %s" % player.global_position)

	# With the practice buddy's toss: up you go.
	await place(Vector3(91, 0.05, -10), _yaw_for(Vector3.RIGHT))
	await press_event(&"call_buddy")
	await ticks(20)
	Input.action_press(&"move_forward")
	await press_event(&"buddy_toss_me")
	for i in 120:
		await ticks(1)
		if player.state.name in [&"Hang", &"Climb"]:
			break
	release_all()
	if player.state.name == &"Hang":
		await tap(&"jump") # Pull up.
	var climbed := await _wait_until_on_top(5.9, 60)
	expect(climbed, "a toss should get you onto the pillar (top 6 m), at %s" % player.global_position)


func test_bridge_pillar_to_greece() -> void:
	await place(Vector3(96, 6.05, -10), _yaw_for(Vector3.RIGHT))
	Input.action_press(&"sprint")
	Input.action_press(&"move_forward")
	Input.action_press(&"jump")
	for i in 120:
		await ticks(1)
		if player.state.name == &"Ground" and player.global_position.x > 100.0:
			break
	release_all()
	await ticks(30)
	expect(player.global_position.x > 103.0 and player.global_position.y > -10.5 and player.global_position.y < -5.0,
			"should land on the Greek side of the bridge or the island, at %s" % player.global_position)


# --- The climbing robot ----------------------------------------------------------

## Climbs a zig-zag of ledge blocks up a building and onto its roof.
## `wall_point`/`along`/`out` describe the wall face the blocks are on (same
## numbers the level generator used), `count` is how many blocks.
func _climb(wall_point: Vector3, along: Vector3, out: Vector3, count: int, roof_height: float) -> void:
	# Start on the ground just before the first block, level with its middle.
	await place(wall_point - along * 1.0 + out * 1.0 + Vector3.UP * 0.05, _yaw_for(along))
	for k in range(1, count + 1):
		var direction := along if (k == 1 or k % 2 == 0) else -along
		if not await _jump_and_climb(direction, 3.0 * k):
			failures.append("couldn't get onto ledge block %d of %d (at %s, state %s)" % [k, count, player.global_position, player.state.name])
			return
	if not await _jump_and_climb(-out, roof_height):
		failures.append("couldn't get from the last ledge onto the roof (at %s, state %s)" % [player.global_position, player.state.name])


## Jumps toward `direction`, grabs/vaults whatever is there and climbs up.
## Returns true if the player ends up standing at about `expected_height`.
func _jump_and_climb(direction: Vector3, expected_height: float) -> bool:
	release_all()
	player.camera_rig.yaw = _yaw_for(direction)
	await ticks(2)
	Input.action_press(&"move_forward")
	Input.action_press(&"jump")
	for i in 90:
		await ticks(1)
		if player.state.name in [&"Hang", &"Climb"]:
			break
	release_all()
	if player.state.name == &"Hang":
		await tap(&"jump")
	return await _wait_until_on_top(expected_height - 0.1, 60)


func _wait_until_on_top(min_height: float, max_ticks: int) -> bool:
	for i in max_ticks:
		await ticks(1)
		if player.state.name == &"Ground" and player.global_position.y >= min_height:
			await ticks(3)
			return true
	return false


func _yaw_for(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)
