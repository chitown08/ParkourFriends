extends GameTest
## Steam (game/network.gd): hosting makes a friends-only Steam lobby, friends
## join from invites. The tests don't start Steam (Network.steam_allowed is
## off: they play over the local network), so these check everything around
## it; playing over Steam itself needs two people with Steam (see docs/DESIGN.md).


func after_each() -> void:
	Settings.dev_tools = true
	await super()


func test_the_tests_dont_start_steam() -> void:
	expect(not main.network.steam_ready, "no Steam in the tests")
	expect(main.network.describe() == "Solo", "playing solo, says '%s'" % main.network.describe())


func test_a_friends_invite_on_the_command_line_is_found() -> void:
	expect(Network.lobby_from_command_line(PackedStringArray(["--path", ".", "+connect_lobby", "109775241021923337"])) == 109775241021923337,
			"Steam starts the game with +connect_lobby <id> when you accept an invite")
	expect(Network.lobby_from_command_line(PackedStringArray(["--solo"])) == 0, "no invite: 0")
	expect(Network.lobby_from_command_line(PackedStringArray(["+connect_lobby"])) == 0, "no id after it: 0")


func test_with_steam_the_menu_hosts_on_steam_and_hides_the_address() -> void:
	main.leave_game()
	await ticks(2)
	Settings.dev_tools = false
	main.menu.set_steam(true)
	expect(main.menu.get_node("%Host").text.contains("Steam"), "hosting invites Steam friends: '%s'" % main.menu.get_node("%Host").text)
	expect(not main.menu.get_node("%JoinRow").visible and not main.menu.get_node("%Hint").visible, "friends join from Steam, not by address")
	main.menu.set_steam(false)
	expect(main.menu.get_node("%JoinRow").visible and main.menu.get_node("%Host").text == "Host a Game", "without Steam: by address")
	Settings.dev_tools = true
	main.menu.set_steam(true)
	expect(main.menu.get_node("%JoinRow").visible, "developers can still join by address")


func test_the_pause_menu_invites_friends_in_a_steam_game() -> void:
	main.set_paused(true)
	expect(not main.pause_menu.get_node("%Invite").visible, "not in a Steam game: no invite button")
	main.set_paused(false)
	main.pause_menu.open(true)
	expect(main.pause_menu.get_node("%Invite").visible, "in a Steam game: Invite Friends")
	var pressed := []
	main.pause_menu.invite_pressed.connect(func() -> void: pressed.append(true))
	main.pause_menu.get_node("%Invite").pressed.emit()
	expect(pressed.size() == 1, "which asks Steam to open its invite window")
