class_name Ledge
extends RefCounted
## A grabbable ledge found by Player.find_ledge().

## A point on the top edge of the ledge.
var position: Vector3
## Flat direction pointing out of the wall, toward the player.
var normal: Vector3
## How far the ledge top is above the player's feet when it was found.
var height: float
## How steeply the top rises going in from the edge (metres up per metre in):
## 0 for a flat top, more for a sloped roof seen from its low edge.
var slope := 0.0
## False for "hang-only" ledges like narrow window sills: you can hang from
## them, but there's no room to stand on top (jumping leaps to the next ledge
## up instead of pulling you up).
var can_stand := true
