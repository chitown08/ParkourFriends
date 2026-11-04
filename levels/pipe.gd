@tool
class_name Pipe
extends Node3D
## A big round tube you can run through, and (going fast enough) round the
## inside of: up the side, across the ceiling and down the other side, like a
## loop-the-loop. Storm drains, road tunnels, glass tubes between towers.
## Running round it is the player's PipeRun state: you're on the wall as long
## as you're going fast enough round it to stay there (slow down near the top
## and you drop off).
##
## Its origin is on the floor in the middle of one end; it runs `length` along
## -Z. Inside, the floor is at the origin's height and the ceiling `2 * radius` up.

## Running round it, gravity slows you going up the wall and speeds you coming
## down (m/s²; gentler than falling, so a loop is about speed, not a miracle)...
const GRAVITY := 10.0
## ...and running pushes you on (m/s², while you steer the way you're going,
## up to your top speed).
const PUSH := 3.0
## You start running round it once you're this far up the side (degrees)...
const ENTER_ANGLE := 25.0
## ...going at least this fast (m/s).
const ENTER_SPEED := 5.0
## Below this (degrees from the bottom) and slower round than SETTLE_SPEED, you're back on the floor.
const SETTLE_ANGLE := 12.0
const SETTLE_SPEED := 2.5
## How thick the tube's wall is (metres).
const WALL := 0.4
const SIDES := 32
const MATERIAL := preload("res://materials/grid_ramp.tres")

@export var length := 30.0:
	set(value):
		length = value
		_build()
@export var radius := 3.5:
	set(value):
		radius = value
		_build()
## A see-through glass tube (between towers) instead of a solid one.
@export var glass := false:
	set(value):
		glass = value
		_build()

var _shape: CSGCombiner3D
## Players who just came off the wall, and until when (seconds, game time)
## they can't get back on: Time.get_ticks_msec() / 1000.
var _blocked := {}


func _ready() -> void:
	add_to_group(&"pipes")
	_build()


## The speed (m/s, round the tube, at the bottom) it takes to get all the way
## round and over the top without dropping off: at the top you need
## v² >= GRAVITY * radius to stay on, and climbing the 2 * radius there takes
## 4 * GRAVITY * radius of v², less what running pushes back (PUSH over half
## the way round).
func loop_speed() -> float:
	return sqrt(maxf(0.0, 5.0 * GRAVITY * radius - 2.0 * PUSH * PI * radius))


## Where your feet are, `along` metres in from the start, `angle` round from
## the bottom (radians; positive toward +X), in world space.
func surface_point(along: float, angle: float) -> Vector3:
	return to_global(Vector3(radius * sin(angle), radius - radius * cos(angle), -along))


## Straight in toward the middle of the tube from `angle` round (world space).
func inward(angle: float) -> Vector3:
	return global_basis * Vector3(-sin(angle), cos(angle), 0.0)


## Which way is round the tube (increasing `angle`) at `angle` (world space).
func around(angle: float) -> Vector3:
	return global_basis * Vector3(cos(angle), sin(angle), 0.0)


## Along the tube, from its start to its end (world space).
func along_direction() -> Vector3:
	return -global_basis.z


## Where `point` is in the tube: Vector3(metres in from the start, angle round
## from the bottom (radians), distance from the middle line).
func locate(point: Vector3) -> Vector3:
	var local := to_local(point)
	var off := Vector2(local.x, local.y - radius)
	return Vector3(-local.z, atan2(off.x, -off.y), off.length())


## The middle line of the tube, `along` metres in (world space).
func axis_point(along: float) -> Vector3:
	return to_global(Vector3(0.0, radius, -along))


## Whether `point` is inside the tube (between its ends, within its wall).
func contains(point: Vector3) -> bool:
	var at := locate(point)
	return at.x >= 0.0 and at.x <= length and at.z <= radius + 0.1


## Stops `player` getting back on the wall for `seconds` (just jumped or dropped off).
func block(player: Player, seconds: float) -> void:
	_blocked[player] = Time.get_ticks_msec() / 1000.0 + seconds


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var now := Time.get_ticks_msec() / 1000.0
	for player: Player in get_tree().get_nodes_in_group(&"players"):
		if not player.is_local or player.state.name not in [&"Ground", &"Air", &"Slide", &"Crouch"]:
			continue
		if _blocked.get(player, 0.0) > now or player.hands_busy():
			continue
		var at := locate(player.global_position)
		if at.x < 0.5 or at.x > length - 0.5 or at.z < radius - 0.6 or at.z > radius + 0.3:
			continue # Not in it, or not with your feet on the wall.
		if absf(rad_to_deg(at.y)) < ENTER_ANGLE or player.velocity.length() < ENTER_SPEED:
			continue
		# Going round fast enough to stick here (see PipeRun), and not flying off it.
		var round_speed := player.velocity.dot(around(at.y))
		if round_speed * round_speed / radius + GRAVITY * cos(at.y) < 0.0 or player.velocity.dot(inward(at.y)) > 3.0:
			continue
		player.change_state(&"PipeRun", {"pipe": self})


func _build() -> void:
	if not is_inside_tree():
		return
	if _shape != null:
		_shape.queue_free()
	_shape = CSGCombiner3D.new()
	_shape.use_collision = true
	var outer := CSGCylinder3D.new()
	outer.radius = radius + WALL
	outer.height = length
	outer.sides = SIDES
	var inner := CSGCylinder3D.new()
	inner.radius = radius
	inner.height = length + 0.2
	inner.sides = SIDES
	inner.operation = CSGShape3D.OPERATION_SUBTRACTION
	_shape.add_child(outer)
	_shape.add_child(inner)
	# A cylinder stands up along Y: lay it down along -Z, its floor at our origin.
	_shape.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(0.0, radius, -length / 2.0))
	var material: Material = MATERIAL
	if glass:
		var see_through := StandardMaterial3D.new()
		see_through.albedo_color = Color(0.75, 0.9, 1.0, 0.25)
		see_through.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		see_through.metallic = 0.3
		see_through.roughness = 0.05
		see_through.cull_mode = BaseMaterial3D.CULL_DISABLED
		material = see_through
	outer.material = material
	inner.material = material
	add_child(_shape)
