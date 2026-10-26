class_name ItemData
extends Resource
## Everything that makes one kind of item what it is. To add a new item:
##   1. In Godot's FileSystem panel, right-click items/data > Create New >
##      Resource > ItemData, and fill in the fields below in the Inspector.
##   2. Optionally give it an `ability` script (see items/item_ability.gd).
##   3. Place it in a world: add a WorldItem (items/world_item.tscn) and set
##      its `item` to your new file.

## A short id, unique among items (e.g. "glider").
@export var id: StringName
## The name players see ("Glider").
@export var display_name := "Item"

@export_group("Looks")
## Placeholder look: a coloured box this size (metres)...
@export var size := Vector3(0.6, 0.6, 0.6)
@export var color := Color(0.8, 0.8, 0.8)
## ...or a proper model scene, which replaces the box once there is one.
@export var model: PackedScene

@export_group("Physics")
@export var mass := 2.0
## How hard it flies when thrown (m/s).
@export var throw_speed := 14.0

@export_group("Returning home")
## Left lying away from its home spot this long (seconds), it goes back home.
@export var abandon_time := 90.0

@export_group("Ability")
## Optional script (extends ItemAbility) for what the item does while it's in
## your hands. Leave empty for items that are just carried.
@export var ability: Script
