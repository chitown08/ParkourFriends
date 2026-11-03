extends PlayerState
## Holding hands in a line, for crack the whip (see Player.try_link()): you
## run beside the friend whose hand you hold (the next one in toward the
## leader), all in a row across the leader's way. The leader steers; you're
## carried along, and jump when they jump. When the leader cracks the whip
## (Whip state) you swing round (Whipped).
##   Toss, jump or crouch          -> let go
##   Dragged too far from your spot -> let go (snagged on something)

## How fast you can be pulled back into your spot in the line (m/s).
const CATCH_UP_SPEED := 25.0

var _inside: Player
## Which side of the friend you hold you run on (+1 right, -1 left, as the
## leader faces).
var _side := 1.0


func enter(data: Dictionary) -> void:
	_inside = data["inside"]
	_side = data["side"]
	player.sync_linked_to = str(_inside.name)
	if player.is_crouched and player.can_stand():
		player.set_crouched(false)


func exit() -> void:
	player.sync_linked_to = ""


func physics_update(delta: float) -> void:
	var leader := player.line_leader()
	if not is_instance_valid(_inside) or leader == player or leader.sync_state not in Player.LEADING:
		let_go()
		return
	if leader.sync_state == &"Whip":
		player.change_state(&"Whipped", {"leader": leader, "inside": _inside, "place": player.line().find(player), "flung": player.is_line_end()})
		return

	var heading := leader.facing_direction()
	var spot := _inside.global_position + heading.cross(Vector3.UP).normalized() * _side * Player.LINK_SPACING
	var offset := Vector3(spot.x - player.global_position.x, 0.0, spot.z - player.global_position.z)
	if offset.length() > Player.LINK_BREAK:
		let_go()
		return
	var pull := (offset / delta).limit_length(CATCH_UP_SPEED)
	player.velocity.x = pull.x
	player.velocity.z = pull.z
	if player.is_on_floor() and leader.global_position.y > player.global_position.y + 0.3 and leader.sync_state == &"Air":
		player.velocity.y = player.jump_velocity # They jumped: so do you.
	else:
		player.apply_gravity(delta)
	player.move_and_slide()
	player.face_direction(heading, delta)

	if player.has_jump_buffered() or input.crouch_just_pressed:
		let_go()


## Lets go of your friend's hand (a jump pressed to get here still happens).
func let_go() -> void:
	player.change_state(&"Ground" if player.is_on_floor() else &"Air")
