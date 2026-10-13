extends GameTest
## Hosting and joining. Each test runs two copies of the game side by side in
## one program, each with its own network connection, and connects them over
## this computer's local network (like two game windows would).

## Not the normal port, so tests don't clash with a game you have open.
const TEST_PORT := 7788

var host_main: Node
var client_main: Node
var _host_side: Node
var _client_side: Node


func before_each() -> void:
	_host_side = _make_side("HostSide")
	_client_side = _make_side("ClientSide")
	host_main = MAIN_SCENE.instantiate()
	client_main = MAIN_SCENE.instantiate()
	_host_side.add_child(host_main)
	_client_side.add_child(client_main)
	await ticks(2)

	host_main.start_host(TEST_PORT)
	client_main.start_join("127.0.0.1", TEST_PORT)
	for i in 300:
		await ticks(1)
		if _player_count(host_main) == 2 and _player_count(client_main) == 2:
			break
	expect(_player_count(host_main) == 2, "host should see 2 players, sees %d" % _player_count(host_main))
	expect(_player_count(client_main) == 2, "client should see 2 players, sees %d" % _player_count(client_main))
	await ticks(10)


func after_each() -> void:
	release_all()
	for side_main: Node in [client_main, host_main]:
		if is_instance_valid(side_main):
			side_main.leave_game()
	await ticks(5)
	for side: Node in [_host_side, _client_side]:
		get_tree().set_multiplayer(null, side.get_path())
		side.queue_free()
	await ticks(2)


func test_everyone_sees_everyone() -> void:
	var client_id: int = client_main.multiplayer.get_unique_id()
	var client_self: Player = client_main.local_player
	expect(client_self != null and client_self.name == str(client_id), "client should control the character named after its id")

	var host_view_of_client := _find(host_main, client_id)
	var client_view_of_host := _find(client_main, 1)
	expect(host_view_of_client != null and not host_view_of_client.is_local, "host should see the client as a puppet")
	expect(client_view_of_host != null and not client_view_of_host.is_local, "client should see the host as a puppet")
	expect(host_main.local_player.name == "1", "host controls character 1")


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


# --- Helpers -------------------------------------------------------------------

func _make_side(side_name: String) -> Node:
	var side := Node.new()
	side.name = side_name
	add_child(side)
	# Everything under this node gets its own, separate network connection.
	get_tree().set_multiplayer(SceneMultiplayer.new(), side.get_path())
	return side


func _player_count(side_main: Node) -> int:
	var count := 0
	for child in side_main.players.get_children():
		if not child.is_queued_for_deletion():
			count += 1
	return count


func _find(side_main: Node, peer_id: int) -> Player:
	return side_main.players.get_node_or_null(str(peer_id))
