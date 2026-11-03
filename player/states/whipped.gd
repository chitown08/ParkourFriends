extends PlayerState
## In a line when the leader cracks the whip (Whip state): the line swings a
## quarter turn round them, and each of you is let go going faster the further
## out you are (Player.whip_boost()). The one on the end is flung off into the air.

var _leader: Player
## How many places out from the leader you are (1 = holding their hand).
var _place := 1
## On the end of the line: flung off at the end of the swing.
var _flung := false
## Where you were, from the leader, when the whip cracked (across the ground).
var _from := Vector3.ZERO
## Which way round the line swings (+1 or -1, around up).
var _round := 1.0
var _speed := 0.0
var _time := 0.0


func enter(data: Dictionary) -> void:
	_leader = data["leader"]
	_place = maxi(data["place"], 1)
	_flung = data["flung"]
	# Still holding hands while you swing (so friends further out know their place).
	player.sync_linked_to = str((data["inside"] as Player).name)
	_time = 0.0
	_from = player.global_position - _leader.global_position
	_from.y = 0.0
	_from = _from.normalized() * _place * Player.LINK_SPACING
	# Round the way you were going: you sweep forward, then across.
	var going := Vector3(player.velocity.x, 0.0, player.velocity.z)
	if going.length() < 0.1:
		going = _leader.facing_direction()
	_round = 1.0 if Vector3.UP.cross(_from).dot(going) >= 0.0 else -1.0
	_speed = maxf(going.length(), player.run_speed)


func exit() -> void:
	player.sync_linked_to = ""


func physics_update(delta: float) -> void:
	_time += delta
	if not is_instance_valid(_leader):
		player.change_state(&"Air")
		return
	var turned := _from.rotated(Vector3.UP, _round * PI / 2.0 * minf(_time / Player.WHIP_TIME, 1.0))
	var spot := _leader.global_position + turned
	var offset := Vector3(spot.x - player.global_position.x, 0.0, spot.z - player.global_position.z)
	player.velocity.x = offset.x / delta
	player.velocity.z = offset.z / delta
	player.apply_gravity(delta)
	player.move_and_slide()
	var across := Vector3.UP.cross(turned).normalized() * _round
	player.face_direction(across, delta * 2.0)
	if _time >= Player.WHIP_TIME:
		player.whip_release(across, _speed * Player.whip_boost(_place), _flung)
