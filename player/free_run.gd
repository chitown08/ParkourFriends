class_name FreeRun
extends Node
## Free-run: hold Shift / right trigger to run where the camera points while
## the character handles obstacles for you.
##
## It works like a helpful co-pilot pressing buttons: each tick it looks ahead
## and, if needed, presses jump or crouch on the PlayerInput. So every
## automatic move is a normal move you could also do yourself, and your own
## presses (a manual jump, a slide) still work at any time.
##   Wall you can get on top of         -> jump (you vault, climb or scramble up it)
##   Wall with a ledge in reach          -> jump (you grab it; jump again to leap up)
##   Wall at an angle                   -> jump (you wall-run along it)
##   Bar at head height, room below     -> crouch (you slide under it)
##   Gap with a landing in jumping range -> jump it
##   Gap with no landing, wall alongside -> jump toward the wall (you wall-run across)
##   Gap with nothing to land on        -> keep running (you drop off)
##   Ramp                               -> keep running (its lip launches you)
##   Hanging from a ledge               -> pull up (or leap to the next ledge up)
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

var player: Player
var input: PlayerInput

## True while you hold jump on the ground, readying a leap.
var readying_leap := false
var _ready_time := 0.0
var _jump_hold_timer := 0.0
var _cooldown_timer := 0.0
var _seek_direction := Vector3.ZERO
var _seek_timer := 0.0


## Called by the Player each tick while free-run is held, after the real
## controls have been read and before the movement states run.
func assist(delta: float) -> void:
	_cooldown_timer -= delta
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
		&"Hang":
			_press_jump() # Pull yourself up straight away.


func _look_ahead() -> void:
	var direction := Vector3(input.move_direction.x, 0.0, input.move_direction.z).normalized()
	if direction == Vector3.ZERO:
		return
	var feet := player.global_position
	var speed := maxf(player.get_horizontal_speed(), player.run_speed)
	var reach := player.body_radius + maxf(MIN_LOOK_AHEAD, speed * LOOK_AHEAD_TIME)

	var low := _wall_ahead(feet + Vector3.UP * KNEE_HEIGHT, direction, reach)
	if not low.is_empty():
		if _can_get_on_top(low, direction, feet) or _ledge_in_reach(low, direction, feet) \
				or _is_glancing(low, direction):
			_press_jump()
		return # A wall too tall and too head-on: free-run won't help (your call).

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


## True if we can get on top of the obstacle: within jump-and-grab reach, or
## with a wall scramble's extra height on top of that.
func _can_get_on_top(wall: Dictionary, direction: Vector3, feet: Vector3) -> bool:
	var scramble_height := player.wall_scramble_speed * player.wall_scramble_time
	var max_height := player.jump_height + scramble_height + player.ledge_max_height
	var above: Vector3 = wall.position + direction * 0.3
	above.y = feet.y + max_height + 0.1
	var top := player.raycast(above, Vector3(above.x, feet.y + 0.1, above.z))
	return not top.is_empty() and top.normal.y > 0.7


## True if we're hitting the wall at a shallow angle (good for a wall run).
func _is_glancing(wall: Dictionary, direction: Vector3) -> bool:
	return direction.dot(-(wall.normal as Vector3)) < 0.5


## True if you're running up a ramp (see Ramp).
func _on_ramp(feet: Vector3) -> bool:
	var hit := player.raycast(feet + Vector3.UP * 0.5, feet + Vector3.DOWN * 0.6)
	return not hit.is_empty() and hit.collider is Node and (hit.collider as Node).get_parent() is Ramp


## True if the ground runs out just ahead.
func _edge_ahead(feet: Vector3, direction: Vector3, speed: float) -> bool:
	var probe := feet + direction * (player.body_radius + 0.35 + speed * 0.03)
	return player.raycast(probe + Vector3.UP * 0.5, probe + Vector3.DOWN * 0.6).is_empty()


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
