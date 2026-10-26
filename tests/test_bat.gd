extends GameTest
## The baseball bat, solo, on the Free-Run Line's runway (clear from z = 5 to
## the first hurdle at z = -58). The bat lies at (2.5, 0.4, -18).

const START := Vector3(0, 0.05, 0)

var bat: WorldItem


func before_each() -> void:
	main = MAIN_SCENE.instantiate()
	add_child(main)
	main.start_solo("free_run_line")
	await ticks(5)
	player = main.get_node_or_null("Players/1")
	expect(player != null, "the game should have created a player")
	if player:
		player.set_profile(SUPERHUMAN)
	bat = main.level.get_node("Items/Bat")
	await ticks(30) # Let the items settle.


func test_a_bat_hit_sends_a_friend_a_long_way() -> void:
	bat.host_give_to(player)
	await place(START, FACE_NORTH)
	await press_event(&"call_buddy")
	var buddy: Player = main.buddy
	var start := buddy.global_position
	await tap(&"use_item")
	await ticks(5)
	expect(buddy.state.name == &"Air", "the buddy should be sent flying")
	for i in 180:
		await ticks(1)
		if buddy.state.name == &"Ground":
			break
	var distance := Vector2(buddy.global_position.x - start.x, buddy.global_position.z - start.z).length()
	expect(distance > 30.0, "a bat hit should carry over 30 m, went %.1f m" % distance)
	expect(buddy.global_position.z < start.z, "the way the camera faces, at %s" % buddy.global_position)


func test_a_bat_hit_is_a_throw_chain_link() -> void:
	bat.host_give_to(player)
	await place(START, FACE_NORTH)
	await press_event(&"call_buddy")
	await tap(&"use_item")
	await ticks(5)
	expect("1" in main.buddy.tossed_by, "the hit should count as you launching them this air time")


func test_hitting_an_item_sends_it_flying() -> void:
	var crate: WorldItem = main.level.get_node("Items/Crate")
	bat.host_give_to(player)
	await place(Vector3(2.5, 0.05, -12.0), FACE_NORTH) # Crate 2 m ahead.
	await tap(&"use_item")
	await ticks(90)
	expect(crate.global_position.z < -30.0, "the crate should fly well down the runway, at %s" % crate.global_position)


func test_hitting_a_hovering_relic_knocks_it_loose() -> void:
	var relic: WorldItem = main.level.get_node("Relics/RelicPillarTop") # Hovers at (10.5, 6.6, -72).
	bat.host_give_to(player)
	await place(Vector3(10.5, 5.05, -70.5), FACE_NORTH)
	expect(relic.state == WorldItem.State.IN_WORLD, "test setup: touch pick-up needs free hands")
	await tap(&"use_item")
	await ticks(30)
	expect(relic.global_position.z < -80.0, "the relic should be knocked away, at %s" % relic.global_position)


func test_one_swing_at_a_time() -> void:
	var crate: WorldItem = main.level.get_node("Items/Crate")
	var balloon: WorldItem = main.level.get_node("Items/TestBalloon")
	bat.host_give_to(player)
	await place(Vector3(2.5, 0.05, -12.0), FACE_NORTH) # Crate 2 m ahead.
	await tap(&"use_item")
	await ticks(10)
	expect(crate.linear_velocity.length() > 5.0, "test setup: the first swing hits the crate")
	balloon.global_position = Vector3(2.5, 0.6, -13.0) # A fresh target, right in front.
	await tap(&"use_item")
	await ticks(5)
	expect(balloon.linear_velocity.length() < 5.0, "swinging again straight away shouldn't hit it")
	await ticks(30)
	await tap(&"use_item")
	await ticks(5)
	expect(balloon.linear_velocity.length() > 5.0, "but once the bat is ready again it should")


func test_no_swing_with_the_bat_in_your_backpack() -> void:
	main.level.get_node("Items/Backpack").host_give_to(player)
	bat.host_give_to(player)
	await tap(&"switch_item")
	await place(START, FACE_NORTH)
	await press_event(&"call_buddy")
	await tap(&"use_item")
	await ticks(5)
	expect(main.buddy.state.name == &"Ground", "a bat in your backpack doesn't swing")
