extends MultiplayerTest
## Hosting and joining: seeing each other, colours, movement, leaving.


func test_everyone_sees_everyone() -> void:
	var client_id: int = client_main.multiplayer.get_unique_id()
	var client_self: Player = client_main.local_player
	expect(client_self != null and client_self.name == str(client_id), "client should control the character named after its id")

	var host_view_of_client := _find(host_main, client_id)
	var client_view_of_host := _find(client_main, 1)
	expect(host_view_of_client != null and not host_view_of_client.is_local, "host should see the client as a puppet")
	expect(client_view_of_host != null and not client_view_of_host.is_local, "client should see the host as a puppet")
	expect(host_main.local_player.name == "1", "host controls character 1")


func test_client_gets_the_hosts_world_and_start_position() -> void:
	expect(client_main.level != null, "the client should have received a world")
	if client_main.level:
		expect(client_main.level.name == host_main.level.name, "client world %s should match host world %s" % [client_main.level.name, host_main.level.name])
	var client_id: int = client_main.multiplayer.get_unique_id()
	var host_view := _find(host_main, client_id)
	expect(_find(client_main, client_id).spawn_position == host_view.spawn_position,
			"the client should start where the host placed them")


func test_colours_are_different_and_match_on_both_screens() -> void:
	var client_id: int = client_main.multiplayer.get_unique_id()
	expect(_find(host_main, 1).color_index == 0, "host should be colour 0")
	expect(_find(host_main, client_id).color_index == 1, "client should be colour 1 on host's screen")
	expect(_find(client_main, 1).color_index == 0, "host should be colour 0 on client's screen")
	expect(_find(client_main, client_id).color_index == 1, "client should be colour 1 on client's screen")


func test_movement_shows_up_on_the_other_screen() -> void:
	# Buttons are shared by both copies here, so switch the host's controls off.
	host_main.local_player.set_controls_enabled(false)
	var client_self: Player = client_main.local_player
	var start := client_self.global_position
	await hold(&"move_forward", 60)
	await ticks(30)
	expect(client_self.global_position.distance_to(start) > 3.0, "client should have run forward")
	var puppet := _find(host_main, client_self.name.to_int())
	expect(puppet.global_position.distance_to(client_self.global_position) < 0.1,
			"host should see client at %s, sees %s" % [client_self.global_position, puppet.global_position])
	expect(_find(client_main, 1).global_position.distance_to(host_main.local_player.global_position) < 0.1,
			"client should see the host where the host really is")


func test_crouching_shows_up_on_the_other_screen() -> void:
	host_main.local_player.set_controls_enabled(false)
	var client_id: int = client_main.multiplayer.get_unique_id()
	await hold(&"crouch", 30)
	Input.action_press(&"crouch")
	await ticks(30)
	var puppet: Player = _find(host_main, client_id)
	expect(puppet.model.current_animation() == &"crouch_idle", "host should see the client crouching, playing %s" % puppet.model.current_animation())
	Input.action_release(&"crouch")
	await ticks(40)
	expect(puppet.model.current_animation() == &"idle", "and standing again afterwards, playing %s" % puppet.model.current_animation())


func test_wall_run_lean_shows_up_on_the_other_screen() -> void:
	host_main.local_player.set_controls_enabled(false)
	var client_self: Player = client_main.local_player
	client_self.global_position = Vector3(3.3, 0.05, 18) # Wall Yard, lined up with the wall-run wall.
	client_self.reset_physics_interpolation()
	client_self.camera_rig.yaw = PI
	await ticks(20)
	client_self.debug_full_flow = true # Top speed straight away.
	Input.action_press(&"move_forward")
	var puppet_visual: Node3D = _find(host_main, client_self.name.to_int()).get_node("Visual")
	var biggest_lean := 0.0
	for i in 200:
		await ticks(1)
		if client_self.global_position.z > 29.4:
			Input.action_press(&"jump")
		biggest_lean = maxf(biggest_lean, absf(puppet_visual.rotation.z))
		if client_self.global_position.z > 38.0:
			break
	expect(biggest_lean > 0.25, "host should see the client lean while wall running, max lean %.2f" % biggest_lean)


func test_no_practice_buddy_in_online_games() -> void:
	await press_event(&"call_buddy")
	await ticks(10)
	expect(host_main.buddy == null and client_main.buddy == null, "the buddy is solo-only")
	expect(_player_count(host_main) == 2 and _player_count(client_main) == 2, "still just the two players")


func test_client_leaving_removes_their_character() -> void:
	client_main.leave_game()
	for i in 120:
		await ticks(1)
		if _player_count(host_main) == 1:
			break
	expect(_player_count(host_main) == 1, "host should be left with 1 player")
	expect(client_main.menu.visible, "client should be back at the main menu")


func test_host_leaving_sends_client_to_menu() -> void:
	host_main.leave_game()
	for i in 300:
		await ticks(1)
		if client_main.menu.visible:
			break
	expect(client_main.menu.visible, "client should be back at the main menu")
	expect(_player_count(client_main) == 0, "client's characters should be removed")


func test_outfits_show_up_on_the_other_screen() -> void:
	var client_id: int = client_main.multiplayer.get_unique_id()
	client_main.local_player.next_outfit()
	host_main.local_player.next_outfit()
	host_main.local_player.next_outfit()
	await ticks(30)
	expect(_find(host_main, client_id).sync_outfit == client_main.local_player.sync_outfit, "host should see what the client wears")
	expect(_find(client_main, 1).sync_outfit == host_main.local_player.sync_outfit, "client should see what the host wears")
	var puppet_skeleton: Skeleton3D = _find(host_main, client_id).model.find_children("*", "Skeleton3D", true, false)[0]
	expect(puppet_skeleton.has_node(Cosmetics.PREFIX + "head_0"), "and the client's hat should be on their head on the host's screen")


func test_a_readied_leap_shows_up_on_the_other_screen() -> void:
	host_main.local_player.set_controls_enabled(false)
	var client_id: int = client_main.multiplayer.get_unique_id()
	var puppet_visual: Node3D = _find(host_main, client_id).get_node("Visual")
	Input.action_press(&"free_run")
	await ticks(5)
	Input.action_press(&"jump")
	var lowest := 1.0
	for i in 25:
		await ticks(1)
		lowest = minf(lowest, puppet_visual.scale.y)
	release_all()
	expect(lowest < 0.85, "host should see the client squash down to leap, lowest scale %.2f" % lowest)


func test_friends_free_running_together_are_a_pack() -> void:
	# Buttons are shared by both copies here, so both free-run the same way.
	var host_self: Player = host_main.local_player
	var client_self: Player = client_main.local_player
	for who: Player in [host_self, client_self]:
		who.camera_rig.yaw = PI / 2 # West, along the start area.
	Input.action_press(&"free_run")
	var host_packed := false
	var client_packed := false
	for i in 30:
		await ticks(1)
		host_packed = host_packed or host_self.pack_size() == 1
		client_packed = client_packed or client_self.pack_size() == 1
	Input.action_release(&"free_run")
	var puppet := _find(host_main, client_self.name.to_int())
	expect(puppet.sync_free_run_velocity.length() > 1.0, "the host should know the client is free-running")
	expect(host_packed and client_packed, "each should run as a pack with the other (host %s, client %s, %.1f m apart)" % [host_packed, client_packed, host_self.global_position.distance_to(client_self.global_position)])


func test_climb_a_friend_hanging_from_a_wall() -> void:
	# A 10 m wall well away from the course (both copies share one physics world).
	for at_size: Array in [[Vector3(100, -0.5, -10), Vector3(40, 1, 40)], [Vector3(100, 5, -30), Vector3(30, 10, 20)]]:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		shape.shape.size = at_size[1]
		body.add_child(shape)
		host_main.level.add_child(body)
		body.global_position = at_size[0]
	await ticks(2)
	var host_self: Player = host_main.local_player
	var client_self: Player = client_main.local_player
	host_main.local_player.set_controls_enabled(false) # Buttons are shared: only the client moves.
	for who: Player in [host_self, client_self]:
		who.set_profile(SUPERHUMAN)
	# The host hangs from the top edge.
	var feet := Vector3(100, 10 - host_self.hang_height, -20 + host_self.body_radius + 0.05)
	host_self.global_position = feet
	host_self.reset_physics_interpolation()
	host_self.change_state(&"Hang", {"ledge": host_self.find_ledge(feet, Vector3.FORWARD)})
	# The client runs at the wall, scrambles up to the host's feet and climbs them.
	client_self.global_position = Vector3(100, 0.05, -10)
	client_self.reset_physics_interpolation()
	client_self.camera_rig.yaw = FACE_NORTH
	await ticks(30)
	Input.action_press(&"move_forward")
	for i in 120:
		await ticks(1)
		if client_self.global_position.z < -17.5:
			Input.action_press(&"jump")
		if client_self.state.name == &"ChainHang":
			break
	release_all()
	expect(client_self.state.name == &"ChainHang" and client_self.sync_hanging_on == str(host_self.name), "the client should hang from the host's feet, %s on %s" % [client_self.state.name, client_self.sync_hanging_on])
	await ticks(10)
	var puppet := _find(host_main, client_self.name.to_int())
	expect(puppet.sync_hanging_on == str(host_self.name), "the host should see the client hanging from them")
	await tap(&"jump")
	for i in 90:
		await ticks(1)
		if client_self.is_on_floor():
			break
	expect(client_self.is_on_floor() and client_self.global_position.y > 9.9, "the client should climb the host onto the top, at %s in %s" % [client_self.global_position, client_self.state.name])


func test_leg_up_from_a_friend() -> void:
	# An 11 m wall well away from the course: too tall alone, not with a leg-up.
	for at_size: Array in [[Vector3(140, -0.5, -10), Vector3(40, 1, 40)], [Vector3(140, 5.5, -30), Vector3(30, 11, 20)]]:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		shape.shape.size = at_size[1]
		body.add_child(shape)
		host_main.level.add_child(body)
		body.global_position = at_size[0]
	await ticks(2)
	var host_self: Player = host_main.local_player
	var client_self: Player = client_main.local_player
	host_main.local_player.set_controls_enabled(false) # Buttons are shared: only the client moves.
	for who: Player in [host_self, client_self]:
		who.set_profile(SUPERHUMAN)
	# The host braces at the foot of the wall.
	host_self.global_position = Vector3(140, 0.05, -19.1)
	host_self.reset_physics_interpolation()
	client_self.global_position = Vector3(140, 0.05, -8)
	client_self.reset_physics_interpolation()
	client_self.camera_rig.yaw = FACE_NORTH
	await ticks(20)
	expect(host_self.try_brace(), "the host should brace at the wall")
	await ticks(10)
	var puppet := _find(client_main, host_self.name.to_int())
	expect(puppet.sync_state == &"Brace", "the client should see the host braced, sees %s" % puppet.sync_state)
	# The client runs at them and jumps: a leg-up, a scramble, onto the top.
	Input.action_press(&"move_forward")
	var stepped_in := false
	for i in 300:
		await ticks(1)
		if client_self.global_position.z < -17.8:
			Input.action_press(&"jump")
		stepped_in = stepped_in or client_self.state.name == &"LegUp"
		if client_self.state.name == &"Hang":
			Input.action_release(&"jump")
			await ticks(2)
			Input.action_press(&"jump")
		if client_self.is_on_floor() and client_self.global_position.y > 10.9:
			break
	release_all()
	expect(stepped_in, "the client should step into the host's leg-up")
	expect(client_self.is_on_floor() and client_self.global_position.y > 10.9, "and get up the 11 m wall, at %s in %s" % [client_self.global_position, client_self.state.name])


func test_crack_the_whip_with_a_friend() -> void:
	# A floor well away from the course: both run north, the client holding the host's hand.
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(80, 1, 80)
	body.add_child(shape)
	host_main.level.add_child(body)
	body.global_position = Vector3(220, -0.5, 0)
	await ticks(2)
	var host_self: Player = host_main.local_player
	var client_self: Player = client_main.local_player
	for who: Player in [host_self, client_self]:
		who.set_profile(SUPERHUMAN)
		who.camera_rig.yaw = FACE_NORTH
	host_self.global_position = Vector3(220, 0.05, 30)
	client_self.global_position = Vector3(217, 0.05, 30)
	for who: Player in [host_self, client_self]:
		who.reset_physics_interpolation()
	Input.action_press(&"free_run")
	await ticks(30)
	client_self.join_line(_find(client_main, host_self.name.to_int()))
	await ticks(30)
	var puppet := _find(host_main, client_self.name.to_int())
	expect(puppet.sync_state == &"Linked" and puppet.sync_linked_to == str(host_self.name), "the host should see the client holding their hand, sees %s" % puppet.sync_state)
	host_self.camera_rig.yaw = -PI / 2 # The host turns hard right (east), away from the client.
	var swung := false
	for i in 60:
		await ticks(1)
		swung = swung or client_self.state.name == &"Whipped"
		if swung and client_self.state.name == &"Air":
			break
	release_all()
	expect(swung, "the client should swing round when the host cracks the whip")
	expect(client_self.state.name == &"Air" and client_self.velocity.x > 15.0, "and be flung off east, %s going %s" % [client_self.state.name, client_self.velocity])


func test_catch_a_friend_falling_short() -> void:
	# A floor and a 10 m building well away from the course. The host stands at
	# its edge looking out; the client falls short of it.
	for box: Array in [[Vector3(300, -0.5, 0), Vector3(60, 1, 60)], [Vector3(300, 5, -10), Vector3(20, 10, 20)]]:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		shape.shape.size = box[1]
		body.add_child(shape)
		host_main.level.add_child(body)
		body.global_position = box[0]
	await ticks(2)
	var host_self: Player = host_main.local_player
	var client_self: Player = client_main.local_player
	for who: Player in [host_self, client_self]:
		who.set_profile(SUPERHUMAN)
	host_self.global_position = Vector3(300, 10.05, -0.6)
	host_self._visual.rotation.y = PI # Facing south, out over the edge.
	host_self.reset_physics_interpolation()
	await ticks(30)
	client_self.global_position = Vector3(300, 10.0 - 1.0 - client_self.hang_height, 1.2)
	client_self.velocity = Vector3(0, -0.1, -2.0)
	client_self.change_state(&"Air")
	client_self.reset_physics_interpolation()
	await ticks(30)
	expect(client_self.state.name == &"Caught" and client_self.sync_hanging_on == str(host_self.name), "the client should be caught by the host, %s on '%s'" % [client_self.state.name, client_self.sync_hanging_on])
	expect_state_of(host_self, &"Catch")
	expect(_find(client_main, host_self.name.to_int()).sync_state == &"Catch", "the client sees the host holding them")
	client_self._jump_buffer_timer = 0.2 # The client presses jump (only on their computer).
	for i in 90:
		await ticks(1)
		if client_self.state.name == &"Ground":
			break
	expect(client_self.state.name == &"Ground" and client_self.global_position.y > 9.9, "the client climbs up, %s at %s" % [client_self.state.name, client_self.global_position])
	await ticks(30)
	expect_state_of(host_self, &"Ground")
