class_name Level
extends Node3D
## Base script for a playable level. Every level needs a SpawnPoint marker.
## In multiplayer, extra markers (SpawnPoint2, ...) can spread players out.

@onready var spawn_point: Marker3D = $SpawnPoint


func get_spawn_position(player_index: int = 0) -> Vector3:
	# Side-by-side so co-op players don't spawn inside each other.
	return spawn_point.global_position + spawn_point.global_basis.x * (player_index * 1.5)
