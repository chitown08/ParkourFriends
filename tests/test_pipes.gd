extends GameTest
## Pipes (levels/pipe.gd): big round tubes you can run round the inside of,
## going fast enough (player/states/pipe_run.gd). One 40 m long running north,
## on a big floor high above the test course.

const FLOOR_Y := 200.0

var pipe: Pipe


func before_each() -> void:
	await super()
	player.set_profile(SUPERHUMAN)
	var floor_box := CSGBox3D.new()
	floor_box.name = "PipeFloor"
	floor_box.size = Vector3(200, 1, 200)
	floor_box.use_collision = true
	main.level.add_child(floor_box)
	floor_box.global_position = Vector3(0, FLOOR_Y - 0.5, 0)
	pipe = Pipe.new()
	pipe.length = 40.0
	pipe.radius = 4.5
	main.level.add_child(pipe)
	pipe.global_position = Vector3(0, FLOOR_Y, -10) # Runs north from z = -10 to -50.
	await ticks(3)


func test_free_running_at_full_flow_takes_you_right_round() -> void:
	var most := await _run_across(true)
	expect(most > 175.0, "fast, you go up the wall, over the ceiling and round: got %.0f° round" % most)


func test_just_running_you_go_up_the_side_and_back_down() -> void:
	var most := await _run_across(false)
	expect(most > Pipe.ENTER_ANGLE and most < 120.0, "slower, you get some way up the side and no further: %.0f°" % most)
	await ticks(120)
	expect(player.state.name in [&"Ground", &"PipeRun"] and player.global_position.y < FLOOR_Y + 1.5, "and come back down to the bottom (%s, %.1f m up)" % [player.state.name, player.global_position.y - FLOOR_Y])


## The checker's loop_speed() matches the real thing: a little faster gets you
## over the top, a little slower drops you off.
func test_loop_speed_is_what_it_takes() -> void:
	var speed := pipe.loop_speed()
	expect(speed > SUPERHUMAN.free_run_speed and speed < SUPERHUMAN.flow_speed, "a loop needs more than free-running, less than full flow: %.1f m/s" % speed)
	expect(await _round_from_bottom(speed + 0.5) > 175.0, "just faster than loop speed: over the top")
	var most := await _round_from_bottom(speed - 1.0)
	expect(most < 175.0, "just slower: you don't make it over (%.0f°)" % most)
	expect(player.state.name in [&"Air", &"Ground"], "you drop off (%s)" % player.state.name)
	expect(body_clear_on_leaving, "upright, clear of the ceiling, as you drop")


func test_jump_off_the_wall() -> void:
	await _round_from_bottom(pipe.loop_speed() + 0.5, 25)
	expect_state(&"PipeRun")
	var at := pipe.locate(player.global_position)
	expect(absf(rad_to_deg(at.y)) > 60.0, "test setup: up the wall (%.0f°)" % rad_to_deg(at.y))
	await tap(&"jump")
	release_all()
	expect_state(&"Air")
	expect(player.velocity.dot(pipe.inward(at.y)) > 3.0, "jumping pushes you off the wall, in toward the middle")
	expect(player.body_fits(player.global_position), "and you're upright, clear of the wall")
	await ticks(150)
	expect(player.is_on_floor() and pipe.contains(player.global_position), "you land back inside, on the floor (%s)" % player.global_position)


func test_run_through_and_out_the_end() -> void:
	await place(pipe.surface_point(2.0, 0.0) + Vector3.UP * 0.05, FACE_NORTH)
	Input.action_press(&"move_forward")
	await ticks(60 * 7)
	release_all()
	expect(player.global_position.z < pipe.global_position.z - pipe.length, "straight through and out the far end: z = %.1f" % player.global_position.z)


func test_the_checker_knows_what_it_takes() -> void:
	var relic := preload("res://items/world_item.tscn").instantiate() as WorldItem
	relic.name = "CeilingRelic"
	relic.item = preload("res://items/data/relic.tres")
	main.level.add_child(relic)
	relic.global_position = pipe.axis_point(20.0) + Vector3.UP * (pipe.radius - 1.2) # Up on the ceiling.
	var roof := CSGBox3D.new() # And one tower at each end, a glass tube between their roofs.
	roof.name = "TowerA"
	roof.size = Vector3(20, 30, 20)
	roof.use_collision = true
	main.level.add_child(roof)
	roof.global_position = Vector3(100, FLOOR_Y + 15, 0)
	var other := roof.duplicate() as CSGBox3D
	other.name = "TowerB"
	main.level.add_child(other)
	other.global_position = Vector3(100, FLOOR_Y + 15, -50)
	var tube := Pipe.new()
	tube.glass = true
	tube.length = 30.0
	tube.radius = 3.0
	main.level.add_child(tube)
	tube.global_position = Vector3(100, FLOOR_Y + 30, -10) # From TowerA's north edge to TowerB's south edge.
	var past := relic.duplicate() as WorldItem # Ceiling height, but just past the far end.
	past.name = "PastTheEnd"
	main.level.add_child(past)
	past.global_position = pipe.axis_point(pipe.length + 2.0) + Vector3.UP * (pipe.radius - 1.2)
	var low_roof := roof.duplicate() as CSGBox3D # A tube from TowerA's east edge, over a roof 6 m lower.
	low_roof.name = "LowRoof"
	main.level.add_child(low_roof)
	low_roof.global_position = Vector3(140, FLOOR_Y + 9, 0)
	var drop := Pipe.new()
	drop.length = 25.0
	drop.radius = 3.0
	main.level.add_child(drop)
	drop.global_position = Vector3(107, FLOOR_Y + 30, 0)
	drop.rotation.y = -PI / 2.0 # (Running east.)
	await ticks(3)
	var map := ReachMap.shared(main.level, SUPERHUMAN)
	var start := map.place_named("PipeFloor")
	var needs := []
	for link in map.links:
		if link.from == start and link.to.name == "CeilingRelic" and link.how == "pipe loop":
			needs = link.needs
	expect(needs == [&"flow"], "round the tube to the ceiling: at full flow (%s)" % [needs])
	expect(map.players_needed(map.target_named("CeilingRelic"), start, []) != 1, "not without it")
	var through := false
	for link in map.links:
		if link.from.name == "TowerA" and link.to.name == "TowerB" and link.how == "pipe":
			through = true
	expect(through, "the glass tube joins the two towers' roofs")
	expect(not map.links.any(func(link: ReachMap.Link) -> bool: return link.to.name == "PastTheEnd" and link.how == "pipe loop"),
			"a relic just past the end of the tube isn't in it")
	expect(not map.links.any(func(link: ReachMap.Link) -> bool: return link.from.name == "LowRoof" and link.how == "pipe"),
			"a roof well below the end of a tube doesn't lead into it")


## Runs east at the tube's side wall from the middle of its floor (free-running
## at full flow, or just running); returns the furthest round you got (degrees).
func _run_across(fast: bool) -> float:
	await place(pipe.surface_point(20.0, -0.35) + Vector3.UP * 0.3, FACE_NORTH) # Up the west side a little.
	player.camera_rig.yaw = -PI / 2.0 # Facing east.
	if fast:
		player.debug_full_flow = true
		Input.action_press(&"free_run")
	Input.action_press(&"move_forward")
	var most := 0.0
	for i in 60 * 4:
		await ticks(1)
		if player.state.name == &"PipeRun":
			most = maxf(most, absf(rad_to_deg(pipe.locate(player.global_position).y)))
	release_all()
	player.debug_full_flow = false
	return most


## Starts you running round from the bottom at `speed`, free-running at full
## flow with the camera across the tube (so running pushes you on round);
## returns the furthest round you got (degrees) in `tick_count` ticks.
## Whether, the moment you came off the wall in _round_from_bottom(), your body
## stood clear of the tube.
var body_clear_on_leaving := true


func _round_from_bottom(speed: float, tick_count := 150) -> float:
	await place(pipe.surface_point(20.0, 0.0) + Vector3.UP * 0.05, -PI / 2.0)
	player.debug_full_flow = true
	Input.action_press(&"free_run")
	player.global_position = pipe.surface_point(20.0, 0.0)
	player.velocity = pipe.around(0.0) * speed
	player.change_state(&"PipeRun", {"pipe": pipe})
	var most := 0.0
	var was_on := true
	for i in tick_count:
		await ticks(1)
		if player.state.name == &"PipeRun":
			most = maxf(most, absf(rad_to_deg(pipe.locate(player.global_position).y)))
		elif was_on:
			was_on = false
			body_clear_on_leaving = player.body_fits(player.global_position)
	if tick_count >= 150:
		release_all()
	player.debug_full_flow = false
	return most


func test_run_off_the_end_of_the_wall() -> void:
	await place(pipe.surface_point(36.0, 0.0) + Vector3.UP * 0.05, FACE_NORTH)
	player.global_position = pipe.surface_point(36.0, deg_to_rad(70.0))
	player.velocity = pipe.along_direction() * 12.0 + pipe.around(deg_to_rad(70.0)) * 9.0
	player.change_state(&"PipeRun", {"pipe": pipe})
	await ticks(30)
	expect(player.state.name != &"PipeRun", "past the end of the tube you're off its wall (%s)" % player.state.name)
	expect(player.global_position.z < pipe.global_position.z - pipe.length, "flying out of the end: z = %.1f" % player.global_position.z)


## What you'd really do: free-run in along the tube at full flow, then turn
## the camera across it.
func test_run_in_along_it_then_turn_across_and_you_go_round() -> void:
	await place(pipe.surface_point(2.0, 0.0) + Vector3.UP * 0.05, FACE_NORTH)
	player.debug_full_flow = true
	Input.action_press(&"free_run")
	await ticks(60)
	player.camera_rig.yaw = -PI / 2.0 + 0.4 # Turned across, still a little along it.
	var most := 0.0
	for i in 60 * 3:
		await ticks(1)
		if player.state.name == &"PipeRun":
			most = maxf(most, absf(rad_to_deg(pipe.locate(player.global_position).y)))
	release_all()
	player.debug_full_flow = false
	expect(most > 175.0, "turned across at full flow: over the top, %.0f°" % most)
