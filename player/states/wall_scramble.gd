extends PlayerState
## Running straight up a wall that's too tall to grab from a jump. Starts from
## the air (see air.gd) when you push head-on into a tall wall. Lasts
## wall_scramble_time; grabs the top as soon as it's in reach. Once per wall
## until you land (like wall jumps).
##   Jump       -> kick off the wall
##   Let go     -> drop off

var _wall_normal: Vector3
var _timer := 0.0


func enter(data: Dictionary) -> void:
	_wall_normal = data["wall_normal"]
	player.last_wall_normal = _wall_normal
	_timer = 0.0


func physics_update(delta: float) -> void:
	_timer += delta
	if player.consume_jump():
		player.wall_jump(_wall_normal, Vector3.ZERO)
		return

	# Run up the wall, pressing into it a little so you stay on it.
	player.velocity = -_wall_normal + Vector3.UP * player.wall_scramble_speed
	player.move_and_slide()
	player.face_direction(-_wall_normal, delta)

	var ledge := player.find_ledge(player.global_position, -_wall_normal)
	if ledge and ledge.height >= player.hang_min_height:
		player.change_state(&"Hang", {"ledge": ledge})
	elif ledge and ledge.can_stand:
		player.change_state(&"Climb", {"ledge": ledge, "duration": player.mantle_time})
	elif _timer >= player.wall_scramble_time or input.move_direction.dot(-_wall_normal) < 0.3 \
			or player.find_wall(true).is_empty():
		player.velocity = Vector3.ZERO # Out of steam: fall back down (you might still grab the top).
		player.change_state(&"Air")
