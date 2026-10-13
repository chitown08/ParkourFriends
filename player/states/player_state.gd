class_name PlayerState
extends Node
## One "mode" the player can be in: on the ground, in the air, hanging, ...
##
## Exactly one state is active at a time. Each state decides how the player
## moves while it's active, and when to switch to another state by calling
## player.change_state(). To add a new move, add a new state.

var player: Player
var input: PlayerInput


## Called when the player switches into this state. `data` can carry extra
## info from the previous state (e.g. which ledge was grabbed).
func enter(_data: Dictionary) -> void:
	pass


## Called when the player switches out of this state.
func exit() -> void:
	pass


## Called every physics tick (60 times a second) while this state is active.
func physics_update(_delta: float) -> void:
	pass
