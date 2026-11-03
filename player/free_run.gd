class_name FreeRun
extends Node
## Free-run: hold Shift / right trigger to run where the camera points while
## the character handles obstacles for you.
##
## It works like a helpful co-pilot pressing buttons: each tick it looks ahead
## and, if needed, presses jump or crouch on the PlayerInput. So every
## automatic move is a normal move you could also do yourself, and your own
## presses (a manual jump, a slide) still work at any time. The one move of
## its own is the flow vault: skimming over low things without a jump.
##   Something low and short, head-on    -> flow vault (you skim over it, keeping your speed)
##   Running down a slope (a roof)        -> crouch (you slide down it, speeding up)
##   Wall you can get on top of         -> jump (you vault, climb or scramble up it)
##   Wall with a ledge in reach          -> jump (you grab it; jump again to leap up)
##   Drainpipe ahead                     -> jump (you grab it on the way; free-run climbs it)
##   Wall too tall, head-on              -> jump (you scramble up it, grabbing any ledge
##                                          or sill on the way; line one up as you come in)
##   Wall at an angle                   -> jump (you wall-run along it)
##   Bar at head height, room below     -> crouch (you slide under it)
##   Gap with a landing in jumping range -> jump it
##   Gap with no landing, wall alongside -> jump toward the wall (you wall-run across)
##   Gap with nothing to land on        -> keep running (you drop off)
##   Ramp                               -> keep running (its lip launches you)
##   Hanging from a ledge or a friend   -> pull up (or leap to the next ledge up, or climb the chain)
##
## Pack-running: friends free-running near you, the way you are heading, pull
## you gently along with them (see _run_with_pack()): your heading bends a
## little toward theirs and toward them, and your pace eases up or down so you
## keep alongside. Nobody leads; it never jumps for you, and steering away
## (or letting go of free-run) breaks it.
##
## Your own jump button becomes a leap: tap it for a normal jump, or hold it to
## ready a leap (higher and longer) and let go to take off. Still holding it
## when free-run would jump (an edge, a wall), you take off right there.

## How far ahead to look for obstacles, in seconds of travel at your speed.
const LOOK_AHEAD_TIME := 0.25
## ...but always at least this far beyond your body (metres).
const MIN_LOOK_AHEAD := 0.9
const KNEE_HEIGHT := 0.5
const HEAD_HEIGHT := 1.5
## Free-run jumps a gap only toward a landing at most this far below your feet;
## anything lower and you just run off the edge (e.g. down to the street).
const MAX_LANDING_DROP := 3.0
## A drop this short with ground right below isn't jumped: you just run off it.
const MAX_STEP_DOWN := 1.5
## Free-run scrambles up a too-tall wall only when running at it at least this
## fast (fraction of run speed): after a failed one you're stopped, so it doesn't retry.
const SCRAMBLE_MIN_SPEED := 0.5
## Minimum time between automatic jumps.
const JUMP_COOLDOWN := 0.3
## How far to the side a wall can be for free-run to steer to it and wall-run a gap.
const WALL_SEEK_DISTANCE := 4.5
## How long to keep steering toward that wall after jumping (seconds).
const WALL_SEEK_TIME := 0.6
## How strongly to steer toward it (1 = as much sideways as forwards).
const WALL_SEEK_STRENGTH := 0.7
## Holding jump shorter than this is a tap: a normal jump (seconds).
const LEAP_TAP_TIME := 0.1
## How squarely you must be heading at something to flow-vault it (1 = dead on).
const VAULT_HEAD_ON := 0.7
## Steps (metres) when feeling across the top of something to vault.
const VAULT_PROBE_STEP := 0.15
## A top that drops this far below its highest point counts as its far side.
const VAULT_FALL_AWAY := 0.3

## Free-run slides down slopes steeper than this (degrees)...
const SLIDE_SLOPE_DEGREES := 10.0
## ...when you're heading this squarely down them (1 = straight down).
const SLIDE_HEADING := 0.5

## Friends within this distance (metres, across) can be your pack...
const PACK_RADIUS := 8.0
## ...and this far above or below you.
const PACK_HEIGHT := 3.0
## ...if they head within this angle of where you steer (degrees).
const PACK_HEADING_DEGREES := 45.0
## How much your heading bends toward the pack's (1 = as much as your own).
const PACK_STEER := 0.25
## How much it bends toward the pack sideways, at the edge of PACK_RADIUS.
const PACK_GATHER := 0.3
## Your pace eases up to this much faster or slower to keep alongside (0.2 = 20%).
const PACK_PACE := 0.2
## How quickly the pace eases (fraction of full change per second).
const PACK_PACE_RATE := 1.0
## A gap this long (metres, ahead or behind) gets the full pace change.
const PACK_CLOSE_UP := 4.0

## What _try_vault() decided: not one to vault, one to vault in a moment, vaulting.
enum Vault { NO, SOON, STARTED }

var player: Player
var input: PlayerInput

## True while you hold jump on the ground, readying a leap.
var readying_leap := false
var _ready_time := 0.0
var _jump_hold_timer := 0.0
var _cooldown_timer := 0.0
var _seek_direction := Vector3.ZERO
var _seek_timer := 0.0
## How many friends are running with you right now (see _run_with_pack()).
var pack_size := 0


## Called by the Player each tick while free-run is held, after the real
## controls have been read and before the movement states run.
func assist(delta: float) -> void:
	_cooldown_timer -= delta
	_run_with_pack(delta)
	_update_leap(delta)
	if _jump_hold_timer > 0.0:
		_jump_hold_timer -= delta
		input.jump_held = true # Hold the jump for full height.

	# Steering toward a wall to wall-run a gap (see _wall_beside()).
	if _seek_timer > 0.0:
		_seek_timer -= delta
		if player.state.name == &"Air":
			input.move_direction = (input.move_direction + _seek_direction * WALL_SEEK_STRENGTH).normalized()
		else:
			_seek_timer = 0.0 # Wall run started (or landed): done steering.

	match player.state.name:
		&"Ground", &"Slide":
			_look_ahead()
		&"Hang", &"ChainHang", &"Caught":
			_press_jump() # Pull yourself up straight away.


func _look_ahead() -> void:
	var direction := Vector3(input.move_direction.x, 0.0, input.move_direction.z).normalized()
	if direction == Vector3.ZERO:
		return
	var feet := player.global_position
	var speed := maxf(player.get_horizontal_speed(), player.free_run_speed)
	var reach := player.body_radius + maxf(MIN_LOOK_AHEAD, speed * LOOK_AHEAD_TIME)

	if not readying_leap and _heading_downhill(direction) and (player.state.name == &"Slide" \
			or player.get_horizontal_speed() >= player.slide_min_start_speed):
		input.crouch_held = true # Slide down it for speed (stand up again where it levels out).

	var low := _wall_ahead(feet + Vector3.UP * KNEE_HEIGHT, direction, reach)
	if not low.is_empty():
		if not readying_leap and _try_vault(low, direction, feet) != Vault.NO:
			return # Vaulting it, or about to.
		if _can_get_on_top(low, direction, feet) or _ledge_in_reach(low, direction, feet) \
				or _is_glancing(low, direction):
			_press_jump()
		elif player.get_horizontal_speed() >= player.free_run_speed * SCRAMBLE_MIN_SPEED:
			# Too tall and too head-on: jump and scramble up it anyway, grabbing any
			# ledge or sill that comes into reach. Line up with one on the way in;
			# miss and you slide back down and stop (no second go without a run-up).
			_press_jump()
		return

	if not _wall_ahead(feet + Vector3.UP * HEAD_HEIGHT, direction, reach).is_empty():
		input.crouch_held = true # Something at head height with room below: slide under.
		return

	if _on_ramp(feet):
		return # Ride it to the lip: the ramp launches you.
	if not _edge_ahead(feet, direction, speed):
		return
	if readying_leap:
		_take_off() # Leap off any edge, landing or not: your call.
		return
	if _step_down_ahead(feet, direction, speed):
		return # Just a short drop (like off a sawtooth roof's ridge): run off it.
	if _landing_ahead(feet, direction, speed):
		_press_jump()
		return
	var wall_side := _wall_beside(feet, direction)
	if wall_side != Vector3.ZERO:
		_press_jump()
		_seek_direction = wall_side
		_seek_timer = WALL_SEEK_TIME


## Your jump button: pressing it on the ground starts readying a leap (the
## press is held back from the movement states); letting go takes off.
func _update_leap(delta: float) -> void:
	if readying_leap:
		if player.state.name != &"Ground":
			readying_leap = false # Dropped off, slid, got tossed...: never mind.
		elif not input.jump_held:
			_take_off()
		else:
			_ready_time += delta
	elif input.jump_just_pressed and player.state.name == &"Ground":
		input.jump_just_pressed = false
		readying_leap = true
		_ready_time = 0.0


## How readied the leap is: 0 (none, or still just a tap) to 1 (a full leap).
func leap_charge() -> float:
	if not readying_leap:
		return 0.0
	var readied := (_ready_time - LEAP_TAP_TIME) / maxf(player.leap_charge_time - LEAP_TAP_TIME, 0.01)
	return clampf(readied, 0.0, 1.0)


func _take_off() -> void:
	player.pending_leap = leap_charge()
	readying_leap = false
	_cooldown_timer = 0.0
	_press_jump()
	_jump_hold_timer = 1.0 # Keep "holding" jump for the whole leap (no short hop).


func _press_jump() -> void:
	if readying_leap:
		_take_off() # Free-run wants to jump (a wall, a gap): leap now.
		return
	if _cooldown_timer > 0.0:
		return
	input.jump_just_pressed = true
	input.jump_held = true
	_jump_hold_timer = player.jump_time_to_peak
	_cooldown_timer = JUMP_COOLDOWN


func _wall_ahead(from: Vector3, direction: Vector3, reach: float) -> Dictionary:
	var hit := player.raycast(from, from + direction * reach)
	if hit.is_empty() or absf(hit.normal.y) > 0.3:
		return {}
	return hit


## Flow-vaults `wall` (hit at knee height) if it's low and short enough, you're
## heading at it squarely and there's room to pass over it.
func _try_vault(wall: Dictionary, direction: Vector3, feet: Vector3) -> Vault:
	if player.hands_busy() or direction.dot(-(wall.normal as Vector3)) < VAULT_HEAD_ON:
		return Vault.NO
	if player.is_crouched and not player.can_stand():
		return Vault.NO
	# Feel across the top for its height and where its far side is.
	var top := -INF
	var depth := -1.0
	var across := 0.1
	while across <= player.vault_max_depth + VAULT_PROBE_STEP:
		var spot: Vector3 = wall.position + direction * across
		var hit := player.raycast(Vector3(spot.x, feet.y + player.vault_max_height + 0.5, spot.z), Vector3(spot.x, feet.y - 0.1, spot.z))
		var height: float = hit.position.y - feet.y if not hit.is_empty() else -INF
		if height > player.vault_max_height:
			return Vault.NO # Too tall.
		if height < player.mantle_min_height or height < top - VAULT_FALL_AWAY:
			depth = across # Past the far side (or where its top slopes away, like a sawtooth roof's).
			break
		top = maxf(top, height)
		across += VAULT_PROBE_STEP
	if top == -INF or depth < 0.0:
		return Vault.NO # Nothing on top (too tall to see), or too deep.

	var speed := maxf(player.get_horizontal_speed(), player.free_run_speed)
	var to_wall: float = (wall.position - feet).dot(direction)
	var risen_at := to_wall - player.body_radius - 0.05
	if risen_at > speed * player.vault_takeoff_time:
		return Vault.SOON # Not yet: keep running at it.
	risen_at = maxf(risen_at, 0.05)
	var rise: float = top + player.vault_clearance
	var clear_at := to_wall + depth + player.body_radius + 0.05
	for along: float in [risen_at, (risen_at + clear_at) / 2.0, clear_at]:
		if not player.body_fits(feet + direction * along + Vector3.UP * rise):
			return Vault.NO # Something in the way: jump it the usual way.
	if player.is_crouched:
		player.set_crouched(false)
	player.change_state(&"Vault", {"direction": direction, "speed": speed,
			"risen_at": risen_at, "clear_at": clear_at, "rise": rise})
	_cooldown_timer = JUMP_COOLDOWN
	return Vault.STARTED


## True if we can get on top of the obstacle: within jump-and-grab reach, or
## with a wall scramble's extra height on top of that. (Looks a little way in,
## and further, past a face that leans back like a sawtooth roof's glass.)
func _can_get_on_top(wall: Dictionary, direction: Vector3, feet: Vector3) -> bool:
	var scramble_height := player.wall_scramble_speed * player.wall_scramble_time
	var max_height := player.jump_height + scramble_height + player.ledge_max_height
	for inward: float in [0.3, 0.9]:
		var above: Vector3 = wall.position + direction * inward
		above.y = feet.y + max_height + 0.1
		var top := player.raycast(above, Vector3(above.x, feet.y + 0.1, above.z))
		if not top.is_empty() and top.normal.y > 0.7:
			return true
	return false


## True if we're hitting the wall at a shallow angle (good for a wall run).
func _is_glancing(wall: Dictionary, direction: Vector3) -> bool:
	return direction.dot(-(wall.normal as Vector3)) < 0.5


## True if you're running up a ramp (see Ramp).
func _on_ramp(feet: Vector3) -> bool:
	var hit := player.raycast(feet + Vector3.UP * 0.5, feet + Vector3.DOWN * 0.6)
	return not hit.is_empty() and hit.collider is Node and (hit.collider as Node).get_parent() is Ramp


## True if you're on a slope (a sloped roof) and heading down it.
func _heading_downhill(direction: Vector3) -> bool:
	if not player.is_on_floor():
		return false
	var normal := player.get_floor_normal()
	var downhill := Vector3(normal.x, 0.0, normal.z)
	return normal.y < cos(deg_to_rad(SLIDE_SLOPE_DEGREES)) and direction.dot(downhill.normalized()) > SLIDE_HEADING


## True if the ground runs out just ahead.
func _edge_ahead(feet: Vector3, direction: Vector3, speed: float) -> bool:
	var probe := feet + direction * (player.body_radius + 0.35 + speed * 0.03)
	return player.raycast(probe + Vector3.UP * 0.5, probe + Vector3.DOWN * 0.6).is_empty()


## True if the edge ahead is only a short drop onto more ground right there.
func _step_down_ahead(feet: Vector3, direction: Vector3, speed: float) -> bool:
	var probe := feet + direction * (player.body_radius + 0.35 + speed * 0.03)
	var hit := player.raycast(probe, probe + Vector3.DOWN * MAX_STEP_DOWN)
	return not hit.is_empty() and hit.normal.y > 0.7


## True if there's somewhere to land on the far side of the gap, within
## jumping distance: anything from MAX_LANDING_DROP below us up to as high as a
## jump plus a ledge grab reaches. (Ground before the gap — the edge we're
## standing on — doesn't count.)
func _landing_ahead(feet: Vector3, direction: Vector3, speed: float) -> bool:
	var jump_distance := speed * (player.jump_time_to_peak + player.jump_time_to_fall)
	var highest := player.jump_height + player.ledge_max_height
	var past_the_gap := false
	var distance := 0.5
	while distance <= jump_distance:
		var spot := feet + direction * distance
		var hit := player.raycast(spot + Vector3.UP * highest, spot + Vector3.DOWN * MAX_LANDING_DROP)
		var ground: bool = not hit.is_empty() and hit.normal.y > 0.7
		if not ground:
			past_the_gap = true
		elif past_the_gap:
			return true
		distance += 0.5
	return false


## If there's a tall wall to our left or right that carries on along the gap
## ahead, returns the direction toward it (otherwise zero).
func _wall_beside(feet: Vector3, direction: Vector3) -> Vector3:
	var right := direction.cross(Vector3.UP)
	for side: Vector3 in [right, -right]:
		var here := _side_wall(feet, side)
		var further := _side_wall(feet + direction * 4.0, side)
		if here and further:
			return side
	return Vector3.ZERO


func _side_wall(feet: Vector3, side: Vector3) -> bool:
	for height: float in [1.0, 2.0]:
		var from := feet + Vector3.UP * height
		var hit := player.raycast(from, from + side * WALL_SEEK_DISTANCE)
		if hit.is_empty() or absf(hit.normal.y) > 0.3:
			return false
	return true


## True if there's a ledge on this wall we could grab from the top of a jump
## (e.g. the first sill of a ledge-leap tower).
func _ledge_in_reach(wall: Dictionary, direction: Vector3, feet: Vector3) -> bool:
	# Imagine standing a little out from the wall (clear of anything sticking out of it).
	var at_the_wall: Vector3 = wall.position + (wall.normal as Vector3) * (player.body_radius + 0.6)
	var jump_top := Vector3(at_the_wall.x, feet.y + player.jump_height * 0.9, at_the_wall.z)
	return player.find_ledge(jump_top, direction) != null


## Friends free-running close by, heading roughly where you steer, nudge your
## heading toward theirs (and toward them, sideways) and ease your pace to
## stay alongside: a little faster if they're ahead or quicker, slower if
## they're behind. Sets player.pack_pace and pack_size.
func _run_with_pack(delta: float) -> void:
	var heading := Vector3(input.move_direction.x, 0.0, input.move_direction.z)
	var steering := heading.length()
	pack_size = 0
	var pack_velocity := Vector3.ZERO
	var centre := Vector3.ZERO
	if steering > 0.1:
		heading /= steering
		for other: Player in player.get_parent().get_children(): # Everyone in this game.
			var running := other.sync_free_run_velocity
			var offset := other.global_position - player.global_position
			if other == player or running.length() < 1.0 or absf(offset.y) > PACK_HEIGHT \
					or Vector2(offset.x, offset.z).length() > PACK_RADIUS \
					or running.normalized().dot(heading) < cos(deg_to_rad(PACK_HEADING_DEGREES)):
				continue
			pack_size += 1
			pack_velocity += running
			centre += other.global_position
	var target_pace := 1.0
	if pack_size > 0:
		pack_velocity /= pack_size
		centre /= pack_size
		var pack_heading := pack_velocity.normalized()
		var offset := centre - player.global_position
		offset.y = 0.0
		var ahead := offset.dot(pack_heading)
		var sideways := offset - pack_heading * ahead
		var bent := heading + pack_heading * PACK_STEER + sideways / PACK_RADIUS * PACK_GATHER
		input.move_direction = Vector3(bent.x, 0.0, bent.z).normalized() * steering
		# Their speed, plus a bit to close the gap (or minus, if you're ahead).
		var wanted := pack_velocity.length() * (1.0 + clampf(ahead / PACK_CLOSE_UP, -1.0, 1.0) * PACK_PACE)
		target_pace = clampf(wanted / player.top_speed(false), 1.0 - PACK_PACE, 1.0 + PACK_PACE)
	player.pack_pace = move_toward(player.pack_pace, target_pace, PACK_PACE_RATE * delta)
