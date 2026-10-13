extends PlayerState
## Running along a wall. Starts from the air (see air.gd) when you're moving
## fast alongside a tall wall.
##   Jump              -> kick off the wall, keeping your speed
##   Crouch            -> drop off
##   Let go of moving  -> drop off
## You slowly lose height and peel off after wall_run_max_time.

var _wall_normal: Vector3
var _direction: Vector3
var _speed := 0.0
var _timer := 0.0


func enter(data: Dictionary) -> void:
	_wall_normal = data["wall_normal"]
	player.last_wall_normal = _wall_normal
	_timer = 0.0
	var horizontal := Vector3(player.velocity.x, 0.0, player.velocity.z)
	var along := horizontal - _wall_normal * horizontal.dot(_wall_normal)
	_direction = along.normalized()
	_speed = maxf(along.length(), player.wall_run_speed)
	player.velocity = _direction * _speed
	player.velocity.y = player.wall_run_lift


func physics_update(delta: float) -> void:
	_timer += delta
	if player.consume_jump():
		player.wall_jump(_wall_normal, _direction * _speed)
		return

	player.velocity.x = _direction.x * _speed - _wall_normal.x # A slight push into the
	player.velocity.z = _direction.z * _speed - _wall_normal.z # wall keeps you on it.
	player.velocity.y -= player.wall_run_gravity * delta
	player.move_and_slide()
	player.face_direction(_direction, delta)
	player.lean = _lean_angle()

	if player.is_on_floor():
		player.change_state(&"Ground")
	elif input.crouch_just_pressed or input.move_direction.length() < 0.3 or _timer >= player.wall_run_max_time:
		player.change_state(&"Air")
	elif not _still_on_wall():
		player.change_state(&"Air") # Ran past the end of the wall.


func _still_on_wall() -> bool:
	var wall := player.find_wall(true)
	if wall.is_empty() or wall.normal.dot(_wall_normal) < 0.8:
		return false
	# Follow gently curving walls.
	_wall_normal = wall.normal
	_direction = (_direction - _wall_normal * _direction.dot(_wall_normal)).normalized()
	return true


## Lean the body away from the wall: positive tips it to the left.
func _lean_angle() -> float:
	var right := _direction.cross(Vector3.UP)
	var wall_on_right := _wall_normal.dot(right) < 0.0
	return deg_to_rad(player.wall_run_lean_degrees) * (1.0 if wall_on_right else -1.0)
