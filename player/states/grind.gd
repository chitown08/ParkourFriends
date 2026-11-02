extends PlayerState
## Grinding a rail: standing on top of it like a skateboarder. Wherever you
## are on it, its slope there pulls you downhill (the steeper, the harder), so
## on a curved rail you speed up down the dips and slow on the rises. Push
## along it to go up it (slower, grind_climb_speed, but all the way if you
## keep at it) or along a flat stretch. Your hands stay free, so you can carry,
## throw, toss and swing while you ride. (Landing on it: see air.gd.)
##   Jump        -> jump off, keeping your speed (jump up along it and you
##                  land further up: quicker than climbing, if you keep hopping)
##   Crouch      -> step off
##   Either end  -> you're flung off forward

var _rail: GrindRail
## Where you are: metres along the rail from its start.
var _distance := 0.0
## How fast you're going along the rail: positive toward its end, negative toward its start.
var _speed := 0.0


func enter(data: Dictionary) -> void:
	_rail = data["rail"]
	_distance = _rail.closest_distance(player.global_position)
	var direction := _rail.direction_at(_distance)
	# Keep the speed you had along the rail, either way; going down a slope (or
	# landing still), at least the slowest ride downhill.
	_speed = player.velocity.dot(direction)
	var downhill := -signf(direction.y) if absf(direction.y) > 0.05 else signf(_speed)
	if downhill != 0.0 and _speed * downhill >= 0.0 and _speed * downhill < player.grind_min_speed:
		_speed = downhill * player.grind_min_speed
	player.refresh_air_moves()


func physics_update(delta: float) -> void:
	var direction := _rail.direction_at(_distance)
	if player.consume_jump():
		_leave(direction * _speed + Vector3.UP * player.jump_velocity * 0.8, true)
		return
	if input.crouch_just_pressed:
		_leave(direction * _speed)
		return

	# The slope here pulls you downhill (direction.y < 0: downhill is toward the end).
	_speed += player.grind_gravity * -direction.y * delta
	var push := _pushing_along(direction)
	if push != 0.0 and _speed * push < player.grind_climb_speed:
		# Slower than climbing speed the way you push (or going the other way):
		# work up to it. Faster than that, the slope has its way.
		_speed = move_toward(_speed, push * player.grind_climb_speed, player.grind_climb_acceleration * delta)
	_speed = clampf(_speed, -player.grind_max_speed, player.grind_max_speed)
	_distance += _speed * delta
	if _distance >= _rail.length() or _distance <= 0.0:
		_leave(_rail.direction_at(clampf(_distance, 0.0, _rail.length())) * _speed) # Flung off the end.
		return
	direction = _rail.direction_at(_distance)
	player.global_position = _rail.point_at_distance(_distance) + Vector3.UP * GrindRail.RAIL_RADIUS
	player.velocity = direction * _speed
	# Side-on to the rail, like a board slide.
	player.face_direction(direction.cross(Vector3.UP), delta)


## +1 if you're steering toward the rail's end, -1 toward its start, 0 if neither.
func _pushing_along(direction: Vector3) -> float:
	var along := Vector3(direction.x, 0.0, direction.z).normalized()
	if input.move_direction.length() < 0.3 or along == Vector3.ZERO:
		return 0.0
	var dot := input.move_direction.normalized().dot(along)
	return signf(dot) if absf(dot) > 0.5 else 0.0


func _leave(launch: Vector3, jumped := false) -> void:
	player.velocity = launch
	# Stepping or being flung off, don't land straight back on. (Jumping is
	# fine: you can only land coming down, so a hop up along it lands further on.)
	player.grind_cooldown = 0.0 if jumped else player.grind_land_delay
	player.change_state(&"Air", {"jumped": jumped})
