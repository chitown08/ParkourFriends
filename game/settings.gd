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
## Moving the mouse/stick up looks down instead of up.
static var invert_y := false


static func load_from_disk() -> void:
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		return # No saved settings yet: keep the defaults.
	mouse_sensitivity = file.get_value("camera", "mouse_sensitivity", mouse_sensitivity)
	invert_y = file.get_value("camera", "invert_y", invert_y)
	movement_profile = file.get_value("movement", "profile", movement_profile)


static func save_to_disk() -> void:
	var file := ConfigFile.new()
	file.set_value("camera", "mouse_sensitivity", mouse_sensitivity)
	file.set_value("camera", "invert_y", invert_y)
	file.set_value("movement", "profile", movement_profile)
	file.save(PATH)
