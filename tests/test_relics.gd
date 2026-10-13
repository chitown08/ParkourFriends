extends GameTest
## Relics in Old Town, solo. (Two-player relic tests: test_relics_network.gd.)

const PLAZA_RELIC := Vector3(11, 1.3, 20) ## RelicPlaza, on the spawn plaza.


func before_each() -> void:
	main = MAIN_SCENE.instantiate()
	add_child(main)
	main.start_solo("old_town")
	await ticks(5)
	player = main.get_node_or_null("Players/1")
	expect(player != null, "the game should have created a player")


func test_counter_shows_all_relics() -> void:
	var counter: Label = main.hud.get_node("Relics")
	expect(counter.visible, "the relic counter should be showing")
	expect(counter.text == "Relics 0 / 11", "counter should read 0 / 11, reads '%s'" % counter.text)


func test_touching_a_relic_collects_it() -> void:
	await place(Vector3(PLAZA_RELIC.x, 0.35, PLAZA_RELIC.z), FACE_NORTH)
	await ticks(5)
	expect(main.collected_relics.has("RelicPlaza"), "the plaza relic should be collected")
	expect(not main.level.get_node("Relics/RelicPlaza").visible, "a found relic should disappear")
	expect(main.hud.get_node("Relics").text == "Relics 1 / 11", "counter should read 1 / 11")


func test_the_buddy_cannot_collect_relics() -> void:
	await press_event(&"call_buddy")
	await ticks(10)
	main.buddy.global_position = Vector3(PLAZA_RELIC.x, 0.35, PLAZA_RELIC.z)
	await ticks(10)
	expect(main.collected_relics.is_empty(), "the practice buddy shouldn't collect relics")


func test_relics_reset_for_a_new_game() -> void:
	await place(Vector3(PLAZA_RELIC.x, 0.35, PLAZA_RELIC.z), FACE_NORTH)
	await ticks(5)
	main.leave_game()
	await ticks(5)
	main.start_solo("old_town")
	await ticks(5)
	expect(main.collected_relics.is_empty(), "a new game should start with no relics found")
	expect(main.level.get_node("Relics/RelicPlaza").visible, "relics should be back in a new game")


func test_test_course_has_no_relic_counter() -> void:
	main.leave_game()
	await ticks(5)
	main.start_solo("test_course")
	await ticks(5)
	expect(not main.hud.get_node("Relics").visible, "no relic counter in a world without relics")
