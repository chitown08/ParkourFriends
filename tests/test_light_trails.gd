extends GameTest
## Light trails (player/light_trail.gd): a ribbon of light along where each
## player has been, fading after a while, so you can spot friends from far off.
## On the Free-Run Line.


func before_each() -> void:
	main = MAIN_SCENE.instantiate()
	add_child(main)
	main.start_solo("free_run_line")
	await ticks(5)
	player = main.get_node("Players/1")
	player.set_profile(SUPERHUMAN)
	Settings.light_trails = true


func test_running_lays_a_trail_behind_you() -> void:
	await place(Vector3(0, 0.05, 0), FACE_NORTH)
	await hold(&"move_forward", 120)
	var points := _trail(player).points()
	expect(points.size() > 10, "points along the way, %d" % points.size())
	var last := points[points.size() - 1]
	expect(last.distance_to(player.global_position + Vector3.UP * LightTrail.HEIGHT) < LightTrail.SPACING + 0.5, "the newest by you, at your middle (%s, you at %s)" % [last, player.global_position])
	expect(points[0].z > last.z + 5.0, "the oldest back where you started (%s)" % points[0])
	for i in range(points.size() - 5, points.size()):
		expect_near(points[i].distance_to(points[i - 1]), LightTrail.SPACING, 0.3, "about %.2f m apart" % LightTrail.SPACING)


func test_it_fades_and_goes() -> void:
	await place(Vector3(0, 0.05, 0), FACE_NORTH)
	await hold(&"move_forward", 60)
	expect(not _trail(player).points().is_empty(), "test setup: a trail")
	await ticks(int(LightTrail.LIFETIME * 60) + 10)
	expect(_trail(player).points().is_empty(), "standing still, after %d s it's gone" % LightTrail.LIFETIME)


func test_a_respawn_starts_a_new_trail() -> void:
	await place(Vector3(0, 0.05, 0), FACE_NORTH)
	await hold(&"move_forward", 30)
	var before := _trail(player).pieces()
	await place(Vector3(0, 0.05, -60), FACE_NORTH)
	await hold(&"move_forward", 30)
	expect(_trail(player).pieces() == before + 1, "a separate trail after jumping 60 m (not a line across): %d then %d" % [before, _trail(player).pieces()])


func test_its_your_colour_and_friends_have_theirs() -> void:
	expect(_trail(player).color == Player.COLORS[player.color_index % Player.COLORS.size()], "your colour")
	main.call_buddy()
	var buddy: Player = main.buddy
	await ticks(5)
	buddy.global_position = player.global_position + Vector3(4, 0, 0)
	await ticks(2)
	for i in 40:
		buddy.global_position += Vector3(0, 0, -0.5)
		await ticks(1)
	expect(_trail(buddy).points().size() > 5, "the buddy leaves one too, %d points" % _trail(buddy).points().size())
	expect(_trail(buddy).color == Player.BUDDY_COLOR, "in their colour")


func test_the_setting_turns_them_off() -> void:
	await place(Vector3(0, 0.05, 0), FACE_NORTH)
	await hold(&"move_forward", 30)
	Settings.light_trails = false
	await ticks(2)
	expect(not _trail(player).visible, "hidden")
	Settings.light_trails = true
	await ticks(2)
	expect(_trail(player).visible, "and back")


func _trail(who: Player) -> LightTrail:
	return who.get_node("LightTrail")
