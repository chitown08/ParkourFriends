extends PlayerState
## Jumping or falling. Grabs ledges when you push toward one.

var _coyote_timer := 0.0
var _regrab_timer := 0.0
var _holding_jump := false


func enter(data: Dictionary) -> void:
	_coyote_timer = player.coyote_time if data.get("coyote", false) else 0.0
	_regrab_timer = data.get("regrab_delay", 0.0)
	_holding_jump = data.get("jumped", false)


func physics_update(delta: float) -> void:
	_coyote_timer -= delta
	_regrab_timer -= delta

	if _coyote_timer > 0.0 and player.consume_jump():
		player.velocity.y = player.jump_velocity
		_coyote_timer = 0.0
		_holding_jump = true

	# Variable jump height: let go of jump early for a short hop.
	if _holding_jump and not input.jump_held and player.velocity.y > 0.0:
		player.velocity.y *= player.jump_cut
		_holding_jump = false

	player.apply_gravity(delta)
	player.move_horizontally(delta, player.air_acceleration, player.air_friction)
	player.move_and_slide()
	player.face_direction(input.move_direction, delta)

	if player.is_on_floor():
		player.change_state(&"Ground")
		return

	_try_grab_ledge()


func _try_grab_ledge() -> void:
	# Only near the top of a jump or while falling, and only when pushing
	# toward the wall, so you can still jump straight up onto things or fall
	# past a ledge on purpose.
	if _regrab_timer > 0.0 or player.velocity.y > player.ledge_grab_max_rise_speed:
		return
	var wish_dir := input.move_direction
	if wish_dir.length() < 0.3:
		return

	var ledge := player.find_ledge(player.global_position, wish_dir)
	if ledge == null or wish_dir.normalized().dot(-ledge.normal) < 0.5:
		return

	if ledge.height >= player.hang_min_height:
		player.change_state(&"Hang", {"ledge": ledge})
	else:
		# Low enough to vault straight over without hanging ("mantle").
		player.change_state(&"Climb", {"ledge": ledge, "duration": player.mantle_time})
