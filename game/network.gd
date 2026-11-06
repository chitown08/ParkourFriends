class_name Network
extends Node
## Starts, joins and leaves online games.
##
## Lives as the "Network" node in game/main.tscn.
##
## How multiplayer works in this game: one player "hosts" and the others
## "join" them. Each player's own computer is in charge of their own character
## and tells everyone else where it is. Simple and responsive, which suits a
## co-op game where nobody needs to be stopped from cheating.

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 8 ## (Designed for 1-4; room for a bigger crew.)


## Starts hosting a game on this computer. Returns OK or an error code.
func host(port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_PLAYERS - 1)
	if error == OK:
		multiplayer.multiplayer_peer = peer
	return error


## Starts connecting to a host. Returns OK if the attempt started; whether it
## worked arrives later as multiplayer.connected_to_server / connection_failed.
func join(address: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error == OK:
		multiplayer.multiplayer_peer = peer
	return error


## Disconnects and goes back to offline (solo) mode.
func leave() -> void:
	if lobby_id:
		_steam.leaveLobby(lobby_id)
		lobby_id = 0
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func is_online() -> bool:
	return not multiplayer.multiplayer_peer is OfflineMultiplayerPeer


## A short description like "Solo", "Hosting" or "Joined as #12345".
func describe() -> String:
	if not is_online():
		return "Solo"
	if multiplayer.is_server():
		return "Hosting on Steam" if lobby_id else "Hosting (port %d)" % DEFAULT_PORT
	return "Joined as #%d" % multiplayer.get_unique_id()


# --- Steam -----------------------------------------------------------------------
# With Steam running, hosting makes a friends-only Steam lobby; friends join it
# from an invite or "Join Game" in their friends list, and the game talks
# through Steam (no addresses, no router settings). Without Steam, hosting and
# joining work by address, as above. (GodotSteam: addons/godotsteam/.)

## Our game's Steam app ID. 480 is Valve's test game ("Spacewar"), for trying
## Steam out before our own ID arrives: put ours here then.
const STEAM_APP_ID := 480
## Off while the tests run (they play over the local network, and shouldn't
## show you as playing on Steam).
static var steam_allowed := true
## Steam's numbers for: a lobby only friends can join, "that worked", and
## "you're in the lobby" (Steam.LOBBY_TYPE_FRIENDS_ONLY, RESULT_OK, CHAT_ROOM_ENTER_RESPONSE_SUCCESS).
const LOBBY_FRIENDS_ONLY := 1
const STEAM_OK := 1
const LOBBY_ENTERED := 1

## Hosting on Steam: the lobby is ready and friends can join (or `ok` is false).
signal steam_hosting(ok: bool)
## A friend accepted our invite, or picked "Join Game": join their lobby.
signal steam_join_requested(lobby: int)
## Joining a friend's lobby didn't work.
signal steam_join_failed

## True once Steam is running and talking to us.
var steam_ready := false
## The Steam lobby we're hosting or in (0: none).
var lobby_id := 0
var _steam: Object


## Starts up Steam, if it's running (otherwise everything works by address).
func start_steam() -> void:
	if steam_ready or not steam_allowed or not Engine.has_singleton("Steam"):
		return
	_steam = Engine.get_singleton("Steam")
	var result: Dictionary = _steam.steamInitEx(STEAM_APP_ID, true)
	if result.get("status", -1) != 0:
		print("Steam isn't available (%s): hosting and joining by address only." % result.get("verbal", ""))
		return
	steam_ready = true
	_steam.lobby_created.connect(_on_lobby_created)
	_steam.lobby_joined.connect(_on_lobby_joined)
	_steam.join_requested.connect(func(lobby: int, _friend: int) -> void: steam_join_requested.emit(lobby))


## Your name on Steam ("" without Steam).
func steam_name() -> String:
	return _steam.getPersonaName() if steam_ready else ""


## Starts hosting through a new friends-only Steam lobby; steam_hosting says how it went.
func host_steam() -> void:
	_steam.createLobby(LOBBY_FRIENDS_ONLY, MAX_PLAYERS)


## Joins a friend's Steam lobby; then multiplayer.connected_to_server (or
## steam_join_failed) says how it went.
func join_steam(lobby: int) -> void:
	_steam.joinLobby(lobby)


## Opens Steam's window for inviting friends to our lobby.
func invite_friends() -> void:
	if lobby_id:
		_steam.activateGameOverlayInviteDialog(lobby_id)


## The lobby a friend's invite started the game with ("+connect_lobby <id>"
## on the command line, from Steam), or 0.
static func lobby_from_command_line(args := OS.get_cmdline_args()) -> int:
	var at := args.find("+connect_lobby")
	return args[at + 1].to_int() if at != -1 and at + 1 < args.size() else 0


func _on_lobby_created(result: int, lobby: int) -> void:
	if result != STEAM_OK:
		steam_hosting.emit(false)
		return
	lobby_id = lobby
	var peer: MultiplayerPeer = ClassDB.instantiate(&"SteamMultiplayerPeer")
	if peer.host_with_lobby(lobby) != OK:
		leave()
		steam_hosting.emit(false)
		return
	multiplayer.multiplayer_peer = peer
	steam_hosting.emit(true)


func _on_lobby_joined(lobby: int, _permissions: int, _locked: bool, response: int) -> void:
	if _steam.getLobbyOwner(lobby) == _steam.getSteamID():
		return # Our own lobby, just made (see _on_lobby_created).
	if response != LOBBY_ENTERED:
		steam_join_failed.emit()
		return
	lobby_id = lobby
	var peer: MultiplayerPeer = ClassDB.instantiate(&"SteamMultiplayerPeer")
	if peer.connect_to_lobby(lobby) != OK:
		leave()
		steam_join_failed.emit()
		return
	multiplayer.multiplayer_peer = peer
