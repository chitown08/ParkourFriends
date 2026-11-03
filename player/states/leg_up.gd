extends PlayerState
## Taking a leg-up (see Player._try_leg_up()): stepping into a braced friend's
## hands, or up the stack on their shoulders to the top one's, then launched
## leg_up_height up the wall (Player.leg_up_launch()). You come out in the air
## pressing into the wall, so you scramble up it and grab the top. If the
## stack breaks up under you, you drop.

## How fast you step up the stack (m/s).
const SPEED := 10.0
## Where you stand, out from the top friend (in front of them, not in them).
const STEP_OUT := 0.3

var _base: Player
## Out of the wall: the way the friend at its foot faces.
var _wall_normal := Vector3.ZERO


func enter(data: Dictionary) -> void:
	_base = data["base"]
	_wall_normal = _base.facing_direction()
	player.velocity = Vector3.ZERO
	if player.is_crouched and player.can_stand():
		player.set_crouched(false)


func physics_update(delta: float) -> void:
	if not is_instance_valid(_base) or _base.sync_state != &"Brace":
		player.change_state(&"Air")
		return
	var top: Player = _base.brace_stack().back()
	var hands := top.global_position + Vector3.UP * Player.BRACE_HANDS + _wall_normal * STEP_OUT
	player.global_position = player.global_position.move_toward(hands, SPEED * delta)
	player.face_direction(-_wall_normal, delta)
	if player.global_position.distance_to(hands) <= 0.05:
		player.leg_up_launch(-_wall_normal)
