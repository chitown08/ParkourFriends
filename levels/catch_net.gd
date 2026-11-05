@tool
class_name CatchNet
extends Node3D
## A rope net sticking out of a building's wall over a gap, some way under the
## roof: miss a jump and it catches you, then bounces you back up, in toward
## the wall, to land on the roof (or grab its edge).
##
## Its origin is at the wall, level with the net; +Z points out of the wall.
## The net is `size` big (along the wall, out from it); it throws you `rise`
## metres above itself (to just over the roof).

const MATERIAL := preload("res://materials/net.tres")
const FRAME_MATERIAL := preload("res://materials/grid_platform.tres")
## How thick the net is (you land on its top), and its frame.
const THICK := 0.15
const FRAME := 0.15
## Your feet must be within this of the net (and not going up).
const REACH := 0.4
## The bounce brings you to the wall this far out from it, at its top.
const AT_WALL := 0.8

@export var size := Vector2(8.0, 4.0):
	set(value):
		size = value
		_build()
@export var rise := 12.0

var _parts: Node3D


func _ready() -> void:
	add_to_group(&"catch_nets")
	_build()


## Flat direction pointing out of the wall.
func out_of_wall() -> Vector3:
	var out := global_basis.z
	return Vector3(out.x, 0.0, out.z).normalized()


## Whether `feet` (world space) are on the net.
func holds(feet: Vector3) -> bool:
	var local := to_local(feet)
	return absf(local.x) <= size.x / 2.0 and local.z >= 0.0 and local.z <= size.y and absf(local.y) < REACH


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	for player: Player in get_tree().get_nodes_in_group(&"players"):
		if player.is_local and player.velocity.y <= 1.0 and holds(player.global_position):
			bounce(player)


## Throws `player` (on the net) back up: `rise` high, drifting in to the wall
## as they go up, to come over the roof's edge at the top.
func bounce(player: Player) -> void:
	var out := out_of_wall()
	var from_wall := (player.global_position - global_position).dot(out)
	var up_speed := sqrt(2.0 * player._rise_gravity * rise)
	var to_top := up_speed / player._rise_gravity
	var inward := maxf(0.0, from_wall - AT_WALL) / to_top
	player.ramp_launch(-out, inward, rise, 0.0)


func _build() -> void:
	if not is_inside_tree():
		return
	if _parts:
		_parts.free()
	_parts = Node3D.new()
	add_child(_parts)
	var net := CSGBox3D.new()
	net.name = "%s_Net" % name # (The reachability checker's place.)
	net.size = Vector3(size.x, THICK, size.y)
	net.position = Vector3(0.0, -THICK / 2.0, size.y / 2.0)
	net.material = MATERIAL
	net.use_collision = true
	_parts.add_child(net)
	# Its frame: an arm out from the wall at each end, and a bar along its outer edge.
	for side in [-1.0, 1.0]:
		_bar(Vector3(side * (size.x / 2.0 + FRAME / 2.0), -THICK / 2.0, size.y / 2.0), Vector3(FRAME, FRAME, size.y))
	_bar(Vector3(0.0, -THICK / 2.0, size.y + FRAME / 2.0), Vector3(size.x + 2.0 * FRAME, FRAME, FRAME))


func _bar(at: Vector3, bar_size: Vector3) -> void:
	var bar := CSGBox3D.new()
	bar.size = bar_size
	bar.position = at
	bar.material = FRAME_MATERIAL
	_parts.add_child(bar)
