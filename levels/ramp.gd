@tool
class_name Ramp
extends Node3D
## A launch roof: a low building whose orange roof slopes down to a lip. Climb
## it from behind (the yellow step, then the back wall), slide down the slope
## and the lip launches you up and on, keeping your speed (you can steer a bit
## in the air). The faster you leave it, the higher you go; still sliding as
## you leave it adds more, and so does a readied free-run leap. Too slow and you
## just drop off the lip.
##
## Its origin is on the ground under the lip, and it faces -Z (the way you
## launch). The lip is `height` up; the roof rises at `pitch` degrees for
## `length` metres back from it.

const WALL_MATERIAL := preload("res://materials/grid_platform.tres")
const STEP_MATERIAL := preload("res://materials/grid_climb.tres")

@export var length := 8.0:
	set(value):
		length = value
		_build()
@export var height := 2.5:
	set(value):
		height = value
		_build()
@export var pitch := 25.0:
	set(value):
		pitch = value
		_build()
@export var width := 6.0:
	set(value):
		width = value
		_build()
## The sloping roof's material (the walls are grey, the step yellow).
@export var material: Material:
	set(value):
		material = value
		_build()

## Leave it slower than this (m/s) and there's no launch.
const MIN_SPEED := 8.0
## Launch height (metres above the lip) from MIN_SPEED up to FULL_SPEED.
const MIN_LAUNCH := 3.0
const FULL_SPEED := 16.0
const MAX_LAUNCH := 8.0
## Extra height for leaving it sliding, and for a fully readied leap.
const SLIDE_BONUS := 3.0
const LEAP_BONUS := 2.0
## Your feet must be within this of the lip as you pass it.
const LIP_REACH := 0.7
## The step up the back: this deep, and halfway up the back wall.
const STEP_DEPTH := 2.5

var _base: CSGBox3D
var _roof: CSGPolygon3D
var _step: CSGBox3D
## Per player: how far past the lip they were last tick.
var _last_along := {}


func _ready() -> void:
	add_to_group(&"ramps")
	_build()


## How high the roof's back edge is above the lip.
func rise() -> float:
	return length * tan(deg_to_rad(pitch))


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	for player: Player in get_tree().get_nodes_in_group(&"players"):
		if not player.is_local:
			continue
		var local := to_local(player.global_position)
		var along := -local.z # Metres past the lip (negative: still on the roof).
		var before: float = _last_along.get(player, along)
		_last_along[player] = along
		if absf(local.x) <= width / 2.0 and before < 0.0 and along >= 0.0 and absf(local.y - height) < LIP_REACH:
			_launch(player)


func _launch(player: Player) -> void:
	var speed := player.get_horizontal_speed()
	if speed < MIN_SPEED:
		return
	var launch := lerpf(MIN_LAUNCH, MAX_LAUNCH, clampf(inverse_lerp(MIN_SPEED, FULL_SPEED, speed), 0.0, 1.0))
	if player.state.name == &"Slide":
		launch += SLIDE_BONUS
	var forward := -global_basis.z.slide(Vector3.UP).normalized()
	player.ramp_launch(forward, speed, launch, LEAP_BONUS)


func _build() -> void:
	if not is_inside_tree():
		return
	if _base == null:
		_base = CSGBox3D.new()
		_roof = CSGPolygon3D.new()
		_step = CSGBox3D.new()
		for part: CSGShape3D in [_base, _roof, _step]:
			part.use_collision = true
			add_child(part)
	_base.size = Vector3(width, height, length)
	_base.position = Vector3(0.0, height / 2.0, length / 2.0)
	_base.material = WALL_MATERIAL
	# The roof side-on, in (back-to-front, up): a wedge from the back edge down
	# to the lip. Laid on its side and stretched across the width.
	_roof.polygon = PackedVector2Array([Vector2(-length, 0.0), Vector2(-length, rise()), Vector2(0.0, 0.0)])
	_roof.depth = width
	# The outline's x runs toward -Z once turned; it's pushed out along -X, so shift it back.
	_roof.transform = Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(width / 2.0, height, 0.0))
	_roof.material = material
	var step_height := (height + rise()) / 2.0
	_step.size = Vector3(width, step_height, STEP_DEPTH)
	_step.position = Vector3(0.0, step_height / 2.0, length + STEP_DEPTH / 2.0)
	_step.material = STEP_MATERIAL
