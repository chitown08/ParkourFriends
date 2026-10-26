extends ItemAbility
## The baseball bat: press "use item" (right mouse / left trigger) to swing.
## Hits the friend in front of you (sending them a long way, the way your
## camera faces) or, if no friend is in reach, the item in front of you.
## A hit friend counts as a throw-chain link, like a toss.

const REACH := 2.5 ## Metres in front of you.
const COOLDOWN := 0.6 ## Seconds between swings.
## A hit friend flies at this speed and angle: far, but low and fast.
const LAUNCH_SPEED := 40.0
const LAUNCH_ANGLE := deg_to_rad(40.0)
## A hit item (items fall with normal gravity, so they need less).
const ITEM_LAUNCH_SPEED := 25.0
const ITEM_LAUNCH_ANGLE := deg_to_rad(30.0)

var _cooldown := 0.0


func physics_update(_player: Player, delta: float) -> void:
	_cooldown -= delta


func use(player: Player) -> void:
	if _cooldown > 0.0 or player.state.name not in Player.TOSS_STATES:
		return
	_cooldown = COOLDOWN
	var forward := Vector3.FORWARD.rotated(Vector3.UP, player.camera_rig.yaw)
	var friend := player.find_toss_target(REACH)
	if friend:
		player.launch_friend(friend, _launch(forward, LAUNCH_SPEED, LAUNCH_ANGLE))
		return
	var target := _item_in_front(player, forward)
	if target:
		target.request_hit.rpc_id(1, _launch(forward, ITEM_LAUNCH_SPEED, ITEM_LAUNCH_ANGLE))


func _launch(forward: Vector3, speed: float, angle: float) -> Vector3:
	return (forward * cos(angle) + Vector3.UP * sin(angle)) * speed


## The closest item lying within reach in front of you (or null).
func _item_in_front(player: Player, forward: Vector3) -> WorldItem:
	var best: WorldItem = null
	var best_distance := REACH
	var chest := player.global_position + Vector3.UP * 0.9
	for other in player.items.items_in_world():
		var offset := other.global_position - chest
		var distance := offset.length()
		if distance < best_distance and Vector3(offset.x, 0.0, offset.z).normalized().dot(forward) > 0.3:
			best_distance = distance
			best = other
	return best
