extends GameTest
## The reachability checker (game/reach/): where players can get to and what
## it takes. Two kinds of test:
## - Calibration: for a move's limit, the checker's answer matches what the
##   real game does, just inside and just outside it.
## - Intent: the rooftop district is what we meant (every ordinary roof solo,
##   the sky relic needs a friend...).

const FLOOR_Y := 200.0
const WALL_FACE_Z := -20.0

var states_entered: Array[StringName] = []


# --- Calibration (walls built over a floor high above the test course) --------

func test_scramble_heights_match_the_game() -> void:
	await _build_floor_and_walls([30.0])
	var map := ReachMap.build(main.level, SUPERHUMAN)
	for leap in [false, true]:
		await place(Vector3(0, FLOOR_Y + 0.05, WALL_FACE_Z + 20.0), FACE_NORTH)
		Input.action_press(&"free_run")
		if leap:
			Input.action_press(&"jump") # Ready a leap: free-run takes off at the wall.
		var highest := 0.0
		for i in 240:
			await ticks(1)
			highest = maxf(highest, player.global_position.y - FLOOR_Y)
		release_all()
		var expected := map.scramble_height(SUPERHUMAN.leap_height if leap else SUPERHUMAN.jump_height)
		expect_near(highest, expected, 0.25, "a %s scramble's height (the checker says %.2f)" % ["leap" if leap else "jump", expected])


func test_a_running_jump_goes_as_far_as_the_checker_says() -> void:
	await _build_floor_and_walls([])
	var map := ReachMap.build(main.level, SUPERHUMAN)
	await place(Vector3(0, FLOOR_Y + 0.05, 40.0), FACE_NORTH)
	Input.action_press(&"move_forward")
	for i in 60:
		player.flow = 0.0 # Plain running speed.
		await ticks(1)
	var took_off := player.global_position.z
	Input.action_press(&"jump")
	for i in 120:
		player.flow = 0.0
		await ticks(1)
		if player.is_on_floor() and i > 5:
			break
	release_all()
	# (The checker is a little cautious: the real jump goes a touch further.)
	var length := took_off - player.global_position.z
	var expected := map.air_distance(SUPERHUMAN.jump_height, SUPERHUMAN.run_speed, 0.0)
	expect(length >= expected and length <= expected + 0.6, "a running jump's length: %.2f m, the checker says %.2f" % [length, expected])


func test_walls_one_player_can_and_cannot_climb() -> void:
	# 10 m: alone, but only with a readied leap. 11.5 m: nobody (a toss reaches
	# about 10.6 m, and a hanging chain needs someone up there first).
	await _build_floor_and_walls([10.0, 11.5])
	var map := ReachMap.build(main.level, SUPERHUMAN)
	var start := _floor(map)
	expect(map.players_needed(_wall(map, 0), start) == 1, "the checker should say one player gets up 10 m")
	expect(map.players_needed(_wall(map, 1), start) == 0, "and nobody gets up 11.5 m, says %d" % map.players_needed(_wall(map, 1), start))
	expect(await _free_run_up(0, true), "in the game, a readied leap gets you up 10 m, via %s" % [states_entered])
	expect(not await _free_run_up(1, true), "but not 11.5 m, via %s" % [states_entered])


func test_a_toss_then_a_hanging_chain_gets_everyone_up() -> void:
	# 10.5 m: too tall alone. A toss gets one of two up; they hang down and the
	# tosser climbs them.
	await _build_floor_and_walls([10.5])
	var map := ReachMap.build(main.level, SUPERHUMAN)
	var start := _floor(map)
	expect(map.players_needed(_wall(map, 0), start) == 2, "the checker should say 10.5 m needs two, says %d" % map.players_needed(_wall(map, 0), start))
	expect(map.solve(start, 2).get(_wall(map, 0), 0) == 2, "and that both of them get up")
	expect(not await _free_run_up(0, true), "in the game, alone you can't, via %s" % [states_entered])
	# The toss: the buddy throws you at the wall and you grab the top.
	main.call_buddy()
	var buddy: Player = main.buddy
	buddy.set_profile(SUPERHUMAN)
	await place(Vector3(0, FLOOR_Y + 0.05, WALL_FACE_Z + 1.5), FACE_NORTH)
	buddy.global_position = player.global_position + Vector3.BACK * 1.0
	buddy.reset_physics_interpolation()
	await ticks(10)
	await press_event(&"buddy_toss_me")
	Input.action_press(&"move_forward")
	var on_top := false
	for i in 150:
		await ticks(1)
		if player.state.name == &"Hang":
			Input.action_press(&"jump")
		if player.is_on_floor() and player.global_position.y > FLOOR_Y + 10.0:
			on_top = true
			break
	release_all()
	expect(on_top, "a toss should get you up 10.5 m, at %s" % player.global_position)
	# The chain: the buddy (as if it had tossed up first) hangs; you climb it.
	var feet := Vector3(0, FLOOR_Y + 10.5 - buddy.hang_height, WALL_FACE_Z + buddy.body_radius + 0.05)
	buddy.global_position = feet
	buddy.reset_physics_interpolation()
	buddy.change_state(&"Hang", {"ledge": buddy.find_ledge(feet, Vector3.FORWARD)})
	await ticks(10)
	expect(await _free_run_up(0, true), "and climbing a friend hanging there gets you up, via %s" % [states_entered])


func test_the_glider_reaches_a_far_lower_roof() -> void:
	# From a 30 m tower to a 20 m one 40 m away: far beyond a jump, an easy glide.
	await _build_floor_and_walls([30.0])
	_box("ReachFarRoof", Vector3(0, FLOOR_Y + 10.0, WALL_FACE_Z - 80.0), Vector3(20, 20, 20))
	await ticks(3)
	var map := ReachMap.build(main.level, SUPERHUMAN)
	var far := map.place_named("ReachFarRoof")
	expect(not map.solve(_wall(map, 0), 1).has(far), "without a glider you can't get across")
	expect(map.solve(_wall(map, 0), 1, [&"flow", &"glider"]).has(far), "with one you can")


# --- Intent: the rooftop district ------------------------------------------------

func test_every_ordinary_roof_can_be_reached_alone() -> void:
	await _load_district()
	var map := ReachMap.build(main.level, SUPERHUMAN)
	var reached := map.solve(_spawn(map), 1)
	var street := map.place_under(Vector3(0, 0.5, 0))
	var from_street := map.solve(street, 1)
	var missing := []
	for b: CSGBox3D in main.level.get_node("Buildings").get_children():
		var roof := map.place_named(b.name)
		if b.size.y < 30.0 and not (reached.has(roof) and from_street.has(roof)):
			missing.append(b.name)
	expect(missing.is_empty(), "every roof but the towers should be reachable alone, from the start and from the street: %s" % [missing])


func test_every_drainpipe_sill_column_and_vent_is_a_way_up() -> void:
	await _load_district()
	var map := ReachMap.build(main.level, SUPERHUMAN)
	var ways := {"drainpipe": 0, "window sills": 0}
	for link in map.links:
		if ways.has(link.how) and link.to.y > link.from.y + 10.0:
			ways[link.how] += 1
	var pipes: int = main.level.find_children("*", "Drainpipe", true, false).size()
	var columns: int = main.level.find_children("*_Sill1", "CSGBox3D", true, false).size()
	var vents: int = main.level.find_children("*", "AirVent", true, false).size()
	expect(ways["drainpipe"] == pipes, "each of the %d drainpipes should lead up to a roof, %d do" % [pipes, ways["drainpipe"]])
	expect(ways["window sills"] == columns, "each of the %d sill columns should, %d do" % [columns, ways["window sills"]])
	var vent_roofs := {}
	for link in map.links:
		if link.how == "air vent":
			vent_roofs[link.to] = true
	expect(vent_roofs.size() >= vents, "each of the %d vents should blow you up to a roof, %d roofs reached" % [vents, vent_roofs.size()])


func test_the_towers_have_no_way_up_yet() -> void:
	await _load_district()
	var map := ReachMap.build(main.level, SUPERHUMAN)
	for b: CSGBox3D in main.level.get_node("Buildings").get_children():
		if b.size.y >= 30.0:
			expect(map.players_needed(map.place_named(b.name), _spawn(map), [&"flow", &"glider"]) == 0,
					"%s is a tower: nothing gets up it yet (when something does, update this test)" % b.name)


func test_what_each_relic_takes() -> void:
	await _load_district()
	var map := ReachMap.build(main.level, SUPERHUMAN)
	for target in map.targets:
		var needed := map.players_needed(target, _spawn(map))
		var meant := 2 if target.name == "RelicSky" else 1
		expect(needed == meant, "%s should need %d player(s), the checker says %d" % [target.name, meant, needed])


# --- Helpers ---------------------------------------------------------------------

## A floor high over the test course and, side by side 40 m apart along x, a
## wall of each height in `heights` (their faces at WALL_FACE_Z, facing south).
## Grey-box CSG boxes, as levels use, so the checker sees them.
func _build_floor_and_walls(heights: Array) -> void:
	player.set_profile(SUPERHUMAN)
	player.state_changed.connect(func(new_state: StringName) -> void: states_entered.append(new_state))
	_box("ReachFloor", Vector3(0, FLOOR_Y - 0.5, 0), Vector3(200, 1, 200))
	for i in heights.size():
		_box("ReachWall%d" % i, Vector3(i * 40.0, FLOOR_Y + heights[i] / 2.0, WALL_FACE_Z - 10.0), Vector3(20, heights[i], 20))
	await ticks(3) # CSG builds its collision a moment later.


func _box(box_name: String, at: Vector3, size: Vector3) -> void:
	var box := CSGBox3D.new()
	box.name = box_name
	box.size = size
	box.use_collision = true
	main.level.add_child(box)
	box.global_position = at


func _floor(map: ReachMap) -> ReachMap.Spot:
	return map.place_named("ReachFloor")


func _wall(map: ReachMap, i: int) -> ReachMap.Spot:
	return map.place_named("ReachWall%d" % i)


## Free-runs at wall `i` (readying a leap if `leap`); true if you end up on top.
func _free_run_up(i: int, leap: bool) -> bool:
	await place(Vector3(i * 40.0, FLOOR_Y + 0.05, WALL_FACE_Z + 20.0), FACE_NORTH)
	states_entered.clear()
	Input.action_press(&"free_run")
	if leap:
		Input.action_press(&"jump")
	var on_top := false
	for i_tick in 60 * 4:
		await ticks(1)
		if player.state.name == &"ChainHang":
			Input.action_release(&"jump") # (Free-run climbs the chain for you.)
		if player.is_on_floor() and player.global_position.y > FLOOR_Y + 5.0:
			on_top = true
			break
	release_all()
	return on_top


func _load_district() -> void:
	main.queue_free()
	await ticks(2)
	main = MAIN_SCENE.instantiate()
	add_child(main)
	main.start_solo("rooftop_district")
	await ticks(5)
	player = main.get_node("Players/1")


func _spawn(map: ReachMap) -> ReachMap.Spot:
	return map.place_under(main.level.get_node("SpawnPoint").global_position + Vector3.UP)
