class_name PlayerInput
extends Node
## Turns the keyboard/gamepad into a few plain variables the Player reads.
##
## Why a separate node? The Player's movement code never touches the keyboard
## directly — it only reads these variables. That keeps controls in one place
## (and lets the automated tests "press" buttons). In multiplayer, only the
## computer that controls a character gathers input for it.

## How much left/right steers you sideways while free-running.
const FREE_RUN_STEER := 0.6

## Which way the player wants to move, in world space, already turned to match
## the camera. Flat (y = 0) with a length between 0 and 1.
var move_direction := Vector3.ZERO
var jump_just_pressed := false
var jump_held := false
var crouch_just_pressed := false
var crouch_held := false
var toss_just_pressed := false
var respawn_just_pressed := false
## Holding the free-run button (Shift / right trigger) with free-run switched on.
var free_run_held := false
## False while a menu is open: gather() then reports "no buttons pressed".
var enabled := true


## Reads the local controls. Called by the Player once per physics tick,
## only when this character belongs to this machine.
func gather(camera_yaw: float) -> void:
	if not enabled:
		clear()
		return
	var stick := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	free_run_held = Settings.free_run_enabled and Input.is_action_pressed("free_run")
	if free_run_held:
		# Free-run: always run where the camera points; left/right nudge you sideways.
		move_direction = Vector3(stick.x * FREE_RUN_STEER, 0.0, -1.0).normalized().rotated(Vector3.UP, camera_yaw)
	else:
		move_direction = Vector3(stick.x, 0.0, stick.y).rotated(Vector3.UP, camera_yaw)
	jump_just_pressed = Input.is_action_just_pressed("jump")
	jump_held = Input.is_action_pressed("jump")
	crouch_just_pressed = Input.is_action_just_pressed("crouch")
	crouch_held = Input.is_action_pressed("crouch")
	toss_just_pressed = Input.is_action_just_pressed("toss")
	respawn_just_pressed = Input.is_action_just_pressed("respawn")


## Lets go of every button (used while controls are off, and by the practice buddy).
func clear() -> void:
	move_direction = Vector3.ZERO
	jump_just_pressed = false
	jump_held = false
	crouch_just_pressed = false
	crouch_held = false
	toss_just_pressed = false
	respawn_just_pressed = false
	free_run_held = false
