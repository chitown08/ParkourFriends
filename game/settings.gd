class_name Settings
extends RefCounted
## The player's preferences, saved between sessions.
##
## Use them from any script, e.g. Settings.mouse_sensitivity. They're stored in
## Godot's per-user data folder (on Windows: %APPDATA%\Godot\app_userdata\
## Parkour Friends\settings.cfg), not in the project.

const PATH := "user://settings.cfg"

## Multiplies the camera's turning speed with the mouse. 1.0 = default.
static var mouse_sensitivity := 1.0
## Which movement feel to use: "superhuman" or "human" (see player/profiles/).
static var movement_profile := "superhuman"
## Hold Shift / right trigger to free-run (auto-run and auto-parkour). Can be
## switched off in the pause menu.
static var free_run_enabled := true
## Moving the mouse/stick up looks down instead of up.
static var invert_y := false
## Background music loudness, 0 (silent) to 1 (full).
static var music_volume := 0.5
## M switches the music off and on.
static var music_on := true


static func load_from_disk() -> void:
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		return # No saved settings yet: keep the defaults.
	mouse_sensitivity = file.get_value("camera", "mouse_sensitivity", mouse_sensitivity)
	invert_y = file.get_value("camera", "invert_y", invert_y)
	movement_profile = file.get_value("movement", "profile", movement_profile)
	free_run_enabled = file.get_value("movement", "free_run", free_run_enabled)
	music_volume = file.get_value("audio", "music_volume", music_volume)
	music_on = file.get_value("audio", "music_on", music_on)


static func save_to_disk() -> void:
	var file := ConfigFile.new()
	file.set_value("camera", "mouse_sensitivity", mouse_sensitivity)
	file.set_value("camera", "invert_y", invert_y)
	file.set_value("movement", "profile", movement_profile)
	file.set_value("movement", "free_run", free_run_enabled)
	file.set_value("audio", "music_volume", music_volume)
	file.set_value("audio", "music_on", music_on)
	file.save(PATH)
