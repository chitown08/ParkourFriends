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
signal launched_off_ramp

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
## For the practice buddy: the player it ghost-runs with (free-running
## alongside them whenever they free-run, see _steer_ghost()), or null.
var ghost_of: Player
var respawn_position := Vector3.ZERO

# Sent from the controlling player's computer to everyone else (NetworkSync node).
var sync_position := Vector3.ZERO
var sync_facing := 0.0
var sync_state := &"Air"
var sync_lean := 0.0
## How readied a free-run leap is, 0..1 (the body squashes down).
var sync_leap_charge := 0.0
## Our velocity across the ground while free-running (zero otherwise), so
## friends free-running nearby can run with us as a pack (FreeRun._run_with_pack()).
## At our own pace: without the pack easing us faster or slower (otherwise
## two friends side by side would keep matching each other's eased-up pace,
## faster and faster).
var sync_free_run_velocity := Vector3.ZERO
## What this player is called (Settings.player_name), shown over their head.
var sync_player_name := "":
	set(value):
		sync_player_name = value
		if _name_tag:
			_name_tag.text = value
## The name of the friend we're hanging from (a hanging chain), or "".
var sync_hanging_on := ""
## The name of the friend whose shoulders we're bracing on (a leg-up stack), or "".
var sync_braced_on := ""
## The name of the friend whose hand we hold in a line (crack the whip), or "".
var sync_linked_to := ""
## A new number each time we start a move: which of its animations play (see
## CharacterModel: "vault", "vault-kong"...), so everyone sees the same one.
var sync_move := 0
## Who has tossed us this air time (see tossed_by).
var sync_tossed_by := PackedStringArray()
## What this player wears: an item name (or "" for nothing) for each slot in
## Cosmetics.SLOTS, in order. Chosen on the player's own computer and sent to
## everyone, so friends see it too.
var sync_outfit := PackedStringArray():
	set(value):
		sync_outfit = value
		if is_node_ready():
			_apply_outfit()

# The movement numbers actually in use, copied from `profile` (see
# apply_profile()). Documented in movement_profile.gd. Change them by editing a
# profile, not here.
var run_speed: float
var free_run_speed: float
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
var leap_height: float
var leap_boost: float
var leap_charge_time: float
var vault_max_height: float
var vault_max_depth: float
var vault_clearance: float
var vault_takeoff_time: float
## How readied the next jump's leap is (0 = a normal jump, 1 = a full leap).
## Set by free-run just before it takes off; used up by start_jump().
var pending_leap := 0.0
## Pack-running eases your top speed by this factor (1 = your own pace); set by free-run.
var pack_pace := 1.0
## Drafting: in a pack, your top speed goes up this much for each friend
## running with you (0.03 = 3%), and flow builds this much faster (0.5 = half
## again as fast)...
const DRAFT_SPEED := 0.03
const DRAFT_FLOW := 0.5
## ...counting at most this many friends.
const MOST_DRAFTING := 3
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
var wall_run_runway: float
var wall_scramble_speed: float
var wall_scramble_time: float
var pipe_climb_speed: float
var pipe_slide_speed: float
var pipe_grab_reach: float
var grind_gravity: float
var grind_min_speed: float
var grind_max_speed: float
var grind_climb_speed: float
var grind_climb_acceleration: float
var grind_land_radius: float
var grind_land_delay: float
var toss_range: float
var toss_height: float
var toss_forward_speed: float
var toss_recoil_height: float
var toss_control_lock: float
var toss_cooldown: float
var limit_tosses_per_air: bool
var leg_up_height: float

## How much flow (momentum) you've built up: 0 = normal running speed,
## 1 = top speed. See _update_flow().
var flow := 0.0
## Time left before you can land on a grind rail again (after leaving one).
var grind_cooldown := 0.0

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
var _outfit_index := 0
## The name over your head, for friends to see (not shown for your own).
var _name_tag: Label3D
## How high above your feet the name floats (metres).
const NAME_TAG_HEIGHT := 2.3

@onready var input: PlayerInput = $PlayerInput
@onready var camera_rig: CameraRig = $CameraRig
@onready var _visual: Node3D = $Visual
## The character model and its animations.
@onready var model: CharacterModel = $Visual/Model
@onready var _body_mesh: MeshInstance3D = model.body
@onready var _states: Node = $States
@onready var _free_run: FreeRun = $FreeRun
## Your two item slots (hands, back) and the item buttons.
@onready var items: ItemCarrier = $Items
@onready var _collision: CollisionShape3D = $CollisionShape3D
## The standing body shape, used to check "would I fit here?". Never resized.
@onready var _stand_shape: CapsuleShape3D = _collision.shape
@onready var body_radius: float = _stand_shape.radius

## True while the body is shrunk down (crouching or sliding).
var is_crouched := false
## Sideways body lean in radians (wall running, banking a glide). Reset whenever the state changes.
var lean := 0.0
## Which way your body's up is: straight up, except running round a tube
## (PipeRun), where it's in toward the tube's middle (the camera follows it).
## Reset whenever the state changes.
var body_up := Vector3.UP

# --- Looks: animations (see CharacterModel), plus squash and stretch, tilts and swings on top.
## States you're in the air in, and landing states (for the landing thud).
const AIRBORNE_STATES: Array[StringName] = [&"Air", &"Glide"]
const LANDED_STATES: Array[StringName] = [&"Ground", &"Crouch", &"Slide", &"Grind"]
## How far the body squashes down for a fully readied leap (0.25 = a quarter).
const LEAP_SQUASH := 0.28
## Landing faster than this (m/s) kicks up dust.
const DUST_LANDING_SPEED := 20.0
## Landing faster than this (m/s) from a standstill plays the landing animation.
const HARD_LANDING_SPEED := 12.0
## Seen moving faster than this (m/s), it was a teleport (a respawn), not a run.
const TELEPORT_SPEED := 60.0
## How far the body tips forward while gliding (radians).
const GLIDE_PITCH := deg_to_rad(-35.0) # (Negative tips forward.)
## A bat swing: how long it takes and the arc it sweeps (radians, around
## your body; the bat starts out behind your right shoulder).
const SWING_TIME := 0.22
const SWING_FROM := deg_to_rad(-120.0)
const SWING_TO := deg_to_rad(80.0)
const SWING_PIVOT := Vector3(0.0, 1.1, 0.0)
## How often sparks fly from your feet while grinding a rail (seconds).
const SPARK_INTERVAL := 0.06

var _stretch := 0.0 ## Squash (below 0) or stretch (above 0) of the body.
var _pitch := 0.0
var _shown_lean := 0.0
var _shown_state := &""
var _last_y := 0.0
var _last_position := Vector3.ZERO
var _ground_speed := 0.0 ## How fast you're seen moving across the ground (smoothed).
var _rising := false
var _fall_speed := 0.0
var _swing_timer := 0.0
var _flash := 0.0 ## Hit flash brightness, fading to 0.
var _spark_timer := 0.0
## Your height lately, for a delivery's style (see recent_peak()): [time, y] pairs.
var _heights: Array[Vector2] = []
var _clock := 0.0
## How far back recent_peak() looks (seconds).
const PEAK_WINDOW := 3.0
## The wall last jumped or run off. You can't use the same wall again until
## you land (so you can't climb a single wall forever). Zero = none.
var last_wall_normal := Vector3.ZERO
var wall_jump_velocity: float

## States that need your hands (not possible with a bulky item in them).
const HANDS_MOVES: Array[StringName] = [&"Hang", &"Climb", &"Vault", &"WallScramble", &"PipeClimb", &"ChainHang", &"ChainClimb", &"Brace", &"Linked", &"Whipped", &"Catch", &"Caught"]
## Hanging, from a ledge or from a friend: someone can hang from your feet.
const CHAIN_STATES: Array[StringName] = [&"Hang", &"ChainHang", &"Caught"]
## How far from a hanging friend's feet your hands can be to grab them.
const CHAIN_GRAB_REACH := 0.8
## Where a held item sits (see item_anchor): in front of your chest, or overhead.
const HAND_OFFSET := Vector3(0.3, 1.0, -0.6)
const OVERHEAD_OFFSET := Vector3(0.0, 2.1, 0.0)

## States you can toss a friend from.
const TOSS_STATES: Array[StringName] = [&"Ground", &"Air", &"Crouch", &"Slide", &"Grind"]
## Toss limits while in the air (see limit_tosses_per_air), refilled by
## refresh_air_moves(): you can toss once, and each person can toss you
## once. So two players can't juggle forever, but every extra friend adds
## another link to a throw chain.
var can_toss_in_air := true
## Names of the players (or "Buddy") who have tossed us this air time.
var tossed_by := PackedStringArray()
var _toss_cooldown_timer := 0.0
var _toss_recoil_velocity: float

## Leg-ups: a braced friend's cupped hands are this high above their feet, and
## a friend standing on their shoulders has their feet this high.
const BRACE_HANDS := 0.9
const BRACE_SHOULDERS := 1.5
## The most friends in one leg-up stack (the one at the wall and those on top).
const MOST_BRACED := 4
## How close (across) to a braced friend you must be to step into their hands
## (pressing jump), or to climb onto their shoulders (pressing toss).
const LEG_UP_REACH := 1.5
## Jumping into a braced friend (rather than pressing jump next to them): this
## close across, moving toward the wall at least this fast (m/s).
const LEG_UP_CATCH := 1.0
const LEG_UP_CATCH_SPEED := 1.0
## How hard a leg-up's launch presses you toward the wall (m/s).
const LEG_UP_PUSH := 2.0
## After a leg-up launch, you can't step into another for this long (seconds):
## you'd be caught again by the same hands.
const LEG_UP_COOLDOWN := 0.5
var _leg_up_cooldown_timer := 0.0
## States you can step into a leg-up from.
const LEG_UP_STATES: Array[StringName] = [&"Ground", &"Air", &"Slide"]


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
	_make_name_tag()
	if is_local and not is_bot:
		# You: your name and outfit, from your settings, sent to everyone.
		sync_player_name = Settings.player_name if Settings.player_name else "Player"
		sync_outfit = Cosmetics.tidy(Settings.outfit)
	elif is_bot:
		sync_player_name = "Buddy"
	_apply_color()
	_apply_outfit()

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
		_steer_ghost(delta)
	else:
		input.gather(camera_rig.yaw)
	if input.free_run_held and state.name not in LINED_UP:
		_free_run.assist(delta)
	else:
		_free_run.readying_leap = false
		_free_run.pack_size = 0
		pack_pace = 1.0
	if input.jump_just_pressed:
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer -= delta

	_toss_cooldown_timer -= delta
	_rally_cooldown -= delta
	if input.rally_just_pressed and _rally_cooldown <= 0.0:
		_rally_cooldown = RALLY_COOLDOWN
		show_effect(&"show_rally", [])
	_leg_up_cooldown_timer -= delta
	catch_cooldown -= delta
	grind_cooldown -= delta
	if input.toss_just_pressed:
		# With nobody to toss, the toss button braces you for a leg-up (or stops).
		# In a pack, it takes a friend's hand (crack the whip).
		if state.name in [&"Brace", &"Linked"]:
			state.let_go()
		elif not try_link() and not try_toss():
			try_brace()

	if hands_busy() and state.name in HANDS_MOVES:
		# A bulky item just landed in your hands (a catch or a swap): let go.
		grind_cooldown = 0.5
		change_state(&"Air", {"regrab_delay": 0.5})
	if state.name in LEG_UP_STATES:
		_try_leg_up()
	if state.name in [&"Ground", &"Slide"]:
		_try_crack_whip()
	if state.name in CATCH_FROM:
		_try_catch()
	state.physics_update(delta)
	_update_flow(delta)
	if not is_bot:
		items.physics_update(delta)

	if input.respawn_just_pressed or global_position.y < kill_height:
		respawn()

	sync_leap_charge = _free_run.leap_charge()
	_pose_visual(state.name, lean, sync_leap_charge, delta)
	sync_position = global_position
	sync_facing = _visual.rotation.y
	sync_state = state.name
	sync_lean = lean
	sync_tossed_by = tossed_by
	var free_running := input.free_run_held and state.name not in LINED_UP # (Holding hands, you're carried.)
	sync_free_run_velocity = Vector3(velocity.x, 0.0, velocity.z) / pack_pace if free_running else Vector3.ZERO


## The ghost runner wanders this far either side of your heading (degrees)...
var ghost_wander_degrees := 15.0
## ...once every this many seconds, so you feel the pack pull you.
const GHOST_WANDER_PERIOD := 12.0
## It also heads this far off your heading besides (degrees, + is left).
var ghost_turn_degrees := 0.0
## Further than this from you (metres), it catches up: it appears beside you.
const GHOST_CATCH_UP := 20.0
## How far beside you it appears.
const GHOST_SIDE := 2.0
var _ghost_time := 0.0


## The practice buddy as a ghost runner: it free-runs whenever the player it
## runs with (ghost_of) does, heading roughly their way but wandering a
## little, so it's a pack of two. Fall far behind (or off a roof) and it
## appears beside them again.
func _steer_ghost(delta: float) -> void:
	if not is_instance_valid(ghost_of) or not ghost_of.input.free_run_held:
		return
	_ghost_time += delta
	var wander := ghost_wander_degrees * sin(TAU * _ghost_time / GHOST_WANDER_PERIOD)
	input.free_run_held = true
	input.move_direction = Vector3.FORWARD.rotated(Vector3.UP, ghost_of.camera_rig.yaw + deg_to_rad(wander + ghost_turn_degrees))
	if global_position.distance_to(ghost_of.global_position) > GHOST_CATCH_UP and ghost_of.is_on_floor():
		var right := Vector3.RIGHT.rotated(Vector3.UP, ghost_of.camera_rig.yaw)
		for side: Vector3 in [right, -right]:
			var spot := ghost_of.global_position + side * GHOST_SIDE + Vector3.UP * 0.05
			if body_fits(spot) and not raycast(spot, spot + Vector3.DOWN).is_empty():
				set_checkpoint(spot)
				respawn()
				velocity = ghost_of.velocity
				return


## Moves this puppet toward where its owner says it is.
func _follow_network(delta: float) -> void:
	if global_position.distance_to(sync_position) > puppet_teleport_distance:
		global_position = sync_position
		reset_physics_interpolation()
	else:
		var weight := 1.0 - exp(-puppet_smoothing * delta)
		global_position = global_position.lerp(sync_position, weight)
	_visual.rotation.y = lerp_angle(_visual.rotation.y, sync_facing, 1.0 - exp(-puppet_smoothing * delta))
	_pose_visual(sync_state, sync_lean, sync_leap_charge, delta)


## Poses the body model (stand-ins until there are animations): squashed down
## while crouched or readying a leap, stretched by a jump, squashed by a
## landing, leaning sideways on a wall run or a glide's turns, tipped forward
## while gliding. Runs on everyone's computer, from what they know of us.
func _pose_visual(shown_state: StringName, lean_angle: float, leap_charge: float, delta: float) -> void:
	_clock += delta
	if _heights.is_empty() or _clock - _heights.back().x >= 0.1:
		_heights.append(Vector2(_clock, global_position.y))
	while _heights.size() > 1 and _clock - _heights[0].x > PEAK_WINDOW:
		_heights.pop_front()
	_show_rally_beam(delta)
	_watch_for_landing(shown_state, delta)
	var moved := (global_position - _last_position).slide(Vector3.UP).length() / maxf(delta, 0.001)
	if moved > TELEPORT_SPEED:
		moved = 0.0
	_last_position = global_position
	_ground_speed = lerpf(_ground_speed, moved, 1.0 - exp(-12.0 * delta))
	model.animate(shown_state, _ground_speed, _rising, lean_angle, not sync_tossed_by.is_empty(), hands_busy(), delta, sync_move)
	_swing_timer -= delta
	_spark_timer -= delta
	if shown_state == &"Grind" and _spark_timer <= 0.0:
		_spark_timer = SPARK_INTERVAL
		Effects.burst(self, global_position, Effects.SPARK, 4, 4.0, true)
	_flash = move_toward(_flash, 0.0, 4.0 * delta)
	var material := _body_mesh.material_override as StandardMaterial3D
	material.emission_enabled = _flash > 0.0
	material.emission = Color.WHITE
	material.emission_energy_multiplier = _flash * 2.0

	var weight := 1.0 - exp(-20.0 * delta)
	_stretch = lerpf(_stretch, -LEAP_SQUASH * leap_charge, 1.0 - exp(-10.0 * delta))
	_pitch = lerpf(_pitch, GLIDE_PITCH if shown_state == &"Glide" else 0.0, 1.0 - exp(-8.0 * delta))
	_shown_lean = lerp_angle(_shown_lean, lean_angle, weight)

	# Squash and stretch keep the body's volume: shorter means wider.
	var wide := 1.0 / sqrt(1.0 + _stretch)
	var size := Vector3(wide, 1.0 + _stretch, wide)
	var yaw := _visual.rotation.y
	var tilted := Basis.from_euler(Vector3(_pitch, yaw, _shown_lean))
	var upright := Basis.from_euler(Vector3(0.0, yaw, _shown_lean))
	# Tip forward around the middle of the body (not the feet).
	var middle := Vector3(0.0, 0.5 * stand_height * size.y, 0.0)
	_visual.transform = Transform3D(tilted * Basis.from_scale(size), upright * middle - tilted * middle)


## Squash and thud when landing (from a fall or a jump).
func _watch_for_landing(shown_state: StringName, delta: float) -> void:
	var rising_speed := (global_position.y - _last_y) / maxf(delta, 0.001)
	_rising = rising_speed > 0.5
	_last_y = global_position.y
	if shown_state != _shown_state:
		if _shown_state in AIRBORNE_STATES and shown_state in LANDED_STATES:
			_landed(_fall_speed)
		elif shown_state == &"Glide":
			Sfx.play(self, global_position, &"glide", -6.0)
		_shown_state = shown_state
	if shown_state in AIRBORNE_STATES:
		_fall_speed = -rising_speed


func _landed(speed: float) -> void:
	if speed < 2.0:
		return
	if speed > HARD_LANDING_SPEED and _ground_speed < 3.0:
		model.play_landing()
	_stretch = -clampf(speed / 50.0, 0.06, 0.35)
	Sfx.play(self, global_position, &"land", linear_to_db(clampf(speed / 25.0, 0.2, 1.0)) - 4.0)
	if speed > DUST_LANDING_SPEED:
		Effects.burst(self, global_position, Effects.DUST, 14, 4.0)


## Plays a jump on everyone's screen: a stretch and a sound, and for a free-run
## leap (`leap` 0..1) a bigger whoosh and a puff of dust.
@rpc("authority", "call_local", "unreliable")
func show_jump(leap: float) -> void:
	_stretch = 0.12 + 0.18 * leap
	if leap > 0.0:
		Sfx.play(self, global_position, &"leap", -6.0 + 4.0 * leap)
		Effects.burst(self, global_position, Effects.DUST, 10 + int(10 * leap), 3.0 + 3.0 * leap)
		if leap > 0.5:
			model.play_leap() # (A flip, a twist... if there are leap animations.)
	else:
		Sfx.play(self, global_position, &"jump", -10.0)


## Plays a bat swing on everyone's screen, and what it hit: `hit` is the
## friend's node name, "item", or "" for a miss; `at` is where it connected.
@rpc("authority", "call_local", "unreliable")
func show_swing(hit: String, at: Vector3) -> void:
	_swing_timer = SWING_TIME
	model.play_action(&"swing")
	if hit.is_empty():
		Sfx.play(self, global_position + Vector3.UP, &"swing", -4.0)
		return
	Sfx.play(self, at, &"whack")
	Effects.burst(self, at, Effects.POP, 18, 7.0, true)
	var friend := get_parent().get_node_or_null(hit) as Player
	if friend:
		friend.flash()


## Plays a one-off move (`throw`, `toss`) on everyone's screen.
@rpc("authority", "call_local", "unreliable")
func show_action(animation: StringName) -> void:
	model.play_action(animation)


## Flashes the body white for a moment (just got hit).
func flash() -> void:
	_flash = 1.0


## Calls an effect (show_jump, show_swing, show_action) on everyone's computer. (The practice
## buddy only exists on this computer, so its effects stay here.)
func show_effect(effect: StringName, args: Array) -> void:
	if is_bot:
		callv(effect, args)
	else:
		callv(&"rpc", [effect] + args)


## Switches to the state (child of the States node) with this name.
func change_state(state_name: StringName, data: Dictionary = {}) -> void:
	lean = 0.0
	body_up = Vector3.UP
	if state:
		state.exit()
	state = _states.get_node(NodePath(state_name))
	if is_local:
		sync_move = randi() % 1000
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


## True while a bulky item (e.g. a glider) is in your hands: no climbing.
## How many friends are pack-running with you right now.
func pack_size() -> int:
	return _free_run.pack_size


func hands_busy() -> bool:
	return not is_bot and items.hands_busy()


## Where an item you're holding sits: in front of your chest (bulky items like
## the glider are held overhead). Follows the way your body faces and tilts.
func item_anchor(overhead := false) -> Transform3D:
	var body := _visual.global_transform.orthonormalized()
	var offset: Vector3 = OVERHEAD_OFFSET if overhead else HAND_OFFSET
	if not overhead and _swing_timer > 0.0:
		# Mid-swing: the item sweeps round in an arc, fast at first.
		var swung := ease(1.0 - _swing_timer / SWING_TIME, 0.4)
		var arc := Basis(Vector3.UP, lerpf(SWING_FROM, SWING_TO, swung))
		return body * Transform3D(arc, SWING_PIVOT) * Transform3D(Basis.IDENTITY, offset - SWING_PIVOT)
	var anchor := body * Transform3D(Basis.IDENTITY, offset)
	if overhead:
		# Keep a wing fairly level when you tip forward to glide (but bank with you).
		anchor.basis = Basis.from_euler(Vector3(_pitch * 0.3, _visual.rotation.y, _shown_lean))
	return anchor


## The flat direction your body is facing.
func facing_direction() -> Vector3:
	return -_visual.global_basis.z.slide(Vector3.UP).normalized()


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
	if model:
		model.climb_up_time = climb_up_time
		model.mantle_time = mantle_time


## How fast you run right now: running speed, or free-running (holding Shift)
## speed rising to top speed with flow (after you let go of Shift, flow
## drains and you ease back down), eased by pack-running (unless `paced` is false).
func top_speed(paced := true) -> float:
	var base := free_run_speed if input.free_run_held else run_speed
	return lerpf(base, flow_speed * drafting(pack_size()), flow) * (pack_pace if paced else 1.0)


## How much a pack with `friends` friends (besides you) raises your top speed
## (1 = not at all). Also used by the reachability checker (rules/jump.gd).
static func drafting(friends: int) -> float:
	return 1.0 + DRAFT_SPEED * mini(friends, MOST_DRAFTING)


## Flow builds while you keep moving at speed (faster in a pack: drafting),
## and drains when you stop, let go of the controls, or crash into something.
func _update_flow(delta: float) -> void:
	if debug_full_flow:
		flow = 1.0
		return
	if state.name in [&"Climb", &"Vault", &"Grind", &"PipeRun", &"PipeClimb", &"ChainHang", &"Caught", &"ChainClimb", &"LegUp", &"Linked", &"Whip", &"Whipped"]:
		return # A vault, a pull-up, a drainpipe or a rail grind doesn't break your flow.
	if not input.free_run_held:
		# Flow is free-running's: without it you ease back down to running speed.
		flow = maxf(flow - delta / flow_decay_time, 0.0)
		return
	var pushing := input.move_direction.length() > 0.3
	var speed := get_horizontal_speed()
	if pushing and speed >= free_run_speed * minf(pack_pace, 1.0) * 0.9:
		var draft := 1.0 + DRAFT_FLOW * mini(pack_size(), MOST_DRAFTING)
		flow = minf(flow + delta / flow_build_time * draft, 1.0)
	elif is_on_floor() and (not pushing or speed < free_run_speed * 0.5):
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
	if _name_tag:
		_name_tag.modulate = material.albedo_color.lightened(0.5)


## The name tag over your head: the same size on screen however far away you
## are, and seen through walls, so you can find each other.
func _make_name_tag() -> void:
	_name_tag = Label3D.new()
	_name_tag.name = "NameTag"
	_name_tag.text = sync_player_name
	_name_tag.position = Vector3.UP * NAME_TAG_HEIGHT
	_name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_tag.fixed_size = true
	_name_tag.pixel_size = 0.0006
	_name_tag.font_size = 40
	_name_tag.outline_size = 12
	_name_tag.no_depth_test = true
	_name_tag.visible = not (is_local and not is_bot)
	add_child(_name_tag)


func _apply_outfit() -> void:
	for i in Cosmetics.SLOTS.size():
		model.wear(Cosmetics.SLOTS[i], sync_outfit[i] if i < sync_outfit.size() else "")


## Until the mall opens: puts on the next outfit (the next item in every slot
## at once), then nothing, and round again.
func next_outfit() -> void:
	var outfits := 0
	for slot in Cosmetics.SLOTS:
		outfits = maxi(outfits, Cosmetics.available(slot).size())
	_outfit_index = (_outfit_index + 1) % (outfits + 1)
	var outfit := PackedStringArray()
	for slot in Cosmetics.SLOTS:
		var items := Cosmetics.available(slot)
		outfit.append("" if _outfit_index == 0 or items.is_empty() else items[mini(_outfit_index - 1, items.size() - 1)])
	sync_outfit = outfit


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
	launch_friend(target, toss_velocity(camera_rig.yaw))
	show_effect(&"show_action", [&"toss"])
	if airborne:
		# Pushing off your friend gives you a little hop: a co-op double jump.
		can_toss_in_air = false
		velocity.y = maxf(velocity.y, _toss_recoil_velocity)
	tossed_someone.emit(target)
	return true


## Sends `target` flying with velocity `launch` (a toss, a bat hit, ...). It
## counts as a link in a throw chain: you can launch each friend once per air time.
func launch_friend(target: Player, launch: Vector3) -> void:
	if target.is_multiplayer_authority():
		target.apply_toss(launch, str(name)) # Run by this computer (the practice buddy).
	else:
		target.receive_toss.rpc_id(target.get_multiplayer_authority(), launch)


## The closest other player within `reach` (default: toss_range) who isn't
## behind you and can be launched right now, or null.
func find_toss_target(reach := -1.0) -> Player:
	if reach < 0.0:
		reach = toss_range
	var forward := Vector3.FORWARD.rotated(Vector3.UP, camera_rig.yaw)
	var best: Player = null
	var best_distance := INF
	for other in get_parent().get_children():
		var friend := other as Player
		if friend == null or friend == self or friend.is_queued_for_deletion():
			continue
		if friend.sync_state in [&"Brace", &"LegUp"]:
			continue # Braced for a leg-up (pressing toss beside them joins in).
		if friend.sync_state in LINED_UP or friend.sync_state == &"Whip":
			continue # Holding hands in a line.
		if limit_tosses_per_air and str(name) in friend.sync_tossed_by:
			continue # We've already tossed them this air time.
		var offset := friend.global_position - global_position
		var flat := Vector3(offset.x, 0.0, offset.z)
		if absf(offset.y) > reach or flat.length() > reach:
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


# --- Leg-ups ---------------------------------------------------------------------
#
# A friend braces at the foot of a wall (Brace state: back to it, hands
# cupped); more friends can climb onto their shoulders and brace there too. You
# jump into them and step up the stack (LegUp state) to be launched up the
# wall from the top one's hands. Your computer decides, from what it knows of
# them (sync_state, sync_braced_on), so nothing needs sending.

## Toss pressed with nobody to toss: brace for a leg-up. Beside a braced
## friend, you climb onto the shoulders of the top one of their stack;
## otherwise you brace with your back to the wall you're next to. Returns true
## if you're bracing.
func try_brace() -> bool:
	if state.name not in [&"Ground", &"Crouch"] or hands_busy():
		return false
	var base := _find_braced_friend(LEG_UP_REACH)
	if base:
		var stack := base.brace_stack()
		var shoulders: Vector3 = stack.back().global_position + Vector3.UP * BRACE_SHOULDERS
		if stack.size() >= MOST_BRACED or not body_fits(shoulders):
			return false
		change_state(&"Brace", {"on": stack.back(), "wall_normal": base.facing_direction()})
		return true
	return brace_at_wall()


## Braces with your back to the tall wall you're next to, if any.
func brace_at_wall() -> bool:
	var wall := find_wall(true)
	if wall.is_empty():
		return false
	change_state(&"Brace", {"wall_normal": wall.normal, "wall_point": wall.point})
	return true


## A braced friend's leg-up stack, from them up: them, the friend on their
## shoulders, the friend on theirs...
func brace_stack() -> Array[Player]:
	var stack: Array[Player] = [self]
	while stack.size() < MOST_BRACED * 2:
		var above: Player = null
		for other in get_parent().get_children():
			if other is Player and not other in stack and other.sync_state == &"Brace" and other.sync_braced_on == str(stack.back().name):
				above = other
		if above == null:
			break
		stack.append(above)
	return stack


## The nearest friend bracing at the foot of a wall (not on someone's
## shoulders), within `reach` across and about level with your feet, or null.
func _find_braced_friend(reach: float) -> Player:
	var best: Player = null
	var best_distance := INF
	for other in get_parent().get_children():
		var friend := other as Player
		if friend == null or friend == self or friend.sync_state != &"Brace" or friend.sync_braced_on != "":
			continue
		var offset := global_position - friend.global_position
		var across := Vector2(offset.x, offset.z).length()
		if across <= reach and absf(offset.y) < 0.5 and across < best_distance:
			best = friend
			best_distance = across
	return best


## Steps into a braced friend's leg-up: pressing jump beside them, or jumping
## into them (moving toward their wall), while pushing toward the wall.
func _try_leg_up() -> void:
	if _leg_up_cooldown_timer > 0.0:
		return
	var jumping := has_jump_buffered()
	for other in get_parent().get_children():
		var friend := other as Player
		if friend == null or friend == self or friend.sync_state != &"Brace" or friend.sync_braced_on != "":
			continue
		var wall_out := friend.facing_direction() # (They face away from the wall.)
		if input.move_direction.dot(-wall_out) < 0.5:
			continue
		var offset := global_position - friend.global_position
		var across := Vector2(offset.x, offset.z).length()
		var hands: float = friend.brace_stack().back().global_position.y + BRACE_HANDS
		if offset.y < -0.5 or global_position.y > hands + stand_height:
			continue # Below them, or already above the top of the stack.
		var closing := -Vector3(velocity.x, 0.0, velocity.z).dot(wall_out)
		var caught := state.name == &"Air" and across <= LEG_UP_CATCH and closing >= LEG_UP_CATCH_SPEED
		if (jumping and across <= LEG_UP_REACH) or caught:
			if jumping:
				consume_jump()
			change_state(&"LegUp", {"base": friend})
			return


## The end of a leg-up: launched leg_up_height up from the hands you're
## standing in, pressing toward the wall (so you scramble up it).
func leg_up_launch(toward_wall: Vector3) -> void:
	velocity = toward_wall * LEG_UP_PUSH + Vector3.UP * sqrt(2.0 * _rise_gravity * leg_up_height)
	last_wall_normal = Vector3.ZERO
	_leg_up_cooldown_timer = LEG_UP_COOLDOWN
	refresh_air_moves()
	change_state(&"Air")
	show_effect(&"show_jump", [1.0])


# --- Crack the whip -------------------------------------------------------------
#
# Free-running in a pack, the toss button takes the nearest friend's hand: you
# join the end of their line (Linked state), in a row across the way the
# leader (the one at the other end) runs. The leader turns hard their own way
# and the whip cracks: they pivot (Whip), the line swings a quarter turn round
# them (Whipped), and each is let go faster the further out they are; the end
# one is flung off into the air. Each computer decides for its own player from
# what it knows of the others (sync_state, sync_linked_to).

## Room between friends in a line (metres).
const LINK_SPACING := 1.2
## How close (across) a friend must be for you to take their hand.
const LINK_REACH := 4.0
## Pulled this far from your spot in the line, you let go (snagged).
const LINK_BREAK := 3.0
## The most players in one line (the leader too).
const MOST_IN_LINE := 6
## The leader cracks the whip by steering at least this far their own way
## (degrees off the way they run)...
const WHIP_TURN_DEGREES := 60.0
## ...running at least this fast (a fraction of run speed).
const WHIP_MIN_SPEED := 0.8
## How long the line takes to swing round (seconds).
const WHIP_TIME := 0.4
## Each place out from the leader, you're let go this much faster (0.3 = 30%
## faster than you were running).
const WHIP_GAIN := 0.3
## The end one, flung off, can't steer for this long (seconds).
const WHIP_LOCK := 0.3
## States of everyone in a line but the leader.
const LINED_UP: Array[StringName] = [&"Linked", &"Whipped"]
## States a line's leader can be in (any other and the line lets go).
const LEADING: Array[StringName] = [&"Ground", &"Air", &"Slide", &"Crouch", &"Whip"]


## The friend whose hand you hold (in toward the leader), or null.
func linked_inside() -> Player:
	return null if sync_linked_to == "" else get_parent().get_node_or_null(sync_linked_to) as Player


## The friend holding your hand from further out, or null.
func linked_outside() -> Player:
	for other in get_parent().get_children():
		if other is Player and other != self and other.sync_linked_to == str(name) and other.sync_state in LINED_UP:
			return other
	return null


## The leader of the line you're in (yourself if you aren't holding anyone's hand).
func line_leader() -> Player:
	var at: Player = self
	for i in MOST_IN_LINE * 2:
		var inside := at.linked_inside()
		if inside == null:
			break
		at = inside
	return at


## Your line, from the leader out to the end (just you, if you're in none).
func line() -> Array[Player]:
	var all: Array[Player] = [line_leader()]
	while all.size() < MOST_IN_LINE * 2:
		var outside := all.back().linked_outside() as Player
		if outside == null or outside in all:
			break
		all.append(outside)
	return all


## True if nobody holds your hand from further out.
func is_line_end() -> bool:
	return linked_outside() == null


## How much faster than you ran you're let go by the whip, `place` places
## out from the leader. Also used by the reachability checker (rules/whip.gd).
static func whip_boost(place: int) -> float:
	return 1.0 + WHIP_GAIN * place


## Toss pressed while free-running in a pack: takes the nearest friend's hand,
## joining the end of their line. (The practice buddy takes yours instead.)
## Returns true if you did.
func try_link() -> bool:
	var best := link_candidate()
	if best == null:
		return false
	var mine := line()
	var theirs := best.line()
	if best.is_bot and best.is_multiplayer_authority() and theirs.size() == 1:
		best.join_line(mine.back()) # Practice: the buddy takes your hand.
	else:
		join_line(theirs.back())
	return true


## The friend whose hand the toss button would take right now (see try_link()), or null.
func link_candidate() -> Player:
	if state.name not in [&"Ground", &"Slide"] or pack_size() == 0 or hands_busy():
		return null
	var mine := line()
	var best: Player = null
	var best_distance := INF
	for other in get_parent().get_children():
		var friend := other as Player
		if friend == null or friend in mine or friend.sync_state not in [&"Ground", &"Slide", &"Linked"]:
			continue
		if friend.sync_state != &"Linked" and friend.sync_free_run_velocity.length() < 1.0:
			continue # Not running with you.
		var offset := friend.global_position - global_position
		var across := Vector2(offset.x, offset.z).length()
		if across <= LINK_REACH and absf(offset.y) < 1.5 and across < best_distance:
			best = friend
			best_distance = across
	if best == null:
		return null
	var theirs := best.line()
	if best.is_bot and best.is_multiplayer_authority() and theirs.size() == 1:
		return best if mine.size() < MOST_IN_LINE else null
	if mine.size() > 1 or theirs.size() >= MOST_IN_LINE:
		return null # You lead a line already, or theirs is full.
	return best


## Takes `inside`'s hand: you run beside them, on the far side from the leader
## (or, beside the leader, on whichever side you're on).
func join_line(inside: Player) -> void:
	var leader := inside.line_leader()
	var right := leader.facing_direction().cross(Vector3.UP).normalized()
	var from := global_position if inside == leader else inside.global_position
	var side := 1.0 if (from - leader.global_position).dot(right) >= 0.0 else -1.0
	change_state(&"Linked", {"inside": inside, "side": side})


## Leading a line, running: steer hard your own way (away from the line) and
## the whip cracks.
func _try_crack_whip() -> void:
	if sync_linked_to != "":
		return
	var follower := linked_outside()
	if follower == null or follower.sync_state != &"Linked":
		return
	var going := Vector3(velocity.x, 0.0, velocity.z)
	var steer := Vector3(input.move_direction.x, 0.0, input.move_direction.z)
	if going.length() < free_run_speed * WHIP_MIN_SPEED or steer.length() < 0.5:
		return
	var right := going.normalized().cross(Vector3.UP)
	var turn_to := -right * signf((follower.global_position - global_position).dot(right))
	if steer.normalized().dot(turn_to) >= sin(deg_to_rad(WHIP_TURN_DEGREES)):
		change_state(&"Whip", {"turn_to": turn_to})


## The end of the whip's swing: let go going `speed` along `across`; the one
## on the end (`flung`) goes up into the air too, as high as a full leap.
func whip_release(across: Vector3, speed: float, flung: bool) -> void:
	velocity.x = across.x * speed
	velocity.z = across.z * speed
	if flung:
		velocity.y = sqrt(2.0 * _rise_gravity * leap_height)
		refresh_air_moves()
		change_state(&"Air", {"control_lock": WHIP_LOCK})
		show_effect(&"show_jump", [1.0])
	else:
		change_state(&"Ground" if is_on_floor() else &"Air")


## Lets you toss and be tossed again. Called when you land, grab a ledge,
## or touch a wall.
func refresh_air_moves() -> void:
	can_toss_in_air = true
	tossed_by.clear()


# --- Catching friends ------------------------------------------------------------
# Stand at an edge, and a friend falling short of it is caught: you reach down
# and grab them (Catch), and they hang from your hands (Caught) right at the
# edge, as if they'd grabbed it, to climb up (or for more friends to hang
# below them). Nothing to press: the one falling decides, on their computer,
# seeing where you stand (find_catcher()); yours sees them hanging from you.

## How far out from the wall a falling friend's hands can be for you to catch
## them, and how far below the edge (metres).
const CATCH_OUT := 1.5
const CATCH_DOWN := 2.0
## How far back from the edge you can stand and still catch someone.
const CATCH_EDGE := 1.5
## Just caught, your friend still looks to be standing about for this long
## (seconds) before their computer says they're catching you.
const CATCH_GRACE := 0.5
## After letting go of a catch (either of you), no catching again for this long.
const CATCH_COOLDOWN := 0.6
## States you can catch from: standing at the edge.
const CATCH_FROM: Array[StringName] = [&"Ground", &"Crouch"]
var catch_cooldown := 0.0


## A friend at an edge who can catch you, falling short of it, right now:
## {"catcher": them, "spot": where your feet hang from the edge, "toward_wall": ...},
## or an empty dictionary.
func find_catcher() -> Dictionary:
	var hands := global_position + Vector3.UP * hang_height
	var taken := {}
	for other in get_parent().get_children():
		if other is Player:
			taken[other.sync_hanging_on] = true
	for other in get_parent().get_children():
		if other == self or not other is Player or not other.sync_state in CATCH_FROM \
				or taken.has(str(other.name)) or other.hands_busy():
			continue
		var edge_y: float = other.global_position.y
		if hands.y > edge_y + 0.2 or hands.y < edge_y - CATCH_DOWN:
			continue # Not below their edge (you'd land), or too far down.
		var toward: Vector3 = other.global_position - global_position
		toward.y = 0.0
		if toward.length() > CATCH_OUT + CATCH_EDGE + body_radius:
			continue
		toward = toward.normalized()
		# The wall under their edge, between you.
		var from := Vector3(global_position.x, edge_y - 0.3, global_position.z)
		var wall := raycast(from, from + toward * (CATCH_OUT + body_radius))
		if wall.is_empty() or absf((wall.normal as Vector3).y) > 0.3:
			continue
		var normal := Vector3(wall.normal.x, 0.0, wall.normal.z).normalized()
		var at_edge := Vector3(wall.position.x, edge_y, wall.position.z)
		var back: Vector3 = other.global_position - at_edge
		back.y = 0.0
		if back.length() > CATCH_EDGE or (other as Player).facing_direction().dot(normal) < 0.3:
			continue # Not at the edge, or not facing out over it.
		if Vector3(velocity.x, 0.0, velocity.z).dot(normal) > 1.0:
			continue # Heading away (dropping off on purpose).
		return {"catcher": other, "spot": at_edge + normal * (body_radius + 0.05) + Vector3.DOWN * hang_height, "toward_wall": -normal}
	return {}


## True if you've caught a friend (they hang from your hands).
func someone_caught() -> bool:
	for other in get_parent().get_children():
		if other != self and other is Player and other.sync_state == &"Caught" and other.sync_hanging_on == str(name):
			return true
	return false


## Starts catching if a friend has just been caught by you.
func _try_catch() -> void:
	if catch_cooldown <= 0.0 and someone_caught():
		change_state(&"Catch")


## The top of a hanging chain: hanging from a ledge, or caught by a friend at it.
func is_chain_top() -> bool:
	return sync_state in [&"Hang", &"Caught"]


# --- Rally call ----------------------------------------------------------------------
# Q / LB: you whistle "over here!" and for a while friends can see where you
# are, wherever they are: a beam of light in your colour rising from you
# (seen through buildings), and an arrow at the edge of their screen (the HUD).

## How long a rally call shows (seconds), and how soon you can call again.
const RALLY_TIME := 6.0
const RALLY_COOLDOWN := 2.0
## The beam: this tall, this wide.
const RALLY_BEAM_HEIGHT := 60.0
const RALLY_BEAM_RADIUS := 0.25

## Time left on your rally call (on every computer: see show_rally()).
var rally_timer := 0.0
var _rally_cooldown := 0.0
var _rally_beam: MeshInstance3D


## Plays a rally call on everyone's screen.
@rpc("authority", "call_local", "reliable")
func show_rally() -> void:
	rally_timer = RALLY_TIME
	Sfx.play(self, global_position + Vector3.UP * 1.6, &"rally", 4.0)
	if model.has_move(&"wave"):
		model.play_action(&"wave")


func _show_rally_beam(delta: float) -> void:
	rally_timer = maxf(rally_timer - delta, 0.0)
	if rally_timer <= 0.0:
		if _rally_beam:
			_rally_beam.visible = false
		return
	if _rally_beam == null:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.no_depth_test = true
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = RALLY_BEAM_RADIUS
		cylinder.bottom_radius = RALLY_BEAM_RADIUS
		cylinder.height = RALLY_BEAM_HEIGHT
		cylinder.material = material
		_rally_beam = MeshInstance3D.new()
		_rally_beam.name = "RallyBeam"
		_rally_beam.mesh = cylinder
		_rally_beam.position = Vector3.UP * (RALLY_BEAM_HEIGHT / 2.0 + 2.2)
		_rally_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_rally_beam)
	_rally_beam.visible = true
	var colour := BUDDY_COLOR if is_bot else COLORS[color_index % COLORS.size()]
	colour.a = 0.6 * minf(rally_timer, 1.0) # Fades out over the last second.
	(_rally_beam.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color = colour


# --- On-screen hints ---------------------------------------------------------------

## A friend this close (metres) counts as "about", for hints about moves together.
const HINT_FRIEND_NEAR := 15.0


## What the controls would do right now, for the on-screen hint: up to two
## [action, words] pairs, most useful first. (An action of "" is something you
## do by steering.) Moves first, then items.
func control_hints() -> Array:
	var hints := []
	match state.name:
		&"Hang":
			var ledge: Ledge = state.ledge()
			if ledge.can_stand:
				hints.append([&"jump", "Climb up"])
			elif find_ledge_above(ledge):
				hints.append([&"jump", "Leap up"])
			hints.append([&"crouch", "Let go"])
		&"ChainHang", &"Caught":
			hints.append([&"jump", "Climb up"])
			hints.append([&"crouch", "Let go"])
		&"Brace":
			hints.append([&"toss", "Stop bracing"])
		&"Linked":
			hints.append([&"toss", "Let go"])
		&"Catch", &"PipeClimb":
			hints.append([&"crouch", "Let go"])
		&"Grind":
			hints.append([&"crouch", "Step off"])
		&"PipeRun":
			hints.append([&"jump", "Jump off the wall"])
		_:
			_friend_hints(hints)
	hints.append_array(items.control_hints())
	return hints.slice(0, 2)


func _friend_hints(hints: Array) -> void:
	if sync_linked_to == "" and linked_outside() != null:
		hints.append([&"", "Turn hard away from your line to crack the whip"])
		return
	var braced := _find_braced_friend(LEG_UP_REACH) if state.name in LEG_UP_STATES else null
	if braced:
		hints.append([&"jump", "Leg-up"])
		if state.name in [&"Ground", &"Crouch"] and braced.brace_stack().size() < MOST_BRACED:
			hints.append([&"toss", "Climb on their shoulders"])
		return
	if link_candidate():
		hints.append([&"toss", "Hold hands"])
	elif state.name in TOSS_STATES and _toss_cooldown_timer <= 0.0 and find_toss_target():
		hints.append([&"toss", "Toss your friend"])
	elif state.name in [&"Ground", &"Crouch"] and not hands_busy() and _friend_about() and not find_wall(true).is_empty():
		hints.append([&"toss", "Brace for a leg-up"])


## True if a friend (not just the practice buddy) is within HINT_FRIEND_NEAR.
func _friend_about() -> bool:
	for other in get_parent().get_children():
		if other != self and other is Player and other.global_position.distance_to(global_position) < HINT_FRIEND_NEAR:
			return true
	return false


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


## Launches a jump from the ground: a normal one, or (if free-run readied one,
## see pending_leap) a higher leap with a burst of forward speed.
func start_jump() -> void:
	var height := lerpf(jump_height, leap_height, pending_leap)
	velocity.y = sqrt(2.0 * _rise_gravity * height)
	if pending_leap > 0.0:
		var forward := input.move_direction.slide(Vector3.UP).normalized()
		if forward == Vector3.ZERO:
			forward = facing_direction()
		velocity += forward * leap_boost * pending_leap
	show_effect(&"show_jump", [pending_leap])
	pending_leap = 0.0


## Launched off a ramp's lip (see Ramp): on along `forward` at `speed`, and
## `rise` metres up, plus up to `leap_bonus` more for a readied free-run leap.
func ramp_launch(forward: Vector3, speed: float, rise: float, leap_bonus: float) -> void:
	rise += leap_bonus * _free_run.leap_charge()
	_free_run.readying_leap = false
	if is_crouched and can_stand():
		set_crouched(false)
	velocity = forward * speed + Vector3.UP * sqrt(2.0 * _rise_gravity * rise)
	refresh_air_moves()
	change_state(&"Air")
	show_effect(&"show_jump", [1.0])
	launched_off_ramp.emit()


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
	return not is_crouched or body_fits(global_position)


## Looks around the body (8 directions) for the closest wall within
## wall_detect_distance. With `tall_only`, the wall must also cover your knees
## and head (so blocks and low ledges don't count). Returns
## {"normal": flat direction out of the wall, "point": where it was hit},
## or an empty dictionary if there's no wall.
## The player (or practice buddy) in this game called `player_name`, or null.
func find_player(player_name: String) -> Player:
	return get_parent().get_node_or_null(NodePath(player_name)) as Player if player_name != "" else null


## The bottom of the hanging chain whose top friend hangs from a ledge at
## `spot` (their feet there), or null if nobody hangs there.
func chain_bottom_at(spot: Vector3) -> Player:
	var at: Player = null
	for other in get_parent().get_children():
		if other != self and other is Player and other.is_chain_top() and other.global_position.distance_to(spot) < CHAIN_GRAB_REACH:
			at = other
	var steps := 0
	while at and steps < 16:
		var below: Player = null
		for other in get_parent().get_children():
			if other != self and other is Player and other.sync_state == &"ChainHang" and other.sync_hanging_on == str(at.name):
				below = other
		if below == null:
			break
		at = below
		steps += 1
	return at


## A friend hanging (from a ledge or another friend) whose feet are within
## reach of your hands, with nobody hanging from them yet, or null.
func find_friend_to_hang_from() -> Player:
	var hands := global_position + Vector3.UP * hang_height
	var taken := {}
	for other in get_parent().get_children():
		if other is Player:
			taken[other.sync_hanging_on] = true
	for other in get_parent().get_children():
		if other != self and other is Player and other.sync_state in CHAIN_STATES \
				and not taken.has(str(other.name)) and other.global_position.distance_to(hands) <= CHAIN_GRAB_REACH:
			return other
	return null


## The drainpipe you're close enough to grab, pushing toward it (or `toward`,
## looking `extra` metres further ahead), or null. Only below its top, and only
## from in front of its wall.
func find_drainpipe(toward := Vector3.ZERO, extra := 0.0) -> Drainpipe:
	var push := toward if toward != Vector3.ZERO else input.move_direction
	push = Vector3(push.x, 0.0, push.z)
	if push.length() < 0.3:
		return null
	for pipe: Drainpipe in get_tree().get_nodes_in_group(&"drainpipes"):
		var out := pipe.out_of_wall()
		var offset := global_position - pipe.point_at(global_position.y)
		if global_position.y < pipe.global_position.y - 0.5 or global_position.y > pipe.top() - 1.0 \
				or offset.dot(out) < 0.0 or push.normalized().dot(-out) < 0.5:
			continue
		if offset.length() <= body_radius + Drainpipe.RADIUS + pipe_grab_reach + extra:
			return pipe
	return null


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


## True if something stands in the way of a wall run heading `direction`
## within wall_run_runway (e.g. the next step of a fire escape): then it's
## something to climb, not a wall to run along.
func wall_run_blocked(direction: Vector3) -> bool:
	var reach := body_radius + wall_run_runway
	for height: float in [0.3, 0.9]:
		var hit := _wall_hit(global_position + Vector3.UP * height, direction, reach)
		if not hit.is_empty() and direction.dot(-(hit.normal as Vector3)) > 0.5:
			return true
	return false


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


## Where the player's feet go after climbing up onto `ledge`. (On a sloped
## top, that far up the slope, and a little higher so the round bottom of the
## body clears it.)
func stand_position(ledge: Ledge) -> Vector3:
	var inward := body_radius + 0.15
	var lift := ledge.slope * inward + body_radius * (sqrt(1.0 + ledge.slope * ledge.slope) - 1.0)
	return ledge.position - ledge.normal * inward + Vector3.UP * (lift + 0.02)


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
	# A sloped top (a roof seen from its eave) rises as you go in from the edge.
	var top_normal: Vector3 = top.normal
	ledge.slope = maxf(top_normal.dot(wall_normal) / top_normal.y, 0.0)

	# 3. Is there open space above the edge, room to pull up, and room to stand?
	var over_edge := ledge.position + wall_normal * reach + Vector3.UP * (0.15 + ledge.slope * 0.3)
	if not raycast(over_edge, over_edge - wall_normal * (reach + 0.3)).is_empty():
		return null # The wall keeps going up; that "top" was something else.
	if not _shuffle_to_fit(ledge):
		return null
	# No room to stand on top (e.g. a narrow sill): still fine to hang from.
	ledge.can_stand = _room_on_top(ledge) and body_fits(stand_position(ledge))
	return ledge


## True if there's room to hang from `ledge` and pull up over it. In a corner
## (say, where a fire escape step meets the building's wall) you'd be pressed
## into the side wall, so this tries shuffling the grab sideways along the edge
## first, moving `ledge` to the spot that fits.
func _shuffle_to_fit(ledge: Ledge) -> bool:
	var sideways := ledge.normal.cross(Vector3.UP)
	for shift: float in [0.0, 0.15, -0.15, 0.3, -0.3, 0.5, -0.5]:
		var spot := ledge.position + sideways * shift
		var hang_column := spot + ledge.normal * (body_radius + 0.05)
		hang_column.y = spot.y + 0.05
		if body_fits(hang_column):
			ledge.position = spot
			return true
	return false


## True if the top of the ledge is deep enough to stand on: nothing (like the
## wall a sill sticks out of) within a body's width behind the edge. (A plain
## line check, because a body-shape check can't tell when the body would be
## mostly inside a wall. On a sloped top, the lines run up the slope.)
func _room_on_top(ledge: Ledge) -> bool:
	var depth_needed := body_radius * 2.0 + 0.2
	for height: float in [0.3, 1.2]:
		var from := ledge.position + Vector3.UP * height + ledge.normal * 0.05
		var to := from - ledge.normal * depth_needed + Vector3.UP * ledge.slope * depth_needed
		if not raycast(from, to).is_empty():
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
func body_fits(feet: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _stand_shape
	query.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * (_stand_shape.height * 0.5 + 0.02))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


## The highest you've been over the last few seconds (PEAK_WINDOW), as seen
## on this computer: how far you came down to get where you are.
func recent_peak() -> float:
	var peak := global_position.y
	for sample in _heights:
		peak = maxf(peak, sample.y)
	return peak


## How fast you're seen moving across the ground (on any computer: it's
## worked out from how you move on screen, so it works for friends too).
func seen_speed() -> float:
	return _ground_speed
