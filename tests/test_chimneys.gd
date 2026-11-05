extends GameTest
## Chimneys (Player.try_chimney_kick(), game/reach/rules/chimney.gd):
## free-running with jump held between two walls facing each other across a
## narrow gap, you kick from wall to wall up to the top of the lower one.

const FLOOR_Y := 500.0

var states_entered: Array[StringName] = []


func before_each() -> void:
	await super()
	player.set_profile(SUPERHUMAN)
	player.state_changed.connect(func(new_state: StringName) -> void: states_entered.append(new_state))


func test_up_a_chimney_this_wide_and_no_wider() -> void:
	# The checker and the game agree: just narrow enough climbs (to the top of
	# the lower wall), a little wider doesn't.
	for case: Array in [[Player.CHIMNEY_WIDTH - 0.5, true], [Player.CHIMNEY_WIDTH + 1.0, false]]:
		var width: float = case[0]
		var root := _chimney(width, 20.0, 35.0)
		await ticks(3)
		var map := ReachMap.build(root, SUPERHUMAN)
		var floor_place := map.place_under(Vector3(0.0, FLOOR_Y + 1.0, 0.0))
		var lower := map.place_under(Vector3(-width / 2.0 - 3.0, FLOOR_Y + 100.0, 0.0))
		var linked := map.links.any(func(l: ReachMap.Link) -> bool: return l.from == floor_place and l.to == lower and l.how == "chimney")
		expect(linked == case[1], "the checker: a %.1f m chimney %s" % [width, "climbs" if case[1] else "doesn't"])
		var made := await _climb(Vector3(width / 2.0 - 0.6, FLOOR_Y + 0.55, 0.0), Vector3.LEFT, FLOOR_Y + 20.0)
		expect(made == case[1], "the game: a %.1f m chimney %s, at %s (went %s)" % [width, "climbs" if case[1] else "doesn't", player.global_position, states_entered.slice(-6)])
		root.free()
		await ticks(3)


func test_scrambling_up_one_wall_you_kick_across_to_the_other() -> void:
	# (Free-run often meets the first wall head-on, and starts to scramble up it.)
	var root := _chimney(4.0, 30.0, 30.0)
	await ticks(3)
	await place(Vector3(1.4, FLOOR_Y + 2.0, 0.0), yaw_for(Vector3.RIGHT))
	player.change_state(&"WallScramble", {"wall_normal": Vector3.LEFT})
	states_entered.clear()
	Input.action_press(&"free_run")
	Input.action_press(&"jump")
	await ticks(3)
	release_all()
	expect(player.state.name == &"Air" and player.velocity.x < -5.0, "kicked off across the chimney (%s, %s)" % [player.state.name, player.velocity])
	root.free()


func test_running_down_a_narrow_gap_doesnt_climb_it() -> void:
	# Free-running along it (jump held, readying a leap), you run, not climb.
	var root := _chimney(4.0, 30.0, 30.0)
	await ticks(3)
	await place(Vector3(1.2, FLOOR_Y + 0.55, 8.0), yaw_for(Vector3.FORWARD))
	Input.action_press(&"free_run")
	Input.action_press(&"jump")
	var highest := 0.0
	for i in 90:
		await ticks(1)
		if i == 20:
			player.camera_rig.yaw = yaw_for(Vector3(0.3, 0, -1).normalized()) # (Drifting into a wall.)
		highest = maxf(highest, player.global_position.y - FLOOR_Y)
	release_all()
	expect(highest < 4.0, "ran down it, %.1f m up at most" % highest)
	root.free()


func test_under_a_lid_you_stop_kicking() -> void:
	# (A chimney with something across its top, a walkway, say: no kicking into it.)
	var root := _chimney(4.0, 30.0, 30.0)
	var lid := CSGBox3D.new()
	lid.size = Vector3(4.0, 1.0, 20.0)
	lid.use_collision = true
	root.add_child(lid)
	lid.position = Vector3(0.0, FLOOR_Y + 12.0, 0.0)
	await ticks(3)
	await place(Vector3(1.4, FLOOR_Y + 0.55, 0.0), yaw_for(Vector3.LEFT))
	Input.action_press(&"free_run")
	Input.action_press(&"move_forward")
	Input.action_press(&"jump")
	# (Its underside is 11.5 m up: a kick needs the head HOP_RISE + 1 m clear of it.)
	var near_lid := FLOOR_Y + 11.5 - 1.8 - Player.CHIMNEY_HOP_RISE - 1.0
	var kicks_near_lid := 0
	var was_up := false
	player.chimney_kicks = 0
	for i in 60 * 4:
		var before := player.chimney_kicks
		await ticks(1)
		was_up = was_up or player.global_position.y > FLOOR_Y + 5.0
		if player.chimney_kicks > before and player.global_position.y > near_lid + 0.2:
			kicks_near_lid += 1
	release_all()
	expect(was_up and player.chimney_kicks > 0, "climbed up toward the lid (%d kicks)" % player.chimney_kicks)
	expect(kicks_near_lid == 0, "but no kicking up into it (%d kicks right under it)" % kicks_near_lid)
	root.free()


func test_up_an_alley_downtown() -> void:
	main.leave_game()
	await ticks(5)
	main.start_solo("rooftop_district")
	await ticks(10)
	player = main.get_node("Players/1")
	player.set_profile(SUPERHUMAN)
	player.state_changed.connect(func(new_state: StringName) -> void: states_entered.append(new_state))
	var map := ReachMap.shared(main.level, SUPERHUMAN)
	var ground := map.place_named("Ground")
	var link: ReachMap.Link
	for l in map.links:
		if l.how == "chimney" and l.from == ground and l.to.name.begins_with("Tower") and l.to.y > 40.0:
			link = l
			break
	expect(link != null, "the checker: up an alley between towers, alone")
	if link == null:
		return
	# Find the alley beside the lower tower's top, and climb it.
	var roof := link.to
	var start := Vector3.INF
	var toward := Vector3.ZERO
	for out: Vector3 in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		var edge := roof.middle() + Vector3(out.x * roof.area.size.x, 0, out.z * roof.area.size.y) / 2.0
		var across := player.raycast(edge + out * 0.3 + Vector3.DOWN * 3.0, edge + out * (Player.CHIMNEY_WIDTH + 0.3) + Vector3.DOWN * 3.0)
		if not across.is_empty():
			start = Vector3(edge.x, 0.05, edge.z) + out * 0.6
			toward = out
			break
	expect(start != Vector3.INF, "an alley beside %s" % roof.name)
	if start == Vector3.INF:
		return
	var made := await _climb(start, toward, roof.y)
	expect(made, "climbed the alley to %s (%.0f m), at %s" % [roof.name, roof.y, player.global_position])


## Free-runs (jump held) from `start` at the wall that way; true if you end
## up standing at `height` or higher.
func _climb(start: Vector3, toward: Vector3, height: float) -> bool:
	await place(start, yaw_for(toward))
	states_entered.clear()
	Input.action_press(&"free_run")
	Input.action_press(&"move_forward")
	Input.action_press(&"jump")
	var made := false
	for i in 60 * 30:
		await ticks(1)
		if player.state.name == &"Hang":
			Input.action_release(&"jump") # (At the top, holding its edge: pull up.)
			await tap(&"jump")
			Input.action_press(&"jump")
		if player.is_on_floor() and player.global_position.y > height - 0.3:
			made = true
			break
		if i > 120 and player.is_on_floor() and player.global_position.y < start.y + 1.0:
			break # (Back on the ground: it didn't take.)
	release_all()
	return made


## Way up in the sky: a floor, and two walls `width` apart along x (the left
## one `left` tall, the right one `right`). Returns their root (free it after).
func _chimney(width: float, left: float, right: float) -> Node3D:
	var root := Node3D.new()
	main.level.add_child(root)
	for box: Array in [[Vector3(0, FLOOR_Y - 0.5, 0), Vector3(60, 1, 40)],
			[Vector3(-width / 2.0 - 6.0, FLOOR_Y + left / 2.0, 0), Vector3(12, left, 20)],
			[Vector3(width / 2.0 + 6.0, FLOOR_Y + right / 2.0, 0), Vector3(12, right, 20)]]:
		var b := CSGBox3D.new()
		b.size = box[1]
		b.position = box[0]
		b.use_collision = true
		root.add_child(b)
	return root
