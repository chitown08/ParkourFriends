extends GameTest
## You, as friends see you: your name (typed in the start menu, shown over your
## head), your outfit (picked in the pause menu, nothing to start with), and
## the settings in the pause menu. All saved between sessions (the tests use
## a settings file of their own).


func before_each() -> void:
	Settings.player_name = ""
	Settings.outfit = PackedStringArray()
	await super()


func after_each() -> void:
	Settings.player_name = ""
	Settings.outfit = PackedStringArray()
	Settings.dev_tools = true
	Settings.master_volume = 1.0
	Settings.effects_volume = 1.0
	Settings.apply_audio()
	Settings.save_to_disk()
	await super()


func test_the_tests_keep_out_of_your_settings() -> void:
	expect(Settings.path == "user://test_settings.cfg", "tests save to their own file, not yours: %s" % Settings.path)


func test_a_new_player_wears_nothing_and_is_called_player() -> void:
	expect(Array(player.sync_outfit).all(func(item: String) -> bool: return item == ""), "nothing on to start with, %s" % [player.sync_outfit])
	expect(player.sync_player_name == "Player", "no name typed yet: 'Player', got '%s'" % player.sync_player_name)


func test_type_your_name_in_the_start_menu() -> void:
	main.leave_game()
	await ticks(5)
	var field: LineEdit = main.menu.get_node("%PlayerName")
	expect(field.has_focus(), "with no name yet, the name box is ready to type in")
	field.text = "  Sam  "
	field.text_changed.emit(field.text)
	expect(Settings.player_name == "Sam", "the name is saved, tidied up: '%s'" % Settings.player_name)
	Settings.player_name = ""
	Settings.load_from_disk()
	expect(Settings.player_name == "Sam", "...to disk, for next time")
	expect(Settings.clean_name("A name far too long for a tag") == "A name far too l", "and kept short")
	main.start_solo("free_run_line")
	await ticks(5)
	player = main.get_node("Players/1")
	expect(player.sync_player_name == "Sam", "you play as Sam")
	expect(not player.get_node("NameTag").visible, "(your own tag isn't shown to you)")


func test_pick_an_outfit_in_the_pause_menu() -> void:
	main.set_paused(true)
	var hat_list: OptionButton = main.pause_menu.get_node("%Slots/Head")
	expect(hat_list.get_item_text(0) == "None" and hat_list.selected == 0, "the hat list starts on None")
	expect(hat_list.item_count == Cosmetics.available(&"head").size() + 1, "then every hat")
	hat_list.select(1)
	hat_list.item_selected.emit(1)
	await ticks(2)
	var hat := Cosmetics.available(&"head")[0]
	expect(player.sync_outfit[0] == hat, "you put the hat on, wearing %s" % [player.sync_outfit])
	Settings.outfit = PackedStringArray()
	Settings.load_from_disk()
	expect(Settings.outfit[0] == hat, "and it's saved for next time")
	main.leave_game()
	await ticks(5)
	main.start_solo("free_run_line")
	await ticks(5)
	expect(main.get_node("Players/1").sync_outfit[0] == hat, "next game, you're still wearing it")
	main.set_paused(true)
	expect(main.pause_menu.get_node("%Slots/Head").selected == 1, "and the menu shows it")


func test_an_outfit_item_no_longer_made_is_left_off() -> void:
	var tidied := Cosmetics.tidy(PackedStringArray(["no_such_hat"]))
	expect(tidied.size() == Cosmetics.SLOTS.size() and Array(tidied).all(func(item: String) -> bool: return item == ""), "unknown or missing: nothing, %s" % [tidied])


func test_volume_sliders_turn_the_sound_down() -> void:
	main.set_paused(true)
	(main.pause_menu.get_node("%Master") as HSlider).value = 0.5
	(main.pause_menu.get_node("%Effects") as HSlider).value = 0.0
	expect_near(AudioServer.get_bus_volume_db(0), linear_to_db(0.5), 0.01, "everything at half")
	var effects := AudioServer.get_bus_index(Settings.EFFECTS_BUS)
	expect(effects != -1 and AudioServer.is_bus_mute(effects), "sound effects off")
	expect(Settings.master_volume == 0.5 and Settings.effects_volume == 0.0, "remembered")


func test_developer_settings_are_hidden_in_the_build_friends_play() -> void:
	Settings.dev_tools = false
	main.set_paused(true)
	expect(not main.pause_menu.get_node("%DevSettings").visible, "no movement feel or free-run switch")
	main.set_paused(false)
	Settings.dev_tools = true
	main.set_paused(true)
	expect(main.pause_menu.get_node("%DevSettings").visible, "developers still get them")


func test_the_version_is_shown() -> void:
	main.set_paused(true)
	for label: Label in [main.pause_menu.get_node("%Version"), main.hud.get_node("Version"), main.menu.get_node("%Version")]:
		expect(label.text.begins_with("v0.") and label.text.ends_with("alpha"), "a version number, '%s'" % label.text)
