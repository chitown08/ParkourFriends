class_name PlayerInput
extends Node
## Turns the keyboard/gamepad into a few plain variables the Player reads.
##
## Why a separate node? The Player's movement code never touches the keyboard
## directly — it only reads these variables. In multiplayer, each machine only
## gathers input for its *own* character; for everyone else these variables
## will be filled in from the network instead (e.g. by a MultiplayerSynchronizer).

## Which way the player wants to move, in world space, already turned to match
## the camera. Flat (y = 0) with a length between 0 and 1.
var move_direction := Vector3.ZERO
var jump_just_pressed := false
var jump_held := false
var sprint_held := false
var respawn_just_pressed := false


## Reads the local controls. Called by the Player once per physics tick,
## only when this character belongs to this machine.
func gather(camera_yaw: float) -> void:
	var stick := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	move_direction = Vector3(stick.x, 0.0, stick.y).rotated(Vector3.UP, camera_yaw)
	jump_just_pressed = Input.is_action_just_pressed("jump")
	jump_held = Input.is_action_pressed("jump")
	sprint_held = Input.is_action_pressed("sprint")
	respawn_just_pressed = Input.is_action_just_pressed("respawn")
