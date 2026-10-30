extends GameTest
## The Free-Run Line: one straight course (built by tools/gen_free_run_line.sh)
## with every move in order, played with free-run and the superhuman profile.
## It runs north (toward -Z) from the spawn at z = 0.

var respawns := 0
## Every state the player has entered since the test began, in order.
var states_entered: Array[StringName] = []


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
		states_entered.clear()
		player.state_changed.connect(func(new_state: StringName) -> void: states_entered.append(new_state))


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
	expect(_holding("RelicOverGap"), "should grab the relic over the 7 m gap on the way")
	for off_line in ["RelicPillarTop", "RelicStreetNook", "RelicTallWall"]:
		expect(not _holding(off_line), "%s is off the line: free-run alone shouldn't get it" % off_line)


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
	expect(_holding("RelicTallWall"), "the relic on top should be picked up")


func test_the_pillar_relic_can_be_reached_by_hand() -> void:
	# A pillar 5 m off the lane's right edge (x = 9..12), top 5 m, beside the hurdles.
	await place(Vector3(3.5, 0.05, -73.1), FACE_NORTH) # Just clear of the hurdle at z = -72.
	expect(await jump_and_climb(Vector3.RIGHT, 5.0), "should jump across and climb the pillar, at %s" % player.global_position)
	# Step over to the relic in the middle of the pillar top.
	player.camera_rig.yaw = yaw_for(Vector3(10.5, 0, -72) - Vector3(player.global_position.x, 0, player.global_position.z))
	await hold(&"move_forward", 6)
	await ticks(10)
	expect(_holding("RelicPillarTop"), "the relic on the pillar should be picked up")


# --- Wall scramble (8.5 m wall at z = -507..-513), ledge leaps (tower at
#     z = -540..-550 with sills at x = -2..2, tops -10, -6, -2; roof +1) and the
#     grind rail (from z = -551, just past the roof, down to the landing at -22) ---

func test_scramble_up_a_wall_too_tall_to_grab() -> void:
	await place(Vector3(0, -14.95, -505), FACE_NORTH)
	states_entered.clear()
	expect(await jump_and_climb(Vector3.FORWARD, -6.5), "should get on top of the 8.5 m wall, at %s" % player.global_position)
	expect(&"WallScramble" in states_entered, "should scramble up it, went through %s" % [states_entered])


func test_only_one_scramble_per_wall() -> void:
	# A plain part of the tower (no sills at x = 3): far too tall even with a scramble.
	await place(Vector3(3, -14.95, -538), FACE_NORTH)
	states_entered.clear()
	Input.action_press(&"move_forward")
	Input.action_press(&"jump")
	await ticks(90)
	release_all()
	expect(states_entered.count(&"WallScramble") == 1, "should scramble exactly once, went through %s" % [states_entered])
	expect(player.global_position.y < -14.0, "and fall back down, at %s" % player.global_position)


func test_ledge_leaps_up_the_sills() -> void:
	await place(Vector3(0, -14.95, -538), FACE_NORTH)
	Input.action_press(&"move_forward")
	Input.action_press(&"jump")
	await _wait_for(&"Hang", 90)
	release_all()
	await ticks(20)
	expect_near(player.global_position.y, -10.0 - player.hang_height, 0.1, "hanging from the first sill")
	# Jumping on a sill (too narrow to stand on) leaps to the next one up...
	for sill_top in [-6.0, -2.0, 1.0]:
		await tap(&"jump")
		await ticks(30)
		expect_state(&"Hang")
		expect_near(player.global_position.y, sill_top - player.hang_height, 0.1, "after leaping up to the ledge at %.0f" % sill_top)
	# ...and from the roof edge (room to stand) it pulls you up.
	await tap(&"jump")
	expect(await wait_until_on_top(0.9, 60), "should climb onto the tower roof, at %s" % player.global_position)


func test_running_off_the_roof_lands_you_on_the_rail() -> void:
	await place(Vector3(0, 1.05, -545), FACE_NORTH)
	Input.action_press(&"move_forward")
	expect(await _wait_for(&"Grind", 90), "should land on the rail, at %s state %s" % [player.global_position, player.state.name])
	await ticks(10)
	var rail: GrindRail = main.level.get_node("GrindRails/RailDown")
	var under_feet := rail.point_at(rail.closest_t(player.global_position))
	expect_near(player.global_position.y - under_feet.y, GrindRail.RAIL_RADIUS, 0.05, "feet on top of the rail")


func test_grinding_speeds_up_and_flings_you_off_the_end() -> void:
	await place(Vector3(0, 1.05, -545), FACE_NORTH)
	Input.action_press(&"move_forward")
	await _wait_for(&"Grind", 90)
	release_all()
	await ticks(10)
	var early_speed := player.get_horizontal_speed()
	await ticks(60)
	expect(player.get_horizontal_speed() > early_speed + 5.0, "should speed up going down (%.1f -> %.1f)" % [early_speed, player.get_horizontal_speed()])
	expect(await _wait_for(&"Ground", 300), "should come off the end and land")
	expect(player.global_position.z < -638.0 and player.global_position.y > -22.5,
			"should land on the final platform, at %s" % player.global_position)
	expect(_holding("RelicRail"), "should pick up the relic along the rail")


func test_jump_off_the_rail_at_any_time() -> void:
	await place(Vector3(0, 1.05, -545), FACE_NORTH)
	Input.action_press(&"move_forward")
	await _wait_for(&"Grind", 90)
	release_all()
	await ticks(30)
	await tap(&"jump")
	expect_state(&"Air")
	expect(player.velocity.y > 0.0, "jumping off should go up a little")
	expect(player.get_horizontal_speed() > 8.0, "and keep the ride's speed, %.1f" % player.get_horizontal_speed())


func test_crouch_steps_off_the_rail() -> void:
	await place(Vector3(0, 1.05, -545), FACE_NORTH)
	Input.action_press(&"move_forward")
	await _wait_for(&"Grind", 90)
	release_all()
	await ticks(20)
	await tap(&"crouch")
	expect_state(&"Air")


func test_rails_only_go_downhill() -> void:
	# Land on the middle of the rail while moving uphill (toward +Z): you still slide down.
	var rail: GrindRail = main.level.get_node("GrindRails/RailDown")
	var middle := rail.point_at(0.5)
	player.global_position = middle + Vector3.UP * 0.2
	player.velocity = Vector3(0, -1, 10)
	player.change_state(&"Air")
	player.reset_physics_interpolation()
	await ticks(2)
	expect_state(&"Grind")
	await ticks(30)
	expect(player.global_position.z < middle.z - 1.0, "should be sliding toward the low end, at z = %.1f (grabbed at %.1f)" % [player.global_position.z, middle.z])


func test_free_run_takes_the_new_sections_to_the_end() -> void:
	await place(Vector3(0, -14.95, -490), FACE_NORTH)
	player.set_checkpoint(Vector3(0, -15, -490))
	states_entered.clear()
	await _free_run_for(60 * 20)
	expect(respawns == 0, "should never fall off, fell %d time(s)" % respawns)
	expect(player.global_position.z < -670.0, "should reach the end of the line, got to z = %.1f" % player.global_position.z)
	for state in [&"WallScramble", &"Hang", &"Grind"]:
		expect(state in states_entered, "should %s on the way" % state)


func _wait_for(state_name: StringName, max_ticks: int) -> bool:
	for i in max_ticks:
		await ticks(1)
		if player.state.name == state_name:
			return true
	return false


func _free_run_for(tick_count: int) -> void:
	Input.action_press(&"free_run")
	await ticks(tick_count)
	release_all()


## True if you're holding the relic with this name.
func _holding(relic_name: String) -> bool:
	var relic: WorldItem = main.level.get_node("Relics/" + relic_name)
	return relic.state == WorldItem.State.HELD and relic.holder_name == str(player.name)


# --- Leap: in free-run, hold jump to ready a leap, let go (or reach an edge) to take off ---

func test_holding_jump_in_free_run_readies_a_leap_instead_of_jumping() -> void:
	await place(Vector3(0, 0.05, 0), FACE_NORTH)
	Input.action_press(&"free_run")
	Input.action_press(&"jump")
	await ticks(15)
	expect_state(&"Ground")
	release_all()


func test_tapping_jump_in_free_run_is_a_normal_jump() -> void:
	await place(Vector3(0, 0.05, 0), FACE_NORTH)
	Input.action_press(&"free_run")
	await ticks(5)
	var ground_y := player.global_position.y
	await tap(&"jump")
	expect_near(await _highest_point() - ground_y, player.jump_height, 0.2, "tap jump height")
	release_all()


func test_a_full_leap_goes_higher_and_faster() -> void:
	await place(Vector3(0, 0.05, 0), FACE_NORTH)
	Input.action_press(&"free_run")
	await ticks(30)
	var run_speed := player.get_horizontal_speed()
	var ground_y := player.global_position.y
	await hold(&"jump", 30) # Longer than leap_charge_time.
	await ticks(2)
	expect(player.get_horizontal_speed() > run_speed + 2.0, "a leap should add a burst of speed (%.1f -> %.1f)" % [run_speed, player.get_horizontal_speed()])
	expect_near(await _highest_point() - ground_y, player.leap_height, 0.25, "full leap height")
	release_all()


func test_holding_jump_into_a_gap_leaps_it_without_full_flow() -> void:
	# Same slow start that falls into the 10 m gap (see test_the_10_m_gap_needs_flow).
	await place(Vector3(0, 0.05, -170), FACE_NORTH)
	Input.action_press(&"free_run")
	await ticks(30)
	Input.action_press(&"jump") # Ready a leap; free-run takes off at the edge.
	for i in 150:
		await ticks(1)
		if player.global_position.z < -195.0 and player.state.name == &"Ground":
			break
	release_all()
	expect(respawns == 0 and player.global_position.z < -193.0 and player.global_position.y > -0.5,
			"a leap should clear the 10 m gap, at %s" % player.global_position)


func test_letting_go_of_free_run_cancels_a_readied_leap() -> void:
	await place(Vector3(0, 0.05, 0), FACE_NORTH)
	Input.action_press(&"free_run")
	Input.action_press(&"jump")
	await ticks(15)
	Input.action_release(&"free_run")
	await ticks(2)
	Input.action_release(&"jump")
	await ticks(10)
	Input.action_press(&"free_run") # Back to free-run: no leftover leap.
	await ticks(10)
	expect_state(&"Ground")
	release_all()


## Waits for the top of the current jump; returns the highest y reached.
func _highest_point() -> float:
	var highest := player.global_position.y
	for i in 90:
		await ticks(1)
		highest = maxf(highest, player.global_position.y)
		if player.velocity.y < 0.0:
			break
	return highest


func test_grinding_keeps_your_hands_free() -> void:
	# A bulky glider in your hands (no climbing) doesn't stop you grinding.
	var glider: WorldItem = main.level.get_node("Items/Glider")
	glider.host_give_to(player)
	await place(Vector3(0, 1.05, -545), FACE_NORTH)
	Input.action_press(&"move_forward")
	expect(await _wait_for(&"Grind", 90), "should land on the rail holding the glider, state %s" % player.state.name)
	await ticks(20)
	expect_state(&"Grind")
	expect(player.items.hands_item() == glider, "and still be holding it")
	release_all()


func test_you_cant_land_on_a_rail_from_below() -> void:
	var rail: GrindRail = main.level.get_node("GrindRails/RailDown")
	var middle := rail.point_at(0.5)
	player.global_position = middle + Vector3.DOWN * 0.5
	player.velocity = Vector3(0, 8, 0) # Jumping up into it.
	player.change_state(&"Air")
	player.reset_physics_interpolation()
	await ticks(3)
	expect_state(&"Air")
