extends GameTest
## The Free-Run Line: one straight course (built by tools/gen_free_run_line.sh)
## with every move in order, played with free-run and the superhuman profile.
## It runs north (toward -Z) from the spawn at z = 0.

var respawns := 0


func before_each() -> void:
	main = MAIN_SCENE.instantiate()
	add_child(main)
	main.start_solo("free_run_line")
	await ticks(5)
	player = main.get_node_or_null("Players/1")
	expect(player != null, "the game should have created a player")
	if player:
		player.set_profile(SUPERHUMAN)
		respawns = 0
		player.respawned.connect(func() -> void: respawns += 1)


func test_free_run_takes_the_whole_line_to_the_tall_wall() -> void:
	# Hold free-run the whole way; slide by hand down the slope (z = -372..-432).
	var visited := {}
	var lowest_flow := 1.0
	Input.action_press(&"free_run")
	for i in 60 * 45:
		await ticks(1)
		var z := player.global_position.z
		if z < -374.0 and z > -433.0:
			Input.action_press(&"crouch")
		else:
			Input.action_release(&"crouch")
		visited[player.state.name] = true
		if z < -50.0:
			lowest_flow = minf(lowest_flow, player.flow)
		if z < -470.0:
			break
	release_all()
	expect(respawns == 0, "should never fall off, fell %d time(s)" % respawns)
	expect(lowest_flow > 0.9, "vaults, slides and wall runs shouldn't break your flow, lowest %d%%" % roundi(lowest_flow * 100))
	expect(player.global_position.z < -470.0, "should reach the tall wall, got to z = %.1f" % player.global_position.z)
	for state in [&"Slide", &"WallRun", &"Climb"]:
		expect(visited.has(state), "should %s somewhere along the line" % state)
	expect(main.collected_relics.has("RelicOverGap"), "should collect the relic over the 7 m gap on the way")
	for off_line in ["RelicPillarTop", "RelicStreetNook", "RelicTallWall"]:
		expect(not main.collected_relics.has(off_line), "%s is off the line: free-run alone shouldn't get it" % off_line)


func test_the_10_m_gap_needs_flow() -> void:
	# Start slow on the 7 m gap's landing (z = -167..-183); the 10 m gap follows.
	await place(Vector3(0, 0.05, -170), FACE_NORTH)
	await _free_run_for(180)
	expect(respawns > 0, "without full flow you should fall into the 10 m gap")

	respawns = 0
	await place(Vector3(0, 0.05, -170), FACE_NORTH)
	player.debug_full_flow = true
	await _free_run_for(120)
	expect(respawns == 0 and player.global_position.z < -195.0, "at full flow you should clear it, at %s" % player.global_position)


func test_the_slope_gap_needs_a_slide() -> void:
	# Running down the slope isn't fast enough for the 14 m gap at its foot...
	await place(Vector3(0, 0.05, -366), FACE_NORTH)
	player.debug_full_flow = true
	await _free_run_for(420)
	expect(respawns > 0, "running (not sliding) down the slope should fall short of the 14 m gap")

	# ...sliding down it is.
	respawns = 0
	await place(Vector3(0, 0.05, -366), FACE_NORTH)
	Input.action_press(&"free_run")
	for i in 420:
		await ticks(1)
		if player.global_position.z < -374.0:
			Input.action_press(&"crouch")
		if player.global_position.z < -432.0:
			Input.action_release(&"crouch")
		if player.global_position.z < -450.0 and player.state.name == &"Ground":
			break
	release_all()
	expect(respawns == 0 and player.global_position.z < -446.0, "a slide should carry you over the gap, at %s" % player.global_position)


func test_free_run_stops_at_the_tall_wall() -> void:
	await place(Vector3(0, -14.95, -460), FACE_NORTH)
	await _free_run_for(120)
	expect_state(&"Ground")
	expect(player.global_position.z > -477.0 and player.global_position.y < -14.0,
			"free-run shouldn't get over the 12 m wall by itself, at %s" % player.global_position)


func test_the_tall_wall_can_be_climbed_by_hand() -> void:
	# Ledge blocks on its south face: x = -4..-2 (top -10) and x = -1.5..0.5 (top -5).
	await place(Vector3(-1.0, -14.95, -476), FACE_NORTH)
	expect(await jump_and_climb(Vector3.LEFT, -10.0), "should get onto the first ledge, at %s" % player.global_position)
	expect(await jump_and_climb(Vector3.RIGHT, -5.0), "should get onto the second ledge, at %s" % player.global_position)
	expect(await jump_and_climb(Vector3.FORWARD, -3.0), "should get onto the wall top, at %s" % player.global_position)
	await hold(&"move_forward", 20)
	expect(main.collected_relics.has("RelicTallWall"), "the relic on top should be collected")


func test_the_pillar_relic_can_be_reached_by_hand() -> void:
	# A pillar 5 m off the lane's right edge (x = 9..12), top 5 m, beside the hurdles.
	await place(Vector3(3.5, 0.05, -73.1), FACE_NORTH) # Just clear of the hurdle at z = -72.
	expect(await jump_and_climb(Vector3.RIGHT, 5.0), "should jump across and climb the pillar, at %s" % player.global_position)
	# Step over to the relic in the middle of the pillar top.
	player.camera_rig.yaw = yaw_for(Vector3(10.5, 0, -72) - Vector3(player.global_position.x, 0, player.global_position.z))
	await hold(&"move_forward", 6)
	await ticks(10)
	expect(main.collected_relics.has("RelicPillarTop"), "the relic on the pillar should be collected")


func test_the_timer_runs_from_start_to_finish() -> void:
	await _free_run_for(40) # Through the start gate at z = -6.
	expect(main.run_start_msec >= 0, "the start gate should start the timer")
	await place(Vector3(0, -14.95, -497), FACE_NORTH)
	await _free_run_for(60) # Through the finish gate at z = -505.
	expect(main.run_start_msec == -1, "the finish gate should stop the timer")
	expect(main.best_run_time < INF, "a time should be recorded")
	expect(main.hud.get_node("Timer").text.contains(":"), "the HUD should show the time")


func _free_run_for(tick_count: int) -> void:
	Input.action_press(&"free_run")
	await ticks(tick_count)
	release_all()
