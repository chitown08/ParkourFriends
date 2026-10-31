@tool
class_name Ramp
extends Node3D
## An orange kicker ramp: hit it fast and its lip launches you up and on,
## keeping your speed (you can steer a bit in the air). The faster you hit it,
## the higher you go; slide into it for the big one, and a readied free-run
## leap at the lip adds a little more. Too slow and you just roll off the lip.
##
## The ramp's origin is the foot of the lip and it faces -Z (the way you
## launch). It rises along a curve from `length` behind that to `height`.

@export var length := 5.0:
	set(value):
		length = value
		_build()
@export var height := 1.5:
	set(value):
		height = value
		_build()
@export var width := 4.0:
	set(value):
		width = value
		_build()
@export var material: Material:
	set(value):
		material = value
		_build()

## Hit the ramp slower than this (m/s) and there's no launch.
const MIN_SPEED := 8.0
## Launch height (metres above the lip) from MIN_SPEED up to FULL_SPEED.
const MIN_LAUNCH := 3.0
const FULL_SPEED := 16.0
const MAX_LAUNCH := 8.0
## Extra height for sliding into the ramp, and for a fully readied leap.
const SLIDE_BONUS := 3.0
const LEAP_BONUS := 2.0
## Your feet must be within this of the lip's top as you pass it.
const LIP_REACH := 0.7
## Your speed is taken as you come onto the ramp, from this far in front of it.
const APPROACH := 4.0
const CURVE_STEPS := 8

var _surface: CSGPolygon3D
## Per player: how far past the lip they were last tick, how fast they hit
## the ramp, and whether they were sliding.
var _last_along := {}
var _hit_speed := {}
var _hit_sliding := {}


func _ready() -> void:
	add_to_group(&"ramps")
	_build()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	for player: Player in get_tree().get_nodes_in_group(&"players"):
		if not player.is_local:
			continue
		var local := to_local(player.global_position)
		var along := -local.z # Metres past the lip (negative: still before it).
		var before: float = _last_along.get(player, along)
		_last_along[player] = along
		var beside := absf(local.x) <= width / 2.0
		if beside and along > -length - APPROACH and along < -length:
			_hit_speed[player] = player.get_horizontal_speed() # Coming onto the ramp.
			_hit_sliding[player] = player.state.name == &"Slide"
		if beside and before < 0.0 and along >= 0.0 and absf(local.y - height) < LIP_REACH:
			_launch(player)
		if along < -length - APPROACH or along > 1.0 or not beside:
			_hit_speed.erase(player) # Gone: only a fresh run at it counts.


func _launch(player: Player) -> void:
	var speed: float = maxf(_hit_speed.get(player, 0.0), player.get_horizontal_speed())
	if speed < MIN_SPEED:
		return
	var rise := lerpf(MIN_LAUNCH, MAX_LAUNCH, clampf(inverse_lerp(MIN_SPEED, FULL_SPEED, speed), 0.0, 1.0))
	if _hit_sliding.get(player, false):
		rise += SLIDE_BONUS
	var forward := -global_basis.z.slide(Vector3.UP).normalized()
	player.ramp_launch(forward, speed, rise, LEAP_BONUS)
	_hit_speed.erase(player)


func _build() -> void:
	if not is_inside_tree():
		return
	if _surface == null:
		_surface = CSGPolygon3D.new()
		_surface.use_collision = true
		add_child(_surface)
	# The side profile, in (back-to-front, up): a curve that gets steeper
	# toward the lip, then straight down at the lip. Laid on its side and
	# stretched across the ramp's width.
	var profile := PackedVector2Array([Vector2(-length, 0.0)])
	for i in range(1, CURVE_STEPS + 1):
		var t := float(i) / CURVE_STEPS
		profile.append(Vector2(-length + length * t, height * t * t))
	profile.append(Vector2(0.0, 0.0))
	_surface.polygon = profile
	_surface.depth = width
	# The profile's x runs toward -Z once turned; it's pushed out along -X, so shift it back.
	_surface.transform = Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(width / 2.0, 0.0, 0.0))
	_surface.material = material
