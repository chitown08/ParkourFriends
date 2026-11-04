extends PlayerState
## Running round the inside of a tube (levels/pipe.gd), like a loop-the-loop.
## Starts when you run up its side fast enough (see Pipe._physics_process()).
## Gravity slows you going up the wall and speeds you coming down; keep
## steering the way you're going and running pushes you on. Go fast enough and
## you go right round over the top; too slow near the top and you drop off.
## Not fast enough to get high, you swing back down like a half-pipe and run on.
##   Steer        -> around (left/right) and along (forward/back) the tube:
##                   as if the tube were unrolled flat under you
##   Jump         -> jump off the wall, in toward the middle
##   Either end   -> you run (or fly) out
## Your body leans with the wall, so you're upside down on the ceiling.

var _pipe: Pipe
## Where you are: metres in from the tube's start, and angle round from the bottom (radians).
var _along := 0.0
var _angle := 0.0
## How fast you're going along it (toward its end) and round it (increasing angle), m/s.
var _along_speed := 0.0
var _round_speed := 0.0
## Facing toward the tube's end (+1) or its start (-1).
var _facing := 1.0


func enter(data: Dictionary) -> void:
	_pipe = data["pipe"]
	var at := _pipe.locate(player.global_position)
	_along = at.x
	_angle = at.y
	_along_speed = player.velocity.dot(_pipe.along_direction())
	_round_speed = player.velocity.dot(_pipe.around(_angle))
	_facing = 1.0 if _along_speed >= 0.0 else -1.0
	player.refresh_air_moves()


func physics_update(delta: float) -> void:
	if player.consume_jump():
		_leave(player.velocity + _pipe.inward(_angle) * player.jump_velocity, true)
		return

	var radius := _pipe.radius
	# Gravity, round the wall.
	_round_speed -= Pipe.GRAVITY * sin(_angle) * delta
	# Steering, on the tube unrolled flat: left/right is round, forward/back along.
	var wish := Vector2(input.move_direction.dot(_pipe.along_direction()), input.move_direction.dot(_pipe.global_basis.x))
	var speed := Vector2(_along_speed, _round_speed)
	if wish.length() > 0.3:
		wish = wish.normalized()
		# Turn the way you're steering, keeping your speed: run in along the
		# tube, turn across it, and all that speed takes you round. (Not back
		# round once you're sliding back down: that's gravity's.)
		var turn := speed.angle_to(wish)
		if speed.length() > 0.1 and absf(turn) < PI / 2.0:
			speed = speed.rotated(clampf(turn, -Pipe.TURN * delta, Pipe.TURN * delta))
		var going := speed.dot(wish)
		var top := player.top_speed()
		if going < top:
			speed += wish * minf(Pipe.PUSH * delta, top - going)
	_along_speed = speed.x
	_round_speed = speed.y

	_along += _along_speed * delta
	_angle = wrapf(_angle + _round_speed / radius * delta, -PI, PI)
	player.global_position = _pipe.surface_point(_along, _angle)
	player.velocity = _pipe.along_direction() * _along_speed + _pipe.around(_angle) * _round_speed

	if _along < 0.0 or _along > _pipe.length:
		_leave(player.velocity) # Out of an end.
		return
	if _round_speed * _round_speed / radius + Pipe.GRAVITY * cos(_angle) < 0.0:
		_leave(player.velocity) # Too slow to stay up here: you drop off.
		return
	if absf(rad_to_deg(_angle)) < Pipe.SETTLE_ANGLE and absf(_round_speed) < Pipe.SETTLE_SPEED:
		player.change_state(&"Ground") # Back on the floor.
		return

	# Face along the tube, leaning with the wall (lean tips you to your left).
	if absf(_along_speed) > 1.0:
		_facing = signf(_along_speed)
	player.face_direction(_pipe.along_direction() * _facing, delta)
	player.lean = _angle * _facing
	player.body_up = _pipe.inward(_angle)


func _leave(launch: Vector3, jumped := false) -> void:
	# Your body stands upright again: in toward the middle, so it fits.
	if absf(_angle) > deg_to_rad(Pipe.ENTER_ANGLE):
		var middle := _pipe.axis_point(clampf(_along, 0.0, _pipe.length))
		var body_middle := middle - _pipe.inward(_angle) * (_pipe.radius - 1.0)
		player.global_position = body_middle + Vector3.DOWN * 0.9
	player.velocity = launch
	_pipe.block(player, 0.5)
	player.change_state(&"Air", {"jumped": jumped})
