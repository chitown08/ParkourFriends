@tool
class_name ZipLine
extends Node3D
## A zip line: a blue cable from a pole on a high roof down to a pole on a
## lower one, often across a street or the boulevard. Jump up and grab it (or
## catch it on the way past), and you whizz down it hanging by your hands
## (player/states/zip.gd), faster the steeper it is, and are flung off the end
## onto the lower roof. Jump to let go early.
##
## Its origin is at the foot of the high pole, on the roof; `end` is the foot
## of the low one (from the origin). Both poles are POLE tall; the cable runs
## between their tops.

const POLE := 3.0
const POLE_RADIUS := 0.08
const CABLE_RADIUS := 0.035
const POLE_MATERIAL := preload("res://materials/iron.tres")
## You hold on this far above your feet.
const HANDS := 2.0
## Hands within this of the cable catch hold.
const GRAB_REACH := 0.7

@export var end := Vector3(30, -10, 0):
	set(value):
		end = value
		_build()

var _parts: Node3D


func _ready() -> void:
	add_to_group(&"zip_lines")
	_build()


## The top of the high pole and of the low one (world space).
func start_point() -> Vector3:
	return global_transform * Vector3(0, POLE, 0)


func end_point() -> Vector3:
	return global_transform * (end + Vector3(0, POLE, 0))


func length() -> float:
	return start_point().distance_to(end_point())


## The way down the cable (a unit vector).
func direction() -> Vector3:
	return (end_point() - start_point()).normalized()


## How far down the cable (metres from the top) the point nearest `at` is.
func closest_distance(at: Vector3) -> float:
	return clampf((at - start_point()).dot(direction()), 0.0, length())


func point_at(distance: float) -> Vector3:
	return start_point() + direction() * distance


func _build() -> void:
	if not is_inside_tree():
		return
	if _parts:
		_parts.free()
	_parts = Node3D.new()
	add_child(_parts)
	for foot: Vector3 in [Vector3.ZERO, end]:
		var pole := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = POLE_RADIUS
		cylinder.bottom_radius = POLE_RADIUS
		cylinder.height = POLE + 0.3
		pole.mesh = cylinder
		pole.material_override = POLE_MATERIAL
		pole.position = foot + Vector3(0, (POLE + 0.3) / 2.0, 0)
		_parts.add_child(pole)
	var top := Vector3(0, POLE, 0)
	var bottom := end + Vector3(0, POLE, 0)
	var cable := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = CABLE_RADIUS
	tube.bottom_radius = CABLE_RADIUS
	tube.height = top.distance_to(bottom)
	tube.radial_segments = 6
	cable.mesh = tube
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.5, 0.95) # Blue: ride it (like a grind rail).
	material.metallic = 0.5
	material.roughness = 0.3
	cable.material_override = material
	# A cylinder stands along its y: turn y to run down the cable.
	var y := (bottom - top).normalized()
	var x := y.cross(Vector3.UP).normalized() if absf(y.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var z := x.cross(y)
	cable.transform = Transform3D(Basis(x, y, z), (top + bottom) / 2.0)
	_parts.add_child(cable)
