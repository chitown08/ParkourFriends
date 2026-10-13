class_name Player
extends CharacterBody3D
## The parkour character.
##
## How it's organized:
## - PlayerInput (child node) turns controls into plain variables. Movement
##   never reads the keyboard directly.
## - The States node holds one child per "mode" (Ground, Air, Hang, Climb).
##   Only the active state runs each tick; it decides how to move and when to
##   switch to another state. This script holds the settings and the shared
##   helpers the states use.
## - Multiplayer: the character is named after the network id of the player
##   who controls it. Only that player's computer runs the movement code; it
##   publishes the sync_* variables, which the MultiplayerSynchronizer node
##   sends to everyone else. On their screens this character is a "puppet"
##   that smoothly follows those values.
##
## Tip: every value under "@export" shows up in the Inspector panel when you
## select the Player in Godot, so you can tweak the feel without coding.

signal respawned
signal state_changed(new_state: StringName)

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

@export_group("Ledges")
@export var ledge_max_height := 2.2 ## Highest ledge (above your feet) you can grab.
@export var hang_min_height := 1.2 ## Ledges lower than this are vaulted over instead of hung from.
@export var mantle_min_height := 0.15 ## Ledges lower than this are just stepped onto.
@export var ledge_detect_distance := 0.35 ## How far in front of your body to look for walls.
@export var ledge_grab_max_rise_speed := 1.0 ## Can't grab while still rising faster than this.
@export var hang_height := 1.7 ## How far your feet hang below the ledge.
@export var hang_snap_speed := 8.0 ## How fast you slide into the hanging spot.
@export var shimmy_speed := 2.0
@export var climb_up_time := 0.45 ## Seconds to pull up from hanging.
@export var mantle_time := 0.25 ## Seconds to vault over a low ledge.
@export var ledge_regrab_delay := 0.35 ## After letting go, can't re-grab for this long.

@export_group("Respawn")
@export var kill_height := -15.0 ## Falling below this height respawns you.

@export_group("Multiplayer")
@export var puppet_smoothing := 25.0 ## How quickly other players' characters catch up to where they really are.
@export var puppet_teleport_distance := 3.0 ## Further off than this, just jump there (e.g. after a respawn).

## Body colours, one per player slot.
const COLORS: Array[Color] = [
	Color(0.2, 0.55, 0.95), # blue
	Color(0.95, 0.5, 0.15), # orange
	Color(0.3, 0.8, 0.35), # green
	Color(0.85, 0.3, 0.75), # pink
]

## True if this character is controlled by this computer.
var is_local := true
var respawn_position := Vector3.ZERO

# Sent from the controlling player's computer to everyone else (NetworkSync node).
var sync_position := Vector3.ZERO
var sync_facing := 0.0
var sync_state := &"Air"

## Which of COLORS this player wears. Chosen by the host and sent to everyone
## (HostSync node), so it's the same on every screen.
var color_index := 0:
	set(value):
		color_index = value
		if is_node_ready():
			_apply_color()

var state: PlayerState

var jump_velocity: float
var _rise_gravity: float
var _fall_gravity: float
var _jump_buffer_timer := 0.0

@onready var input: PlayerInput = $PlayerInput
@onready var camera_rig: CameraRig = $CameraRig
@onready var _visual: Node3D = $Visual
@onready var _body_mesh: MeshInstance3D = $Visual/Body
@onready var _states: Node = $States
@onready var _body_shape: CapsuleShape3D = $CollisionShape3D.shape
@onready var body_radius: float = _body_shape.radius


func _enter_tree() -> void:
	# The player whose network id matches our name is in charge of us
	# (Godot calls this the "multiplayer authority").
	set_multiplayer_authority(str(name).to_int())
	# ...except the HostSync node, which carries things only the host decides.
	$HostSync.set_multiplayer_authority(1)


func _ready() -> void:
	is_local = is_multiplayer_authority()
	add_to_group(&"players")
	_apply_color()

	# Work out jump physics from designer-friendly numbers (height + timing).
	jump_velocity = 2.0 * jump_height / jump_time_to_peak
	_rise_gravity = 2.0 * jump_height / (jump_time_to_peak * jump_time_to_peak)
	_fall_gravity = 2.0 * jump_height / (jump_time_to_fall * jump_time_to_fall)

	for child in _states.get_children():
		var player_state := child as PlayerState
		player_state.player = self
		player_state.input = input

	respawn_position = global_position
	sync_position = global_position
	camera_rig.set_active(is_local)
	change_state(&"Air")


func _physics_process(delta: float) -> void:
	if not is_local:
		_follow_network(delta)
		return

	input.gather(camera_rig.yaw)
	if input.jump_just_pressed:
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer -= delta

	state.physics_update(delta)

	if input.respawn_just_pressed or global_position.y < kill_height:
		respawn()

	sync_position = global_position
	sync_facing = _visual.rotation.y
	sync_state = state.name


## Moves this puppet toward where its owner says it is.
func _follow_network(delta: float) -> void:
	if global_position.distance_to(sync_position) > puppet_teleport_distance:
		global_position = sync_position
		reset_physics_interpolation()
	else:
		var weight := 1.0 - exp(-puppet_smoothing * delta)
		global_position = global_position.lerp(sync_position, weight)
	_visual.rotation.y = lerp_angle(_visual.rotation.y, sync_facing, 1.0 - exp(-puppet_smoothing * delta))


## Switches to the state (child of the States node) with this name.
func change_state(state_name: StringName, data: Dictionary = {}) -> void:
	if state:
		state.exit()
	state = _states.get_node(NodePath(state_name))
	state.enter(data)
	state_changed.emit(state_name)


func set_checkpoint(position_: Vector3) -> void:
	respawn_position = position_


func respawn() -> void:
	global_position = respawn_position
	velocity = Vector3.ZERO
	change_state(&"Air")
	reset_physics_interpolation() # Teleport instantly instead of "sliding" there.
	respawned.emit()


func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


## Turns the player's controls and camera on or off (e.g. while a menu is open).
func set_controls_enabled(enabled: bool) -> void:
	input.enabled = enabled
	camera_rig.controls_enabled = enabled


func _apply_color() -> void:
	# Each player gets their own copy of the material, so recolouring one
	# doesn't recolour everyone.
	var material := _body_mesh.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
	material.albedo_color = COLORS[color_index % COLORS.size()]
	_body_mesh.material_override = material


# --- Helpers shared by the states --------------------------------------------

## True (once) if jump was pressed recently. Lets a slightly-early press count.
func consume_jump() -> bool:
	if _jump_buffer_timer > 0.0:
		_jump_buffer_timer = 0.0
		return true
	return false


func apply_gravity(delta: float) -> void:
	var gravity := _rise_gravity if velocity.y > 0.0 else _fall_gravity
	velocity.y = maxf(velocity.y - gravity * delta, -max_fall_speed)


## Speeds up toward the input direction (or slows down if there's no input).
func move_horizontally(delta: float, acceleration: float, friction: float) -> void:
	var wish_dir := input.move_direction
	var target_speed := sprint_speed if input.sprint_held else run_speed
	var rate := acceleration if wish_dir != Vector3.ZERO else friction
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish_dir * target_speed, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


## Smoothly turns the body to face `direction` (ignored if it's ~zero).
func face_direction(direction: Vector3, delta: float) -> void:
	if Vector2(direction.x, direction.z).length_squared() < 0.01:
		return
	# The model's "front" is -Z, so atan2(-x, -z) gives the angle to face `direction`.
	var target_yaw := atan2(-direction.x, -direction.z)
	_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))


## Where the player's feet go when hanging from `ledge`.
func hang_position(ledge: Ledge) -> Vector3:
	return ledge.position + ledge.normal * (body_radius + 0.05) + Vector3.DOWN * hang_height


## Where the player's feet go after climbing up onto `ledge`.
func stand_position(ledge: Ledge) -> Vector3:
	return ledge.position - ledge.normal * (body_radius + 0.15) + Vector3.UP * 0.02


## Looks for a grabbable ledge in front of a player standing at `feet` and
## facing `forward`. Returns null if there isn't one.
func find_ledge(feet: Vector3, forward: Vector3) -> Ledge:
	forward = Vector3(forward.x, 0.0, forward.z).normalized()
	if forward == Vector3.ZERO:
		return null
	var reach := body_radius + ledge_detect_distance

	# 1. Is there a wall in front of us? Check at a few heights.
	var wall := {}
	for height: float in [0.3, 0.9, 1.5]:
		var from := feet + Vector3.UP * height
		wall = _raycast(from, from + forward * reach)
		if not wall.is_empty():
			break
	if wall.is_empty():
		return null
	var wall_normal: Vector3 = wall.normal
	if absf(wall_normal.y) > 0.3:
		return null # That's a slope or floor, not a wall.
	wall_normal = Vector3(wall_normal.x, 0.0, wall_normal.z).normalized()

	# 2. Find the top of the wall by looking down from above, just behind its face.
	var above: Vector3 = wall.position - wall_normal * 0.2
	above.y = feet.y + ledge_max_height + 0.1
	var top := _raycast(above, Vector3(above.x, feet.y + mantle_min_height, above.z))
	if top.is_empty() or top.normal.y < 0.7:
		return null # No flat top within reach.

	var ledge := Ledge.new()
	ledge.normal = wall_normal
	ledge.position = Vector3(wall.position.x, top.position.y, wall.position.z)
	ledge.height = ledge.position.y - feet.y

	# 3. Is there open space above the edge, room to pull up, and room to stand?
	var over_edge := ledge.position + wall_normal * reach + Vector3.UP * 0.15
	if not _raycast(over_edge, over_edge - wall_normal * (reach + 0.3)).is_empty():
		return null # The wall keeps going up; that "top" was something else.
	var hang_column := hang_position(ledge)
	hang_column.y = ledge.position.y + 0.05
	if not _body_fits(hang_column) or not _body_fits(stand_position(ledge)):
		return null
	return ledge


func _raycast(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query)


## True if the player's body would fit with its feet at `feet` without
## overlapping the level.
func _body_fits(feet: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _body_shape
	query.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * (_body_shape.height * 0.5 + 0.02))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
