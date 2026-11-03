extends PlayerState
## Catching a friend who fell short of your edge (they're Caught: see
## Player.find_catcher()). Down on one knee holding their hands while they
## climb up, or while more friends hang below them. You stay put.
##   Jump or crouch          -> let go (they drop)
##   Nobody to hold any more -> back on your feet

## With nobody hanging from your hands for this long (seconds), you're done.
## (Not straight away: when the one you caught climbs up, the friend hanging
## below them takes their place.)
const NOBODY_FOR := 0.25

var _nobody := 0.0


func enter(_data: Dictionary) -> void:
	_nobody = 0.0


func physics_update(delta: float) -> void:
	player.velocity.x = 0.0
	player.velocity.z = 0.0
	player.apply_gravity(delta)
	player.move_and_slide()
	var friend := _caught()
	if friend:
		_nobody = 0.0
		player.face_direction(friend.global_position - player.global_position, delta)
	else:
		_nobody += delta

	if not player.is_on_floor():
		player.change_state(&"Air")
	elif player.consume_jump() or input.crouch_just_pressed:
		player.catch_cooldown = Player.CATCH_COOLDOWN
		_stand()
	elif _nobody >= NOBODY_FOR:
		_stand()


func _stand() -> void:
	player.change_state(&"Crouch" if player.is_crouched else &"Ground")


## The friend hanging from your hands, or null.
func _caught() -> Player:
	for other in player.get_parent().get_children():
		if other is Player and other.sync_state == &"Caught" and other.sync_hanging_on == str(player.name):
			return other
	return null
