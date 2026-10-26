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
signal tossed_someone(target: Player)
signal got_tossed

## The movement numbers to use (how fast, how high, ...). Edit the profile
## files in player/profiles/ to change the feel; the pause menu can switch
## between them.
@export var profile: MovementProfile = preload("res://player/profiles/superhuman.tres")
## For testing and level design: act as if you're always at full flow (top speed).
@export var debug_full_flow := false

@export_group("Body")
@export var stand_height := 1.8 ## Body height when standing (meters).
@export var crouch_height := 1.0 ## Body height when crouched or sliding; you fit under gaps taller than this.

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

## Grey colour for the practice buddy.
const BUDDY_COLOR := Color(0.75, 0.75, 0.72)

## True if this character is controlled by this computer.
var is_local := true
## True for the solo practice buddy: run by this computer, but with no
## camera and no controls. Set before adding it to the scene.
var is_bot := false
var respawn_position := Vector3.ZERO

# Sent from the controlling player's computer to everyone else (NetworkSync node).
var sync_position := Vector3.ZERO
var sync_facing := 0.0
var sync_state := &"Air"
var sync_lean := 0.0
## Who has tossed us this air time (see tossed_by).
var sync_tossed_by := PackedStringArray()

# The movement numbers actually in use, copied from `profile` (see
# apply_profile()). Documented in movement_profile.gd. Change them by editing a
# profile, not here.
var run_speed: float
var flow_speed: float
var flow_build_time: float
var flow_decay_time: float
var ground_acceleration: float
var ground_friction: float
var air_acceleration: float
var air_friction: float
var turn_speed: float
var jump_height: float
var jump_time_to_peak: float
var jump_time_to_fall: float
var jump_cut: float
var coyote_time: float
var jump_buffer_time: float
var max_fall_speed: float
var ledge_max_height: float
var hang_min_height: float
var mantle_min_height: float
var ledge_detect_distance: float
var ledge_grab_max_rise_speed: float
var hang_height: float
var hang_snap_speed: float
var shimmy_speed: float
var climb_up_time: float
var mantle_time: float
var ledge_regrab_delay: float
var ledge_leap_height: float
var ledge_leap_speed: float
var crouch_speed: float
var slide_min_start_speed: float
var slide_boost: float
var slide_friction: float
var slide_slope_gravity: float
var slide_steer_speed: float
var slide_max_speed: float
var slide_end_speed: float
var wall_detect_distance: float
var wall_jump_push: float
var wall_jump_height: float
var wall_jump_control_lock: float
var wall_run_min_speed: float
var wall_run_speed: float
var wall_run_lift: float
var wall_run_gravity: float
var wall_run_max_time: float
var wall_run_min_height: float
var wall_run_lean_degrees: float
var wall_scramble_speed: float
var wall_scramble_time: float
var zipline_gravity: float
var zipline_min_speed: float
var zipline_max_speed: float
var zipline_grab_radius: float
var zipline_hang_height: float
var zipline_regrab_delay: float
var toss_range: float
var toss_height: float
var toss_forward_speed: float
var toss_recoil_height: float
var toss_control_lock: float
var toss_cooldown: float
var limit_tosses_per_air: bool

## How much flow (momentum) you've built up: 0 = normal running speed,
## 1 = top speed. See _update_flow().
var flow := 0.0
## Time left before you can grab a zipline again (after leaving one).
var zipline_cooldown := 0.0

## Where this player starts. Chosen by the host and sent along when the
## character is created (HostSync node), so joining players don't need the
## world loaded to know where they are.
var spawn_position := Vector3.ZERO:
	set(value):
		spawn_position = value
		position = value
		if is_node_ready():
			respawn_position = value
			sync_position = value

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
@onready var _free_run: FreeRun = $FreeRun
## Your two item slots (hands, back) and the item buttons.
@onready var items: ItemCarrier = $Items
@onready var _collision: CollisionShape3D = $CollisionShape3D
## The standing body shape, used to check "would I fit here?". Never resized.
@onready var _stand_shape: CapsuleShape3D = _collision.shape
@onready var body_radius: float = _stand_shape.radius

## Which states keep the body low.
const CROUCHED_STATES: Array[StringName] = [&"Crouch", &"Slide"]

## True while the body is shrunk down (crouching or sliding).
var is_crouched := false
## Sideways body lean in radians (wall running). Reset whenever the state changes.
var lean := 0.0
## The wall last jumped or run off. You can't use the same wall again until
## you land (so you can't climb a single wall forever). Zero = none.
var last_wall_normal := Vector3.ZERO
var wall_jump_velocity: float

## States you can toss a friend from.
const TOSS_STATES: Array[StringName] = [&"Ground", &"Air", &"Crouch", &"Slide"]
## Toss limits while in the air (see limit_tosses_per_air), refilled by
## refresh_air_moves(): you can toss once, and each person can toss you
## once. So two players can't juggle forever, but every extra friend adds
## another link to a throw chain.
var can_toss_in_air := true
## Names of the players (or "Buddy") who have tossed us this air time.
var tossed_by := PackedStringArray()
var _toss_cooldown_timer := 0.0
var _toss_recoil_velocity: float


func _enter_tree() -> void:
	# The player whose network id matches our name is in charge of us
	# (Godot calls this the "multiplayer authority").
	# (The practice buddy has no player of its own; this computer runs it.)
	if is_bot:
		set_multiplayer_authority(multiplayer.get_unique_id())
	else:
		set_multiplayer_authority(str(name).to_int())
	# ...except the HostSync node, which carries things only the host decides.
	$HostSync.set_multiplayer_authority(1)


func _ready() -> void:
	is_local = is_multiplayer_authority()
	add_to_group(&"players")
	_apply_color()

	apply_profile()

	for child in _states.get_children():
		var player_state := child as PlayerState
		player_state.player = self
		player_state.input = input
	_free_run.player = self
	_free_run.input = input
	items.player = self

	# Our own copy of the body shape, so crouching only shrinks *this* player.
	_collision.shape = _stand_shape.duplicate()

	respawn_position = global_position
	sync_position = global_position
	camera_rig.set_active(is_local and not is_bot)
	change_state(&"Air")


func _physics_process(delta: float) -> void:
	if not is_local:
		_follow_network(delta)
		return

	if is_bot:
		input.clear()
	else:
		input.gather(camera_rig.yaw)
		if input.free_run_held:
			_free_run.assist(delta)
	if input.jump_just_pressed:
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer -= delta

	_toss_cooldown_timer -= delta
	zipline_cooldown -= delta
	if input.toss_just_pressed:
		try_toss()

	state.physics_update(delta)
	_update_flow(delta)
	if not is_bot:
		items.physics_update(delta)

	if input.respawn_just_pressed or global_position.y < kill_height:
		respawn()

	_pose_visual(is_crouched, lean, delta)
	sync_position = global_position
	sync_facing = _visual.rotation.y
	sync_state = state.name
	sync_lean = lean
	sync_tossed_by = tossed_by


## Moves this puppet toward where its owner says it is.
func _follow_network(delta: float) -> void:
	if global_position.distance_to(sync_position) > puppet_teleport_distance:
		global_position = sync_position
		reset_physics_interpolation()
	else:
		var weight := 1.0 - exp(-puppet_smoothing * delta)
		global_position = global_position.lerp(sync_position, weight)
	_visual.rotation.y = lerp_angle(_visual.rotation.y, sync_facing, 1.0 - exp(-puppet_smoothing * delta))
	_pose_visual(sync_state in CROUCHED_STATES, sync_lean, delta)


## Squashes the body model down while crouched and leans it sideways while
## wall running (stand-ins until there are animations).
func _pose_visual(crouched: bool, lean_angle: float, delta: float) -> void:
	var weight := 1.0 - exp(-20.0 * delta)
	var target_scale := crouch_height / stand_height if crouched else 1.0
	_visual.scale.y = lerpf(_visual.scale.y, target_scale, weight)
	_visual.rotation.z = lerp_angle(_visual.rotation.z, lean_angle, weight)


## Switches to the state (child of the States node) with this name.
func change_state(state_name: StringName, data: Dictionary = {}) -> void:
	lean = 0.0
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
	set_crouched(false)
	change_state(&"Air")
	reset_physics_interpolation() # Teleport instantly instead of "sliding" there.
	respawned.emit()


func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


## Where an item you're holding sits: slot 0 (hands) in front of your chest,
## slot 1 on your back. Follows the way your body faces.
func item_anchor(slot: int) -> Transform3D:
	var body := Transform3D(_visual.global_basis.orthonormalized(), global_position)
	var offset := Vector3(0.3, 1.0, -0.6) if slot == 0 else Vector3(0.0, 1.15, 0.45)
	return body * Transform3D(Basis.IDENTITY, offset)


## The direction the camera is looking (for throwing items).
func aim_direction() -> Vector3:
	return Vector3.FORWARD.rotated(Vector3.RIGHT, camera_rig.pitch).rotated(Vector3.UP, camera_rig.yaw)


# --- Movement profile and flow ---------------------------------------------------

## Switches to a different set of movement numbers.
func set_profile(new_profile: MovementProfile) -> void:
	profile = new_profile
	apply_profile()


## Copies the numbers from `profile` and works out the physics that follow
## from them.
func apply_profile() -> void:
	for property in profile.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			set(property.name, profile.get(property.name))

	# Jump physics from designer-friendly numbers (height + timing).
	jump_velocity = 2.0 * jump_height / jump_time_to_peak
	_rise_gravity = 2.0 * jump_height / (jump_time_to_peak * jump_time_to_peak)
	_fall_gravity = 2.0 * jump_height / (jump_time_to_fall * jump_time_to_fall)
	wall_jump_velocity = sqrt(2.0 * _rise_gravity * wall_jump_height)
	_toss_recoil_velocity = sqrt(2.0 * _rise_gravity * toss_recoil_height)


## How fast you run right now: normal speed, rising to top speed with flow.
func top_speed() -> float:
	return lerpf(run_speed, flow_speed, flow)


## Flow builds while you keep moving at speed, and drains when you stop,
## let go of the controls, or crash into something.
func _update_flow(delta: float) -> void:
	if debug_full_flow:
		flow = 1.0
		return
	if state.name in [&"Climb", &"Zipline"]:
		return # A quick vault, a pull-up or a zipline ride doesn't break your flow.
	var pushing := input.move_direction.length() > 0.3
	var speed := get_horizontal_speed()
	if pushing and speed >= run_speed * 0.9:
		flow = minf(flow + delta / flow_build_time, 1.0)
	elif is_on_floor() and (not pushing or speed < run_speed * 0.5):
		# Only drains on the ground: bumping into a ledge mid-jump on your way
		# up onto it doesn't count as crashing.
		flow = maxf(flow - delta / flow_decay_time, 0.0)


## Turns the player's controls and camera on or off (e.g. while a menu is open).
func set_controls_enabled(enabled: bool) -> void:
	input.enabled = enabled
	camera_rig.controls_enabled = enabled


func _apply_color() -> void:
	# Each player gets their own copy of the material, so recolouring one
	# doesn't recolour everyone.
	var material := _body_mesh.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
	material.albedo_color = BUDDY_COLOR if is_bot else COLORS[color_index % COLORS.size()]
	_body_mesh.material_override = material


# --- Tossing friends -----------------------------------------------------------
#
# The thrower's computer picks a target and sends it a "you've been tossed"
# message (receive_toss). Only the target's own computer can move the target,
# so that's where the launch actually happens.

## Tosses the nearest friend in reach, if any. Returns true if someone was tossed.
func try_toss() -> bool:
	if state.name not in TOSS_STATES or _toss_cooldown_timer > 0.0:
		return false
	var airborne := state.name == &"Air"
	if airborne and limit_tosses_per_air and not can_toss_in_air:
		return false
	var target := find_toss_target()
	if target == null:
		return false

	_toss_cooldown_timer = toss_cooldown
	if target.is_multiplayer_authority():
		target.apply_toss(toss_velocity(camera_rig.yaw), str(name)) # Run by this computer (the practice buddy).
	else:
		target.receive_toss.rpc_id(target.get_multiplayer_authority(), toss_velocity(camera_rig.yaw))
	if airborne:
		# Pushing off your friend gives you a little hop: a co-op double jump.
		can_toss_in_air = false
		velocity.y = maxf(velocity.y, _toss_recoil_velocity)
	tossed_someone.emit(target)
	return true


## The closest other player within toss_range who isn't behind you and can be
## tossed right now, or null.
func find_toss_target() -> Player:
	var forward := Vector3.FORWARD.rotated(Vector3.UP, camera_rig.yaw)
	var best: Player = null
	var best_distance := INF
	for other in get_parent().get_children():
		var friend := other as Player
		if friend == null or friend == self or friend.is_queued_for_deletion():
			continue
		if limit_tosses_per_air and str(name) in friend.sync_tossed_by:
			continue # We've already tossed them this air time.
		var offset := friend.global_position - global_position
		var flat := Vector3(offset.x, 0.0, offset.z)
		if absf(offset.y) > toss_range or flat.length() > toss_range:
			continue
		if flat.length() > 0.3 and flat.normalized().dot(forward) < -0.2:
			continue # Behind you.
		if flat.length() < best_distance:
			best_distance = flat.length()
			best = friend
	return best


## The launch a toss gives, aimed with a camera facing `yaw`.
func toss_velocity(yaw: float) -> Vector3:
	var forward := Vector3.FORWARD.rotated(Vector3.UP, yaw)
	return forward * toss_forward_speed + Vector3.UP * sqrt(2.0 * _rise_gravity * toss_height)


## Sent by a thrower's computer to this character's owner.
@rpc("any_peer", "call_remote", "reliable")
func receive_toss(launch: Vector3) -> void:
	if not is_local:
		return
	# Sanity check: the thrower should be (roughly) next to us. Generous,
	# because their view of us is a fraction of a second old.
	var thrower := get_parent().get_node_or_null(str(multiplayer.get_remote_sender_id())) as Player
	if thrower == null or thrower.global_position.distance_to(global_position) > toss_range * 3.0:
		return
	apply_toss(launch, str(thrower.name))


## Launches this player (the receiving end of a toss from `thrower_name`).
func apply_toss(launch: Vector3, thrower_name: String = "") -> void:
	if limit_tosses_per_air and thrower_name in tossed_by:
		return
	if is_crouched:
		if not can_stand():
			return
		set_crouched(false)
	velocity = launch
	tossed_by.append(thrower_name)
	change_state(&"Air", {"control_lock": toss_control_lock})
	got_tossed.emit()


## Lets you toss and be tossed again. Called when you land, grab a ledge,
## or touch a wall.
func refresh_air_moves() -> void:
	can_toss_in_air = true
	tossed_by.clear()


# --- Helpers shared by the states --------------------------------------------

## True (once) if jump was pressed recently. Lets a slightly-early press count.
func consume_jump() -> bool:
	if _jump_buffer_timer > 0.0:
		_jump_buffer_timer = 0.0
		return true
	return false


## True if jump was pressed recently, without using it up.
func has_jump_buffered() -> bool:
	return _jump_buffer_timer > 0.0


func apply_gravity(delta: float) -> void:
	var gravity := _rise_gravity if velocity.y > 0.0 else _fall_gravity
	velocity.y = maxf(velocity.y - gravity * delta, -max_fall_speed)


## Speeds up toward the input direction (or slows down if there's no input).
## `max_speed` overrides the usual running speed (which grows with flow). With `keep_momentum`,
## going faster than that (e.g. jumping out of a slide) isn't slowed down while
## you keep pushing; you can still steer.
func move_horizontally(delta: float, acceleration: float, friction: float,
		max_speed: float = -1.0, keep_momentum: bool = false) -> void:
	var wish_dir := input.move_direction
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var target_speed := max_speed
	if target_speed < 0.0:
		target_speed = top_speed()
	if keep_momentum and wish_dir != Vector3.ZERO:
		target_speed = maxf(target_speed, horizontal.length())
	var rate := acceleration if wish_dir != Vector3.ZERO else friction
	horizontal = horizontal.move_toward(wish_dir * target_speed, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


## Shrinks the body (for crouching/sliding) or returns it to full height.
## Check can_stand() before standing up.
func set_crouched(crouched: bool) -> void:
	is_crouched = crouched
	var shape := _collision.shape as CapsuleShape3D
	shape.height = crouch_height if crouched else stand_height
	_collision.position.y = shape.height * 0.5


## True if there's room to stand up right here (always true if not crouched).
func can_stand() -> bool:
	return not is_crouched or _body_fits(global_position)


## Looks around the body (8 directions) for the closest wall within
## wall_detect_distance. With `tall_only`, the wall must also cover your knees
## and head (so blocks and low ledges don't count). Returns
## {"normal": flat direction out of the wall, "point": where it was hit},
## or an empty dictionary if there's no wall.
func find_wall(tall_only: bool = false) -> Dictionary:
	var reach := body_radius + wall_detect_distance
	var best := {}
	var best_distance := INF
	for i in 8:
		var direction := Vector3.FORWARD.rotated(Vector3.UP, i * TAU / 8.0)
		var hit := _wall_hit(global_position + Vector3.UP * 0.9, direction, reach)
		if hit.is_empty():
			continue
		if tall_only and (_wall_hit(global_position + Vector3.UP * 0.3, direction, reach).is_empty()
				or _wall_hit(global_position + Vector3.UP * 1.6, direction, reach).is_empty()):
			continue
		var distance: float = (hit.position - global_position).length()
		if distance < best_distance:
			best_distance = distance
			best = {"normal": hit.normal, "point": hit.position}
	return best


## True unless this is the wall you last jumped or ran off (see last_wall_normal).
func can_use_wall(wall_normal: Vector3) -> bool:
	return last_wall_normal == Vector3.ZERO or wall_normal.dot(last_wall_normal) < 0.7


## Kicks off a wall: away from it and upward, keeping any speed you had
## along it (`along`).
func wall_jump(wall_normal: Vector3, along: Vector3) -> void:
	velocity = along + wall_normal * wall_jump_push
	velocity.y = wall_jump_velocity
	last_wall_normal = wall_normal
	refresh_air_moves()
	change_state(&"Air", {"jumped": true, "control_lock": wall_jump_control_lock})


## True if there's ground within `distance` below your feet.
func is_near_ground(distance: float) -> bool:
	var from := global_position + Vector3.UP * 0.05
	return not raycast(from, from + Vector3.DOWN * (distance + 0.05)).is_empty()


func _wall_hit(from: Vector3, direction: Vector3, reach: float) -> Dictionary:
	var hit := raycast(from, from + direction * reach)
	if hit.is_empty() or absf(hit.normal.y) > 0.3:
		return {}
	hit.normal = Vector3(hit.normal.x, 0.0, hit.normal.z).normalized()
	return hit


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
		wall = raycast(from, from + forward * reach)
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
	var top := raycast(above, Vector3(above.x, feet.y + mantle_min_height, above.z))
	if top.is_empty() or top.normal.y < 0.7:
		return null # No flat top within reach.

	var ledge := Ledge.new()
	ledge.normal = wall_normal
	ledge.position = Vector3(wall.position.x, top.position.y, wall.position.z)
	ledge.height = ledge.position.y - feet.y

	# 3. Is there open space above the edge, room to pull up, and room to stand?
	var over_edge := ledge.position + wall_normal * reach + Vector3.UP * 0.15
	if not raycast(over_edge, over_edge - wall_normal * (reach + 0.3)).is_empty():
		return null # The wall keeps going up; that "top" was something else.
	var hang_column := hang_position(ledge)
	hang_column.y = ledge.position.y + 0.05
	if not _body_fits(hang_column):
		return null
	# No room to stand on top (e.g. a narrow sill): still fine to hang from.
	ledge.can_stand = _room_on_top(ledge) and _body_fits(stand_position(ledge))
	return ledge


## True if the top of the ledge is deep enough to stand on: nothing (like the
## wall a sill sticks out of) within a body's width behind the edge. (A plain
## line check, because a body-shape check can't tell when the body would be
## mostly inside a wall.)
func _room_on_top(ledge: Ledge) -> bool:
	var depth_needed := body_radius * 2.0 + 0.2
	for height: float in [0.3, 1.2]:
		var from := ledge.position + Vector3.UP * height + ledge.normal * 0.05
		if not raycast(from, from - ledge.normal * depth_needed).is_empty():
			return false
	return true


## While hanging from `ledge`, looks for another ledge above it that you can
## leap up to (within ledge_leap_height). Returns null if there isn't one.
func find_ledge_above(ledge: Ledge) -> Ledge:
	var hanging := hang_position(ledge)
	# Search as if standing high enough that the ledge we want is within reach:
	# first where we hang (finds sills sticking out like this one), then a bit
	# closer in (finds a plain wall top set back behind the sill).
	for step_in: float in [0.0, 0.6]:
		var search_feet := Vector3(hanging.x, ledge.position.y + ledge_leap_height - ledge_max_height, hanging.z) \
				- ledge.normal * step_in
		var above := find_ledge(search_feet, -ledge.normal)
		if above != null and above.position.y >= ledge.position.y + 1.0:
			return above
	return null


## A ray from `from` to `to` against the world (ignoring this player).
func raycast(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query)


## True if the player's body would fit with its feet at `feet` without
## overlapping the level.
func _body_fits(feet: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _stand_shape
	query.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * (_stand_shape.height * 0.5 + 0.02))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
