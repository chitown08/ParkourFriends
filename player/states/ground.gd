extends PlayerState
## Standing, running or sprinting on the floor.


func enter(_data: Dictionary) -> void:
	player.last_wall_normal = Vector3.ZERO # Landed: every wall is usable again.
	player.refresh_air_moves()


func physics_update(delta: float) -> void:
	var jumped := player.consume_jump()
	if jumped:
		player.velocity.y = player.jump_velocity
	elif input.crouch_held:
		# Fast enough: slide. Otherwise: just crouch.
		if player.get_horizontal_speed() >= player.slide_min_start_speed:
			player.change_state(&"Slide")
		else:
			player.change_state(&"Crouch")
		player.state.physics_update(delta)
		return

	player.move_horizontally(delta, player.ground_acceleration, player.ground_friction)
	player.move_and_slide()
	player.face_direction(input.move_direction, delta)

	if jumped:
		player.change_state(&"Air", {"jumped": true})
	elif not player.is_on_floor():
		# Ran off an edge: allow a late "coyote" jump for a moment.
		player.change_state(&"Air", {"coyote": true})
