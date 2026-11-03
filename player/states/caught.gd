extends PlayerState
## Caught by a friend at an edge you fell short of (see Player.find_catcher()):
## hanging from their hands right at the edge, as if you'd grabbed it yourself.
## Friends can hang from your feet, like any hanging chain.
##   Jump                 -> climb up over the edge
##   Crouch, or pull away -> let go
##   They let go          -> you drop

var _catcher: Player
## Where your feet hang (you're pulled in to it).
var _spot := Vector3.ZERO
var _toward_wall := Vector3.ZERO
var _time := 0.0


func enter(data: Dictionary) -> void:
	_catcher = data["catcher"]
	_spot = data["spot"]
	_toward_wall = data["toward_wall"]
	_time = 0.0
	player.velocity = Vector3.ZERO
	player.refresh_air_moves()
	player.sync_hanging_on = str(_catcher.name)


func exit() -> void:
	player.sync_hanging_on = ""


func physics_update(delta: float) -> void:
	_time += delta
	# (Their computer takes a moment to see they've caught you.)
	var holding := is_instance_valid(_catcher) and (_catcher.sync_state == &"Catch" \
			or (_time < Player.CATCH_GRACE and _catcher.sync_state in Player.CATCH_FROM))
	if not holding:
		_let_go()
		return

	player.global_position = player.global_position.move_toward(_spot, player.hang_snap_speed * delta)
	player.face_direction(_toward_wall, delta)

	if player.consume_jump():
		var ledge := player.find_ledge(_spot, _toward_wall)
		if ledge and ledge.can_stand:
			player.change_state(&"Climb", {"ledge": ledge, "duration": player.climb_up_time})
		elif ledge:
			player.change_state(&"Hang", {"ledge": ledge})
	elif input.crouch_just_pressed or input.move_direction.dot(_toward_wall) < -0.5:
		_let_go()


func _let_go() -> void:
	player.change_state(&"Air", {"regrab_delay": Player.CATCH_COOLDOWN})
