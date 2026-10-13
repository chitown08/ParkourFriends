extends PlayerState
## Crouched down, walking slowly. Hold crouch to stay down; you only stand
## back up once there's room above you.


func enter(_data: Dictionary) -> void:
	player.set_crouched(true)


func physics_update(delta: float) -> void:
	var jumped := player.consume_jump() and player.can_stand()
	if jumped:
		player.set_crouched(false)
		player.velocity.y = player.jump_velocity
	elif not player.is_on_floor():
		player.apply_gravity(delta)

	player.move_horizontally(delta, player.ground_acceleration, player.ground_friction, player.crouch_speed)
	player.move_and_slide()
	player.face_direction(input.move_direction, delta)

	if jumped:
		player.change_state(&"Air", {"jumped": true})
	elif not player.is_on_floor() and player.can_stand():
		player.set_crouched(false)
		player.change_state(&"Air", {"coyote": true})
	elif not input.crouch_held and player.can_stand():
		player.set_crouched(false)
		player.change_state(&"Ground")
