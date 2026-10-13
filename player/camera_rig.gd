class_name CameraRig
extends Node3D
## Third-person orbit camera. Mouse / right stick turns it; the SpringArm3D
## pulls the camera in when a wall is in the way.
##
## The rig is "top level", meaning it doesn't inherit the Player's movement
## automatically. Instead it follows the Player's *smoothed* (interpolated)
## position every rendered frame, which keeps the view jitter-free on
## high-refresh monitors.

@export var follow_height := 1.6
@export var mouse_sensitivity := 0.0025
@export var gamepad_sensitivity := 3.0 ## Radians per second at full tilt.
@export var invert_y := false
@export_range(-89.0, 0.0) var min_pitch_degrees := -70.0
@export_range(0.0, 89.0) var max_pitch_degrees := 30.0

var yaw := 0.0
var pitch := -0.25

@onready var _target := get_parent() as Node3D
@onready var _spring_arm: SpringArm3D = $SpringArm3D
@onready var _camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
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
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		yaw -= motion.relative.x * mouse_sensitivity
		pitch -= motion.relative.y * mouse_sensitivity * (-1.0 if invert_y else 1.0)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	yaw -= look.x * gamepad_sensitivity * delta
	pitch -= look.y * gamepad_sensitivity * delta * (-1.0 if invert_y else 1.0)
	pitch = clampf(pitch, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))

	rotation = Vector3(0.0, yaw, 0.0)
	_spring_arm.rotation = Vector3(pitch, 0.0, 0.0)
	_follow_target()


func _follow_target() -> void:
	global_position = _target.get_global_transform_interpolated().origin + Vector3.UP * follow_height
