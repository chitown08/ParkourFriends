extends PlayerState
## Hanging from a friend's feet: a hanging chain. Starts when you jump or
## scramble up to a friend who's hanging (from a ledge, or from someone else)
## with nobody below them yet (see Player.find_friend_to_hang_from()). Each
## of you adds about two metres of reach down the wall.
##   Jump                    -> climb up the chain, over everyone, onto the top
##   Crouch, or pull away    -> let go
##   The friend above climbs up (or past you) -> you move up into their place
##   The friend above lets go                 -> you drop too

var _anchor: Player
## Who the friend above you was hanging from ("" for a ledge), and where they were.
var _above_name := ""
var _above_spot := Vector3.ZERO
## Which way the wall is (you face it, like the friend above).
var _toward_wall := Vector3.ZERO


func enter(data: Dictionary) -> void:
	_anchor = data["anchor"]
	_toward_wall = data["toward_wall"]
	_remember_above()
	player.velocity = Vector3.ZERO
	player.refresh_air_moves()
	player.sync_hanging_on = str(_anchor.name)


func exit() -> void:
	player.sync_hanging_on = ""


## The friend you're hanging from.
func anchor() -> Player:
	return _anchor


func physics_update(delta: float) -> void:
	if not is_instance_valid(_anchor) or not _anchor.sync_state in Player.CHAIN_STATES:
		_anchor_moved_on()
		return
	_remember_above()

	# Your hands at their feet.
	var target := _anchor.global_position + Vector3.DOWN * player.hang_height
	player.global_position = player.global_position.move_toward(target, player.hang_snap_speed * delta)
	player.face_direction(_toward_wall, delta)

	if player.consume_jump():
		player.change_state(&"ChainClimb", {"anchor": _anchor, "toward_wall": _toward_wall})
	elif input.crouch_just_pressed or input.move_direction.dot(_toward_wall) < -0.5:
		player.change_state(&"Air", {"regrab_delay": player.ledge_regrab_delay})


func _remember_above() -> void:
	_above_name = _anchor.sync_hanging_on
	_above_spot = _anchor.global_position


## The friend above you isn't hanging any more: if they went up (pulled
## themselves up or are climbing past), take their place; if they let go, so do you.
func _anchor_moved_on() -> void:
	var went_up := is_instance_valid(_anchor) and _anchor.sync_state in [&"Climb", &"ChainClimb", &"Ground"]
	if went_up:
		if _above_name != "":
			var above := player.find_player(_above_name)
			if above and above.sync_state in Player.CHAIN_STATES:
				player.change_state(&"ChainHang", {"anchor": above, "toward_wall": _toward_wall})
				return
		else:
			# They were on the ledge: hang from it where they did.
			var ledge := player.find_ledge(_above_spot + Vector3.DOWN * 0.2, _toward_wall)
			if ledge and ledge.height >= player.hang_min_height:
				player.change_state(&"Hang", {"ledge": ledge})
				return
	player.change_state(&"Air", {"regrab_delay": player.ledge_regrab_delay})
