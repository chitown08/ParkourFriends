@tool
class_name AirVent
extends Node3D
## An orange air vent grate in the pavement beside a building: step on it and
## it blows you straight up to just above the roof next to it. Push toward
## the wall near the top to grab the roof edge and pull yourself up.
##
## Its origin is on the ground in the middle of the grate. `rise` is how high
## it blows you (metres above the grate).

const MATERIAL := preload("res://materials/grid_ramp.tres")
## The grate is this wide (square) and this thick: flush with the pavement
## (no edge to trip on; you walk on the street under it).
const SIZE := 2.4
const THICKNESS := 0.04
## You keep this much of your running speed as it lifts you (it blows you
## mostly straight up, so you rise beside the wall rather than past it).
const KEEP_SPEED := 0.3
## Your feet must be within this of the pavement.
const REACH := 0.4

@export var rise := 15.0

var _grate: CSGBox3D


func _ready() -> void:
	add_to_group(&"air_vents")
	_grate = CSGBox3D.new()
	_grate.size = Vector3(SIZE, THICKNESS, SIZE)
	_grate.position = Vector3(0.0, THICKNESS / 2.0, 0.0)
	_grate.material = MATERIAL
	add_child(_grate)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	for player: Player in get_tree().get_nodes_in_group(&"players"):
		if not player.is_local or player.velocity.y > 1.0:
			continue
		var local := to_local(player.global_position)
		if absf(local.x) <= SIZE / 2.0 and absf(local.z) <= SIZE / 2.0 and absf(local.y) < REACH:
			var running := Vector3(player.velocity.x, 0.0, player.velocity.z) * KEEP_SPEED
			player.ramp_launch(running.normalized(), running.length(), rise, 0.0)
