@tool
class_name Launcher
extends Node3D
## An orange ramp you run UP and fly off the top: the faster you hit it, the
## higher it throws you. (The launch roofs round the plaza, Ramp, are the other
## way round: you slide down them and off the lip.) Two shapes:
##   - straight (a wall ramp): a narrow incline `length` long rising to `height`,
##     built along a building's side: it throws you up and on, high up the wall,
##     to grab or scramble onto the roof;
##   - curved (a quarter-pipe): a curve of `radius` rising from flat to `angle`
##     degrees, that turns your run into a big launch straight up. Two facing
##     each other make a half-pipe.
## Its origin is on the ground at the foot; you run along -Z to go up it. Too
## slow and you just run up and stop (a straight one: you step off the top).

## Leave it slower than this (m/s) and there's no launch...
const MIN_SPEED := 7.0
## ...and from there to FULL_SPEED it throws you from MIN_RISE to `max_rise`
## metres above the lip (more with a readied leap).
const FULL_SPEED := 16.0
const MIN_RISE := 3.0
const LEAP_BONUS := 2.0
## Your feet must be within this of the surface as you pass the launch point.
const REACH := 0.9
## A curve launches you where it gets this steep (degrees): steeper than you
## can run up (the rest of the curve is "ridden" in the launch).
const CURVE_LAUNCH := 40.0
const MATERIAL := preload("res://materials/grid_ramp.tres")
const BACK_MATERIAL := preload("res://materials/grid_platform.tres")

@export var curved := false:
	set(value):
		curved = value
		_build()
@export var width := 3.0:
	set(value):
		width = value
		_build()
@export_group("Straight")
@export var length := 12.0:
	set(value):
		length = value
		_build()
@export var height := 5.0:
	set(value):
		height = value
		_build()
@export_group("Curved")
@export var radius := 5.0:
	set(value):
		radius = value
		_build()
@export_range(10.0, 90.0) var angle := 75.0:
	set(value):
		angle = value
		_build()
@export_group("")
## The most it throws you above the launch point (metres), at full speed.
@export var max_rise := 9.0

var _shape: CSGPolygon3D
## Per player: how far along the launch point they were last tick.
var _last_along := {}


func _ready() -> void:
	add_to_group(&"launchers")
	_build()


## The launch point, from the foot: (metres along -Z, metres up).
func launch_point() -> Vector2:
	if not curved:
		return Vector2(length, height)
	var a := deg_to_rad(minf(angle, CURVE_LAUNCH))
	return Vector2(radius * sin(a), radius * (1.0 - cos(a)))


## Which way it throws you (a unit vector: along -Z and up).
func launch_direction() -> Vector3:
	var a := deg_to_rad(angle) if curved else atan2(height, length)
	return (-global_basis.z * cos(a) + Vector3.UP * sin(a)).normalized()


## How high (metres above the launch point) it throws you, going `speed`.
func rise_for(speed: float) -> float:
	if speed < MIN_SPEED:
		return 0.0
	return lerpf(MIN_RISE, max_rise, clampf(inverse_lerp(MIN_SPEED, FULL_SPEED, speed), 0.0, 1.0))


## The top of its launch, world space: its launch point, plus the most it throws you.
func top() -> Vector3:
	var at := launch_point()
	return global_position - global_basis.z * at.x + Vector3.UP * (at.y + max_rise + LEAP_BONUS)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var at := launch_point()
	for player: Player in get_tree().get_nodes_in_group(&"players"):
		if not player.is_local:
			continue
		var local := to_local(player.global_position)
		var along := -local.z - at.x # Metres past the launch point (negative: before it).
		var before: float = _last_along.get(player, along)
		_last_along[player] = along
		if absf(local.x) <= width / 2.0 and before < 0.0 and along >= 0.0 and absf(local.y - at.y) < REACH:
			_launch(player)


func _launch(player: Player) -> void:
	var speed := player.get_horizontal_speed()
	if speed < MIN_SPEED:
		return
	var way := launch_direction()
	var flat := Vector3(way.x, 0.0, way.z)
	# On along the ramp at your speed (what's left of it, the steeper it is),
	# and up as high as your speed earns.
	player.ramp_launch(flat.normalized() if flat.length() > 0.01 else Vector3.ZERO, speed * flat.length(), rise_for(speed), LEAP_BONUS)


func _build() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = CSGPolygon3D.new()
		_shape.use_collision = true
		add_child(_shape)
	# Side-on, in (along, up): the surface you run on, closed underneath.
	var outline := PackedVector2Array([Vector2.ZERO])
	if curved:
		var steps := 16
		for i in range(1, steps + 1):
			var a := deg_to_rad(angle) * i / steps
			outline.append(Vector2(radius * sin(a), radius * (1.0 - cos(a))))
		outline.append(Vector2(outline[outline.size() - 1].x, 0.0))
	else:
		outline.append(Vector2(length, height))
		outline.append(Vector2(length, 0.0))
	_shape.polygon = outline
	_shape.depth = width
	# The outline's x runs toward -Z once turned; it's pushed out along -X, so shift it back.
	_shape.transform = Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(width / 2.0, 0.0, 0.0))
	_shape.material = MATERIAL
