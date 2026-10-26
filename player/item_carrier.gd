class_name ItemCarrier
extends Node
## The player's side of items: two slots (hands = the active item, back),
## the item buttons, and running the ability of whatever's in your hands.
##   F / X       -> pick up the nearest item (if you have a free slot);
##                  otherwise drop the item in your hands, or hand it to the
##                  friend you're facing
##   T / Y       -> throw the item in your hands where the camera points
##   Tab / D-pad -> swap hands and back
##   Right mouse / left trigger -> use the item in your hands
## The host decides what actually happens (see WorldItem); this only asks.

## How close (metres) an item must be to pick it up, or a friend to hand it to.
const PICKUP_RANGE := 2.0

var player: Player

var _ability: ItemAbility
var _ability_item: WorldItem


## Called by the Player each tick (its own computer only), after it has moved.
func physics_update(delta: float) -> void:
	var input := player.input
	if input.interact_just_pressed:
		_interact()
	if input.throw_item_just_pressed:
		var in_hands := hands_item()
		if in_hands:
			in_hands.request_throw.rpc_id(1, player.aim_direction())
	if input.switch_item_just_pressed:
		request_swap.rpc_id(1)

	_update_ability()
	if _ability:
		_ability.physics_update(player, delta)
		if input.use_item_just_pressed:
			_ability.use(player)


func hands_item() -> WorldItem:
	return _held_in(WorldItem.HANDS)


func back_item() -> WorldItem:
	return _held_in(WorldItem.BACK)


func has_free_slot() -> bool:
	return hands_item() == null or back_item() == null


## The closest item lying in the world within reach (or null).
func nearest_item() -> WorldItem:
	var best: WorldItem = null
	var best_distance := PICKUP_RANGE
	var chest := player.global_position + Vector3.UP * 0.9
	for item: WorldItem in player.get_tree().get_nodes_in_group(&"items"):
		if item.state != WorldItem.State.IN_WORLD or not _same_game(item):
			continue
		var distance := chest.distance_to(item.global_position)
		if distance < best_distance:
			best_distance = distance
			best = item
	return best


## The friend in front of you within reach, if any (for handing items over).
func friend_in_front() -> Player:
	var forward := Vector3.FORWARD.rotated(Vector3.UP, player.camera_rig.yaw)
	for other in player.get_parent().get_children():
		var friend := other as Player
		if friend == null or friend == player or friend.is_bot:
			continue
		var offset := friend.global_position - player.global_position
		if offset.length() <= PICKUP_RANGE and Vector3(offset.x, 0.0, offset.z).normalized().dot(forward) > 0.3:
			return friend
	return null


## What the HUD should prompt, e.g. "F - pick up Crate" (or "" for nothing).
func prompt_text() -> String:
	var nearby := nearest_item()
	if nearby and has_free_slot():
		return "F - pick up %s" % nearby.display_name()
	var in_hands := hands_item()
	if in_hands:
		var friend := friend_in_front()
		var action := "give %s to your friend" % in_hands.display_name() if friend else "drop %s" % in_hands.display_name()
		return "F - %s    T - throw it" % action
	return ""


## Swap the items in your hands and on your back (runs on the host).
@rpc("any_peer", "call_local", "reliable")
func request_swap() -> void:
	if not multiplayer.is_server():
		return
	for item in _all_held():
		item.slot = WorldItem.BACK if item.slot == WorldItem.HANDS else WorldItem.HANDS


func _interact() -> void:
	var nearby := nearest_item()
	if nearby and has_free_slot():
		nearby.request_pick_up.rpc_id(1)
		return
	var in_hands := hands_item()
	if in_hands:
		var friend := friend_in_front()
		in_hands.request_drop.rpc_id(1, str(friend.name) if friend else "")


## Starts/stops the ability of whatever is in your hands when that changes.
func _update_ability() -> void:
	var in_hands := hands_item()
	if in_hands == _ability_item:
		return
	if _ability:
		_ability.unequipped(player)
	_ability = null
	_ability_item = in_hands
	if in_hands and in_hands.item and in_hands.item.ability:
		_ability = in_hands.item.ability.new() as ItemAbility
		_ability.item = in_hands
		_ability.equipped(player)


func _held_in(slot: int) -> WorldItem:
	for item in _all_held():
		if item.slot == slot:
			return item
	return null


func _all_held() -> Array[WorldItem]:
	var found: Array[WorldItem] = []
	for item: WorldItem in player.get_tree().get_nodes_in_group(&"items"):
		if item.state == WorldItem.State.HELD and item.holder_name == str(player.name) and _same_game(item):
			found.append(item)
	return found


## Items in this game (tests can run two games in one program).
func _same_game(item: WorldItem) -> bool:
	return item._players_node() == player.get_parent()
