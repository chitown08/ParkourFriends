extends GameTest
## Relics on the Free-Run Line, solo: touch one to pick it up, then carry or
## throw it into the drop-off beside the spawn for it to count.
## (Two-player relic tests: test_relics_network.gd.)

const RELIC_COUNT := 7
const PILLAR_TOP := Vector3(10.5, 5.05, -72) ## Standing under RelicPillarTop.
const BY_DROP_OFF := Vector3(0, 0.05, 0) ## The spawn; the drop-off is 7 m west.
const DROP_OFF := Vector3(-7, 0.05, 0)
const OPEN_GROUND := Vector3(0, 0.05, -30)


func before_each() -> void:
	main = MAIN_SCENE.instantiate()
	add_child(main)
	main.start_solo("free_run_line")
	await ticks(5)
	player = main.get_node_or_null("Players/1")
	expect(player != null, "the game should have created a player")
	if player:
		player.set_profile(SUPERHUMAN)


func test_counter_shows_all_relics() -> void:
	var counter: Label = main.hud.get_node("Relics")
	expect(counter.visible, "the relic counter should be showing")
	expect(counter.text == "Relics 0 / %d" % RELIC_COUNT, "counter should read 0 / %d, reads '%s'" % [RELIC_COUNT, counter.text])


func test_relics_hover_until_taken() -> void:
	await ticks(60)
	expect_near(_relic("RelicOverGap").global_position.y, 2.5, 0.05, "the relic over the gap should stay up")


func test_touching_a_relic_picks_it_up() -> void:
	await _stand_at(PILLAR_TOP)
	expect(_relic("RelicPillarTop").holder_name == "1", "touching the relic should put it in your hands")
	expect(main.delivered_relics.is_empty(), "but it only counts once delivered")


func test_no_touch_pick_up_with_full_hands() -> void:
	main.level.get_node("Items/Crate").host_give_to(player)
	await _stand_at(PILLAR_TOP)
	expect(_relic("RelicPillarTop").state == WorldItem.State.IN_WORLD, "with your hands full the relic stays put")


func test_carrying_a_relic_to_the_drop_off_delivers_it() -> void:
	var relic := _relic("RelicPillarTop")
	relic.host_give_to(player)
	await place(DROP_OFF, FACE_NORTH)
	expect(main.delivered_relics.has("RelicPillarTop"), "the relic should be delivered")
	expect(relic.state == WorldItem.State.DELIVERED and not relic.visible, "and disappear")
	expect(player.items.hands_item() == null, "your hands should be free again")
	var counter: Label = main.hud.get_node("Relics")
	expect(counter.text == "Relics 1 / %d" % RELIC_COUNT, "counter should read 1 / %d, reads '%s'" % [RELIC_COUNT, counter.text])


func test_throwing_a_relic_into_the_drop_off_delivers_it() -> void:
	_relic("RelicPillarTop").host_give_to(player)
	await place(BY_DROP_OFF, FACE_WEST)
	player.camera_rig.pitch = 0.0
	await tap(&"throw_item")
	await ticks(30)
	expect(main.delivered_relics.has("RelicPillarTop"), "a relic thrown through the drop-off should count")


func test_the_buddy_cannot_pick_up_relics() -> void:
	await press_event(&"call_buddy")
	await ticks(10)
	main.buddy.global_position = PILLAR_TOP
	await ticks(10)
	expect(_relic("RelicPillarTop").state == WorldItem.State.IN_WORLD, "the practice buddy shouldn't pick up relics")


func test_a_lost_relic_goes_home_and_hovers_again() -> void:
	var relic := _relic("RelicPillarTop")
	var home := relic.global_position
	relic.host_give_to(player)
	await place(OPEN_GROUND, FACE_NORTH)
	await tap(&"interact") # Drop it: off its hovering spot it falls like anything else.
	await ticks(60)
	expect(relic.global_position.y < 0.6, "a dropped relic should fall to the ground, at y = %.2f" % relic.global_position.y)
	relic.global_position = Vector3(30, -70, -14) # Below the kill height.
	await ticks(roundi(WorldItem.RETURN_DELAY * 60) + 60)
	expect(relic.global_position.distance_to(home) < 0.1, "it should be back home, hovering, at %s" % relic.global_position)


func test_relics_reset_for_a_new_game() -> void:
	_relic("RelicPillarTop").host_give_to(player)
	await place(DROP_OFF, FACE_NORTH)
	main.leave_game()
	await ticks(5)
	main.start_solo("free_run_line")
	await ticks(5)
	expect(main.delivered_relics.is_empty(), "a new game should start with no relics delivered")
	expect(_relic("RelicPillarTop").visible, "relics should be back in a new game")


func test_test_course_has_no_relic_counter() -> void:
	main.leave_game()
	await ticks(5)
	main.start_solo("test_course")
	await ticks(5)
	expect(not main.hud.get_node("Relics").visible, "no relic counter in a world without relics")


func _relic(relic_name: String) -> WorldItem:
	return main.level.get_node("Relics/" + relic_name)


func _stand_at(feet: Vector3) -> void:
	player.global_position = feet
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	await ticks(5)
