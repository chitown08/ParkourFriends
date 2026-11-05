extends GameTest
## Ways back up in the rooftop district (tools/gen_district.gd): yellow
## drainpipes (player/states/pipe_climb.gd) and columns of window sills up the
## buildings, and orange air vents on the pavement (levels/air_vent.gd).

var states_entered: Array[StringName] = []


func before_each() -> void:
	main = MAIN_SCENE.instantiate()
	add_child(main)
	main.start_solo("rooftop_district")
	await ticks(5)
	player = main.get_node_or_null("Players/1")
	expect(player != null, "the game should have created a player")
	if player:
		player.set_profile(SUPERHUMAN)
		player.state_changed.connect(func(new_state: StringName) -> void: states_entered.append(new_state))


func test_every_flat_roof_has_a_way_up() -> void:
	var missing := []
	for b in _buildings():
		if b.size.y > 30.0 or not _is_flat(b):
			continue # Towers, old-town houses and sawtooth sheds.
		var area := _footprint(b).grow(3.5) # (A fire escape step's middle is 1.5 m out.)
		var ways: Array = main.level.get_node("FireEscapes").get_children() + main.level.get_node("WaysUp").get_children()
		if not ways.any(func(way: Node3D) -> bool: return area.has_point(Vector2(way.global_position.x, way.global_position.z))):
			missing.append(b.name)
	expect(missing.is_empty(), "every flat-roofed building should have a fire escape, drainpipe or sills: %s" % [missing])
	expect(_pipes().size() >= 8, "there should be drainpipes about, %d" % _pipes().size())
	expect(_sill_columns().size() >= 3, "and columns of sills, %d" % _sill_columns().size())
	expect(_vents().size() >= 20, "and an air vent in most blocks, %d" % _vents().size())


func test_ways_up_are_yellow_and_vents_orange() -> void:
	for sill in _sill_columns():
		expect(sill.material == load("res://materials/grid_climb.tres"), "%s should be yellow (climb)" % sill.name)
	expect(Drainpipe.MATERIAL == load("res://materials/grid_climb.tres"), "drainpipes should be yellow (climb)")
	expect(AirVent.MATERIAL == load("res://materials/grid_ramp.tres"), "air vents should be orange (launch)")


func test_nothing_on_the_pavement_sits_on_a_vent() -> void:
	for vent in _vents():
		var grate := Rect2(vent.global_position.x - AirVent.SIZE / 2.0, vent.global_position.z - AirVent.SIZE / 2.0, AirVent.SIZE, AirVent.SIZE)
		for thing: CSGBox3D in main.level.get_node("StreetClutter").get_children():
			expect(not _footprint(thing).intersects(grate), "%s is on %s" % [thing.name, vent.name])


func test_run_into_a_drainpipe_and_climb_it_to_the_roof() -> void:
	var pipe := _tallest_pipe()
	var start := _in_front_of(pipe, 4.0)
	await place(start, yaw_for(-pipe.out_of_wall()))
	Input.action_press(&"move_forward")
	var climbing_ticks := 0
	for i in 60 * 12:
		await ticks(1)
		if player.state.name == &"PipeClimb":
			climbing_ticks += 1
		if player.is_on_floor() and player.global_position.y > pipe.top() - 0.2:
			break
	release_all()
	expect(&"PipeClimb" in states_entered, "should grab the pipe, went through %s" % [states_entered])
	expect(player.global_position.y > pipe.top() - 0.2 and player.is_on_floor(), "should end up on the roof (%.1f m), at %s in %s" % [pipe.top(), player.global_position, player.state.name])
	var fastest := (pipe.top() - 3.0) / player.pipe_climb_speed
	expect(climbing_ticks / 60.0 > fastest, "climbing should be slow and steady, took %.1f s for %.1f m" % [climbing_ticks / 60.0, pipe.top()])


func test_free_run_climbs_a_drainpipe() -> void:
	var pipe := _tallest_pipe()
	# A run-up (as long as the street or alley it faces leaves room for).
	var run_up := 10.0
	var across := player.raycast(_in_front_of(pipe, 0.5) + Vector3.UP, _in_front_of(pipe, 20.0) + Vector3.UP)
	if not across.is_empty():
		run_up = minf(run_up, (across.position - pipe.point_at(1.0)).length() - 1.5)
	await place(_in_front_of(pipe, run_up), yaw_for(-pipe.out_of_wall()))
	Input.action_press(&"free_run")
	for i in 60 * 12:
		await ticks(1)
		if player.is_on_floor() and player.global_position.y > pipe.top() - 0.2:
			break
	release_all()
	expect(&"PipeClimb" in states_entered and not &"WallScramble" in states_entered, "free-run should run into the pipe and climb it, not scramble, went through %s" % [states_entered])
	expect(player.global_position.y > pipe.top() - 0.2, "and get onto the roof, at %s" % player.global_position)


func test_slide_down_or_kick_off_a_drainpipe() -> void:
	var pipe := _tallest_pipe()
	await place(_in_front_of(pipe, 1.5), yaw_for(-pipe.out_of_wall()))
	await hold(&"move_forward", 90) # Up the pipe a way...
	expect_state(&"PipeClimb")
	var high := player.global_position.y
	expect(high > 3.0, "should have climbed, at %.1f m" % high)
	await hold(&"move_back", 60) # ...then pull away: slide back down.
	await ticks(10)
	expect(player.global_position.y < 0.5 and player.state.name == &"Ground", "pulling away should slide you down, at %s in %s" % [player.global_position, player.state.name])

	await hold(&"move_forward", 60)
	expect_state(&"PipeClimb")
	await tap(&"jump")
	await ticks(5)
	var away := (player.global_position - pipe.point_at(player.global_position.y)).dot(pipe.out_of_wall())
	expect(player.state.name == &"Air" and player.velocity.dot(pipe.out_of_wall()) > 3.0, "jump should kick you off the wall, %s going %s" % [player.state.name, player.velocity])
	expect(away > 0.5, "away from the pipe, %.1f m" % away)


func test_climb_a_column_of_sills() -> void:
	var sills := _sills_of(_sill_columns()[0])
	var lowest: CSGBox3D = sills[0]
	var out := _out_of_wall(lowest)
	var top := _building_top_behind(lowest)
	await place(Vector3(lowest.global_position.x, 0.05, lowest.global_position.z) + out * 4.0, yaw_for(-out)) # (It may face a 5 m alley.)
	Input.action_press(&"free_run")
	for i in 60 * 15:
		await ticks(1)
		if player.is_on_floor() and player.global_position.y > top - 0.2:
			break
	release_all()
	expect(&"Hang" in states_entered, "should hang from the sills on the way, went through %s" % [states_entered])
	expect(player.global_position.y > top - 0.2, "free-run should leap up the sills to the roof (%.1f m), at %s" % [top, player.global_position])


func test_an_air_vent_blows_you_up_to_the_roof() -> void:
	var vent := _vents()[0]
	var wall := _wall_beside(vent)
	var roof: float = vent.rise - 1.0
	await place(vent.global_position + Vector3.UP * 0.5 - wall * 2.0, yaw_for(wall))
	Input.action_press(&"move_forward") # Walk onto it, pushing toward the wall.
	var highest := -INF
	for i in 60 * 5:
		await ticks(1)
		highest = maxf(highest, player.global_position.y)
		if player.state.name == &"Hang":
			Input.action_press(&"jump") # Pull up.
		if player.is_on_floor() and player.global_position.y > roof - 0.2:
			break
	release_all()
	expect(highest > roof, "the vent should blow you up past the roof (%.1f m), highest %.1f" % [roof, highest])
	expect(player.global_position.y > roof - 0.2, "and you grab the edge and climb on, at %s" % player.global_position)


# --- Helpers -------------------------------------------------------------------

func _pipes() -> Array[Drainpipe]:
	var found: Array[Drainpipe] = []
	for child in main.level.get_node("WaysUp").get_children():
		if child is Drainpipe and not child is Scaffold and absf(child.global_position.y) < 0.01: # (Old town: from the street.)
			found.append(child)
	return found


func _tallest_pipe() -> Drainpipe:
	var pipes := _pipes()
	pipes.sort_custom(func(a: Drainpipe, b: Drainpipe) -> bool: return a.height > b.height)
	return pipes[0]


## The lowest sill of each column.
func _sill_columns() -> Array[CSGBox3D]:
	var found: Array[CSGBox3D] = []
	for child in main.level.get_node("WaysUp").get_children():
		if String(child.name).ends_with("_Sill1"):
			found.append(child)
	return found


func _sills_of(lowest: CSGBox3D) -> Array[CSGBox3D]:
	var found: Array[CSGBox3D] = []
	var prefix := String(lowest.name).trim_suffix("1")
	var k := 1
	while main.level.has_node("WaysUp/%s%d" % [prefix, k]):
		found.append(main.level.get_node("WaysUp/%s%d" % [prefix, k]))
		k += 1
	return found


func _vents() -> Array[AirVent]:
	var found: Array[AirVent] = []
	for child in main.level.get_node("AirVents").get_children():
		found.append(child)
	return found


func _in_front_of(pipe: Drainpipe, distance: float) -> Vector3:
	return pipe.point_at(0.05) + pipe.out_of_wall() * distance


## Which way a sill faces (out of its wall): its short side.
func _out_of_wall(sill: CSGBox3D) -> Vector3:
	var building := _building_beside(sill.global_position, sill.size.x < sill.size.z)
	var out := sill.global_position - building.global_position
	return Vector3(signf(out.x), 0, 0) if sill.size.x < sill.size.z else Vector3(0, 0, signf(out.z))


func _building_top_behind(sill: CSGBox3D) -> float:
	var b := _building_beside(sill.global_position, sill.size.x < sill.size.z)
	return b.global_position.y + b.size.y / 2.0


## The building whose wall `at` is against (across x if `across_x`).
func _building_beside(at: Vector3, across_x: bool) -> CSGBox3D:
	var best: CSGBox3D
	var best_gap := INF
	for b in _buildings():
		var r := _footprint(b)
		var gap := r.grow(0.0).get_center().distance_to(Vector2(at.x, at.z))
		if r.grow(1.0).has_point(Vector2(at.x, at.z)) and gap < best_gap:
			best = b
			best_gap = gap
	return best


## The way from a vent toward the wall of the building it blows you up.
func _wall_beside(vent: AirVent) -> Vector3:
	var at := Vector2(vent.global_position.x, vent.global_position.z)
	for b in _buildings():
		var r := _footprint(b)
		if r.grow(AirVent.SIZE).has_point(at):
			var middle := r.get_center()
			var inside := Vector2(clampf(at.x, r.position.x, r.end.x), clampf(at.y, r.position.y, r.end.y))
			var toward := (inside - at).normalized()
			return Vector3(toward.x, 0, toward.y) if toward != Vector2.ZERO else Vector3(middle.x - at.x, 0, middle.y - at.y).normalized()
	return Vector3.FORWARD


func _buildings() -> Array[CSGBox3D]:
	var found: Array[CSGBox3D] = []
	for child in main.level.get_node("Buildings").get_children():
		if child is CSGBox3D: # (Not round ones.)
			found.append(child as CSGBox3D)
	return found


func _is_flat(b: CSGBox3D) -> bool: # (Not a sloped roof, nor another shape.)
	return not b.has_meta(&"shape") and main.level.get_node("Roofs").get_children().all(func(roof: Node) -> bool:
			return not String(roof.name).begins_with(b.name + "_"))


func _footprint(b: CSGBox3D) -> Rect2:
	return Rect2(b.global_position.x - b.size.x / 2.0, b.global_position.z - b.size.z / 2.0, b.size.x, b.size.z)
