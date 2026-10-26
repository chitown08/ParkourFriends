class_name Level
extends Node3D
## Base script for a playable world (the Free-Run Line, the test course, ...).
## Every world needs a SpawnPoint marker.

## Falling below this height respawns you at your last checkpoint.
@export var kill_height := -15.0

@onready var spawn_point: Marker3D = $SpawnPoint


func get_spawn_position(player_index: int = 0) -> Vector3:
	# Side-by-side so co-op players don't spawn inside each other.
	return spawn_point.global_position + spawn_point.global_basis.x * (player_index * 1.5)
