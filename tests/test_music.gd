extends GameTest
## Background music: a world with music starts with its own song (Level.music),
## then plays everything in audio/music/ shuffled (Playlist); M mutes it, and
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


func test_the_district_starts_with_its_song_then_plays_on() -> void:
	expect(main.music.playing, "music should be playing")
	expect(main.music.stream == main.level.music and main.level.music != null, "it should be the world's song")
	expect(not main.music.stream.loop, "it doesn't loop: the playlist moves on")
	main.music.stop()
	main.music.finished.emit() # (As if it had played to the end.)
	await ticks(2)
	expect(main.music.playing and main.music.stream != null, "the next track plays")


func test_the_playlist_plays_everything_once_before_repeating() -> void:
	var tracks: Array[String] = ["a.ogg", "b.ogg", "c.ogg", "d.ogg"]
	var playlist := Playlist.new(tracks)
	playlist.start_with("c.ogg")
	var heard := ["c.ogg"]
	for i in 3:
		heard.append(playlist.next())
	heard.sort()
	expect(heard == ["a.ogg", "b.ogg", "c.ogg", "d.ogg"], "each track once in a round, %s" % [heard])
	for round in 20:
		var last := playlist.current
		var first := playlist.next()
		expect(first != last, "a new round doesn't start with the track that just ended")
		for i in 3:
			playlist.next()


func test_the_music_folder_is_found() -> void:
	expect("res://audio/music/test_level.mp3" in Playlist.find_tracks(), "the tracks in audio/music/: %s" % [Playlist.find_tracks()])


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
