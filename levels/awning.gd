@tool
class_name Awning
extends Node3D
## A shop's awning over the pavement, a storey up: orange (it launches you),
## and springy. Land on it and it bounces you up, keeping your speed along
## the street, so you can bounce from awning to awning down a street, or drop
## off a roof onto one and bounce instead of landing hard. (The bigger the
## drop, the bigger the bounce, up to a limit.)
##
## Its origin is at the wall, level with its top; +Z points out of the wall.
## It's `size` big (along the wall, out from it).

const MATERIAL := preload("res://materials/grid_ramp.tres")
const FRAME_MATERIAL := preload("res://materials/iron.tres")
const THICK := 0.15
## Feet within this of its top (and not going up) count as landing on it.
const REACH := 0.35
## The bounce: at least this high (metres above it), and at most this (from a
## big drop, which gives back this share of the height you fell).
const BOUNCE := 3.5
const MOST_BOUNCE := 6.5
const GIVE_BACK := 0.5
## Not twice in a row: you've just left it (physics frames).
const AGAIN_AFTER := 15

@export var size := Vector2(5.0, 2.2):
	set(value):
		size = value
		_build()

var _parts: Node3D
var _last_bounce := {}


func _ready() -> void:
	add_to_group(&"awnings")
	_build()


## Flat direction pointing out of the wall.
func out_of_wall() -> Vector3:
	var out := global_basis.z
	return Vector3(out.x, 0.0, out.z).normalized()


## Whether `feet` (world space) are on it.
func holds(feet: Vector3) -> bool:
	var local := to_local(feet)
	return absf(local.x) <= size.x / 2.0 + 0.1 and local.z >= 0.0 and local.z <= size.y + 0.1 and absf(local.y) < REACH


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var now := Engine.get_physics_frames()
	for player: Player in get_tree().get_nodes_in_group(&"players"):
		if player.is_local and player.velocity.y <= 1.0 and holds(player.global_position) \
				and now - int(_last_bounce.get(player, -1000)) > AGAIN_AFTER:
			_last_bounce[player] = now
			bounce(player)


## Bounces `player` (landing on it) back up, keeping their speed across the
## ground (but not into the wall).
func bounce(player: Player) -> void:
	var fallen := player.recent_peak() - player.global_position.y
	var rise := clampf(fallen * GIVE_BACK, BOUNCE, MOST_BOUNCE)
	var across := Vector3(player.velocity.x, 0.0, player.velocity.z)
	var out := out_of_wall()
	if across.dot(out) < 0.0:
		across -= out * across.dot(out) # (Not on into the wall.)
	player.ramp_launch(across.normalized() if across.length() > 0.1 else out, across.length(), rise, 0.0)


## How high it bounces you, at most (for the reachability checker).
func most_bounce() -> float:
	return MOST_BOUNCE


func _build() -> void:
	if not is_inside_tree():
		return
	if _parts:
		_parts.free()
	_parts = Node3D.new()
	add_child(_parts)
	var top := CSGBox3D.new()
	top.name = "%s_Top" % name # (The reachability checker's place.)
	top.size = Vector3(size.x, THICK, size.y)
	top.position = Vector3(0.0, -THICK / 2.0, size.y / 2.0)
	top.material = MATERIAL
	top.use_collision = true
	_parts.add_child(top)
	# A valance hanging from its front edge, and an arm under each end.
	var valance := CSGBox3D.new()
	valance.size = Vector3(size.x, 0.4, 0.05)
	valance.position = Vector3(0.0, -THICK - 0.2, size.y)
	valance.material = MATERIAL
	_parts.add_child(valance)
	for side: float in [-1.0, 1.0]:
		var arm := CSGBox3D.new()
		arm.size = Vector3(0.06, 0.06, Vector2(size.y, 0.9).length())
		arm.position = Vector3(side * (size.x / 2.0 - 0.1), -THICK - 0.45, size.y / 2.0)
		arm.rotation.x = atan2(0.9, size.y)
		arm.material = FRAME_MATERIAL
		_parts.add_child(arm)
