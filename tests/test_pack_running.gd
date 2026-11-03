extends GameTest
## Pack-running: friends free-running near each other pull each other gently
## along (FreeRun._run_with_pack()), and the ghost runner (H) to try it alone.
## Runs on a big flat floor added high above the test course.

const FLOOR_Y := 200.0

var buddy: Player


func before_each() -> void:
	await super()
	player.set_profile(SUPERHUMAN)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(400, 1, 400)
	floor_body.add_child(shape)
	main.level.add_child(floor_body)
	floor_body.global_position = Vector3(0, FLOOR_Y - 0.5, 0)


func after_each() -> void:
	Settings.free_run_enabled = true
	await super()


func test_you_ease_up_to_run_alongside_a_friend_ahead() -> void:
	# The buddy runs north 4 m to your left and 5 m ahead, at the same pace.
	var gap := await _run_beside(Vector3(-4, 0, -5), 0.0, 180)
	expect(gap < 1.5, "you should close up with your friend, still %.1f m behind" % gap)
	expect(player.pack_size() == 1, "you should be a pack of two, pack of %d" % (player.pack_size() + 1))


func test_a_quick_friend_and_a_slow_one_meet_in_the_middle() -> void:
	# The buddy at full flow (15 m/s), you starting out (10 m/s): alone it
	# would be 15 m ahead in 3 seconds, out of the pack.
	buddy = _ghost_buddy(Vector3(-4, 0, 0))
	buddy.debug_full_flow = true
	var gap := await _run_beside(Vector3(-4, 0, 0), 0.0, 180, false)
	expect(gap < 6.0, "your friend should ease off and you speed up, but it's %.1f m ahead" % gap)
	expect(player.pack_size() == 1, "you should still be running together")


func test_your_heading_bends_toward_the_pack() -> void:
	# You steer 30 degrees right of the buddy's heading (north).
	await _run_beside(Vector3(-3, 0, 0), deg_to_rad(-30.0), 60)
	var going := Vector3(player.velocity.x, 0.0, player.velocity.z).normalized()
	var angle := rad_to_deg(going.angle_to(Vector3.FORWARD))
	expect(angle < 25.0, "you should bend toward your friend's heading, %.0f degrees off it" % angle)
	expect(angle > 5.0, "...gently: you still go your own way, %.0f degrees off it" % angle)


func test_steering_away_breaks_the_pack() -> void:
	await _run_beside(Vector3(-3, 0, 0), deg_to_rad(-60.0), 60)
	var going := Vector3(player.velocity.x, 0.0, player.velocity.z).normalized()
	var own := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(-60.0))
	expect(player.pack_size() == 0, "steering 60 degrees away shouldn't count as a pack")
	expect(going.dot(own) > 0.999, "you should go exactly where you steer, %s not %s" % [going, own])
	expect(player.pack_pace == 1.0, "at your own pace, %.2f" % player.pack_pace)


func test_friends_too_far_off_are_not_your_pack() -> void:
	await _run_beside(Vector3(-12, 0, 0), 0.0, 60)
	expect(player.pack_size() == 0, "a friend 12 m away isn't in your pack")


func test_letting_go_of_free_run_is_never_carried() -> void:
	await _run_beside(Vector3(-3, 0, 0), 0.0, 60)
	await ticks(60) # Let go: the buddy keeps running.
	expect(player.pack_size() == 0 and player.pack_pace == 1.0, "letting go leaves the pack")
	expect(player.get_horizontal_speed() < 0.1, "and you stop, %.1f m/s" % player.get_horizontal_speed())


func test_drafting_builds_flow_faster() -> void:
	await place(Vector3(0, FLOOR_Y + 0.05, 0), FACE_NORTH)
	await hold(&"free_run", 60)
	var alone := player.flow
	await ticks(60) # Let go: flow drains away.
	await _run_beside(Vector3(-3, 0, 0), 0.0, 60)
	expect(player.flow > alone * 1.3, "in a pack of two, flow should build faster: %.2f, alone %.2f" % [player.flow, alone])


func test_a_bigger_pack_runs_a_little_faster() -> void:
	player.debug_full_flow = true
	buddy = _ghost_buddy(Vector3(-3, 0, 0))
	buddy.debug_full_flow = true
	await _run_beside(Vector3(-3, 0, 0), 0.0, 120, false)
	expect(player.pack_size() == 1, "test setup: a pack of two")
	var two := player.top_speed(false)
	expect_near(two, SUPERHUMAN.flow_speed * 1.03, 0.01, "a pack of two: top speed")
	expect(player.pack_pace < 1.05 and buddy.pack_pace < 1.05, "side by side, neither eases faster (%.2f, %.2f): friends don't keep speeding each other up" % [player.pack_pace, buddy.pack_pace])
	# Two more friends join in.
	for i in 2:
		var friend := main.PLAYER_SCENE.instantiate() as Player
		friend.name = "Friend%d" % i
		friend.is_bot = true
		main.players.add_child(friend)
		friend.set_profile(SUPERHUMAN)
		friend.debug_full_flow = true
		friend.ghost_of = player
		friend.ghost_wander_degrees = 0.0
		friend.global_position = player.global_position + Vector3(3.0 + 3.0 * i, 0.0, 0.0)
		friend.reset_physics_interpolation()
	Input.action_press(&"free_run")
	await ticks(120)
	# The whole pack's pace (one runner can briefly go faster or slower to keep alongside).
	var pack: Array[Node] = main.players.get_children()
	var before := pack.map(func(p: Player) -> Vector3: return p.global_position)
	await ticks(60)
	var travelled := 0.0
	for i in pack.size():
		travelled += (pack[i].global_position - before[i]).length() / pack.size()
	release_all()
	player.debug_full_flow = false
	expect(player.pack_size() == 3, "should be a pack of four, pack of %d" % (player.pack_size() + 1))
	expect_near(player.top_speed(false), SUPERHUMAN.flow_speed * 1.09, 0.01, "a pack of four: top speed")
	expect(travelled > SUPERHUMAN.flow_speed * 1.05, "and the pack really runs faster, %.2f m/s" % travelled)


func test_the_ghost_runner_runs_with_you() -> void:
	await place(Vector3(0, FLOOR_Y + 0.05, 0), FACE_NORTH)
	await press_event(&"ghost_run")
	buddy = main.buddy
	expect(buddy != null and buddy.ghost_of == player, "H should bring the buddy as a ghost runner")
	if buddy == null:
		return
	await ticks(20)
	var start := buddy.global_position
	Input.action_press(&"free_run")
	var packed := 0
	for i in 240:
		await ticks(1)
		if player.pack_size() > 0:
			packed += 1
	release_all()
	expect(buddy.global_position.distance_to(start) > 30.0, "the ghost should free-run with you, moved %.1f m" % buddy.global_position.distance_to(start))
	expect(packed > 180, "and you should run as a pack most of the way, %d of 240 ticks" % packed)
	await ticks(30)
	var stopped := buddy.global_position
	await ticks(30)
	expect(buddy.global_position.distance_to(stopped) < 0.1, "it stops when you stop")

	await press_event(&"ghost_run")
	expect(buddy.ghost_of == null, "H again turns it off")
	stopped = buddy.global_position
	await hold(&"free_run", 60)
	expect(buddy.global_position.distance_to(stopped) < 0.1, "then it stays put while you run")


func test_the_ghost_runner_catches_up() -> void:
	await place(Vector3(0, FLOOR_Y + 0.05, 0), FACE_NORTH)
	await press_event(&"ghost_run")
	await place(Vector3(60, FLOOR_Y + 0.05, 0), FACE_NORTH)
	Input.action_press(&"free_run")
	await ticks(10)
	release_all()
	var apart: float = main.buddy.global_position.distance_to(player.global_position)
	expect(apart < 3.0, "the ghost should appear beside you, %.1f m away" % apart)


## Free-runs from the middle of the floor, steering `yaw` (0 = north), with
## the buddy as a ghost runner heading north from `buddy_offset` beside you.
## Holds free-run for `run_ticks`, then lets go; returns how far behind the
## buddy you are (along north).
func _run_beside(buddy_offset: Vector3, yaw: float, run_ticks: int, make_buddy := true) -> float:
	if make_buddy:
		buddy = _ghost_buddy(buddy_offset)
	await place(Vector3(0, FLOOR_Y + 0.05, 0), yaw)
	buddy.global_position = player.global_position + buddy_offset
	buddy.velocity = Vector3.ZERO
	buddy.reset_physics_interpolation()
	buddy.ghost_turn_degrees = -rad_to_deg(yaw) # Heads north whichever way you steer.
	await hold(&"free_run", run_ticks)
	return (buddy.global_position - player.global_position).dot(Vector3.FORWARD)


## Calls the buddy and makes it a steady ghost runner (no wandering).
func _ghost_buddy(offset: Vector3) -> Player:
	main.call_buddy()
	var ghost: Player = main.buddy
	ghost.ghost_of = player
	ghost.ghost_wander_degrees = 0.0
	ghost.global_position = Vector3(0, FLOOR_Y + 0.05, 0) + offset
	ghost.reset_physics_interpolation()
	return ghost
