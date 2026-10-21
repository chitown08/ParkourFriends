extends GameTest
## The Old Town world (first slice). Mostly checks that the ledge-block routes
## up each building really can be climbed solo, using a little climbing robot
## that follows the zig-zag blocks the way a player would.

## Height between ledge blocks (matches LEDGE_RISE in the level generator).
const LEDGE_RISE := 5.0


func before_each() -> void:
	main = MAIN_SCENE.instantiate()
	add_child(main)
	main.start_solo("old_town")
	await ticks(5)
	player = main.get_node_or_null("Players/1")
	expect(player != null, "the game should have created a player")
	if player:
		player.set_profile(SUPERHUMAN)


func test_spawns_on_the_plaza() -> void:
	await ticks(30)
	expect(main.level.name == &"OldTown", "Old Town should be loaded, got %s" % main.level.name)
	expect_state(&"Ground")
	expect(player.global_position.distance_to(Vector3(0, 0.3, 57)) < 0.2, "should stand at the spawn, at %s" % player.global_position)


func test_menu_default_world_is_the_free_run_line() -> void:
	main.leave_game()
	await ticks(5)
	main.start_solo() # Whatever the menu has selected.
	await ticks(5)
	expect(main.level != null and main.level.name == &"FreeRunLine", "the menu should default to the Free-Run Line")


func test_climb_shops() -> void:
	await _climb(Vector3(-60, 0, 45), Vector3(0, 0, 1), Vector3(1, 0, 0), 1, 9.6)


func test_climb_block_with_three_ledges() -> void:
	await _climb(Vector3(-69, 0, -18), Vector3(0, 0, 1), Vector3(1, 0, 0), 3, 19.2)


func test_climb_glider_roof() -> void:
	await _climb(Vector3(52.5, 0, -9), Vector3(0, 0, 1), Vector3(-1, 0, 0), 4, 24.0)


func test_climb_offices() -> void:
	await _climb(Vector3(81, 0, -82.5), Vector3(0, 0, 1), Vector3(1, 0, 0), 7, 40.0)


func test_climb_clock_tower() -> void:
	await _climb(Vector3(-7.5, 0, -51), Vector3(1, 0, 0), Vector3(0, 0, 1), 12, 64.0)


func test_bridge_pillar_needs_a_toss() -> void:
	# Alone: jumping at the 9 m pillar (x = 141..147) from the bridge stub gets nowhere.
	await place(Vector3(139.5, 0.05, -15), yaw_for(Vector3.RIGHT))
	Input.action_press(&"move_forward")
	Input.action_press(&"jump")
	await ticks(90)
	release_all()
	await ticks(10)
	var on_stub := player.state.name == &"Ground" and absf(player.global_position.y) < 0.2 \
			and player.global_position.x > 123.0 and player.global_position.x < 141.0
	expect(on_stub, "should still be standing on the bridge stub, unable to climb the pillar, at %s" % player.global_position)

	# With the practice buddy's toss: up you go.
	await place(Vector3(138, 0.05, -15), yaw_for(Vector3.RIGHT))
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
	var climbed := await wait_until_on_top(8.9, 60)
	expect(climbed, "a toss should get you onto the pillar (top 9 m), at %s" % player.global_position)


func test_bridge_pillar_to_greece() -> void:
	await place(Vector3(144, 9.05, -15), yaw_for(Vector3.RIGHT))
	player.debug_full_flow = true # Top speed straight away.
	Input.action_press(&"move_forward")
	Input.action_press(&"jump")
	for i in 120:
		await ticks(1)
		if player.state.name == &"Ground" and player.global_position.x > 150.0:
			break
	release_all()
	await ticks(30)
	expect(player.global_position.x > 159.0 and player.global_position.y > -16.5 and player.global_position.y < -9.0,
			"should land on the Greek side of the bridge or the island, at %s" % player.global_position)


func test_free_run_climbs_the_broken_stairway() -> void:
	# Greece's broken stairway: three blocks rising 4 m each with gaps between
	# (tops at about -12.8, -8.8 and -4.8). Free-run should take it all the way up.
	await place(Vector3(180, -15.9, 27), yaw_for(Vector3.RIGHT))
	var highest := -99.0
	Input.action_press(&"free_run")
	for i in 300:
		await ticks(1)
		highest = maxf(highest, player.global_position.y)
	release_all()
	expect(highest > -5.0, "should reach the top step (about -4.8), highest %.2f" % highest)


# --- The climbing robot ----------------------------------------------------------

## Climbs a zig-zag of ledge blocks up a building and onto its roof.
## `wall_point`/`along`/`out` describe the wall face the blocks are on (same
## numbers the level generator used), `count` is how many blocks.
func _climb(wall_point: Vector3, along: Vector3, out: Vector3, count: int, roof_height: float) -> void:
	# Start on the ground just before the first block, level with its middle.
	await place(wall_point - along * 1.0 + out * 1.0 + Vector3.UP * 0.05, yaw_for(along))
	for k in range(1, count + 1):
		var direction := along if (k == 1 or k % 2 == 0) else -along
		if not await jump_and_climb(direction, LEDGE_RISE * k):
			failures.append("couldn't get onto ledge block %d of %d (at %s, state %s)" % [k, count, player.global_position, player.state.name])
			return
	if not await jump_and_climb(-out, roof_height):
		failures.append("couldn't get from the last ledge onto the roof (at %s, state %s)" % [player.global_position, player.state.name])
