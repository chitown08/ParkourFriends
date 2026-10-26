class_name WorldItem
extends RigidBody3D
## A physical item: lies in the world (real physics), can be held by a player,
## and returns home if it falls off the map or is left lying around.
##
## The host is in charge of every item: it runs the item's physics and decides
## who holds it. Players' computers ask the host (request_* functions below),
## and the ItemSync node shares the result with everyone. To make a new kind of
## item, make an ItemData (see item_data.gd) and set it as `item`.

enum State { IN_WORLD, HELD, RETURNING, DELIVERED }

## How close (metres from your chest) a thrown item must pass to be caught.
const CATCH_DISTANCE := 1.3
## A thrower can't catch their own throw for this long (seconds).
const OWN_CATCH_DELAY := 0.4
## How long an item disappears for before reappearing at home (seconds).
const RETURN_DELAY := 2.0
## Slots: hands (the active item), back (stowed in a backpack), and the
## backpack itself, worn. Everyone has hands; only a backpack gives a back slot.
const HANDS := 0
const BACK := 1
const WORN := 2

@export var item: ItemData

# Shared with everyone by the ItemSync node (the host decides them).
var state := State.IN_WORLD
## Node name of the player holding it ("" if nobody).
var holder_name := ""
var slot := HANDS
var sync_transform := Transform3D.IDENTITY

var _home: Transform3D
var _idle_time := 0.0
var _return_timer := 0.0
## Who threw it ("" if it wasn't thrown). Only thrown items can be caught.
var _thrown_by := ""
var _own_catch_timer := 0.0
## Still sitting untouched at home (items that hover stay put until taken).
var _at_home := true
var _applied_state := State.IN_WORLD

@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _mesh: MeshInstance3D = $Mesh


func _enter_tree() -> void:
	set_multiplayer_authority(1) # The host is in charge of items.


func _ready() -> void:
	add_to_group(&"items")
	_home = global_transform
	sync_transform = global_transform
	_build_looks()
	if item:
		mass = item.mass
	_apply_state()


func display_name() -> String:
	return item.display_name if item else "Item"


## True if this item needs both hands (you can't climb while holding it).
func is_bulky() -> bool:
	return item != null and item.bulky


func is_backpack() -> bool:
	return item != null and item.is_backpack


func is_deliverable() -> bool:
	return item != null and item.deliverable


## Still sitting untouched at its home spot. (Only the host knows for sure;
## other computers go by whether it's where it started.)
func is_at_home() -> bool:
	var in_place := global_position.distance_to(_home.origin) < 0.1
	return in_place and (_at_home or not multiplayer.is_server())


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_host_update(delta)
		if state == State.IN_WORLD:
			sync_transform = global_transform
	else:
		if state != _applied_state:
			_apply_state() # The host changed it.
		if state == State.IN_WORLD:
			global_transform = global_transform.interpolate_with(sync_transform, 0.5)
	if state == State.HELD:
		var holder := find_player(holder_name)
		if holder:
			global_transform = holder.item_anchor(slot, is_bulky())


# --- Requests from players' computers (always run on the host) -----------------

## A player asks to pick this item up.
@rpc("any_peer", "call_local", "reliable")
func request_pick_up() -> void:
	var player := _sender()
	if player == null or state != State.IN_WORLD:
		return # Someone else got it first, or it's on its way home.
	if player.global_position.distance_to(global_position) > ItemCarrier.PICKUP_RANGE * 2.0:
		return # Too far away (generous: their view of us is a moment old).
	host_give_to(player)


## A player ran into this pick-up-on-touch item (collectibles). Only works
## while it's at home, so you don't instantly re-grab one you dropped or threw.
@rpc("any_peer", "call_local", "reliable")
func request_touch_pick_up() -> void:
	if item and item.pick_up_on_touch and is_at_home():
		request_pick_up()


## The holder asks to drop it, or hand it to the friend named `give_to`.
@rpc("any_peer", "call_local", "reliable")
func request_drop(give_to: String) -> void:
	var player := _sender()
	if player == null or holder_name != str(player.name) or slot == BACK:
		return
	var friend := find_player(give_to)
	if friend and free_slot(friend) != -1 and friend.global_position.distance_to(player.global_position) < ItemCarrier.PICKUP_RANGE * 2.0:
		var was_in := slot
		host_give_to(friend)
		_unpack(player, was_in)
		return
	_release(player, player.velocity * 0.5)


## The holder asks to throw it in direction `aim`.
@rpc("any_peer", "call_local", "reliable")
func request_throw(aim: Vector3) -> void:
	var player := _sender()
	if player == null or holder_name != str(player.name) or slot != HANDS:
		return
	var throw_speed := item.throw_speed if item else 14.0
	_release(player, aim.normalized() * throw_speed + Vector3.UP * 3.0 + player.velocity * 0.5)
	_thrown_by = str(player.name)
	_own_catch_timer = OWN_CATCH_DELAY


# --- Host-side changes ---------------------------------------------------------

## Gives the item to `player`: a backpack goes on their back; anything else
## goes in their hands (what was in their hands moves into their backpack).
## Returns false if they have no room for it.
func host_give_to(player: Player) -> bool:
	var free := free_slot(player)
	if free == -1:
		return false
	if free == BACK:
		# Hands are full: that item goes in the backpack, the new one in the hands.
		for other in held_by(player):
			if other.slot == HANDS:
				other.slot = BACK
	state = State.HELD
	holder_name = str(player.name)
	slot = WORN if is_backpack() else HANDS
	_idle_time = 0.0
	_thrown_by = ""
	_at_home = false
	_apply_state()
	return true


## Host only: the item has been delivered to a drop-off and is gone for good.
func host_deliver() -> void:
	state = State.DELIVERED
	holder_name = ""
	_thrown_by = ""
	_apply_state()


## Sends the item straight home (after a short disappearance).
func host_return_home() -> void:
	state = State.RETURNING
	holder_name = ""
	_return_timer = RETURN_DELAY
	_apply_state()


func _release(player: Player, launch: Vector3) -> void:
	var hand := player.item_anchor(HANDS)
	var was_in := slot
	state = State.IN_WORLD
	holder_name = ""
	_idle_time = 0.0
	_thrown_by = "" # Set again by request_throw() if this is a throw.
	_unpack(player, was_in)
	_apply_state()
	global_transform = Transform3D(Basis.IDENTITY, hand.origin)
	linear_velocity = launch
	angular_velocity = Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 4.0
	sync_transform = global_transform


func _host_update(delta: float) -> void:
	match state:
		State.IN_WORLD:
			_own_catch_timer -= delta
			if global_position.y < _kill_height():
				host_return_home()
				return
			# Left lying around away from home: eventually it goes back.
			if global_position.distance_to(_home.origin) > 2.0 and linear_velocity.length() < 0.2:
				_idle_time += delta
				var abandon_time := item.abandon_time if item else 90.0
				if _idle_time >= abandon_time:
					host_return_home()
					return
			else:
				_idle_time = 0.0
			if _thrown_by.is_empty():
				pass
			elif linear_velocity.length() < 3.0:
				_thrown_by = "" # Landed: no longer catchable.
			else:
				_try_catch()
		State.RETURNING:
			_return_timer -= delta
			if _return_timer <= 0.0:
				state = State.IN_WORLD
				_at_home = true
				_apply_state()
				global_transform = _home
				linear_velocity = Vector3.ZERO
				angular_velocity = Vector3.ZERO
				sync_transform = _home


## After this item left `player`'s `was_in` slot: whatever was in their
## backpack comes out into their (now free) hands. (A backpack can only be
## taken off with empty hands, so this works for that too.)
func _unpack(player: Player, was_in: int) -> void:
	if was_in == HANDS or was_in == WORN:
		for other in held_by(player):
			if other.slot == BACK:
				other.slot = HANDS


## A flying item lands in the hands of a player it passes close to (who has room).
func _try_catch() -> void:
	for player in all_players():
		if str(player.name) == _thrown_by and _own_catch_timer > 0.0:
			continue
		var chest := player.global_position + Vector3.UP * 1.1
		if chest.distance_to(global_position) <= CATCH_DISTANCE and host_give_to(player):
			return


# --- Helpers -------------------------------------------------------------------

## Shows/hides the item and turns its physics on or off to match `state`.
func _apply_state() -> void:
	_applied_state = state
	visible = state == State.IN_WORLD or state == State.HELD
	var in_world := state == State.IN_WORLD
	var hovering := _at_home and item != null and item.hovers_at_home
	# Only the host simulates items; everyone else just shows where they are.
	freeze = not (in_world and multiplayer.is_server()) or hovering
	_shape.set_deferred(&"disabled", not in_world)


## The slot this item would go in for `player`, or -1 if they have no room:
## a backpack needs a free back (you can only wear one); anything else goes in
## free hands, or in the backpack (if they wear one with room) when hands are full.
func free_slot(player: Player) -> int:
	var used := {}
	for other in held_by(player):
		used[other.slot] = true
	if is_backpack():
		return -1 if used.has(WORN) else WORN
	if not used.has(HANDS):
		return HANDS
	if used.has(WORN) and not used.has(BACK):
		return BACK
	return -1


## Every item held by `player` in this game.
func held_by(player: Player) -> Array[WorldItem]:
	var found: Array[WorldItem] = []
	for other: WorldItem in get_tree().get_nodes_in_group(&"items"):
		if other.holder_name == str(player.name) and other.state == State.HELD and _same_game(other):
			found.append(other)
	return found


## The player character with this node name in this game (or null).
func find_player(player_name: String) -> Player:
	var players := _players_node()
	if players == null or player_name.is_empty():
		return null
	return players.get_node_or_null(player_name) as Player


func all_players() -> Array[Player]:
	var found: Array[Player] = []
	var players := _players_node()
	if players:
		for child in players.get_children():
			if child is Player and not child.is_bot and not child.is_queued_for_deletion():
				found.append(child)
	return found


## The player who sent the request being handled.
func _sender() -> Player:
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id() # Called on the host itself.
	return find_player(str(sender))


## The game's Players node (the item lives in a world under the same Main).
func _players_node() -> Node:
	var node := get_parent()
	while node:
		if node.has_node(^"Players"):
			return node.get_node(^"Players")
		node = node.get_parent()
	return null


func _same_game(other: WorldItem) -> bool:
	return other._players_node() == _players_node()


func _kill_height() -> float:
	var node := get_parent()
	while node:
		if node is Level:
			return (node as Level).kill_height
		node = node.get_parent()
	return -60.0


func _build_looks() -> void:
	if item == null:
		return
	if item.model:
		_mesh.visible = false
		add_child(item.model.instantiate())
	else:
		var mesh := BoxMesh.new()
		mesh.size = item.size
		var material := StandardMaterial3D.new()
		material.albedo_color = item.color
		mesh.material = material
		_mesh.mesh = mesh
	var shape := BoxShape3D.new()
	shape.size = item.size
	_shape.shape = shape
