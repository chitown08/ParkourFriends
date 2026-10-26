extends MultiplayerTest
## Items with two players: the host decides who holds what, everyone sees the
## same thing, and items can be thrown to, caught by, and handed to friends.
## Uses the Free-Run Line's Crate at (2.5, 0.4, -14).

const BY_CRATE := Vector3(2.5, 0.05, -12.5)
const SPOT := Vector3(0, 0.05, -30) ## Open ground, away from the items.

var host_player: Player
var client_player: Player


func _init() -> void:
	world_id = "free_run_line"


func before_each() -> void:
	await super()
	host_player = host_main.local_player
	client_player = client_main.local_player
	host_player.set_controls_enabled(false) # Buttons are shared; only the client acts.
	await ticks(30) # Let the items settle.


func test_a_joining_player_picks_up_an_item_for_everyone_to_see() -> void:
	await _move(client_player, BY_CRATE)
	await tap(&"interact")
	await ticks(10)
	var client_id := str(client_player.name)
	expect(_crate(host_main).holder_name == client_id, "the host should see the client holding the crate")
	expect(_crate(client_main).holder_name == client_id, "the client should see it too")
	var anchor := host_main.players.get_node(client_id).item_anchor(WorldItem.HANDS, true) as Transform3D
	expect(_crate(host_main).global_position.distance_to(anchor.origin) < 0.5, "on the host's screen it sits in the client's hands")


func test_only_one_player_gets_an_item_grabbed_at_the_same_time() -> void:
	await _move(client_player, BY_CRATE)
	await _move(host_player, BY_CRATE + Vector3(0.5, 0, 0))
	_crate(client_main).request_pick_up.rpc_id(1)
	_crate(host_main).request_pick_up.rpc_id(1)
	await ticks(10)
	var holder := _crate(host_main).holder_name
	expect(holder == "1" or holder == str(client_player.name), "exactly one of them should hold it, holder '%s'" % holder)
	expect(_crate(client_main).holder_name == holder, "and both screens should agree")
	# Grabbing again doesn't snatch it out of the holder's hands.
	var other_side := client_main if holder == "1" else host_main
	_crate(other_side).request_pick_up.rpc_id(1)
	await ticks(10)
	expect(_crate(host_main).holder_name == holder, "a held item can't be grabbed away, holder now '%s'" % _crate(host_main).holder_name)


func test_throw_an_item_to_a_friend_who_catches_it() -> void:
	await _move(client_player, BY_CRATE)
	await tap(&"interact")
	await ticks(5)
	# The host stands 3 m in front of the client; the client throws straight at them.
	await _move(client_player, SPOT)
	await _move(host_player, SPOT + Vector3(0, 0, -3))
	client_player.camera_rig.yaw = 0.0
	client_player.camera_rig.pitch = 0.0
	await tap(&"throw_item")
	await ticks(40)
	expect(_crate(host_main).holder_name == "1", "the host should catch the crate, holder '%s'" % _crate(host_main).holder_name)


func test_hand_an_item_to_the_friend_you_face() -> void:
	await _move(client_player, BY_CRATE)
	await tap(&"interact")
	await ticks(5)
	await _move(client_player, SPOT)
	await _move(host_player, SPOT + Vector3(0, 0, -1.5))
	client_player.camera_rig.yaw = 0.0
	await ticks(10)
	await tap(&"interact")
	await ticks(10)
	expect(_crate(host_main).holder_name == "1", "the crate should be handed to the host, holder '%s'" % _crate(host_main).holder_name)
	expect(_crate(client_main).holder_name == "1", "and the client should see that")


func test_items_held_by_someone_who_leaves_go_home() -> void:
	var home := _crate(host_main).global_position
	await _move(client_player, BY_CRATE)
	await tap(&"interact")
	await ticks(10)
	expect(_crate(host_main).holder_name == str(client_player.name), "test setup: the client holds the crate")
	await _move(client_player, SPOT)
	client_main.leave_game()
	await ticks(roundi(WorldItem.RETURN_DELAY * 60) + 60)
	var crate := _crate(host_main)
	expect(crate.state == WorldItem.State.IN_WORLD and crate.holder_name.is_empty(), "the crate should be back in the world")
	expect(crate.global_position.distance_to(home) < 0.5, "at its home spot, at %s" % crate.global_position)


func _crate(side_main: Node) -> WorldItem:
	return side_main.level.get_node("Items/Crate")


func _move(who: Player, spot: Vector3) -> void:
	who.global_position = spot
	who.velocity = Vector3.ZERO
	who.reset_physics_interpolation()
	await ticks(15)
