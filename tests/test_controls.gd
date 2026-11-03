extends GameTest
## The streamlined controls: a short controls card in a corner, one prompt for
## what a button would do right now (named for the keyboard or the gamepad,
## whichever you last used), F for everything items (hold to throw), and the
## developer-only keys. On the Free-Run Line (a Crate at (2.5, 0.4, -14)).

const BY_CRATE := Vector3(2.5, 0.05, -12.5)
const FLOOR_Y := 200.0

var crate: WorldItem
var hud: CanvasLayer


func before_each() -> void:
	main = MAIN_SCENE.instantiate()
	add_child(main)
	main.start_solo("free_run_line")
	await ticks(5)
	player = main.get_node("Players/1")
	player.set_profile(SUPERHUMAN)
	crate = main.level.get_node("Items/Crate")
	hud = main.hud
	ControlNames.gamepad = false
	await ticks(30)


func after_each() -> void:
	Settings.dev_tools = true
	ControlNames.gamepad = false
	await super()


func test_the_controls_card_is_short() -> void:
	await ticks(2)
	var card: String = hud.get_node("Card").get_parsed_text()
	for key in ["WASD", "Space", "Shift", "C", "E", "F", "Click", "R", "Esc"]:
		expect(card.contains(key), "the card should show %s:\n%s" % [key, card])
	for gone in ["Tab", "T ", "G ", "H ", "Q ", "F3"]:
		expect(not card.contains(gone), "no %s on the card any more" % gone)
	expect(not card.contains("Right-click"), "swapping with a backpack only shows when you wear one")
	expect(hud.CARD.size() <= 12, "a dozen lines at most")


func test_the_card_and_prompt_name_gamepad_buttons_after_using_one() -> void:
	await place(BY_CRATE, FACE_NORTH)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_START
	pad.pressed = false
	Input.parse_input_event(pad)
	await ticks(2)
	expect(ControlNames.gamepad, "touching the gamepad switches the names over")
	var card: String = hud.get_node("Card").get_parsed_text()
	expect(card.contains("RB") and card.contains("RT") and not card.contains("Shift"), "gamepad buttons on the card:\n%s" % card)
	expect(hud.get_node("Prompt").text == "X  Pick up Crate", "the prompt names the gamepad button, '%s'" % hud.get_node("Prompt").text)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	Input.parse_input_event(key)
	await ticks(2)
	expect(hud.get_node("Prompt").text == "F  Pick up Crate", "and back to keys after a key, '%s'" % hud.get_node("Prompt").text)


func test_nothing_to_do_nothing_prompted() -> void:
	await place(Vector3(0, 0.05, -40), FACE_NORTH)
	expect(player.control_hints().is_empty(), "standing about alone: no prompt, %s" % [player.control_hints()])
	await ticks(2)
	expect(hud.get_node("Prompt").text == "", "an empty prompt")
	expect(hud.get_node("Items").text == "", "empty hands: nothing listed")


func test_hold_f_to_throw_but_a_short_hold_drops() -> void:
	await place(BY_CRATE, FACE_NORTH)
	await hold(&"interact", 30) # Empty hands: holding F still picks up.
	await ticks(5)
	expect(player.items.hands_item() == crate, "holding F with empty hands picks it up")
	await place(Vector3(0, 0.05, -30), FACE_NORTH)
	await hold(&"interact", roundi(PlayerInput.THROW_HOLD * 60.0) - 3) # Not quite long enough.
	await ticks(60)
	expect(crate.state == WorldItem.State.IN_WORLD and crate.global_position.z > -33.0, "a shortish press drops it at your feet, at %s" % crate.global_position)


func test_hanging_prompts_climb_and_let_go() -> void:
	_box(Vector3(0, FLOOR_Y - 0.5, 0), Vector3(40, 1, 40))
	_box(Vector3(0, FLOOR_Y + 1.5, -10), Vector3(10, 3, 10)) # Face at z = -5, top 3 m up.
	await ticks(3)
	await place(Vector3(0, FLOOR_Y + 0.05, -4.0), FACE_NORTH)
	var feet := Vector3(0, FLOOR_Y + 3.0 - player.hang_height, -5.0 + player.body_radius + 0.05)
	player.global_position = feet
	player.change_state(&"Hang", {"ledge": player.find_ledge(feet, Vector3.FORWARD)})
	await ticks(5)
	expect(player.control_hints() == [[&"jump", "Climb up"], [&"crouch", "Let go"]], "hanging: %s" % [player.control_hints()])
	await ticks(2)
	expect(hud.get_node("Prompt").text.begins_with("Space  Climb up"), "on screen: '%s'" % hud.get_node("Prompt").text)


func test_a_friend_beside_you_prompts_a_toss() -> void:
	await place(Vector3(0, 0.05, -40), FACE_NORTH)
	main.call_buddy()
	await ticks(20)
	expect([&"toss", "Toss your friend"] in player.control_hints(), "a friend in reach: %s" % [player.control_hints()])


func test_at_a_wall_with_a_friend_about_it_prompts_a_brace() -> void:
	_box(Vector3(0, FLOOR_Y - 0.5, 0), Vector3(40, 1, 40))
	_box(Vector3(0, FLOOR_Y + 5.0, -10), Vector3(10, 10, 10)) # Face at z = -5.
	await ticks(3)
	await place(Vector3(0, FLOOR_Y + 0.05, -4.4), FACE_NORTH)
	expect(player.control_hints().is_empty(), "alone at a wall: nothing to brace for, %s" % [player.control_hints()])
	main.call_buddy()
	main.buddy.global_position = Vector3(8, FLOOR_Y + 0.05, 5) # About, but out of tossing reach.
	await ticks(20)
	expect([&"toss", "Brace for a leg-up"] in player.control_hints(), "with a friend about: %s" % [player.control_hints()])


func test_the_practice_buddy_keys_are_for_developers_only() -> void:
	Settings.dev_tools = false
	await press_event(&"call_buddy")
	await press_event(&"ghost_run")
	expect(not is_instance_valid(main.buddy), "no practice buddy in the build friends play")
	await press_event(&"toggle_stats")
	expect(not hud.get_node("Stats").visible, "nor the stats readout")
	Settings.dev_tools = true
	await press_event(&"call_buddy")
	expect(is_instance_valid(main.buddy), "developers still get it")
	await press_event(&"toggle_stats")
	expect(hud.get_node("Stats").visible, "and F3 shows the stats")


func _box(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	body.add_child(shape)
	main.level.add_child(body)
	body.global_position = at
