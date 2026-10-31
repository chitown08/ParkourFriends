extends PlayerState
## Grinding a rail: standing on top of it like a skateboarder. The rail slides
## you toward its lower end, speeding up the steeper it is. Push up the rail to
## go up it instead: slower (grind_climb_speed), but all the way to the top if
## you keep at it. Your hands stay free, so you can carry, throw, toss and
## swing while you ride. (Landing on it: see air.gd.)
##   Jump        -> jump off, keeping your speed (jump up along it and you
##                  land further up: quicker than climbing, if you keep hopping)
##   Crouch      -> step off
##   Either end  -> you're flung off forward

var _rail: GrindRail
var _t := 0.0
## How fast you're going along the rail: positive down it, negative up it.
var _speed := 0.0


func enter(data: Dictionary) -> void:
	_rail = data["rail"]
	_t = _rail.closest_t(player.global_position)
	# Keep the speed you had along the rail, either way.
	_speed = player.velocity.dot(_rail.down_direction())
	if _speed >= 0.0:
		_speed = maxf(_speed, player.grind_min_speed)
	player.refresh_air_moves()


func physics_update(delta: float) -> void:
	var direction := _rail.down_direction()
	if player.consume_jump():
		_leave(direction * _speed + Vector3.UP * player.jump_velocity * 0.8, true)
		return
	if input.crouch_just_pressed:
		_leave(direction * _speed)
		return

	# Steeper rail = faster acceleration (downhill).
	var pull := player.grind_gravity * -direction.y * delta
	if _pushing_up(direction):
		if _speed > -player.grind_climb_speed:
			# Slow down (if sliding) and work up to climbing speed.
			_speed = move_toward(_speed, -player.grind_climb_speed, player.grind_climb_acceleration * delta)
		else:
			# Faster than that (you came in fast): the slope eats the extra.
			_speed = minf(_speed + pull, -player.grind_climb_speed)
	else:
		_speed = minf(_speed + pull, player.grind_max_speed)
	_t += _speed * delta / _rail.length()
	if _t >= 1.0 or _t <= 0.0:
		_leave(direction * _speed) # Flung off the end.
		return
	player.global_position = _rail.point_at(_t) + Vector3.UP * GrindRail.RAIL_RADIUS
	player.velocity = direction * _speed
	# Side-on to the rail, like a board slide.
	player.face_direction(direction.cross(Vector3.UP), delta)


## True if you're steering up the rail.
func _pushing_up(direction: Vector3) -> bool:
	var up_the_rail := -Vector3(direction.x, 0.0, direction.z).normalized()
	return input.move_direction.length() > 0.3 and input.move_direction.normalized().dot(up_the_rail) > 0.5


func _leave(launch: Vector3, jumped := false) -> void:
	player.velocity = launch
	# Stepping or being flung off, don't land straight back on. (Jumping is
	# fine: you can only land coming down, so a hop up along it lands further on.)
	player.grind_cooldown = 0.0 if jumped else player.grind_land_delay
	player.change_state(&"Air", {"jumped": jumped})
