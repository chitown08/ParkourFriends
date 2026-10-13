extends PlayerState
## Sliding low along the ground. Starts from a run when you crouch.
## - Slows down gradually on flat ground; slopes speed you up going down.
## - Steer a little with the movement keys.
## - Jump to leap out with your slide speed ("slide-hop").
## - Let go of crouch to stand up (once there's room above you).


func enter(_data: Dictionary) -> void:
	player.set_crouched(true)
	# A small burst of speed, but not one you can stack by sliding repeatedly.
	var horizontal := Vector3(player.velocity.x, 0.0, player.velocity.z)
	var speed := horizontal.length()
	var boosted_cap := player.sprint_speed + player.slide_boost
	if speed < boosted_cap and speed > 0.01:
		var boosted := minf(speed + player.slide_boost, boosted_cap)
		player.velocity.x = horizontal.x / speed * boosted
		player.velocity.z = horizontal.z / speed * boosted


func physics_update(delta: float) -> void:
	if player.consume_jump() and player.can_stand():
		player.set_crouched(false)
		player.velocity.y = player.jump_velocity
		player.move_and_slide()
		player.change_state(&"Air", {"jumped": true})
		return

	var horizontal := Vector3(player.velocity.x, 0.0, player.velocity.z)
	var speed := horizontal.length()
	var direction := horizontal / speed if speed > 0.01 else Vector3.ZERO

	# Steer gently toward the input direction.
	var wish_dir := input.move_direction
	if wish_dir.length() > 0.1 and direction != Vector3.ZERO:
		var angle := direction.signed_angle_to(wish_dir.normalized(), Vector3.UP)
		var max_turn := player.slide_steer_speed * delta
		direction = direction.rotated(Vector3.UP, clampf(angle, -max_turn, max_turn))

	horizontal = direction * speed
	if player.is_on_floor():
		# Slopes: the steeper the downhill, the more you speed up (uphill slows you).
		var floor_normal := player.get_floor_normal()
		var downhill := Vector3.DOWN - floor_normal * Vector3.DOWN.dot(floor_normal)
		horizontal += Vector3(downhill.x, 0.0, downhill.z) * player.slide_slope_gravity * delta
		speed = horizontal.length()
		if speed > 0.01:
			direction = horizontal / speed
		speed = maxf(speed - player.slide_friction * delta, 0.0)
	else:
		player.apply_gravity(delta)
	speed = minf(speed, player.slide_max_speed)

	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	player.move_and_slide()
	player.face_direction(direction, delta)

	if not player.is_on_floor() and player.can_stand():
		# Slid off an edge: you can still jump for a moment.
		player.set_crouched(false)
		player.change_state(&"Air", {"coyote": true})
	elif not input.crouch_held and player.can_stand():
		player.set_crouched(false)
		player.change_state(&"Ground")
	elif player.get_horizontal_speed() < player.slide_end_speed:
		player.change_state(&"Crouch")
