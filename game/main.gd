extends Node3D
## The root of the game: shows the menu, starts solo/host/join, and creates a
## character for every player.
##
## Only the host creates and removes characters. The PlayerSpawner node then
## copies them to everyone who's connected (including people who join later).
## Each character is named after its player's network id, e.g. "1" for the host.
##
## Shortcut for testing: launch with "-- --solo", "-- --host" or
## "-- --join=127.0.0.1" to skip the menu.

const PLAYER_SCENE := preload("res://player/player.tscn")

@onready var level: Level = $TestCourse
@onready var players: Node3D = $Players
@onready var hud: CanvasLayer = $HUD
@onready var menu: CanvasLayer = $MainMenu
@onready var network: Network = $Network


func _ready() -> void:
	hud.network = network
	players.child_entered_tree.connect(_on_player_added)
	for checkpoint: Checkpoint in get_tree().get_nodes_in_group(&"checkpoints"):
		checkpoint.reached.connect(_on_checkpoint_reached)

	menu.solo_pressed.connect(start_solo)
	menu.host_pressed.connect(start_host)
	menu.join_pressed.connect(start_join)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	_handle_command_line()


func start_solo() -> void:
	network.leave()
	menu.hide()
	spawn_player(1)


func start_host() -> void:
	var error := network.host()
	if error != OK:
		menu.open("Couldn't host: %s. Is another copy already hosting?" % error_string(error))
		return
	menu.hide()
	spawn_player(1)


func start_join(address: String) -> void:
	if address.is_empty():
		address = "127.0.0.1"
	var error := network.join(address)
	if error != OK:
		menu.open("Couldn't start joining: %s" % error_string(error))
		return
	menu.set_busy(true, "Connecting to %s..." % address)


## Creates a character for the player with this network id. Host only.
func spawn_player(peer_id: int) -> void:
	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id) # The name is how every computer knows whose it is.
	players.add_child(player, true)


# --- Network events ----------------------------------------------------------

func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		spawn_player(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server():
		var player := players.get_node_or_null(str(peer_id))
		if player:
			player.queue_free()


func _on_connected_to_server() -> void:
	menu.hide() # The host will now send us everyone's characters, including ours.


func _on_connection_failed() -> void:
	network.leave()
	menu.open("Couldn't connect. Is the host running, and is the address right?")


func _on_server_disconnected() -> void:
	network.leave()
	for player in players.get_children():
		player.queue_free()
	menu.open("The host left the game.")


# --- Players -----------------------------------------------------------------

## Runs on every computer whenever a character appears (spawned here or copied
## from the host), before the character's own _ready().
func _on_player_added(node: Node) -> void:
	var player := node as Player
	player.position = level.get_spawn_position(player.get_index())
	player.ready.connect(_on_player_ready.bind(player), CONNECT_ONE_SHOT)


func _on_player_ready(player: Player) -> void:
	if player.is_local:
		hud.player = player


func _on_checkpoint_reached(player: Player) -> void:
	if player.is_local:
		hud.show_message("Checkpoint!")


func _handle_command_line() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--solo":
			start_solo()
		elif arg == "--host":
			start_host()
		elif arg.begins_with("--join"):
			start_join(arg.get_slice("=", 1))
