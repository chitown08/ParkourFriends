extends PlayerState
## Climbing a drainpipe (levels/drainpipe.gd): a slow but sure way back up a
## building. Starts when you run or jump into one (see Player.find_drainpipe()).
##   Push toward the wall -> climb up (pipe_climb_speed); free-run climbs for you
##   Pull away from it    -> slide back down
##   Near the top         -> pull yourself onto the roof
##   Jump                 -> kick off the wall
##   Crouch               -> let go

## How tightly you're held to the pipe (per second).
const HOLD := 15.0

var _pipe: Drainpipe


func enter(data: Dictionary) -> void:
	_pipe = data["pipe"]
	player.velocity = Vector3.ZERO
	player.refresh_air_moves()


func physics_update(delta: float) -> void:
	var out := _pipe.out_of_wall()
	if player.consume_jump():
		player.last_wall_normal = Vector3.ZERO
		player.wall_jump(out, Vector3.ZERO)
		return
	if input.crouch_just_pressed:
		player.change_state(&"Air", {"regrab_delay": 0.5})
		return

	var push := 1.0 if input.free_run_held else input.move_direction.dot(-out)
	var climb := 0.0
	if push > 0.3:
		climb = player.pipe_climb_speed
	elif push < -0.3:
		climb = -player.pipe_slide_speed
	var feet := player.global_position
	if feet.y >= _pipe.top() - 0.3:
		climb = minf(climb, 0.0) # The top of the pipe.
	# Hug the pipe, moving with collisions (never pushed into the wall).
	var hold := _pipe.point_at(feet.y) + out * (Drainpipe.RADIUS + player.body_radius + 0.05)
	var to_hold := Vector3(hold.x - feet.x, 0.0, hold.z - feet.z)
	player.velocity = to_hold * HOLD + Vector3.UP * climb
	player.move_and_slide()
	player.face_direction(-out, delta)

	if climb >= 0.0:
		var ledge := player.find_ledge(player.global_position, -out)
		if ledge and ledge.can_stand:
			player.change_state(&"Climb", {"ledge": ledge, "duration": player.climb_up_time})
			return
	if climb < 0.0 and player.is_on_floor():
		player.change_state(&"Ground")
