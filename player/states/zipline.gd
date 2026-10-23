extends PlayerState
## Riding a zipline: hanging under the cable, sliding toward its lower end and
## speeding up the steeper it is. (Grabbing it: see air.gd.)
##   Jump        -> jump off, keeping your speed
##   Crouch      -> let go
##   Bottom end  -> you're flung off forward

var _zipline: Zipline
var _t := 0.0
var _speed := 0.0


func enter(data: Dictionary) -> void:
	_zipline = data["zipline"]
	var hands := player.global_position + Vector3.UP * player.zipline_hang_height
	_t = _zipline.closest_t(hands)
	# Keep the speed you had going down the line (downhill only: grabbing it
	# while heading uphill just starts you sliding back down).
	_speed = maxf(player.velocity.dot(_zipline.down_direction()), player.zipline_min_speed)
	player.refresh_air_moves()


func physics_update(delta: float) -> void:
	var direction := _zipline.down_direction()
	if player.consume_jump():
		_leave(direction * _speed + Vector3.UP * player.jump_velocity * 0.8)
		return
	if input.crouch_just_pressed:
		_leave(direction * _speed)
		return

	# Steeper cable = faster acceleration.
	_speed = minf(_speed + player.zipline_gravity * -direction.y * delta, player.zipline_max_speed)
	_t += _speed * delta / _zipline.length()
	if _t >= 1.0:
		_leave(direction * _speed) # Flung off the bottom end.
		return
	player.global_position = _zipline.point_at(_t) + Vector3.DOWN * player.zipline_hang_height
	player.velocity = direction * _speed
	player.face_direction(direction, delta)


func _leave(launch: Vector3) -> void:
	player.velocity = launch
	player.zipline_cooldown = player.zipline_regrab_delay
	player.change_state(&"Air", {"jumped": launch.y > 0.0})
