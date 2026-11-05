@tool
class_name Ledges
extends Node3D
## Rows of window ledges along a building's wall, one at each of `heights`:
## yellow (climb) lips too narrow to stand on, but you can hang from them.
## Botch a jump at a wall like this and push toward it to catch the next ledge
## down. From any ledge, jump to leap up to the next (a storey up), shimmy
## along, or pull yourself onto the roof at the top (player/states/hang.gd).
##
## Its origin is at one end of the wall, on the ground; +X runs along the wall
## (`length` long) and +Z points out of it. Each ledge's top is at its height
## (above the origin). The rows leave `gaps` (from, to along the wall) clear,
## e.g. round a drainpipe. `top` is the height of the wall (its roof's edge).

const MATERIAL := preload("res://materials/grid_climb.tres")
## How far each ledge sticks out of the wall, and how thick it is.
const DEPTH := 0.5
const THICK := 0.3
## Pieces shorter than this (between gaps) are left out.
const SHORTEST := 1.0

@export var length := 10.0:
	set(value):
		length = value
		_build()
@export var heights := PackedFloat32Array():
	set(value):
		heights = value
		_build()
@export var gaps := PackedVector2Array():
	set(value):
		gaps = value
		_build()
@export var top := 14.0

var _parts: Node3D


func _ready() -> void:
	add_to_group(&"ledges")
	_build()


## Flat direction pointing out of the wall.
func out_of_wall() -> Vector3:
	var out := global_basis.z
	return Vector3(out.x, 0.0, out.z).normalized()


## Flat direction along the wall (+X).
func along_wall() -> Vector3:
	var along := global_basis.x
	return Vector3(along.x, 0.0, along.z).normalized()


## The pieces of each row, from, to along the wall (between the gaps).
func pieces() -> Array[Vector2]:
	var found: Array[Vector2] = [Vector2(0.0, length)]
	for gap in gaps:
		var kept: Array[Vector2] = []
		for piece in found:
			if gap.y <= piece.x or gap.x >= piece.y:
				kept.append(piece)
				continue
			if gap.x - piece.x >= SHORTEST:
				kept.append(Vector2(piece.x, gap.x))
			if piece.y - gap.y >= SHORTEST:
				kept.append(Vector2(gap.y, piece.y))
		found = kept
	return found


## A point on the wall's face, `along` it, at height `y` (world space, y too).
func point_at(along: float, y: float) -> Vector3:
	var at := global_position + along_wall() * along
	return Vector3(at.x, y, at.z)


func _build() -> void:
	if not is_inside_tree():
		return
	if _parts:
		_parts.free()
	_parts = Node3D.new()
	add_child(_parts)
	var body := StaticBody3D.new()
	_parts.add_child(body)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	for piece in pieces():
		var size := Vector3(piece.y - piece.x, THICK, DEPTH)
		var box := BoxShape3D.new()
		box.size = size
		var mesh := BoxMesh.new()
		mesh.size = size
		for y in heights:
			var middle := Vector3((piece.x + piece.y) / 2.0, y - THICK / 2.0, DEPTH / 2.0)
			var shape := CollisionShape3D.new()
			shape.shape = box
			shape.position = middle
			body.add_child(shape)
			tool.append_from(mesh, 0, Transform3D(Basis.IDENTITY, middle))
			count += 1
	if count == 0:
		return
	var rows := MeshInstance3D.new()
	rows.mesh = tool.commit()
	rows.material_override = MATERIAL
	_parts.add_child(rows)


## The ledge (to hang from) nearest `at` (world space): the row whose top is
## nearest its height, at the point along the wall nearest it.
func ledge_near(at: Vector3) -> Ledge:
	var base := global_position.y
	var best := INF
	for h in heights:
		if absf(base + h - at.y) < absf(best - at.y):
			best = base + h
	var along := (at - global_position).dot(along_wall())
	var nearest := INF
	for piece in pieces():
		var on := clampf(along, piece.x + 0.3, piece.y - 0.3)
		if absf(on - along) < absf(nearest - along):
			nearest = on
	if is_inf(best) or is_inf(nearest):
		return null
	var ledge := Ledge.new()
	ledge.normal = out_of_wall()
	ledge.position = point_at(nearest, best) + ledge.normal * DEPTH
	ledge.height = best - at.y
	ledge.can_stand = false
	return ledge
