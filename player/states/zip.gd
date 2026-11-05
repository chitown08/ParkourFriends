extends PlayerState
## Whizzing down a zip line (levels/zip_line.gd), hanging from it by your
## hands: the slope pulls you along, faster and faster (up to FASTEST),
## and at the bottom you're flung off onto the roof there. (Grabbing it: see
## air.gd.)
##   Jump    -> let go, keeping your speed (with a little hop)
##   Crouch  -> just let go

## Gravity's pull along it, less a little drag (m/s²), and the speed limits (m/s).
const PULL := 18.0
const SLOWEST := 8.0
const FASTEST := 24.0
## Flung off this far from the bottom (metres), with this much hop (m/s up).
const END_MARGIN := 1.0
const FLING_UP := 4.0

var _line: ZipLine
var _distance := 0.0
var _speed := 0.0


func enter(data: Dictionary) -> void:
	_line = data["line"]
	_distance = _line.closest_distance(player.global_position + Vector3.UP * ZipLine.HANDS)
	_speed = maxf(player.velocity.dot(_line.direction()), SLOWEST)
	player.refresh_air_moves()


func physics_update(delta: float) -> void:
	var direction := _line.direction()
	if player.consume_jump():
		_leave(direction * _speed + Vector3.UP * player.jump_velocity * 0.6)
		return
	if input.crouch_just_pressed:
		_leave(direction * _speed)
		return
	_speed = clampf(_speed + PULL * -direction.y * delta, SLOWEST, FASTEST)
	_distance += _speed * delta
	if _distance >= _line.length() - END_MARGIN:
		_leave(direction * _speed + Vector3.UP * FLING_UP) # Off the end, onto the roof.
		return
	player.global_position = _line.point_at(_distance) + Vector3.DOWN * ZipLine.HANDS
	player.velocity = direction * _speed
	player.face_direction(direction, delta)


func _leave(velocity: Vector3) -> void:
	player.velocity = velocity
	player.change_state(&"Air", {"regrab_delay": 0.6})


## The line you're on and how far down it (for tests).
func line() -> ZipLine:
	return _line
