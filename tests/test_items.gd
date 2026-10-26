extends GameTest
## The item system, solo, with the placeholder items at the start of the
## Free-Run Line: a Crate at (2.5, 0.4, -14) and a Test Balloon at (-2.5, 0.4, -14).
## (Two-player item tests: test_items_network.gd.)

const BY_CRATE := Vector3(2.5, 0.05, -12.5)
const BY_BALLOON := Vector3(-2.5, 0.05, -12.5)
const OPEN_GROUND := Vector3(0, 0.05, -30)

var crate: WorldItem
var balloon: WorldItem


func before_each() -> void:
	main = MAIN_SCENE.instantiate()
	add_child(main)
	main.start_solo("free_run_line")
	await ticks(5)
	player = main.get_node_or_null("Players/1")
	expect(player != null, "the game should have created a player")
	if player:
		player.set_profile(SUPERHUMAN)
	crate = main.level.get_node("Items/Crate")
	balloon = main.level.get_node("Items/TestBalloon")
	await ticks(30) # Let the items settle on the ground.


func test_pick_up_puts_it_in_your_hands() -> void:
	await place(BY_CRATE, FACE_NORTH)
	await tap(&"interact")
	await ticks(5)
	expect(crate.state == WorldItem.State.HELD and crate.holder_name == "1", "you should be holding the crate")
	expect(player.items.hands_item() == crate, "in your hands")
	expect(crate.global_position.distance_to(player.item_anchor(WorldItem.HANDS).origin) < 0.1, "and it should sit in front of you")


func test_held_item_follows_you() -> void:
	await place(BY_CRATE, FACE_NORTH)
	await tap(&"interact")
	await hold(&"move_forward", 30)
	await ticks(5)
	expect(crate.global_position.distance_to(player.item_anchor(WorldItem.HANDS).origin) < 0.1, "the crate should move with you")


func test_second_item_goes_in_your_hands_and_the_first_on_your_back() -> void:
	await place(BY_CRATE, FACE_NORTH)
	await tap(&"interact")
	await place(BY_BALLOON, FACE_NORTH)
	await tap(&"interact")
	await ticks(5)
	expect(player.items.hands_item() == balloon, "the balloon should be in your hands")
	expect(player.items.back_item() == crate, "the crate should move to your back")
	await tap(&"switch_item")
	await ticks(5)
	expect(player.items.hands_item() == crate and player.items.back_item() == balloon, "Tab swaps hands and back")


func test_with_both_slots_full_f_drops_instead() -> void:
	await place(BY_CRATE, FACE_NORTH)
	await tap(&"interact")
	await place(BY_BALLOON, FACE_NORTH)
	await tap(&"interact")
	var third := _spawn_item(Vector3(0, 0.4, -14))
	await place(Vector3(0, 0.05, -12.5), FACE_NORTH)
	await tap(&"interact")
	await ticks(5)
	expect(third.state == WorldItem.State.IN_WORLD, "a third item can't be picked up with both slots full")
	expect(balloon.state == WorldItem.State.IN_WORLD, "F drops the item in your hands instead")
	expect(player.items.hands_item() == crate, "and the item from your back moves to your hands")


func test_drop_falls_to_the_ground() -> void:
	await place(BY_CRATE, FACE_NORTH)
	await tap(&"interact")
	await place(OPEN_GROUND, FACE_NORTH)
	await tap(&"interact")
	await ticks(90)
	expect(crate.state == WorldItem.State.IN_WORLD, "the crate should be back in the world")
	expect(crate.global_position.distance_to(OPEN_GROUND) < 2.0, "near your feet, at %s" % crate.global_position)
	expect(absf(crate.global_position.y - 0.35) < 0.1, "resting on the ground, at y = %.2f" % crate.global_position.y)


func test_throw_sends_it_flying() -> void:
	await place(BY_CRATE, FACE_NORTH)
	await tap(&"interact")
	await place(OPEN_GROUND, FACE_NORTH)
	await tap(&"throw_item")
	await ticks(60)
	expect(crate.state == WorldItem.State.IN_WORLD, "a thrown item is back in the world")
	expect(crate.global_position.z < OPEN_GROUND.z - 6.0, "it should fly well ahead of you, at %s" % crate.global_position)


func test_falling_off_the_world_sends_it_home() -> void:
	var home := crate.global_position
	crate.global_position = Vector3(30, -70, -14) # Below the kill height.
	await ticks(10)
	expect(crate.state == WorldItem.State.RETURNING, "it should start returning home")
	await ticks(roundi(WorldItem.RETURN_DELAY * 60) + 10)
	expect(crate.state == WorldItem.State.IN_WORLD, "and reappear")
	expect(crate.global_position.distance_to(home) < 0.5, "at home, at %s" % crate.global_position)


func test_abandoned_items_go_home() -> void:
	crate.item = crate.item.duplicate() # So the short timer only affects this crate.
	crate.item.abandon_time = 1.0
	var home := crate.global_position
	await place(BY_CRATE, FACE_NORTH)
	await tap(&"interact")
	await place(OPEN_GROUND, FACE_NORTH)
	await tap(&"interact")
	await ticks(60 + 60 + roundi(WorldItem.RETURN_DELAY * 60) + 30)
	expect(crate.global_position.distance_to(home) < 0.5, "a crate left lying around should go home, at %s" % crate.global_position)


func test_balloon_ability_slows_your_fall_only_in_your_hands() -> void:
	await place(BY_BALLOON, FACE_NORTH)
	await tap(&"interact")
	player.global_position = Vector3(0, 30, -30)
	player.reset_physics_interpolation()
	await ticks(60)
	expect(player.velocity.y >= -4.1, "with the balloon in your hands you fall slowly, vy = %.2f" % player.velocity.y)
	await tap(&"switch_item") # Only item: moves to your back.
	await ticks(30)
	expect(player.items.back_item() == balloon, "test setup: balloon on your back")
	expect(player.velocity.y < -8.0, "on your back it does nothing, vy = %.2f" % player.velocity.y)


func _spawn_item(spot: Vector3) -> WorldItem:
	var extra := preload("res://items/world_item.tscn").instantiate() as WorldItem
	extra.item = preload("res://items/data/crate.tres")
	extra.position = spot
	main.level.get_node("Items").add_child(extra)
	return extra
