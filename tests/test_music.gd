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


func test_the_district_starts_with_its_layered_song_then_plays_on() -> void:
	expect(main.music.playing, "music should be playing")
	expect(main.layered != null and main.music.stream == main.layered.stream, "the world's own song: the layered one")
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


func test_a_layered_song_is_a_folder_of_layers() -> void:
	expect("res://audio/music/rooftop_test/" in Playlist.find_tracks(), "the folder counts as one track: %s" % [Playlist.find_tracks()])
	var song: LayeredSong = main.layered
	expect(song.layers.has("base") and song.layers.has("pack1") and song.layers.has("pack2"), "base, pack1, pack2 layers: %s" % [song.layers])
	var extras: Array = song.layers.filter(func(layer: String) -> bool: return layer.begins_with("extra-"))
	expect(extras.size() >= 3, "and the extras: %s" % [extras])
	expect(song.picked.size() >= 1 and song.picked.size() <= 2 and song.picked.all(func(layer: String) -> bool: return layer in extras), "one or two extras picked to play this time: %s" % [song.picked])


func test_the_song_swells_with_your_pack() -> void:
	var song := LayeredSong.new("res://audio/music/rooftop_test/")
	var unpicked: String = song.layers.filter(func(layer: String) -> bool: return layer.begins_with("extra-") and not layer in song.picked)[0]
	expect(song.volume("base") == 1.0 and song.volume("pack1") == 0.0 and song.volume("pack2") == 0.0, "alone: just the base")
	expect(song.volume(song.picked[0]) == 1.0 and song.volume(unpicked) == 0.0, "and the extras picked this time")
	song.set_pack(1, LayeredSong.FADE_TIME / 2.0)
	expect_near(song.volume("pack1"), 0.5, 0.01, "a friend joins: the synth fades in")
	song.set_pack(1, LayeredSong.FADE_TIME)
	expect(song.volume("pack1") == 1.0 and song.volume("pack2") == 0.0, "...all the way, and no brass yet")
	song.set_pack(2, 10.0)
	expect(song.volume("pack2") == 1.0 and song.volume(unpicked) == 0.0, "two friends: brass")
	song.set_pack(3, 10.0)
	expect(song.layers.all(func(layer: String) -> bool: return song.volume(layer) == 1.0), "three: everything")
	song.set_pack(0, 10.0)
	expect(song.volume("pack1") == 0.0 and song.volume("base") == 1.0, "and back down when the pack breaks up")


func test_alone_its_muffled_and_a_friend_opens_it_up() -> void:
	await ticks(240)
	expect(Settings.music_cutoff() < main.MUFFLED_HZ + 500.0, "alone, a layered song is a little muffled: %.0f Hz" % Settings.music_cutoff())
	main.call_buddy()
	var buddy: Player = main.buddy
	buddy.set_profile(player.profile)
	buddy.ghost_of = player
	buddy.ghost_wander_degrees = 0.0
	var floor_body := StaticBody3D.new() # (A big empty floor high up, to run on.)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(400, 1, 400)
	floor_body.add_child(shape)
	main.level.add_child(floor_body)
	floor_body.global_position = Vector3(0, 299.5, 0)
	await place(Vector3(0, 300.05, 0), FACE_NORTH)
	buddy.global_position = player.global_position + Vector3(-3, 0, 0)
	buddy.reset_physics_interpolation()
	Input.action_press(&"free_run")
	await ticks(180)
	expect(player.pack_size() == 1, "test setup: running as a pack of two")
	expect(main.layered.volume("pack1") > 0.9, "running with a friend, the synth comes in: %.2f" % main.layered.volume("pack1"))
	expect(Settings.music_cutoff() > 10000.0, "and it opens up: %.0f Hz" % Settings.music_cutoff())
	release_all()
