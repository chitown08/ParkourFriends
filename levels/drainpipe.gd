@tool
class_name Drainpipe
extends Node3D
## A yellow drainpipe up the side of a building: a slow but sure way back up to
## the roof. Run or jump into it to grab hold (see Player.find_drainpipe()),
## push toward the wall to climb, and you pull yourself onto the roof at the
## top (player/states/pipe_climb.gd).
##
## Its origin is on the ground at the foot of the pipe, against the wall; +Z
## points out of the wall (toward you as you climb). It's `height` tall: the
## height of the roof edge it leads to.

const MATERIAL := preload("res://materials/grid_climb.tres")
## The pipe's thickness, and how far it stands out from the wall.
const RADIUS := 0.15
const OUT := 0.25
## Brackets holding it to the wall, about this far apart.
const BRACKET_SPACING := 3.5

@export var height := 14.0:
	set(value):
		height = value
		_build()

var _parts: Node3D


func _ready() -> void:
	add_to_group(&"drainpipes")
	_build()


## The middle of the pipe at height `y` (world space).
func point_at(y: float) -> Vector3:
	var foot := global_position + out_of_wall() * OUT
	return Vector3(foot.x, y, foot.z)


## Where you'd hold on, climbing it near `at` (world space): the pipe at that
## height. (Something wider you climb, like scaffolding, holds you where you grabbed.)
func grab_point(at: Vector3) -> Vector3:
	return point_at(at.y)


## Flat direction pointing out of the wall.
func out_of_wall() -> Vector3:
	var out := global_basis.z
	return Vector3(out.x, 0.0, out.z).normalized()


## The height of the roof edge at its top (world space).
func top() -> float:
	return global_position.y + height


func _build() -> void:
	if not is_inside_tree():
		return
	if _parts:
		_parts.free()
	_parts = Node3D.new()
	add_child(_parts)
	var pipe := CSGCylinder3D.new()
	pipe.radius = RADIUS
	pipe.height = height
	pipe.sides = 10
	pipe.position = Vector3(0, height / 2.0, OUT)
	pipe.material = MATERIAL
	pipe.use_collision = true
	_parts.add_child(pipe)
	var count := maxi(int(height / BRACKET_SPACING), 1)
	for i in count:
		var bracket := CSGBox3D.new()
		bracket.size = Vector3(0.4, 0.1, OUT + RADIUS)
		bracket.position = Vector3(0, (i + 0.5) * height / count, (OUT + RADIUS) / 2.0)
		bracket.material = MATERIAL
		_parts.add_child(bracket)
