extends PlayerState
## Cracking the whip, as the leader of a line (see Player._try_crack_whip()):
## you plant your feet and pivot, turning a quarter turn your way, and the
## line swings round you (Whipped). Then you run on.

var _time := 0.0
var _turn_to := Vector3.ZERO


func enter(data: Dictionary) -> void:
	_time = 0.0
	_turn_to = data["turn_to"]
	player.show_effect(&"show_action", [&"toss"])


func physics_update(delta: float) -> void:
	_time += delta
	var flat := Vector3(player.velocity.x, 0.0, player.velocity.z)
	flat = flat.move_toward(Vector3.ZERO, flat.length() / maxf(Player.WHIP_TIME - _time, delta) * delta)
	player.velocity.x = flat.x
	player.velocity.z = flat.z
	player.apply_gravity(delta)
	player.move_and_slide()
	player.face_direction(_turn_to, delta * 2.0)
	if _time >= Player.WHIP_TIME:
		player.change_state(&"Ground" if player.is_on_floor() else &"Air")
