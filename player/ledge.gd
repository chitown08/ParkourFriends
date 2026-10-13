class_name Ledge
extends RefCounted
## A grabbable ledge found by Player.find_ledge().

## A point on the top edge of the ledge.
var position: Vector3
## Flat direction pointing out of the wall, toward the player.
var normal: Vector3
## How far the ledge top is above the player's feet when it was found.
var height: float
