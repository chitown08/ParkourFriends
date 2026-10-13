extends PlayerState
## Hanging from a ledge by your hands.
##   Jump              -> pull yourself up
##   Left / right      -> shimmy along the ledge
##   Crouch, or back   -> let go

var _ledge: Ledge


func enter(data: Dictionary) -> void:
	_ledge = data["ledge"]
	player.velocity = Vector3.ZERO
	player.refresh_air_moves()


func physics_update(delta: float) -> void:
	# Slide smoothly into the hanging spot (it's usually a little off at first).
	var target := player.hang_position(_ledge)
	player.global_position = player.global_position.move_toward(target, player.hang_snap_speed * delta)
	player.face_direction(-_ledge.normal, delta)

	var toward_wall := input.move_direction.dot(-_ledge.normal)

	if player.consume_jump():
		player.change_state(&"Climb", {"ledge": _ledge, "duration": player.climb_up_time})
	elif input.crouch_just_pressed or toward_wall < -0.5:
		player.change_state(&"Air", {"regrab_delay": player.ledge_regrab_delay})
	else:
		_shimmy(delta)


func _shimmy(delta: float) -> void:
	var right := Vector3.UP.cross(_ledge.normal)
	var side := input.move_direction.dot(right)
	if absf(side) < 0.2:
		return

	var step := right * signf(side) * player.shimmy_speed * delta
	if player.test_move(player.global_transform, step):
		return # Something's in the way (like an inside corner).

	# Only move if there's still a ledge to hold onto over there.
	var next_ledge := player.find_ledge(player.global_position + step, -_ledge.normal)
	if next_ledge != null and next_ledge.height >= player.hang_min_height:
		_ledge = next_ledge
		player.global_position = player.hang_position(next_ledge)
