class_name Checkpoint
extends Area3D
## Touch this and you'll respawn here when you fall.
## Drop checkpoint.tscn into any level to use it.

signal reached(player: Player)


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if player == null or not player.is_local or player.is_bot or player.respawn_position.is_equal_approx(global_position):
		return
	player.set_checkpoint(global_position)
	reached.emit(player)
