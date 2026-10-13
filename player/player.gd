class_name Player
extends CharacterBody3D
## The parkour character: running, sprinting and jumping.
##
## Movement only ever reads from the PlayerInput child node, never from the
## keyboard. That's what will let a remote player's input drive this same code
## once multiplayer is added.
##
## Tip: every value under "@export" shows up in the Inspector panel when you
## select the Player in Godot, so you can tweak the feel without coding.

signal respawned

@export_group("Running")
@export var run_speed := 6.0
@export var sprint_speed := 9.5
@export var ground_acceleration := 60.0
@export var ground_friction := 50.0 ## How fast you stop when you let go.
@export var air_acceleration := 20.0 ## How much you can steer mid-air.
@export var air_friction := 2.0 ## Keeps your momentum when you let go mid-air.
@export var turn_speed := 12.0 ## How fast the body turns to face where you run.

@export_group("Jumping")
@export var jump_height := 1.7 ## Meters, if you hold the jump button.
@export var jump_time_to_peak := 0.36 ## Seconds to reach the top of a jump.
@export var jump_time_to_fall := 0.30 ## Seconds to fall back down (snappier than going up).
@export_range(0.0, 1.0) var jump_cut := 0.5 ## Releasing jump early keeps this much upward speed.
@export var coyote_time := 0.12 ## You can still jump this long after running off a ledge.
@export var jump_buffer_time := 0.12 ## Pressing jump this early before landing still counts.
@export var max_fall_speed := 40.0

@export_group("Respawn")
@export var kill_height := -15.0 ## Falling below this height respawns you.

## True if this character is controlled by this computer. In multiplayer this
## will be decided by who "owns" the character (Godot calls it the authority).
var is_local := true
var respawn_position := Vector3.ZERO

var _jump_velocity: float
var _rise_gravity: float
var _fall_gravity: float
var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _is_jumping := false

@onready var input: PlayerInput = $PlayerInput
@onready var camera_rig: CameraRig = $CameraRig
@onready var _visual: Node3D = $Visual


func _ready() -> void:
	# Work out jump physics from designer-friendly numbers (height + timing).
	_jump_velocity = 2.0 * jump_height / jump_time_to_peak
	_rise_gravity = 2.0 * jump_height / (jump_time_to_peak * jump_time_to_peak)
	_fall_gravity = 2.0 * jump_height / (jump_time_to_fall * jump_time_to_fall)

	respawn_position = global_position
	camera_rig.set_active(is_local)


func _physics_process(delta: float) -> void:
	if is_local:
		input.gather(camera_rig.yaw)

	_update_timers(delta)
	_apply_gravity(delta)
	_try_jump()
	_apply_horizontal_movement(delta)
	move_and_slide()
	_turn_to_face_movement(delta)

	if input.respawn_just_pressed or global_position.y < kill_height:
		respawn()


func set_checkpoint(position_: Vector3) -> void:
	respawn_position = position_


func respawn() -> void:
	global_position = respawn_position
	velocity = Vector3.ZERO
	_is_jumping = false
	reset_physics_interpolation() # Teleport instantly instead of "sliding" there.
	respawned.emit()


func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func _update_timers(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
		if velocity.y <= 0.0:
			_is_jumping = false
	else:
		_coyote_timer -= delta

	if input.jump_just_pressed:
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer -= delta


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	var gravity := _rise_gravity if velocity.y > 0.0 else _fall_gravity
	velocity.y = maxf(velocity.y - gravity * delta, -max_fall_speed)


func _try_jump() -> void:
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = _jump_velocity
		_is_jumping = true
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0

	# Variable jump height: let go of jump early for a short hop.
	if _is_jumping and not input.jump_held and velocity.y > 0.0:
		velocity.y *= jump_cut
		_is_jumping = false


func _apply_horizontal_movement(delta: float) -> void:
	var wish_dir := input.move_direction
	var target_speed := sprint_speed if input.sprint_held else run_speed
	var target_velocity := wish_dir * target_speed

	var rate: float
	if is_on_floor():
		rate = ground_acceleration if wish_dir != Vector3.ZERO else ground_friction
	else:
		rate = air_acceleration if wish_dir != Vector3.ZERO else air_friction

	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(target_velocity, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _turn_to_face_movement(delta: float) -> void:
	var dir := input.move_direction
	if dir.length_squared() < 0.01:
		return
	# The model's "front" is -Z, so atan2(-x, -z) gives the angle to face `dir`.
	var target_yaw := atan2(-dir.x, -dir.z)
	_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))
