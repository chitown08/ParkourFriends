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
const MAX_PLAYERS := 4


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
		return "Hosting (port %d)" % DEFAULT_PORT
	return "Joined as #%d" % multiplayer.get_unique_id()
