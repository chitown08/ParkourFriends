extends PlayerState
## Bracing for a leg-up: back to a wall, hands cupped, for friends to run at
## and jump into (see LegUp). Started with the toss button when there's nobody
## to toss (Player.try_brace()). Beside a braced friend you climb onto the
## shoulders of the top one instead and brace there: each friend in the stack
## puts the hands Player.BRACE_SHOULDERS higher.
##   Toss, jump, crouch, or step away from the wall -> stop bracing
##   The friend under you stops bracing             -> you drop

## How fast you climb onto a friend's shoulders (m/s).
const CLIMB_ON_SPEED := 8.0

var _wall_normal := Vector3.ZERO
## The friend whose shoulders you're on, or null at the foot of the wall.
var _on: Player


func enter(data: Dictionary) -> void:
	_wall_normal = data["wall_normal"]
	_on = data.get("on")
	player.velocity = Vector3.ZERO
	if player.is_crouched and player.can_stand():
		player.set_crouched(false)
	player.sync_braced_on = str(_on.name) if _on else ""
	if _on == null and data.has("wall_point"):
		# Back right up against the wall.
		var point: Vector3 = data["wall_point"]
		var feet := Vector3(point.x, player.global_position.y, point.z) + _wall_normal * (player.body_radius + 0.05)
		if player.body_fits(feet):
			player.global_position = feet
	# Face out straight away: friends read the wall from the way you face.
	player.face_direction(_wall_normal, 1.0)


func exit() -> void:
	player.sync_braced_on = ""


func physics_update(delta: float) -> void:
	if _on:
		if not is_instance_valid(_on) or _on.sync_state != &"Brace":
			player.change_state(&"Air")
			return
		var shoulders := _on.global_position + Vector3.UP * Player.BRACE_SHOULDERS
		player.global_position = player.global_position.move_toward(shoulders, CLIMB_ON_SPEED * delta)
	else:
		player.velocity = Vector3(0.0, player.velocity.y, 0.0)
		player.apply_gravity(delta)
		player.move_and_slide()
	player.face_direction(_wall_normal, delta)

	if player.has_jump_buffered() or input.crouch_just_pressed or input.move_direction.dot(_wall_normal) > 0.5:
		let_go()


## Stops bracing: steps off the friend you're on, or stands up at the wall
## (a jump pressed to get here still happens).
func let_go() -> void:
	player.change_state(&"Air" if _on else &"Ground")
