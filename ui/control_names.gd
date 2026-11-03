class_name ControlNames
extends RefCounted
## What to call each control on screen: the keyboard/mouse name, or the
## gamepad one while you're playing with a gamepad (whichever you touched last).

## True after a gamepad button or stick, false after a key or the mouse.
static var gamepad := false

const KEYBOARD := {
	&"move": "WASD",
	&"look": "Mouse",
	&"jump": "Space",
	&"free_run": "Shift",
	&"crouch": "C",
	&"toss": "E",
	&"interact": "F",
	&"use_item": "Click",
	&"rally": "Q",
	&"respawn": "R",
	&"pause": "Esc",
	&"toggle_help": "F1",
}
const GAMEPAD := {
	&"move": "Left stick",
	&"look": "Right stick",
	&"jump": "A",
	&"free_run": "RT",
	&"crouch": "B",
	&"toss": "RB",
	&"interact": "X",
	&"use_item": "LT",
	&"rally": "LB",
	&"respawn": "Back",
	&"pause": "Start",
	&"toggle_help": "",
}


## The name of the control for `action` (e.g. "E" or "RB"), or "" if it has none.
static func key(action: StringName) -> String:
	return (GAMEPAD if gamepad else KEYBOARD).get(action, "")


## Notes which kind of controller `event` came from.
static func note(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		gamepad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		gamepad = false
