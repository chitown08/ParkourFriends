extends Node3D
## The root of the game: shows the menus, starts solo/host/join, and creates a
## character for every player.
##
## Only the host creates and removes characters. The PlayerSpawner node then
## copies them to everyone who's connected (including people who join later).
## Each character is named after its player's network id, e.g. "1" for the host.
##
## Shortcut for testing: launch with "-- --solo", "-- --host" or
## "-- --join=127.0.0.1" to skip the menu.

const PLAYER_SCENE := preload("res://player/player.tscn")

## The character this computer controls (null while in the main menu).
var local_player: Player
## The solo practice buddy, once called (see call_buddy()).
var buddy: Player
var is_paused := false

@onready var level: Level = $TestCourse
@onready var players: Node3D = $Players
@onready var hud: CanvasLayer = $HUD
@onready var menu: CanvasLayer = $MainMenu
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var network: Network = $Network


func _ready() -> void:
	Settings.load_from_disk()
	hud.network = network
	players.child_entered_tree.connect(_on_player_added)
	for checkpoint: Checkpoint in get_tree().get_nodes_in_group(&"checkpoints"):
		if level.is_ancestor_of(checkpoint):
			checkpoint.reached.connect(_on_checkpoint_reached)

	menu.solo_pressed.connect(start_solo)
	menu.host_pressed.connect(start_host)
	menu.join_pressed.connect(start_join)
	pause_menu.resume_pressed.connect(set_paused.bind(false))
	pause_menu.leave_pressed.connect(leave_game)
	pause_menu.quit_pressed.connect(get_tree().quit)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	_handle_command_line()


func _unhandled_input(event: InputEvent) -> void:
	if local_player == null:
		return
	if event.is_action_pressed("pause"):
		set_paused(not is_paused)
		get_viewport().set_input_as_handled()
	elif is_paused:
		return
	elif event.is_action_pressed("call_buddy"):
		call_buddy()
	elif event.is_action_pressed("buddy_toss_me"):
		buddy_toss_me()


func start_solo() -> void:
	network.leave()
	menu.hide()
	spawn_player(1)


func start_host(port: int = Network.DEFAULT_PORT) -> void:
	var error := network.host(port)
	if error != OK:
		menu.open("Couldn't host: %s. Is another copy already hosting?" % error_string(error))
		return
	menu.hide()
	spawn_player(1)


func start_join(address: String, port: int = Network.DEFAULT_PORT) -> void:
	if address.is_empty():
		address = "127.0.0.1"
	var error := network.join(address, port)
	if error != OK:
		menu.open("Couldn't start joining: %s" % error_string(error))
		return
	menu.set_busy(true, "Connecting to %s..." % address)


## Leaves the current game (solo, hosting or joined) and returns to the menu.
## If the host leaves, everyone else goes back to their menu too.
func leave_game() -> void:
	_return_to_menu("")


## Opens or closes the pause menu. The game keeps running (friends may still
## be playing); this player's controls are just switched off.
func set_paused(paused: bool) -> void:
	is_paused = paused
	if paused:
		pause_menu.open()
	else:
		pause_menu.hide()
	if local_player:
		local_player.set_controls_enabled(not paused)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED


## Solo only: brings the practice buddy (creating it the first time) to stand
## 1.5 m in front of you (within toss reach), facing you. It respawns here if it falls.
func call_buddy() -> void:
	if network.is_online() or local_player == null:
		return
	if not is_instance_valid(buddy):
		buddy = PLAYER_SCENE.instantiate() as Player
		buddy.name = "Buddy"
		buddy.is_bot = true
		players.add_child(buddy)
	var forward := Vector3.FORWARD.rotated(Vector3.UP, local_player.camera_rig.yaw)
	var spot := local_player.global_position + forward * 1.5 + Vector3.UP * 0.05
	buddy.set_checkpoint(spot)
	buddy.respawn()
	buddy.face_direction(-forward, 1.0)


## Solo only: the practice buddy tosses you the way your camera faces, if
## you're within its reach (works mid-jump too, like a mid-air toss).
func buddy_toss_me() -> void:
	if not is_instance_valid(buddy) or local_player == null:
		return
	var offset := local_player.global_position - buddy.global_position
	var flat_distance := Vector2(offset.x, offset.z).length()
	if flat_distance > buddy.toss_range or absf(offset.y) > buddy.toss_range:
		hud.show_message("Get closer to your buddy")
		return
	local_player.apply_toss(buddy.toss_velocity(local_player.camera_rig.yaw))


## Creates a character for the player with this network id. Host only.
func spawn_player(peer_id: int) -> void:
	var player := PLAYER_SCENE.instantiate() as Player
	player.name = str(peer_id) # The name is how every computer knows whose it is.
	player.color_index = _free_color_index()
	players.add_child(player, true)


func _free_color_index() -> int:
	var taken := {}
	for player: Player in players.get_children():
		taken[player.color_index] = true
	for index in Player.COLORS.size():
		if not taken.has(index):
			return index
	return players.get_child_count()


func _return_to_menu(message: String) -> void:
	is_paused = false
	pause_menu.hide()
	network.leave()
	for player in players.get_children():
		player.queue_free()
	menu.open(message)


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
	_return_to_menu("The host left the game.")


# --- Players -----------------------------------------------------------------

## Runs on every computer whenever a character appears (spawned here or copied
## from the host), before the character's own _ready().
func _on_player_added(node: Node) -> void:
	var player := node as Player
	player.position = level.get_spawn_position(player.get_index())
	player.ready.connect(_on_player_ready.bind(player), CONNECT_ONE_SHOT)


func _on_player_ready(player: Player) -> void:
	if player.is_local and not player.is_bot:
		local_player = player
		hud.player = player
		player.tree_exiting.connect(func() -> void: local_player = null)


func _on_checkpoint_reached(player: Player) -> void:
	if player == local_player:
		hud.show_message("Checkpoint!")


func _handle_command_line() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--solo":
			start_solo()
		elif arg == "--host":
			start_host()
		elif arg.begins_with("--join"):
			start_join(arg.get_slice("=", 1))
