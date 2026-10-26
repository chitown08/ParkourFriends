class_name WorldItem
extends RigidBody3D
## A physical item: lies in the world (real physics), can be held by a player,
## and returns home if it falls off the map or is left lying around.
##
## The host is in charge of every item: it runs the item's physics and decides
## who holds it. Players' computers ask the host (request_* functions below),
## and the ItemSync node shares the result with everyone. To make a new kind of
## item, make an ItemData (see item_data.gd) and set it as `item`.

enum State { IN_WORLD, HELD, RETURNING }

## How close (metres from your chest) a thrown item must pass to be caught.
const CATCH_DISTANCE := 1.3
## A thrower can't catch their own throw for this long (seconds).
const OWN_CATCH_DELAY := 0.4
## How long an item disappears for before reappearing at home (seconds).
const RETURN_DELAY := 2.0
## Slots: 0 = hands (the active item), 1 = back.
const HANDS := 0
const BACK := 1

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


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_host_update(delta)
		if state == State.IN_WORLD:
			sync_transform = global_transform
	elif state == State.IN_WORLD:
		global_transform = global_transform.interpolate_with(sync_transform, 0.5)
	if state == State.HELD:
		var holder := find_player(holder_name)
		if holder:
			global_transform = holder.item_anchor(slot)


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


## The holder asks to drop it, or hand it to the friend named `give_to`.
@rpc("any_peer", "call_local", "reliable")
func request_drop(give_to: String) -> void:
	var player := _sender()
	if player == null or holder_name != str(player.name):
		return
	var friend := find_player(give_to)
	if friend and _free_slot(friend) != -1 and friend.global_position.distance_to(player.global_position) < ItemCarrier.PICKUP_RANGE * 2.0:
		host_give_to(friend)
		return
	_release(player, player.velocity * 0.5)


## The holder asks to throw it in direction `aim`.
@rpc("any_peer", "call_local", "reliable")
func request_throw(aim: Vector3) -> void:
	var player := _sender()
	if player == null or holder_name != str(player.name):
		return
	var throw_speed := item.throw_speed if item else 14.0
	_release(player, aim.normalized() * throw_speed + Vector3.UP * 3.0 + player.velocity * 0.5)
	_thrown_by = str(player.name)
	_own_catch_timer = OWN_CATCH_DELAY


# --- Host-side changes ---------------------------------------------------------

## Puts the item in `player`'s hands (their current hand item moves to their back).
## Returns false if both their slots are full.
func host_give_to(player: Player) -> bool:
	var free := _free_slot(player)
	if free == -1:
		return false
	if free == BACK:
		# Hands are full: that item moves to the back, the new one goes in the hands.
		for other in held_by(player):
			other.slot = BACK
	state = State.HELD
	holder_name = str(player.name)
	slot = HANDS
	_idle_time = 0.0
	_thrown_by = ""
	_apply_state()
	return true


## Sends the item straight home (after a short disappearance).
func host_return_home() -> void:
	state = State.RETURNING
	holder_name = ""
	_return_timer = RETURN_DELAY
	_apply_state()


func _release(player: Player, launch: Vector3) -> void:
	var hand := player.item_anchor(HANDS)
	state = State.IN_WORLD
	holder_name = ""
	_idle_time = 0.0
	_thrown_by = "" # Set again by request_throw() if this is a throw.
	# Every other item they hold moves to their hands.
	for other in held_by(player):
		if other != self:
			other.slot = HANDS
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
				_apply_state()
				global_transform = _home
				linear_velocity = Vector3.ZERO
				angular_velocity = Vector3.ZERO
				sync_transform = _home


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
	visible = state != State.RETURNING
	var in_world := state == State.IN_WORLD
	# Only the host simulates items; everyone else just shows where they are.
	freeze = not (in_world and multiplayer.is_server())
	_shape.set_deferred(&"disabled", not in_world)


## The first free slot `player` has (hands first), or -1 if both are full.
func _free_slot(player: Player) -> int:
	var used := {}
	for other in held_by(player):
		used[other.slot] = true
	if not used.has(HANDS):
		return HANDS
	if not used.has(BACK):
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
