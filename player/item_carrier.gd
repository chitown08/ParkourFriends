class_name ItemCarrier
extends Node
## The player's side of items. You carry one thing at a time, in your hands:
## if you aren't holding it, you aren't using it.
##   F / X       -> pick up the nearest item (if your hands are free);
##                  otherwise drop the item in your hands, or hand it to the
##                  friend you're facing
##   Hold F / X  -> throw the item in your hands where the camera points
##                  (with empty hands, it's like a quick press)
##   Left mouse / left trigger -> use the item in your hands
## Some items (collectibles) are picked up just by touching them, while they
## sit at their home spot.
## The host decides what actually happens (see WorldItem); this only asks.

## How close (metres) an item must be to pick it up, or a friend to hand it to.
const PICKUP_RANGE := 2.0
## How close (metres from your middle) a pick-up-on-touch item must be, unless
## the item says otherwise (ItemData.touch_range).
const TOUCH_RANGE := 1.3
## Don't ask the host about the same touched item more often than this (seconds).
const TOUCH_RETRY := 0.2

var player: Player

var _ability: ItemAbility
var _ability_item: WorldItem
var _touch_cooldown := 0.0


## Called by the Player each tick (its own computer only), after it has moved.
func physics_update(delta: float) -> void:
	var input := player.input
	if input.interact_just_pressed:
		_interact()
	if input.throw_item_just_pressed:
		var in_hands := hands_item()
		if in_hands:
			in_hands.request_throw.rpc_id(1, player.aim_direction())
			player.show_effect(&"show_action", [&"throw"])
		else:
			_interact()
	_pick_up_touched(delta)

	_update_ability()
	if _ability:
		_ability.physics_update(player, delta)
		if input.use_item_just_pressed:
			_ability.use(player)


func hands_item() -> WorldItem:
	var held := _all_held()
	return held[0] if not held.is_empty() else null


## True while the item in your hands needs both of them (no climbing).
func hands_busy() -> bool:
	var in_hands := hands_item()
	return in_hands != null and in_hands.is_bulky()


func can_take(item: WorldItem) -> bool:
	return item.has_room(player)


## The closest item lying in the world within reach that you have room for (or null).
func nearest_item() -> WorldItem:
	var best: WorldItem = null
	var best_distance := PICKUP_RANGE
	var chest := player.global_position + Vector3.UP * 0.9
	for item in items_in_world():
		var distance := chest.distance_to(item.global_position)
		if distance < best_distance and can_take(item):
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


## What the item controls would do right now, for the on-screen hint (see
## Player.control_hints()): [action, words] pairs.
func control_hints() -> Array:
	var nearby := nearest_item()
	if nearby:
		return [[&"interact", "Pick up %s" % nearby.display_name()]]
	var in_hands := hands_item()
	var friend := friend_in_front()
	if in_hands and friend:
		return [[&"interact", "Give %s" % in_hands.display_name()]]
	if _ability and _ability_item == in_hands:
		var use := _ability.use_hint(player)
		if use:
			return [[&"use_item", use]]
	return []


func _interact() -> void:
	var nearby := nearest_item()
	if nearby:
		nearby.request_pick_up.rpc_id(1)
		return
	var to_drop := hands_item()
	if to_drop:
		var friend := friend_in_front()
		to_drop.request_drop.rpc_id(1, str(friend.name) if friend else "")


## Grabs pick-up-on-touch items (collectibles) you run into, if you have room.
func _pick_up_touched(delta: float) -> void:
	_touch_cooldown -= delta
	if _touch_cooldown > 0.0:
		return
	var middle := player.global_position + Vector3.UP * 0.9
	for item in items_in_world():
		if item.item and item.item.pick_up_on_touch and item.is_at_home() and middle.distance_to(item.global_position) <= touch_range_of(item.item) and can_take(item):
			item.request_touch_pick_up.rpc_id(1)
			_touch_cooldown = TOUCH_RETRY
			return


## How close you must pass to pick up `data` by touch.
static func touch_range_of(data: ItemData) -> float:
	return data.touch_range if data.touch_range > 0.0 else TOUCH_RANGE


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


func _all_held() -> Array[WorldItem]:
	var found: Array[WorldItem] = []
	for item: WorldItem in player.get_tree().get_nodes_in_group(&"items"):
		if item.state == WorldItem.State.HELD and item.holder_name == str(player.name) and _same_game(item):
			found.append(item)
	return found


## Items lying in the world in this game (not held, returning or delivered).
func items_in_world() -> Array[WorldItem]:
	var found: Array[WorldItem] = []
	for item: WorldItem in player.get_tree().get_nodes_in_group(&"items"):
		if item.state == WorldItem.State.IN_WORLD and _same_game(item):
			found.append(item)
	return found


## Items in this game (tests can run two games in one program).
func _same_game(item: WorldItem) -> bool:
	return item._players_node() == player.get_parent()
