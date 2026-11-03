class_name DropOff
extends Node3D
## Where the team brings collectibles (items marked `deliverable`). Carry one
## in, or throw it in, and it counts for everyone. The host checks; game/main.gd
## does the counting. Drop drop_off.tscn into a world to add one.

## Sent on the host when a collectible arrives: who brought it (node name, "" if
## nobody), and whether it was thrown in.
signal delivered(item: WorldItem, by: String, thrown: bool)

## The drop zone: a cylinder this wide (radius, metres) and tall, from the base up.
const RADIUS := 2.0
const HEIGHT := 3.0


func _ready() -> void:
	add_to_group(&"drop_offs")


func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	for item: WorldItem in get_tree().get_nodes_in_group(&"items"):
		if item.is_deliverable() and item.state in [WorldItem.State.IN_WORLD, WorldItem.State.HELD] and contains(item.global_position) and _same_world(item):
			var thrown := item.state == WorldItem.State.IN_WORLD and item.thrown_by() != ""
			var by := item.holder_name if item.holder_name else item.thrown_by()
			item.host_deliver()
			delivered.emit(item, by, thrown)


func contains(point: Vector3) -> bool:
	var offset := point - global_position
	return Vector2(offset.x, offset.z).length() <= RADIUS and offset.y >= -0.5 and offset.y <= HEIGHT


## Tests can run two games in one program: only take this world's items.
func _same_world(item: WorldItem) -> bool:
	var node := get_parent()
	while node and not node is Level:
		node = node.get_parent()
	return node != null and node.is_ancestor_of(item)
