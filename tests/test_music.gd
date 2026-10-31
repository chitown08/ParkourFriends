extends GameTest
## Background music: each world can have a song (Level.music), M mutes it, and
## the pause menu has a volume slider.

var saved_volume: float
var saved_on: bool


func before_each() -> void:
	saved_volume = Settings.music_volume
	saved_on = Settings.music_on
	Settings.music_on = true
	main = MAIN_SCENE.instantiate()
	add_child(main)
	main.start_solo("rooftop_district")
	await ticks(5)
	player = main.get_node_or_null("Players/1")


func after_each() -> void:
	Settings.music_volume = saved_volume
	Settings.music_on = saved_on
	Settings.save_to_disk()
	await super()


func test_the_district_plays_its_song_on_a_loop() -> void:
	expect(main.music.playing, "music should be playing")
	expect(main.music.stream == main.level.music and main.level.music != null, "it should be the world's song")
	expect(main.music.stream.loop, "the song should loop")


func test_m_mutes_and_unmutes() -> void:
	var loud: float = main.music.volume_db
	await press_event(&"toggle_music")
	expect(main.music.volume_db <= -79.0, "M should mute the music")
	expect(not Settings.music_on, "and remember it")
	await press_event(&"toggle_music")
	expect_near(main.music.volume_db, loud, 0.01, "M again brings it back")


func test_the_pause_menu_slider_sets_the_volume() -> void:
	main.set_paused(true)
	var slider: HSlider = main.pause_menu.get_node("%Music")
	slider.value = 0.25
	expect_near(main.music.volume_db, linear_to_db(0.25), 0.01, "the slider should turn it down")
	slider.value = 1.0
	expect_near(main.music.volume_db, 0.0, 0.01, "and up")


func test_leaving_stops_the_music() -> void:
	main.leave_game()
	await ticks(5)
	expect(not main.music.playing, "the menu should be quiet")
