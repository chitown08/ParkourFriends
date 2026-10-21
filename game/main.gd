extends Node3D
## The root of the game: shows the menus, starts solo/host/join, and creates a
## character for every player.
##
## Only the host creates and removes characters. The PlayerSpawner node then
## copies them to everyone who's connected (including people who join later).
## Each character is named after its player's network id, e.g. "1" for the host.
##
## The world (Old Town, the test course, ...) is loaded into the World node
## when a game starts. The host's choice is copied to joining players by the
## WorldSpawner node, the same way characters are.
##
## Shortcut for testing: launch with "-- --solo", "-- --host" or
## "-- --join=127.0.0.1" to skip the menu (add "--world=test_course" to pick
## the world).

const PLAYER_SCENE := preload("res://player/player.tscn")
## The worlds you can play in: id -> scene. (New ones also need adding to the
## WorldSpawner's spawnable scenes in main.tscn.)
const WORLDS := {
	"free_run_line": "res://levels/free_run_line.tscn",
	"old_town": "res://levels/old_town.tscn",
	"test_course": "res://levels/test_course.tscn",
}
const DEFAULT_WORLD := "free_run_line"
## Movement feels you can pick in the pause menu.
const PROFILES := {
	"superhuman": preload("res://player/profiles/superhuman.tres"),
	"human": preload("res://player/profiles/human.tres"),
}
## How many relics the team needs for each agility level (Crackdown style):
## level 1 to start, level 2 at 2 relics, ... level 5 at 11.
const AGILITY_RELICS: Array[int] = [0, 2, 5, 8, 11]

## The character this computer controls (null while in the main menu).
var local_player: Player
## The solo practice buddy, once called (see call_buddy()).
var buddy: Player
var is_paused := false
## The world being played (null while in the main menu).
var level: Level
## Relics the team has found, by relic name. The host's copy is the official
## one; it tells everyone else (see collect_relic()).
var collected_relics := {}
## The team's agility level, from relics found. Makes everyone jump higher and run faster.
var agility_level := 1

@onready var world: Node3D = $World
@onready var players: Node3D = $Players
@onready var hud: CanvasLayer = $HUD
@onready var menu: CanvasLayer = $MainMenu
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var network: Network = $Network


func _ready() -> void:
	Settings.load_from_disk()
	hud.network = network
	players.child_entered_tree.connect(_on_player_added)
	world.child_entered_tree.connect(_on_world_added)

	menu.set_worlds(WORLDS.keys(), DEFAULT_WORLD)
	menu.solo_pressed.connect(func() -> void: start_solo())
	menu.host_pressed.connect(func() -> void: start_host())
	menu.join_pressed.connect(start_join)
	pause_menu.resume_pressed.connect(set_paused.bind(false))
	pause_menu.leave_pressed.connect(leave_game)
	pause_menu.quit_pressed.connect(get_tree().quit)
	pause_menu.movement_changed.connect(set_movement_profile)

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


## Starts a solo game in `world_id` (or the world picked in the menu).
func start_solo(world_id: String = "") -> void:
	network.leave()
	menu.hide()
	load_world(world_id if world_id else menu.selected_world())
	spawn_player(1)


## Hosts a game in `world_id` (or the world picked in the menu).
func start_host(port: int = Network.DEFAULT_PORT, world_id: String = "") -> void:
	var error := network.host(port)
	if error != OK:
		menu.open("Couldn't host: %s. Is another copy already hosting?" % error_string(error))
		return
	menu.hide()
	load_world(world_id if world_id else menu.selected_world())
	spawn_player(1)


## Loads a world (replacing any current one). Solo or host only; joining
## players receive the host's world automatically.
func load_world(world_id: String) -> void:
	if not WORLDS.has(world_id):
		push_warning("Unknown world '%s', loading %s instead" % [world_id, DEFAULT_WORLD])
		world_id = DEFAULT_WORLD
	_clear_world()
	collected_relics.clear()
	var new_level := (load(WORLDS[world_id]) as PackedScene).instantiate()
	world.add_child(new_level, true)


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
	buddy.set_profile(local_player.profile) # The buddy moves the way you do.
	buddy.set_agility_level(agility_level)
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
	player.spawn_position = level.get_spawn_position(players.get_child_count())
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
	_clear_world()
	collected_relics.clear()
	hud.set_relic_count(0, 0)
	agility_level = 1
	menu.open(message)


func _clear_world() -> void:
	for child in world.get_children():
		child.queue_free()
	level = null


# --- Network events ----------------------------------------------------------

func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		spawn_player(peer_id)
		_receive_relic_list.rpc_id(peer_id, collected_relics.keys())


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

## Runs on every computer whenever a world appears (loaded here or copied from
## the host).
func _on_world_added(node: Node) -> void:
	node.ready.connect(_on_world_ready.bind(node), CONNECT_ONE_SHOT)


func _on_world_ready(new_level: Level) -> void:
	level = new_level
	for player: Player in players.get_children():
		player.kill_height = level.kill_height
	for checkpoint: Checkpoint in get_tree().get_nodes_in_group(&"checkpoints"):
		if level.is_ancestor_of(checkpoint):
			checkpoint.reached.connect(_on_checkpoint_reached)
	for relic in _relics():
		relic.touched.connect(_on_relic_touched.bind(relic))
	_show_relics()


# --- Relics (shared by the team) --------------------------------------------------

func _relics() -> Array[Relic]:
	var found: Array[Relic] = []
	if level:
		for relic: Relic in get_tree().get_nodes_in_group(&"relics"):
			if level.is_ancestor_of(relic):
				found.append(relic)
	return found


func _on_relic_touched(player: Player, relic: Relic) -> void:
	# Only your own character picks things up on your computer; everyone else's
	# computer handles theirs. (The practice buddy doesn't collect.)
	var relic_name := String(relic.name)
	if player != local_player or collected_relics.has(relic_name):
		return
	if multiplayer.is_server():
		collect_relic(relic_name)
	else:
		_request_relic.rpc_id(1, relic_name)


## Host only: marks a relic as found and tells everyone.
func collect_relic(relic_name: String) -> void:
	if collected_relics.has(relic_name):
		return # Someone else got there first.
	_relic_collected(relic_name)
	_relic_collected.rpc(relic_name)


## A joining player asking the host to collect a relic for the team.
@rpc("any_peer", "call_remote", "reliable")
func _request_relic(relic_name: String) -> void:
	if multiplayer.is_server():
		collect_relic(relic_name)


## The host announcing a found relic.
@rpc("authority", "call_remote", "reliable")
func _relic_collected(relic_name: String) -> void:
	collected_relics[relic_name] = true
	var old_level := agility_level
	_show_relics()
	if local_player == null:
		return
	if agility_level > old_level:
		hud.show_message("Relic found! AGILITY UP: level %d" % agility_level)
	else:
		hud.show_message("Relic found! (%d/%d)" % [collected_relics.size(), _relics().size()])


## The host catching up a newly joined player on what's already been found.
@rpc("authority", "call_remote", "reliable")
func _receive_relic_list(relic_names: Array) -> void:
	for relic_name: String in relic_names:
		collected_relics[relic_name] = true
	_show_relics()


## Hides found relics and updates the counter.
func _show_relics() -> void:
	var relics := _relics()
	for relic in relics:
		relic.set_collected(collected_relics.has(String(relic.name)))
	hud.set_relic_count(collected_relics.size(), relics.size())
	_update_agility()


## Works out the team's agility level from the relics found and applies it
## to your character (and the practice buddy).
func _update_agility() -> void:
	var level := 0
	for needed in AGILITY_RELICS:
		if collected_relics.size() >= needed:
			level += 1
	agility_level = level
	for who: Player in [local_player, buddy]:
		if is_instance_valid(who) and who.agility_level != level:
			who.set_agility_level(level)


## Runs on every computer whenever a character appears (spawned here or copied
## from the host), before the character's own _ready().
func _on_player_added(node: Node) -> void:
	var player := node as Player
	if level:
		player.kill_height = level.kill_height
	player.ready.connect(_on_player_ready.bind(player), CONNECT_ONE_SHOT)


func _on_player_ready(player: Player) -> void:
	if player.is_local and not player.is_bot:
		local_player = player
		hud.player = player
		player.tree_exiting.connect(func() -> void: local_player = null)
		player.set_profile(PROFILES.get(Settings.movement_profile, PROFILES["superhuman"]))
		player.set_agility_level(agility_level)


## Switches your movement feel ("superhuman" or "human") and remembers it.
func set_movement_profile(profile_id: String) -> void:
	if not PROFILES.has(profile_id):
		return
	Settings.movement_profile = profile_id
	Settings.save_to_disk()
	for who: Player in [local_player, buddy]:
		if is_instance_valid(who):
			who.set_profile(PROFILES[profile_id])


func _on_checkpoint_reached(player: Player) -> void:
	if player == local_player:
		hud.show_message("Checkpoint!")


func _handle_command_line() -> void:
	var world_id := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--world="):
			world_id = arg.get_slice("=", 1)
	for arg in OS.get_cmdline_user_args():
		if arg == "--solo":
			start_solo(world_id)
		elif arg == "--host":
			start_host(Network.DEFAULT_PORT, world_id)
		elif arg.begins_with("--join"):
			start_join(arg.get_slice("=", 1))
