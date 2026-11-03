extends Node3D
## The root of the game: shows the menus, starts solo/host/join, and creates a
## character for every player.
##
## Only the host creates and removes characters. The PlayerSpawner node then
## copies them to everyone who's connected (including people who join later).
## Each character is named after its player's network id, e.g. "1" for the host.
##
## The world (the rooftop district, the Free-Run Line, ...) is loaded into the World node
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
	"rooftop_district": "res://levels/rooftop_district.tscn",
	"free_run_line": "res://levels/free_run_line.tscn",
	"test_course": "res://levels/test_course.tscn",
}
const DEFAULT_WORLD := "rooftop_district"
## What the start menu calls each world: the playground, then the training grounds.
const WORLD_NAMES := {
	"rooftop_district": "Rooftop District",
	"free_run_line": "Training: Free-Run Line",
	"test_course": "Training: Test Course",
}
## Movement feels you can pick in the pause menu.
const PROFILES := {
	"superhuman": preload("res://player/profiles/superhuman.tres"),
	"human": preload("res://player/profiles/human.tres"),
}
## The character this computer controls (null while in the main menu).
var local_player: Player
## The solo practice buddy, once called (see call_buddy()).
var buddy: Player
## Calling the buddy while looking at a wall this close (metres) has it brace there.
const BUDDY_BRACE_DISTANCE := 10.0
var is_paused := false
## The world being played (null while in the main menu).
var level: Level
## Relics the team has delivered to a drop-off, by item name. The host's copy is the official
## one; it tells everyone else (see _on_delivered()).
var delivered_relics := {}

@onready var world: Node3D = $World
@onready var players: Node3D = $Players
@onready var hud: CanvasLayer = $HUD
@onready var menu: CanvasLayer = $MainMenu
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var network: Network = $Network
@onready var music: AudioStreamPlayer = $Music
## What plays next (see Playlist): worlds with music start with their own song.
var playlist := Playlist.new()
## The layered song playing (null for an ordinary one).
var layered: LayeredSong
## A layered song alone sounds a little muffled (as if from the next room): it
## opens up when a friend runs with you. Frequencies (Hz) the music is cut off
## above, and how quickly it changes.
const MUFFLED_HZ := 3500.0
const OPEN_HZ := 20000.0
const MUFFLE_EASE := 1.5


func _ready() -> void:
	Settings.load_from_disk()
	Settings.apply_audio()
	music.bus = Settings.MUSIC_BUS
	Settings.apply_display()
	network.start_steam()
	if Settings.player_name == "" and network.steam_ready:
		Settings.player_name = Settings.clean_name(network.steam_name()) # Your Steam name, to start with.
	menu.set_steam(network.steam_ready)
	menu.open() # (Again, now your name is known.)
	hud.network = network
	players.child_entered_tree.connect(_on_player_added)
	world.child_entered_tree.connect(_on_world_added)

	menu.set_worlds(WORLDS.keys(), DEFAULT_WORLD, WORLD_NAMES)
	menu.solo_pressed.connect(func() -> void: start_solo())
	menu.host_pressed.connect(func() -> void:
		if network.steam_ready:
			start_host_steam()
		else:
			start_host())
	network.steam_join_requested.connect(start_steam_join)
	network.steam_join_failed.connect(func() -> void:
		network.leave()
		menu.open("Couldn't join your friend's game. Has it ended?"))
	pause_menu.invite_pressed.connect(network.invite_friends)
	menu.join_pressed.connect(start_join)
	pause_menu.resume_pressed.connect(set_paused.bind(false))
	pause_menu.leave_pressed.connect(leave_game)
	pause_menu.music_changed.connect(update_music_volume)
	music.finished.connect(_play_next_track)
	update_music_volume()
	pause_menu.quit_pressed.connect(get_tree().quit)
	pause_menu.movement_changed.connect(set_movement_profile)
	pause_menu.outfit_changed.connect(func() -> void:
		if local_player:
			local_player.sync_outfit = Cosmetics.tidy(Settings.outfit))

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	_handle_command_line()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		Settings.fullscreen = not Settings.fullscreen
		Settings.save_to_disk()
		Settings.apply_display()
		return
	if local_player == null:
		return
	if event.is_action_pressed("pause"):
		set_paused(not is_paused)
		get_viewport().set_input_as_handled()
	elif is_paused:
		return
	elif event.is_action_pressed("toggle_music"):
		Settings.music_on = not Settings.music_on
		Settings.save_to_disk()
		update_music_volume()
	elif not Settings.dev_tools:
		return
	elif event.is_action_pressed("call_buddy"):
		call_buddy()
	elif event.is_action_pressed("buddy_toss_me"):
		buddy_toss_me()
	elif event.is_action_pressed("ghost_run"):
		ghost_run()
	elif event.is_action_pressed("cycle_outfit") and local_player:
		local_player.next_outfit()


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


## Hosts a game through a friends-only Steam lobby, then opens Steam's window
## for inviting friends.
func start_host_steam(world_id: String = "") -> void:
	menu.set_busy(true, "Starting a game on Steam...")
	network.host_steam()
	if not await network.steam_hosting:
		menu.open("Couldn't start a game on Steam. Try again?")
		return
	menu.hide()
	load_world(world_id if world_id else menu.selected_world())
	spawn_player(1)
	network.invite_friends()
	hud.show_message("Invite friends: Esc > Invite Friends")


## Joins a friend's Steam lobby (from an invite or "Join Game" in Steam),
## leaving the game you're in first.
func start_steam_join(lobby: int) -> void:
	if local_player:
		_return_to_menu("")
	menu.set_busy(true, "Joining your friend...")
	network.join_steam(lobby)


## Loads a world (replacing any current one). Solo or host only; joining
## players receive the host's world automatically.
func load_world(world_id: String) -> void:
	if not WORLDS.has(world_id):
		push_warning("Unknown world '%s', loading %s instead" % [world_id, DEFAULT_WORLD])
		world_id = DEFAULT_WORLD
	_clear_world()
	delivered_relics.clear()
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
		pause_menu.open(network.lobby_id != 0)
	else:
		pause_menu.hide()
	if local_player:
		local_player.set_controls_enabled(not paused)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED


## Solo only: brings the practice buddy (creating it the first time) to stand
## 1.5 m in front of you (within toss reach), facing you. It respawns here if it falls.
## If you're hanging from a ledge, it hangs there too instead; if you're
## looking at a wall (within BUDDY_BRACE_DISTANCE), it braces at its foot.
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
	buddy.respawn()
	buddy.face_direction(-forward, 1.0)
	if local_player.state.name == &"Hang":
		# Hanging: the buddy hangs from the same ledge, for you to drop down and
		# climb (practising a hanging chain).
		var ledge: Ledge = local_player.state.ledge()
		buddy.global_position = buddy.hang_position(ledge)
		buddy.reset_physics_interpolation()
		buddy.change_state(&"Hang", {"ledge": ledge})
		return
	# At an edge, looking out over it: the buddy stands at it beside you,
	# looking out too, to catch you when you fall short of it.
	if local_player.state.name in Player.CATCH_FROM:
		var ahead := spot + Vector3.UP * 0.5
		var beside := local_player.global_position + forward.cross(Vector3.UP) * 1.5 + Vector3.UP * 0.05
		if local_player.raycast(ahead, ahead + Vector3.DOWN * 3.0).is_empty() and buddy.body_fits(beside) \
				and not local_player.raycast(beside + Vector3.UP * 0.5, beside + Vector3.DOWN * 0.5).is_empty():
			buddy.set_checkpoint(beside)
			buddy.respawn()
			buddy.face_direction(forward, 1.0)
			hud.show_message("Buddy's at the edge: fall short of it and it'll catch you")
			return
	# Looking at a wall: the buddy braces at its foot, for you to run at and
	# jump into (a leg-up).
	var eyes := local_player.global_position + Vector3.UP * Player.BRACE_HANDS
	var wall := local_player.raycast(eyes, eyes + forward * BUDDY_BRACE_DISTANCE)
	if not wall.is_empty() and absf(wall.normal.y) < 0.3:
		var at: Vector3 = wall.position + Vector3(wall.normal.x, 0.0, wall.normal.z).normalized() * (buddy.body_radius + 0.1)
		at.y = local_player.global_position.y + 0.05
		if buddy.body_fits(at):
			buddy.set_checkpoint(at)
			buddy.respawn()
			if buddy.brace_at_wall():
				hud.show_message("Buddy's braced: run at it and jump for a leg-up")


## Solo only: turns the ghost runner on or off: the practice buddy (called
## beside you if it isn't about) free-runs with you whenever you free-run, so
## you can try pack-running alone.
func ghost_run() -> void:
	if network.is_online() or local_player == null:
		return
	if is_instance_valid(buddy) and buddy.ghost_of != null:
		buddy.ghost_of = null
		hud.show_message("Ghost runner off")
		return
	if not is_instance_valid(buddy) or buddy.global_position.distance_to(local_player.global_position) > Player.GHOST_CATCH_UP:
		call_buddy()
	buddy.ghost_of = local_player
	hud.show_message("Ghost runner on: free-run and it runs with you")


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
	local_player.apply_toss(buddy.toss_velocity(local_player.camera_rig.yaw), str(buddy.name))


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
	delivered_relics.clear()
	hud.set_relic_count(0, 0)
	menu.open(message)


func _clear_world() -> void:
	music.stop()
	for child in world.get_children():
		child.queue_free()
	level = null


# --- Network events ----------------------------------------------------------

func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		spawn_player(peer_id)
		_receive_relic_list.rpc_id(peer_id, delivered_relics.keys())


func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server():
		# Items they were holding go back where they came from.
		for item: WorldItem in get_tree().get_nodes_in_group(&"items"):
			if level and level.is_ancestor_of(item) and item.holder_name == str(peer_id):
				item.host_return_home()
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
	_play_music(level.music, level.music_folder)
	for player: Player in players.get_children():
		player.kill_height = level.kill_height
	for checkpoint: Checkpoint in get_tree().get_nodes_in_group(&"checkpoints"):
		if level.is_ancestor_of(checkpoint):
			checkpoint.reached.connect(_on_checkpoint_reached)
	for drop_off: DropOff in get_tree().get_nodes_in_group(&"drop_offs"):
		if level.is_ancestor_of(drop_off):
			drop_off.delivered.connect(_on_delivered)
	_show_relics()


# --- Relics (shared by the team) --------------------------------------------------
# Relics are items (items/data/relic.tres): you carry them, or throw them, to a
# drop-off (levels/drop_off.tscn), and only then do they count for the team.

func _relics() -> Array[WorldItem]:
	var found: Array[WorldItem] = []
	if level:
		for item: WorldItem in get_tree().get_nodes_in_group(&"items"):
			if item.is_deliverable() and level.is_ancestor_of(item):
				found.append(item)
	return found


## Host only: a drop-off received a relic. Tell everyone.
func _on_delivered(item: WorldItem) -> void:
	var relic_name := String(item.name)
	if delivered_relics.has(relic_name):
		return
	_relic_delivered(relic_name)
	_relic_delivered.rpc(relic_name)


## The host announcing a delivered relic.
@rpc("authority", "call_remote", "reliable")
func _relic_delivered(relic_name: String) -> void:
	delivered_relics[relic_name] = true
	_show_relics()
	if local_player == null:
		return
	Sfx.play_ui(self, &"delivered", -4.0)
	hud.show_message("Relic delivered! (%d/%d)" % [delivered_relics.size(), _relics().size()])


## The host catching up a newly joined player on what's already been delivered.
@rpc("authority", "call_remote", "reliable")
func _receive_relic_list(relic_names: Array) -> void:
	for relic_name: String in relic_names:
		delivered_relics[relic_name] = true
	_show_relics()


## Updates the counter.
func _show_relics() -> void:
	hud.set_relic_count(delivered_relics.size(), _relics().size())


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
		elif arg == "--check-build":
			check_build.call_deferred()
	var invited := Network.lobby_from_command_line()
	if invited and network.steam_ready:
		start_steam_join(invited) # Started from a friend's invite.


## For build_windows.cmd: checks the built game has everything it needs (the
## things that work from the editor but can go missing from a build), prints
## a report, and quits (exit code 1 if anything is wrong).
func check_build() -> void:
	var problems := []
	for world_id: String in WORLDS:
		start_solo(world_id)
		for i in 10:
			await get_tree().physics_frame
		var relics := level.find_children("*", "WorldItem", true, false).filter(func(item: WorldItem) -> bool: return item.item.deliverable)
		print("%s: loaded, %d relics, player %s" % [world_id, relics.size(), "in" if local_player else "MISSING"])
		if local_player == null:
			problems.append("no player in " + world_id)
		leave_game()
		await get_tree().process_frame
	for slot in Cosmetics.SLOTS:
		var items := Cosmetics.available(slot)
		print("outfit %s: %d" % [slot, items.size()])
		if items.is_empty():
			problems.append("no %s items" % slot)
	var tracks := Playlist.find_tracks()
	var runs := CharacterModel.variants_of("run")
	print("animations: %s" % ("found" if not runs.is_empty() else "MISSING"))
	if runs.is_empty():
		problems.append("no animations")
	print("music: %d track(s)" % tracks.size())
	if tracks.is_empty():
		problems.append("no music")
	for track in tracks:
		if track.ends_with("/"):
			var layers := LayeredSong.new(track).layers.size() if LayeredSong.is_layered(track) else 0
			print("  layered song %s: %d layers" % [track, layers])
			if layers == 0:
				problems.append("no layers in " + track)
	print("developer tools: %s" % ("ON (should be off in a release build)" if Settings.dev_tools else "off"))
	if Settings.dev_tools and not OS.is_debug_build():
		problems.append("developer tools on")
	print("Steam: %s" % ("found" if Engine.has_singleton("Steam") else "MISSING"))
	if not Engine.has_singleton("Steam"):
		problems.append("no Steam")
	print("BUILD CHECK " + ("OK" if problems.is_empty() else "FAILED: " + ", ".join(problems)))
	get_tree().quit(0 if problems.is_empty() else 1)


# --- Music -------------------------------------------------------------------

## Sets the music's loudness from Settings (the pause menu slider and M to mute).
func update_music_volume() -> void:
	music.volume_db = linear_to_db(Settings.music_volume) if Settings.music_on else -80.0


## Starts the music with `song` or the layered song in `folder` (a world's
## own), then the rest of the playlist shuffled; or goes quiet if it has none.
func _play_music(song: AudioStream, folder := "") -> void:
	music.stop()
	music.stream = null
	layered = null
	if folder:
		if not folder.ends_with("/"):
			folder += "/"
		playlist.start_with(folder)
		_play_layered(folder)
	elif song:
		playlist.start_with(song.resource_path)
		_play_track(song)


## The track that was playing finished: on to the next.
func _play_next_track() -> void:
	if music.stream == null:
		return
	var path := playlist.next()
	if LayeredSong.is_layered(path):
		_play_layered(path)
	elif path:
		_play_track(load(path))


func _play_track(song: AudioStream) -> void:
	layered = null
	if "loop" in song:
		song.loop = false # (The playlist moves on when it ends.)
	music.stream = song
	music.play()


## Plays the layered song in `folder` (see LayeredSong): it swells with your pack.
func _play_layered(folder: String) -> void:
	layered = LayeredSong.new(folder)
	music.stream = layered.stream
	music.play()


## The layered song swells with your pack, and alone it's a little muffled.
func _process(delta: float) -> void:
	var pack := local_player.pack_size() if local_player else 0
	if layered:
		layered.set_pack(pack, delta)
	var cutoff := MUFFLED_HZ if layered and pack == 0 else OPEN_HZ
	Settings.set_music_cutoff(lerpf(Settings.music_cutoff(), cutoff, 1.0 - exp(-MUFFLE_EASE * delta)))
