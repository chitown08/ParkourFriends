extends PlayerState
## Standing, running or sprinting on the floor.


func physics_update(delta: float) -> void:
	var jumped := player.consume_jump()
	if jumped:
		player.velocity.y = player.jump_velocity

	player.move_horizontally(delta, player.ground_acceleration, player.ground_friction)
	player.move_and_slide()
	player.face_direction(input.move_direction, delta)

	if jumped:
		player.change_state(&"Air", {"jumped": true})
	elif not player.is_on_floor():
		# Ran off an edge: allow a late "coyote" jump for a moment.
		player.change_state(&"Air", {"coyote": true})
