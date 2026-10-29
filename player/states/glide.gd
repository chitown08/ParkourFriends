extends PlayerState
## Gliding (with a glider in your hands, holding "use item" in the air).
## You sink slowly and keep a steady speed, but turn poorly. Ends when you
## land, let go of the button, hit a wall, or the glider leaves your hands.
## The glider's numbers come from its ability (items/abilities/glide.gd).

const SPEED_CHANGE := 4.0 ## How quickly you ease to cruising speed (m/s per second).
const FLARE := 30.0 ## How quickly a fall slows to the sink speed (m/s per second).
## How far you bank into a turn (radians), like a bird.
const BANK := deg_to_rad(25.0)

var _item: WorldItem
var _speed := 0.0 ## Cruising speed (m/s).
var _sink_speed := 0.0 ## How fast you lose height (m/s).
var _turn_rate := 0.0 ## Radians per second.


func enter(data: Dictionary) -> void:
	_item = data["item"]
	_speed = data["speed"]
	_sink_speed = data["sink_speed"]
	_turn_rate = data["turn_rate"]


func physics_update(delta: float) -> void:
	if not input.use_item_held or player.items.hands_item() != _item:
		player.change_state(&"Air")
		return

	var horizontal := Vector3(player.velocity.x, 0.0, player.velocity.z)
	var heading := horizontal.normalized() if horizontal.length() > 0.1 else player.facing_direction()
	# Turn slowly toward where you're steering.
	var wish := input.move_direction
	var angle := 0.0
	if wish.length() > 0.3:
		angle = heading.signed_angle_to(wish.normalized(), Vector3.UP)
		heading = heading.rotated(Vector3.UP, clampf(angle, -_turn_rate * delta, _turn_rate * delta))
	player.lean = BANK * clampf(angle / deg_to_rad(45.0), -1.0, 1.0)
	# Ease toward cruising speed; faster entries (a throw, a dive) bleed off gently.
	var speed := move_toward(horizontal.length(), _speed, SPEED_CHANGE * delta)
	player.velocity.x = heading.x * speed
	player.velocity.z = heading.z * speed
	# Rising (e.g. thrown): gravity as usual. Falling: flare out to the sink speed.
	if player.velocity.y > -_sink_speed:
		player.apply_gravity(delta)
		player.velocity.y = maxf(player.velocity.y, -_sink_speed)
	else:
		player.velocity.y = move_toward(player.velocity.y, -_sink_speed, FLARE * delta)

	player.move_and_slide()
	player.face_direction(heading, delta)
	if player.is_on_floor():
		player.change_state(&"Ground")
	elif player.is_on_wall():
		player.change_state(&"Air") # Bonk.
