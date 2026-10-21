class_name FreeRun
extends Node
## Free-run: hold Shift / right trigger to run where the camera points while
## the character handles obstacles for you.
##
## It works like a helpful co-pilot pressing buttons: each tick it looks ahead
## and, if needed, presses jump or crouch on the PlayerInput. So every
## automatic move is a normal move you could also do yourself, and your own
## presses (a manual jump, a slide) still work at any time.
##   Low obstacle you can get over      -> jump (you vault or climb it)
##   Wall at an angle                   -> jump (you wall-run along it)
##   Bar at head height, room below     -> crouch (you slide under it)
##   Gap with a landing in jumping range -> jump it
##   Gap with nothing to land on        -> keep running (you drop off)
##   Hanging from a ledge               -> pull up

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

var player: Player
var input: PlayerInput

var _jump_hold_timer := 0.0
var _cooldown_timer := 0.0


## Called by the Player each tick while free-run is held, after the real
## controls have been read and before the movement states run.
func assist(delta: float) -> void:
	_cooldown_timer -= delta
	if _jump_hold_timer > 0.0:
		_jump_hold_timer -= delta
		input.jump_held = true # Hold the jump for full height.

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
		if _can_get_on_top(low, direction, feet) or _is_glancing(low, direction):
			_press_jump()
		return # A wall too tall and too head-on: free-run won't help (your call).

	if not _wall_ahead(feet + Vector3.UP * HEAD_HEIGHT, direction, reach).is_empty():
		input.crouch_held = true # Something at head height with room below: slide under.
		return

	if _edge_ahead(feet, direction, speed) and _landing_ahead(feet, direction, speed):
		_press_jump()


func _press_jump() -> void:
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


## True if the obstacle's top is within jump-and-grab reach.
func _can_get_on_top(wall: Dictionary, direction: Vector3, feet: Vector3) -> bool:
	var max_height := player.jump_height + player.ledge_max_height
	var above: Vector3 = wall.position + direction * 0.3
	above.y = feet.y + max_height + 0.1
	var top := player.raycast(above, Vector3(above.x, feet.y + 0.1, above.z))
	return not top.is_empty() and top.normal.y > 0.7


## True if we're hitting the wall at a shallow angle (good for a wall run).
func _is_glancing(wall: Dictionary, direction: Vector3) -> bool:
	return direction.dot(-(wall.normal as Vector3)) < 0.5


## True if the ground runs out just ahead.
func _edge_ahead(feet: Vector3, direction: Vector3, speed: float) -> bool:
	var probe := feet + direction * (player.body_radius + 0.35 + speed * 0.03)
	return player.raycast(probe + Vector3.UP * 0.5, probe + Vector3.DOWN * 0.6).is_empty()


## True if there's somewhere to land within jumping distance, no more than
## MAX_LANDING_DROP below us.
func _landing_ahead(feet: Vector3, direction: Vector3, speed: float) -> bool:
	var jump_distance := speed * (player.jump_time_to_peak + player.jump_time_to_fall)
	var distance := 1.0
	while distance <= jump_distance:
		var spot := feet + direction * distance
		var hit := player.raycast(spot + Vector3.UP * (player.jump_height + 0.5), spot + Vector3.DOWN * MAX_LANDING_DROP)
		if not hit.is_empty() and hit.normal.y > 0.7:
			return true
		distance += 0.5
	return false
