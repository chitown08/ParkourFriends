extends PlayerState
## Climbing up a hanging chain of friends (from ChainHang): up over each of
## them to the one at the top, then onto the ledge they hang from. Quicker
## than climbing a wall. If the chain falls apart under you, you drop.

## How fast you climb up your friends (m/s).
const SPEED := 8.0

var _toward_wall := Vector3.ZERO
## The friends above you when you started, from the one you held up to the top.
var _chain: Array[Player] = []


func enter(data: Dictionary) -> void:
	_toward_wall = data["toward_wall"]
	player.velocity = Vector3.ZERO
	_chain.clear()
	var at: Player = data["anchor"]
	while at and not at in _chain:
		_chain.append(at)
		at = player.find_player(at.sync_hanging_on) if at.sync_state == &"ChainHang" else null


func physics_update(delta: float) -> void:
	var top := _top_of_chain()
	if top == null:
		player.change_state(&"Air", {"regrab_delay": player.ledge_regrab_delay})
		return
	player.global_position = player.global_position.move_toward(top.global_position, SPEED * delta)
	player.face_direction(_toward_wall, delta)
	if player.global_position.distance_to(top.global_position) > 0.05:
		return
	# Up level with the friend at the top: onto their ledge.
	var ledge := player.find_ledge(player.global_position, _toward_wall)
	if ledge and ledge.can_stand:
		player.change_state(&"Climb", {"ledge": ledge, "duration": player.climb_up_time})
	elif ledge:
		player.change_state(&"Hang", {"ledge": ledge})
	else:
		player.change_state(&"Air", {"regrab_delay": player.ledge_regrab_delay})


## The friend at the top of the chain you're climbing (the one hanging from the
## ledge, or caught by a friend at it). If they pull up meanwhile, the next one
## down takes their place. Null if nobody in the chain is at the top any more.
func _top_of_chain() -> Player:
	for i in range(_chain.size() - 1, -1, -1):
		if is_instance_valid(_chain[i]) and _chain[i].is_chain_top():
			return _chain[i]
	return null
