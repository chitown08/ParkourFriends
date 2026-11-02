extends PlayerState
## Crouched down, walking slowly. Hold crouch to stay down; you only stand
## back up once there's room above you.
## Crouch-walk off an edge and you lower yourself over it and hang from it
## (then a friend can hang from you: a hanging chain).


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
	elif not player.is_on_floor() and _hang_off_edge():
		return
	elif not player.is_on_floor() and player.can_stand():
		player.set_crouched(false)
		player.change_state(&"Air", {"coyote": true})
	elif not input.crouch_held and player.can_stand():
		player.set_crouched(false)
		player.change_state(&"Ground")


## Just walked off an edge: hang from it, facing back toward the wall.
func _hang_off_edge() -> bool:
	var back := -Vector3(player.velocity.x, 0.0, player.velocity.z).normalized()
	if back == Vector3.ZERO or player.hands_busy():
		return false
	# Where your feet will hang: a body's width out from the edge, below it.
	var feet := player.global_position - back * player.body_radius + Vector3.DOWN * player.hang_height
	var ledge := player.find_ledge(feet, back)
	if ledge == null or ledge.height < player.hang_min_height:
		return false
	player.set_crouched(false)
	player.change_state(&"Hang", {"ledge": ledge})
	return true
