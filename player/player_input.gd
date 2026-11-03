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
## Hold the item button (F / X) this long (seconds) to throw what you hold;
## a quicker press picks up, drops or hands over.
const THROW_HOLD := 0.3

## Which way the player wants to move, in world space, already turned to match
## the camera. Flat (y = 0) with a length between 0 and 1.
var move_direction := Vector3.ZERO
var jump_just_pressed := false
var jump_held := false
var crouch_just_pressed := false
var crouch_held := false
var toss_just_pressed := false
var interact_just_pressed := false
var throw_item_just_pressed := false
var switch_item_just_pressed := false
var use_item_just_pressed := false
var use_item_held := false
var respawn_just_pressed := false
## How long the item button has been held (seconds), or -1 when it isn't.
var _item_held := -1.0
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
	_gather_item_button()
	switch_item_just_pressed = Input.is_action_just_pressed("switch_item")
	use_item_just_pressed = Input.is_action_just_pressed("use_item")
	use_item_held = Input.is_action_pressed("use_item")
	respawn_just_pressed = Input.is_action_just_pressed("respawn")


## Lets go of every button (used while controls are off, and by the practice buddy).
func clear() -> void:
	move_direction = Vector3.ZERO
	jump_just_pressed = false
	jump_held = false
	crouch_just_pressed = false
	crouch_held = false
	toss_just_pressed = false
	interact_just_pressed = false
	throw_item_just_pressed = false
	switch_item_just_pressed = false
	use_item_just_pressed = false
	use_item_held = false
	respawn_just_pressed = false
	free_run_held = false
	_item_held = -1.0


## The item button: a quick press (on letting go) picks up, drops or hands
## over; held for THROW_HOLD it throws instead (as soon as it's been held that long).
func _gather_item_button() -> void:
	interact_just_pressed = false
	throw_item_just_pressed = false
	if Input.is_action_pressed("interact"):
		var before := maxf(_item_held, 0.0)
		_item_held = before + 1.0 / Engine.physics_ticks_per_second
		throw_item_just_pressed = before < THROW_HOLD and _item_held >= THROW_HOLD
	elif _item_held >= 0.0 or Input.is_action_just_pressed("interact"):
		interact_just_pressed = _item_held < THROW_HOLD
		_item_held = -1.0
