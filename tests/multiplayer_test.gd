class_name MultiplayerTest
extends GameTest
## Base for tests that need two players. Each test runs two copies of the game
## side by side in one program, each with its own network connection, and
## connects them over this computer's local network (like two game windows).
## host_main is the hosting copy, client_main the one that joined.

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
