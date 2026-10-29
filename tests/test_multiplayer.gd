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
	var puppet_visual: Node3D = _find(host_main, client_id).get_node("Visual")
	expect(puppet_visual.scale.y < 0.7, "host should see the client squashed down, scale is %.2f" % puppet_visual.scale.y)
	Input.action_release(&"crouch")
	await ticks(40)
	expect(puppet_visual.scale.y > 0.95, "and standing again afterwards, scale is %.2f" % puppet_visual.scale.y)


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
