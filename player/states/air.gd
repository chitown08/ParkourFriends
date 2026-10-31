extends PlayerState
## Jumping or falling. From here you can:
## - grab a ledge (push toward a wall near its top),
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
		player.change_state(&"Ground")
		return

	if _try_land_on_rail():
		return
	# Ledges and scrambles need your hands free of bulky items.
	if not player.hands_busy() and (_try_grab_ledge() or _try_wall_scramble()):
		return
	_try_wall_run()


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
		var t := rail.closest_t(feet)
		var spot := rail.point_at(t)
		if t < 0.98 and feet.y > spot.y - 0.3 and spot.distance_to(feet) <= player.grind_land_radius:
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
