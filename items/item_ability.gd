class_name ItemAbility
extends RefCounted
## What an item does while it's in a player's hands. Make a script that
## `extends ItemAbility`, override the functions you need, and set it as the
## `ability` in the item's ItemData. It runs on the holder's own computer.

## The item this ability belongs to.
var item: WorldItem


## The item went into the player's hands.
func equipped(_player: Player) -> void:
	pass


## The item left the player's hands (dropped, thrown, given away or moved to their back).
func unequipped(_player: Player) -> void:
	pass


## Every physics tick while in the player's hands, after they've moved.
func physics_update(_player: Player, _delta: float) -> void:
	pass


## The player pressed "use item" (right mouse / left trigger).
func use(_player: Player) -> void:
	pass
