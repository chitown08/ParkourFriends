extends PlayerState
## Grinding a rail: standing on top of it like a
## skateboarder, sliding toward its lower end and speeding up the steeper it is.
## Your hands stay free, so you can carry, throw, toss and swing while you ride.
## (Landing on it: see air.gd.)
##   Jump        -> jump off, keeping your speed
##   Crouch      -> step off
##   Bottom end  -> you're flung off forward

var _rail: GrindRail
var _t := 0.0
var _speed := 0.0


func enter(data: Dictionary) -> void:
	_rail = data["rail"]
	_t = _rail.closest_t(player.global_position)
	# Keep the speed you had going down the rail (downhill only: landing on it
	# while heading uphill just starts you sliding back down).
	_speed = maxf(player.velocity.dot(_rail.down_direction()), player.grind_min_speed)
	player.refresh_air_moves()


func physics_update(delta: float) -> void:
	var direction := _rail.down_direction()
	if player.consume_jump():
		_leave(direction * _speed + Vector3.UP * player.jump_velocity * 0.8)
		return
	if input.crouch_just_pressed:
		_leave(direction * _speed)
		return

	# Steeper rail = faster acceleration.
	_speed = minf(_speed + player.grind_gravity * -direction.y * delta, player.grind_max_speed)
	_t += _speed * delta / _rail.length()
	if _t >= 1.0:
		_leave(direction * _speed) # Flung off the bottom end.
		return
	player.global_position = _rail.point_at(_t) + Vector3.UP * GrindRail.RAIL_RADIUS
	player.velocity = direction * _speed
	# Side-on to the rail, like a board slide.
	player.face_direction(direction.cross(Vector3.UP), delta)


func _leave(launch: Vector3) -> void:
	player.velocity = launch
	player.grind_cooldown = player.grind_land_delay
	player.change_state(&"Air", {"jumped": launch.y > 0.0})
