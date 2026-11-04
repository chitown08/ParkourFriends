class_name CameraRig
extends Node3D
## Third-person orbit camera. Mouse / right stick / arrow keys turn it; the
## SpringArm3D pulls the camera in when a wall is in the way.
##
## The rig is "top level", meaning it doesn't inherit the Player's movement
## automatically. Instead it follows the Player's *smoothed* (interpolated)
## position every rendered frame, which keeps the view jitter-free on
## high-refresh monitors.

@export var follow_height := 1.6
@export var mouse_sensitivity := 0.0025 ## Scaled by the player's Settings.mouse_sensitivity.
@export var stick_sensitivity := 3.0 ## Radians per second at full tilt (gamepad and arrow keys).
@export_range(-89.0, 0.0) var min_pitch_degrees := -70.0
@export_range(0.0, 89.0) var max_pitch_degrees := 30.0
## How far behind you the camera sits (metres)...
@export var distance := 3.75
## ...and how much further back for each friend pack-running with you (up to
## three), so you can see the crowd round you.
@export var pack_pull_back := 1.0
## How quickly it eases in and out (higher: quicker).
@export var distance_ease := 1.5

## Which way is up for the body it follows (eased): straight up, except
## running round the inside of a tube (Player.body_up), where the camera
## stays on your head's side of you, inside the tube.
var _up := Vector3.UP
var yaw := 0.0
var pitch := -0.25
## False while a menu is open, so the camera ignores the mouse and keys.
var controls_enabled := true

@onready var _target := get_parent() as Node3D
@onready var _spring_arm: SpringArm3D = $SpringArm3D
@onready var _camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	_spring_arm.spring_length = distance
	if _target is CollisionObject3D:
		_spring_arm.add_excluded_object((_target as CollisionObject3D).get_rid())
	_follow_target()


## Turns this camera on (for the local player) or off (for other players).
func set_active(active: bool) -> void:
	_camera.current = active
	set_process(active)
	set_process_unhandled_input(active)
	if active:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		var sensitivity := mouse_sensitivity * Settings.mouse_sensitivity
		yaw -= motion.relative.x * sensitivity
		pitch -= motion.relative.y * sensitivity * _y_direction()
	elif event is InputEventMouseButton and event.pressed:
		# Clicking back into the window (e.g. after alt-tabbing) grabs the mouse again.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if controls_enabled:
		var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		yaw -= look.x * stick_sensitivity * delta
		pitch -= look.y * stick_sensitivity * delta * _y_direction()
	pitch = clampf(pitch, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))
	_spring_arm.spring_length = lerpf(_spring_arm.spring_length, wanted_distance(), 1.0 - exp(-distance_ease * delta))

	rotation = Vector3(0.0, yaw, 0.0)
	_spring_arm.rotation = Vector3(pitch, 0.0, 0.0)
	_up = _up.slerp(_target.body_up if _target is Player else Vector3.UP, 1.0 - exp(-10.0 * delta))
	_follow_target()


## How far back the camera wants to be: further while you pack-run.
func wanted_distance() -> float:
	var pack: int = _target.pack_size() if _target is Player else 0
	return distance + pack_pull_back * mini(pack, Player.MOST_DRAFTING)


func _y_direction() -> float:
	return -1.0 if Settings.invert_y else 1.0


func _follow_target() -> void:
	global_position = _target.get_global_transform_interpolated().origin + _up * follow_height
