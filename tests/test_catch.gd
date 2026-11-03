extends GameTest
## Catch (player/states/catch.gd, caught.gd): a friend standing at an edge
## catches you falling short of it, and you hang from their hands right at the
## edge to climb up. The practice buddy plays the friend. On a 10 m building
## over a floor high above the test course, its face looking south (+Z).

const FLOOR_Y := 200.0
const TOP := FLOOR_Y + 10.0
const WALL_FACE_Z := -20.0
const FACE_SOUTH := PI

var buddy: Player


func before_each() -> void:
	await super()
	player.set_profile(SUPERHUMAN)
	_box("CatchFloor", Vector3(0, FLOOR_Y - 0.5, 0), Vector3(200, 1, 200))
	_box("CatchFar", Vector3(0, FLOOR_Y + 5.0, WALL_FACE_Z - 10.0), Vector3(30, 10, 20))
	main.call_buddy()
	buddy = main.buddy
	buddy.set_profile(SUPERHUMAN)
	await ticks(3) # CSG builds its collision a moment later.


func test_a_friend_at_the_edge_catches_you_falling_short() -> void:
	await _stand_at_edge(buddy)
	await _fall_short(1.2, 1.0, -2.0)
	expect(player.state.name == &"Caught" and player.sync_hanging_on == "Buddy", "the buddy should catch you, %s on '%s'" % [player.state.name, player.sync_hanging_on])
	await ticks(30)
	expect_state_of(buddy, &"Catch")
	expect_near(player.global_position.y, TOP - player.hang_height, 0.1, "hanging from their hands at the edge")
	expect_near(player.global_position.z, WALL_FACE_Z + player.body_radius + 0.05, 0.1, "pulled in to the wall")
	await tap(&"jump")
	expect(await wait_until_on_top(TOP - 0.1, 90), "jump: you climb up onto the roof")
	await ticks(30)
	expect_state_of(buddy, &"Ground")


func test_crouch_to_let_go() -> void:
	await _stand_at_edge(buddy)
	await _fall_short(1.2, 1.0, -2.0)
	await ticks(20)
	await tap(&"crouch")
	await ticks(60)
	expect(player.state.name != &"Caught" and player.global_position.y < FLOOR_Y + 1.0, "you let go and drop to the street (not caught again), %s" % player.state.name)
	expect_state_of(buddy, &"Ground")


func test_a_jump_that_makes_it_isnt_a_catch() -> void:
	await _stand_at_edge(buddy, 0.6)
	buddy.global_position.x = 1.5 # (Not in your way.)
	await _fall_short(1.2, -player.hang_height - 0.5, -8.0) # Feet above the edge, moving fast.
	var caught := player.state.name == &"Caught"
	for i in 60:
		await ticks(1)
		caught = caught or player.state.name == &"Caught"
	expect(not caught, "high enough to make it yourself: nobody catches you")
	expect(player.global_position.y > TOP - 0.1, "you're up on the roof")


func test_a_catch_reaches_just_this_far_out_and_down() -> void:
	await _stand_at_edge(buddy)
	await _fall_short(Player.CATCH_OUT + player.body_radius - 0.1, Player.CATCH_DOWN - 0.1, 0.0)
	expect(player.state.name == &"Caught", "just in reach: caught, %s" % player.state.name)


func test_too_far_out_to_catch() -> void:
	await _stand_at_edge(buddy)
	await _fall_short(Player.CATCH_OUT + player.body_radius + 0.2, 0.5, 0.0)
	expect(player.state.name != &"Caught", "too far out: you fall")


func test_too_far_down_to_catch() -> void:
	await _stand_at_edge(buddy)
	await _fall_short(1.0, Player.CATCH_DOWN + 0.1, 0.0)
	expect(player.state.name != &"Caught", "too far below the edge: you fall")


func test_a_friend_back_from_the_edge_cant_catch() -> void:
	await _stand_at_edge(buddy, Player.CATCH_EDGE + 0.3)
	await _fall_short(1.0, 1.0, -2.0)
	expect(player.state.name != &"Caught", "they're too far back from the edge")


func test_a_friend_facing_away_cant_catch() -> void:
	await _stand_at_edge(buddy, 0.6, FACE_NORTH)
	await _fall_short(1.0, 1.0, -2.0)
	expect(player.state.name != &"Caught", "they're not looking")


func test_stepping_off_beside_a_friend_isnt_a_catch() -> void:
	await _stand_at_edge(buddy)
	await place(Vector3(1.5, TOP + 0.05, WALL_FACE_Z - 2.0), FACE_SOUTH)
	Input.action_press(&"move_forward")
	var caught := false
	for i in 90:
		await ticks(1)
		caught = caught or player.state.name == &"Caught"
	release_all()
	expect(not caught, "you dropped off on purpose: nobody catches you")
	expect(player.global_position.y < FLOOR_Y + 1.0, "down to the street")


func test_backing_off_the_edge_slowly_isnt_a_catch() -> void:
	await _stand_at_edge(buddy)
	buddy.global_position.x = 1.0
	await _fall_short(0.6, 0.1, 3.0) # Just off the edge, heading away.
	expect(player.state.name != &"Caught", "you're dropping off on purpose")


func test_one_catch_at_a_time() -> void:
	await _stand_at_edge(buddy)
	var friend := _second_friend()
	main.players.move_child(buddy, -1) # (So you both fall before the buddy sees either of you.)
	_put_in_air(friend, 1.2, 1.0, -2.0)
	friend.global_position.x = 0.8
	_put_in_air(player, 1.2, 1.0, -2.0)
	player.global_position.x = -0.8
	await ticks(10)
	expect((friend.state.name == &"Caught") != (player.state.name == &"Caught"), "the buddy catches one of you, not both: you %s, friend %s" % [player.state.name, friend.state.name])


func test_let_go_straight_away_and_they_drop() -> void:
	await place(Vector3(0, TOP + 0.05, WALL_FACE_Z - 0.6), FACE_SOUTH)
	player._visual.rotation.y = FACE_SOUTH
	_put_in_air(buddy, 1.2, 1.0, -2.0)
	for i in 10:
		await ticks(1)
		if player.state.name == &"Catch":
			break
	await tap(&"crouch")
	await ticks(60)
	expect(buddy.state.name != &"Caught", "you let go before they knew you had them: they still drop, %s" % buddy.state.name)


func test_you_catch_a_friend_and_hold_on_until_you_let_go() -> void:
	await place(Vector3(0, TOP + 0.05, WALL_FACE_Z - 0.6), FACE_SOUTH)
	player._visual.rotation.y = FACE_SOUTH
	_put_in_air(buddy, 1.2, 1.0, -2.0)
	await ticks(10)
	expect(buddy.state.name == &"Caught" and buddy.sync_hanging_on == str(player.name), "you should catch the buddy, it's %s" % buddy.state.name)
	expect_state(&"Catch")
	var at := player.global_position
	await hold(&"move_forward", 20)
	expect(player.global_position.distance_to(at) < 0.05, "holding on, you stay put")
	expect_state_of(buddy, &"Caught")
	await tap(&"crouch")
	expect(player.state.name != &"Catch", "crouch: you let go")
	await ticks(60)
	expect(buddy.state.name != &"Caught" and buddy.global_position.y < FLOOR_Y + 1.0, "and the buddy drops (not caught again), it's %s" % buddy.state.name)


func test_hang_below_a_caught_friend_and_climb_up_over_them() -> void:
	await _stand_at_edge(buddy)
	var friend := _second_friend()
	_put_in_air(friend, 1.2, 1.0, -2.0)
	await ticks(30)
	expect_state_of(friend, &"Caught")
	# Jump up to their feet.
	player.global_position = friend.global_position + Vector3.DOWN * (player.hang_height + 0.2)
	player.velocity = Vector3(0, -0.1, 0)
	player.change_state(&"Air")
	player.reset_physics_interpolation()
	await ticks(5)
	expect(player.state.name == &"ChainHang" and player.sync_hanging_on == "Friend", "you hang from the caught friend's feet, %s" % player.state.name)
	await tap(&"jump")
	expect(await wait_until_on_top(TOP - 0.1, 120), "jump: up over them onto the roof")
	expect_state_of(friend, &"Caught")
	expect_state_of(buddy, &"Catch")


func test_when_the_caught_one_climbs_up_the_one_below_is_caught_instead() -> void:
	await _stand_at_edge(buddy)
	await _fall_short(1.2, 1.0, -2.0)
	await ticks(20)
	var friend := _second_friend()
	friend.global_position = player.global_position + Vector3.DOWN * player.hang_height
	friend.change_state(&"ChainHang", {"anchor": player, "toward_wall": Vector3.FORWARD})
	await ticks(10)
	await tap(&"jump")
	await ticks(30)
	expect(friend.state.name == &"Caught" and friend.sync_hanging_on == "Buddy", "the friend below moves up into your place, held by the buddy: %s on '%s'" % [friend.state.name, friend.sync_hanging_on])
	expect_near(friend.global_position.y, TOP - player.hang_height, 0.1, "at the edge")
	expect_state_of(buddy, &"Catch")


func test_free_running_you_climb_straight_up() -> void:
	await _stand_at_edge(buddy)
	Input.action_press(&"free_run")
	await _fall_short(1.2, 1.0, -2.0)
	expect(await wait_until_on_top(TOP - 0.1, 90), "free-running, you're up and over without pressing jump")
	release_all()


func test_a_catch_saves_a_jump_as_the_checker_says() -> void:
	# A gap a full-flow running jump falls short of, but a friend at the far edge
	# catches you: as wide as the checker says a catch takes. (Its room to spare,
	# ReachMap.JUMP_MARGIN, is about what the real jump gets on top.)
	var map := ReachMap.build(main.level, SUPERHUMAN)
	var caught := map.air_distance(SUPERHUMAN.jump_height, SUPERHUMAN.flow_speed, -SUPERHUMAN.hang_height - Player.CATCH_DOWN) + Player.CATCH_OUT
	var gap := caught - ReachMap.JUMP_MARGIN - 0.05
	_box("CatchNear", Vector3(0, FLOOR_Y + 5.0, WALL_FACE_Z + gap + 10.0), Vector3(30, 10, 20))
	await ticks(3)
	map = ReachMap.build(main.level, SUPERHUMAN)
	var near := map.place_named("CatchNear")
	var far := map.place_named("CatchFar")
	var how := []
	for link in map.links:
		if link.from == near and link.to == far:
			how.append(link.how)
	expect(not "flow jump" in how and how.any(func(h: String) -> bool: return h.ends_with(", caught")), "the checker: a %.2f m gap is too far for a flow jump, not with a catch, links %s" % [gap, how])
	buddy.global_position = Vector3(20, FLOOR_Y + 0.05, 0) # Out of the way.
	expect(not await _running_jump(gap), "alone, a running jump falls short")
	await _stand_at_edge(buddy)
	expect(await _running_jump(gap), "with the buddy at the edge, you're caught")


func test_call_the_buddy_at_an_edge_to_practise() -> void:
	await place(Vector3(0, TOP + 0.05, WALL_FACE_Z - 0.6), FACE_SOUTH)
	await press_event(&"call_buddy")
	await ticks(20)
	expect(buddy.global_position.y > TOP - 0.1 and buddy.state.name == &"Ground", "the buddy should stand on the roof by you, %s at %s" % [buddy.state.name, buddy.global_position])
	expect(buddy.facing_direction().dot(Vector3.BACK) > 0.9, "looking out over the edge, %s" % buddy.facing_direction())
	_put_in_air(player, 1.2, 1.0, -2.0) # Now fall short of it.
	player.global_position.x = buddy.global_position.x
	await ticks(10)
	expect(player.state.name == &"Caught", "and it catches you, %s" % player.state.name)


## Stands `who` on the roof `back` metres from the edge, facing `yaw` (out over it).
func _stand_at_edge(who: Player, back := 0.6, yaw := FACE_SOUTH) -> void:
	who.global_position = Vector3(0, TOP + 0.05, WALL_FACE_Z - back)
	who.velocity = Vector3.ZERO
	who.change_state(&"Air")
	who.reset_physics_interpolation()
	who._visual.rotation.y = yaw
	await ticks(10)


## Puts you in the air `out` metres from the wall (your middle), your hands
## `down` metres below the edge, falling slowly and moving `toward_z` along z.
func _fall_short(out: float, down: float, toward_z: float) -> void:
	_put_in_air(player, out, down, toward_z)
	for i in 10:
		await ticks(1)
		if player.state.name == &"Caught":
			return


func _put_in_air(who: Player, out: float, down: float, toward_z: float) -> void:
	who.global_position = Vector3(0, TOP - down - who.hang_height, WALL_FACE_Z + out)
	who.velocity = Vector3(0, -0.1, toward_z)
	who.change_state(&"Air")
	who.reset_physics_interpolation()


## A second practice friend, standing out of the way.
func _second_friend() -> Player:
	var friend := main.PLAYER_SCENE.instantiate() as Player
	friend.name = "Friend"
	friend.is_bot = true
	main.players.add_child(friend)
	friend.set_profile(SUPERHUMAN)
	friend.global_position = Vector3(-20, FLOOR_Y + 0.05, 0)
	friend.reset_physics_interpolation()
	return friend


## Runs north off the near roof (a gap `gap` wide before the far one) with a
## running jump at full flow from its edge; true if you end up on the far roof.
func _running_jump(gap: float) -> bool:
	var edge := WALL_FACE_Z + gap
	await place(Vector3(0, TOP + 0.05, edge + 8.0), FACE_NORTH)
	Input.action_press(&"move_forward")
	var jumped := false
	for i in 60 * 4:
		player.flow = 1.0
		await ticks(1)
		if not jumped and player.global_position.z < edge + 0.3:
			Input.action_press(&"jump")
			jumped = true
		if player.state.name == &"Caught":
			release_all()
			await tap(&"jump")
		if player.is_on_floor() and (player.global_position.z < WALL_FACE_Z - 0.2 or player.global_position.y < TOP - 1.0):
			break
	release_all()
	return player.global_position.y > TOP - 0.2 and player.global_position.z < WALL_FACE_Z


func _box(box_name: String, at: Vector3, size: Vector3) -> void:
	var box := CSGBox3D.new()
	box.name = box_name
	box.size = size
	box.use_collision = true
	main.level.add_child(box)
	box.global_position = at
