extends Node3D
## The root of the game. It loads a level and creates the players in it.
##
## Right now it creates one local player. When multiplayer is added, this is
## where players get spawned for each connected peer — spawn_player() already
## takes a peer id for that reason.

const PLAYER_SCENE := preload("res://player/player.tscn")

@onready var level: Level = $TestCourse
@onready var players: Node3D = $Players
@onready var hud: CanvasLayer = $HUD


func _ready() -> void:
	var local_player := spawn_player(1, true)
	hud.player = local_player
	for checkpoint: Checkpoint in get_tree().get_nodes_in_group(&"checkpoints"):
		checkpoint.reached.connect(_on_checkpoint_reached)


## Creates a player. `peer_id` is the network id of whoever controls it
## (1 = the host / single-player).
func spawn_player(peer_id: int, is_local: bool) -> Player:
	var player := PLAYER_SCENE.instantiate() as Player
	player.name = str(peer_id) # Network code finds players by name, so use the id.
	player.is_local = is_local
	player.position = level.get_spawn_position(players.get_child_count())
	players.add_child(player)
	return player


func _on_checkpoint_reached(player: Player) -> void:
	if player.is_local:
		hud.show_message("Checkpoint!")
