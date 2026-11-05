@tool
class_name Stairs
extends Node3D
## A flight of fire escape stairs: `run` long, climbing `rise`, `width` wide,
## with a handrail along its outer side. You run straight up it (it's a smooth
## slope underfoot, steps to look at).
##
## Its origin is at the bottom of the flight, in the middle of its width; +X
## runs up the flight and +Z points out of the building's wall (or into it,
## if `landing_in` is negative). The deck it leads from and to (at each end)
## is `landing_in` toward the wall from it.

const MATERIAL := preload("res://materials/iron.tres")
const THICK := 0.2
const STEP := 0.25 ## Each step about this tall.
const RAIL := 1.0 ## The handrail's height.
const BAR := 0.06

@export var run := 5.0:
	set(value):
		run = value
		_build()
@export var rise := 3.5:
	set(value):
		rise = value
		_build()
@export var width := 1.2:
	set(value):
		width = value
		_build()
@export var landing_in := 1.35

var _parts: Node3D


func _ready() -> void:
	_build()


## The bottom and top of the flight, on its middle line (world space).
func bottom() -> Vector3:
	return global_position


func top() -> Vector3:
	return global_transform * Vector3(run, rise, 0.0)


## Flat direction toward the wall (to the decks either end).
func toward_wall() -> Vector3:
	var back := -global_basis.z * signf(landing_in)
	return Vector3(back.x, 0.0, back.z).normalized()


func _build() -> void:
	if not is_inside_tree():
		return
	if _parts:
		_parts.free()
	_parts = Node3D.new()
	add_child(_parts)
	# A smooth slab underfoot, its top from the bottom to the top of the flight.
	var angle := atan2(rise, run)
	var basis := Basis(Vector3.BACK, angle)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(Vector2(run, rise).length(), THICK, width)
	shape.shape = slab
	shape.transform = Transform3D(basis, Vector3(run / 2.0, rise / 2.0, 0.0) - basis.y * THICK / 2.0)
	body.add_child(shape)
	_parts.add_child(body)
	# To look at: steps, a stringer each side, a handrail on posts outside.
	var boxes: Array = [] # [middle, size, turn about z]
	var steps := maxi(1, roundi(rise / STEP))
	for i in steps:
		var going := run / steps
		boxes.append([Vector3((i + 0.5) * going, (i + 1) * rise / steps - 0.04, 0.0), Vector3(going + 0.05, 0.08, width - 0.1), 0.0])
	var slope_length := Vector2(run, rise).length()
	for side: float in [-1.0, 1.0]:
		var at := Vector3(run / 2.0, rise / 2.0, side * (width / 2.0 - BAR)) - basis.y * 0.1
		boxes.append([at, Vector3(slope_length, 0.25, BAR), angle])
	var outer := (width / 2.0 - BAR / 2.0) * signf(landing_in)
	boxes.append([Vector3(run / 2.0, rise / 2.0 + RAIL, outer), Vector3(slope_length, BAR, BAR), angle])
	for post in 3:
		var x := run * post / 2.0
		boxes.append([Vector3(x, x * rise / run + RAIL / 2.0, outer), Vector3(BAR, RAIL, BAR), 0.0])
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for box: Array in boxes:
		var mesh := BoxMesh.new()
		mesh.size = box[1]
		tool.append_from(mesh, 0, Transform3D(Basis(Vector3.BACK, box[2]), box[0]))
	var look := MeshInstance3D.new()
	look.mesh = tool.commit()
	look.material_override = MATERIAL
	_parts.add_child(look)
