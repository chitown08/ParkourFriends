class_name Settings
extends RefCounted
## The player's preferences, saved between sessions.
##
## Use them from any script, e.g. Settings.mouse_sensitivity. They're stored in
## Godot's per-user data folder (on Windows: %APPDATA%\Godot\app_userdata\
## Parkour Friends\settings.cfg), not in the project.

## Where they're saved. (The tests use a file of their own.)
static var path := "user://settings.cfg"

## What you're called: shown over your head to friends. "" until you type one.
static var player_name := ""
## The longest name allowed (characters).
const NAME_LENGTH := 16
## What you wear: an item name (or "" for nothing) for each slot in
## Cosmetics.SLOTS, in order. Nothing at all to start with.
static var outfit := PackedStringArray()
## Multiplies the camera's turning speed with the mouse. 1.0 = default.
static var mouse_sensitivity := 1.0
## Which movement feel to use: "superhuman" or "human" (see player/profiles/).
static var movement_profile := "superhuman"
## Hold Shift / right trigger to free-run (auto-run and auto-parkour). Can be
## switched off in the pause menu (developers only).
static var free_run_enabled := true
## Moving the mouse/stick up looks down instead of up.
static var invert_y := false
## Fill the screen (F11 switches), or play in a window.
static var fullscreen := false
## How loud everything is, the music, and the sound effects: 0 (silent) to 1 (full).
static var master_volume := 1.0
static var music_volume := 0.5
static var effects_volume := 1.0
## M switches the music off and on.
static var music_on := true
## Save what the crew's done (relics delivered and earned) between sessions
## (see Progress). Only developers can switch it off.
static var save_progress := true
## Developer tools: the practice buddy (G, Q, H), trying on outfits (O) and the
## stats readout (F3). On when running from the editor (or a debug build), off
## in the build friends play.
static var dev_tools := OS.is_debug_build()


static func load_from_disk() -> void:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return # No saved settings yet: keep the defaults.
	player_name = file.get_value("player", "name", player_name)
	outfit = file.get_value("player", "outfit", outfit)
	mouse_sensitivity = file.get_value("camera", "mouse_sensitivity", mouse_sensitivity)
	invert_y = file.get_value("camera", "invert_y", invert_y)
	movement_profile = file.get_value("movement", "profile", movement_profile)
	free_run_enabled = file.get_value("movement", "free_run", free_run_enabled)
	fullscreen = file.get_value("display", "fullscreen", fullscreen)
	master_volume = file.get_value("audio", "master_volume", master_volume)
	music_volume = file.get_value("audio", "music_volume", music_volume)
	effects_volume = file.get_value("audio", "effects_volume", effects_volume)
	music_on = file.get_value("audio", "music_on", music_on)
	save_progress = file.get_value("developer", "save_progress", save_progress)


static func save_to_disk() -> void:
	var file := ConfigFile.new()
	file.set_value("player", "name", player_name)
	file.set_value("player", "outfit", outfit)
	file.set_value("camera", "mouse_sensitivity", mouse_sensitivity)
	file.set_value("camera", "invert_y", invert_y)
	file.set_value("movement", "profile", movement_profile)
	file.set_value("movement", "free_run", free_run_enabled)
	file.set_value("display", "fullscreen", fullscreen)
	file.set_value("audio", "master_volume", master_volume)
	file.set_value("audio", "music_volume", music_volume)
	file.set_value("audio", "effects_volume", effects_volume)
	file.set_value("audio", "music_on", music_on)
	file.set_value("developer", "save_progress", save_progress)
	file.save(path)


## Your name as typed, tidied up: trimmed and cut to NAME_LENGTH.
static func clean_name(text: String) -> String:
	return text.strip_edges().left(NAME_LENGTH)


## The game's version (Project Settings > Application > Config > Version).
static func version() -> String:
	return "v%s alpha" % ProjectSettings.get_setting("application/config/version", "0.1.0")


# --- Sound and screen ------------------------------------------------------------

## The sound mixer's channel for sound effects, on its way to Master (where
## everything goes), so effects can be turned down apart from the music. (The
## music's own volume is set on its player: see main.gd update_music_volume().)
const EFFECTS_BUS := &"Effects"
## The music's channel: it has a filter that can muffle it (cut off the high
## notes), for layered songs when you're alone (see main.gd).
const MUSIC_BUS := &"Music"


## Makes the Effects and Music channels (once) and sets the overall and effects volumes.
static func apply_audio() -> void:
	if AudioServer.get_bus_index(EFFECTS_BUS) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, EFFECTS_BUS)
		AudioServer.set_bus_send(AudioServer.bus_count - 1, &"Master")
	if AudioServer.get_bus_index(MUSIC_BUS) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, MUSIC_BUS)
		AudioServer.set_bus_send(AudioServer.bus_count - 1, &"Master")
		var muffle := AudioEffectLowPassFilter.new()
		muffle.cutoff_hz = 20000.0
		AudioServer.add_bus_effect(AudioServer.bus_count - 1, muffle)
	_set_volume(&"Master", master_volume)
	_set_volume(EFFECTS_BUS, effects_volume)


static func _set_volume(bus: StringName, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_volume_db(index, linear_to_db(volume))
	AudioServer.set_bus_mute(index, volume <= 0.001)


## Puts the window into fullscreen or back to a window, as Settings.fullscreen says.
static func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


## The music's muffle: everything above `hz` is cut off (20000: nothing is).
static func set_music_cutoff(hz: float) -> void:
	var bus := AudioServer.get_bus_index(MUSIC_BUS)
	if bus != -1:
		(AudioServer.get_bus_effect(bus, 0) as AudioEffectLowPassFilter).cutoff_hz = hz


static func music_cutoff() -> float:
	var bus := AudioServer.get_bus_index(MUSIC_BUS)
	return (AudioServer.get_bus_effect(bus, 0) as AudioEffectLowPassFilter).cutoff_hz if bus != -1 else 20000.0
