extends PlayerState
## Jumping or falling. From here you can:
## - grab a ledge (push toward a wall near its top),
## - grab a drainpipe (push toward it),
## - grab a hanging friend's feet (a hanging chain),
## - be caught by a friend at the edge you're falling short of,
## - wall jump (press jump next to a wall),
## - start a wall run (move fast alongside a tall wall).
## - scramble up a wall too tall to grab (push straight into it),
## - land on a grind rail (come down on it).
## (Not the ones that need your hands while you hold a bulky item.)

var _coyote_timer := 0.0
var _regrab_timer := 0.0
var _control_lock_timer := 0.0
var _holding_jump := false


func enter(data: Dictionary) -> void:
	_coyote_timer = player.coyote_time if data.get("coyote", false) else 0.0
	_regrab_timer = data.get("regrab_delay", 0.0)
	_control_lock_timer = data.get("control_lock", 0.0)
	_holding_jump = data.get("jumped", false)


func physics_update(delta: float) -> void:
	_coyote_timer -= delta
	_regrab_timer -= delta
	_control_lock_timer -= delta

	if _coyote_timer > 0.0 and player.consume_jump():
		player.velocity.y = player.jump_velocity
		_coyote_timer = 0.0
		_holding_jump = true
	elif player.has_jump_buffered() and _try_wall_jump():
		return

	# Variable jump height: let go of jump early for a short hop.
	if _holding_jump and not input.jump_held and player.velocity.y > 0.0:
		player.velocity.y *= player.jump_cut
		_holding_jump = false

	player.apply_gravity(delta)
	if _control_lock_timer <= 0.0:
		player.move_horizontally(delta, player.air_acceleration, player.air_friction, -1.0, true)
	player.move_and_slide()
	player.face_direction(input.move_direction, delta)

	if player.is_on_floor():
		# Come down on a window ledge: hang from it (there's no room to stand).
		var lip := player.ledge_lip_under()
		if lip:
			player.change_state(&"Hang", {"ledge": lip})
		else:
			player.change_state(&"Ground")
		return

	if _try_land_on_rail():
		return
	# Ledges and scrambles need your hands free of bulky items.
	# (In a chimney you kick across rather than scramble up the wall you meet;
	# but a ledge in reach you grab.)
	if not player.hands_busy() and (_try_get_caught() or _try_grab_friend() or _try_grab_zip_line() or _try_grab_pipe() or _try_grab_ledge() or _try_chimney() or _try_wall_scramble()):
		return
	_try_wall_run()


## Grabs the feet of a friend hanging just above you (a hanging chain), near
## the top of a jump or coming down.
func _try_grab_friend() -> bool:
	if _regrab_timer > 0.0 or player.velocity.y > player.ledge_grab_max_rise_speed:
		return false
	var friend := player.find_friend_to_hang_from()
	if friend == null:
		return false
	player.change_state(&"ChainHang", {"anchor": friend, "toward_wall": friend.facing_direction()})
	return true


## A friend at the edge you're falling short of catches you (see
## Player.find_catcher()).
func _try_get_caught() -> bool:
	if _regrab_timer > 0.0 or player.velocity.y > 0.0:
		return false
	var catch := player.find_catcher()
	if catch.is_empty():
		return false
	player.change_state(&"Caught", catch)
	return true


## Catches hold of a zip line your hands come to (jumping up into it, or
## falling past it), anywhere but right at its bottom.
func _try_grab_zip_line() -> bool:
	if _regrab_timer > 0.0:
		return false
	var hands := player.global_position + Vector3.UP * ZipLine.HANDS
	for line: ZipLine in player.get_tree().get_nodes_in_group(&"zip_lines"):
		var along := line.closest_distance(hands)
		if along < line.length() - 3.0 and line.point_at(along).distance_to(hands) <= ZipLine.GRAB_REACH:
			player.change_state(&"Zip", {"line": line})
			return true
	return false


func _try_grab_pipe() -> bool:
	if _regrab_timer > 0.0:
		return false
	var pipe := player.find_drainpipe()
	if pipe == null:
		return false
	player.change_state(&"PipeClimb", {"pipe": pipe})
	return true


## Climbing a chimney (a narrow gap between two walls, like an alley between
## towers): free-running with jump held, each wall you come to kicks you
## straight across to the one facing it, a little higher each time.
func _try_chimney() -> bool:
	return player.try_chimney_kick()


func _try_wall_jump() -> bool:
	var wall := player.find_wall()
	if wall.is_empty() or not player.can_use_wall(wall.normal):
		return false
	player.consume_jump()
	# Keep the speed you had along the wall, lose the part going into it.
	var horizontal := Vector3(player.velocity.x, 0.0, player.velocity.z)
	var along: Vector3 = horizontal - wall.normal * horizontal.dot(wall.normal)
	player.wall_jump(wall.normal, along)
	return true


func _try_grab_ledge() -> bool:
	# Only near the top of a jump or while falling, and only when pushing
	# toward the wall, so you can still jump straight up onto things or fall
	# past a ledge on purpose.
	if _regrab_timer > 0.0 or player.velocity.y > player.ledge_grab_max_rise_speed:
		return false
	var wish_dir := input.move_direction
	if wish_dir.length() < 0.3:
		return false

	var ledge := player.find_ledge(player.global_position, wish_dir)
	if ledge == null or wish_dir.normalized().dot(-ledge.normal) < 0.5:
		return false

	if ledge.height >= player.hang_min_height:
		player.change_state(&"Hang", {"ledge": ledge})
	elif ledge.can_stand:
		# Low enough to vault straight over without hanging ("mantle").
		player.change_state(&"Climb", {"ledge": ledge, "duration": player.mantle_time})
	else:
		return false # A sill too low to hang from and too narrow to stand on.
	return true


func _try_wall_run() -> void:
	var wish_dir := input.move_direction
	if wish_dir.length() < 0.3 or player.is_near_ground(player.wall_run_min_height):
		return
	if player.is_under_ceiling(player.wall_run_headroom):
		return # (Too low to run up the wall: a fire escape's next deck, say.)
	var wall := player.find_wall(true)
	if wall.is_empty() or not player.can_use_wall(wall.normal):
		return
	# You must be moving fast *along* the wall, and steering that way too.
	var horizontal := Vector3(player.velocity.x, 0.0, player.velocity.z)
	var along: Vector3 = horizontal - wall.normal * horizontal.dot(wall.normal)
	if along.length() < player.wall_run_min_speed or wish_dir.normalized().dot(along.normalized()) < 0.5:
		return
	if player.wall_run_blocked(along.normalized()):
		return # Something to climb just ahead (like the next fire escape step).
	player.change_state(&"WallRun", {"wall_normal": wall.normal})


## Lands you on a grind rail if your feet come down on (or close to) one.
func _try_land_on_rail() -> bool:
	if player.grind_cooldown > 0.0 or player.velocity.y > 0.0:
		return false # (Going up: you'd pass through it from below.)
	var feet := player.global_position
	for rail: GrindRail in player.get_tree().get_nodes_in_group(&"grind_rails"):
		var along := rail.closest_distance(feet)
		var spot := rail.point_at_distance(along)
		# (Not right at an end: you'd only be flung straight off.)
		if along > 0.3 and along < rail.length() - 0.8 and feet.y > spot.y - 0.3 and spot.distance_to(feet) <= player.grind_land_radius:
			player.change_state(&"Grind", {"rail": rail})
			return true
	return false


func _try_wall_scramble() -> bool:
	# Pushing straight into a tall wall near the top of a jump (or just after).
	# Never while rising faster than a scramble would carry you (e.g. a toss).
	var wish_dir := input.move_direction
	if wish_dir.length() < 0.3 or player.velocity.y < -2.0 or player.velocity.y > player.wall_scramble_speed:
		return false
	var wall := player.find_wall(true)
	if wall.is_empty() or not player.can_use_wall(wall.normal):
		return false
	if wish_dir.normalized().dot(-(wall.normal as Vector3)) < 0.7:
		return false
	player.change_state(&"WallScramble", {"wall_normal": wall.normal})
	return true
