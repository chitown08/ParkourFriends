@tool
class_name Scaffold
extends Drainpipe
## Yellow scaffolding up the side of a building: a climbing frame `width` wide
## and DEPTH deep, standing on the ground against the wall, up to the roof
## edge. You climb it like a drainpipe (player/states/pipe_climb.gd), but
## anywhere across its face: run or jump into it to grab hold (a jump across
## the gap from a lower roof next door will do), push toward the wall to climb,
## and pull yourself up onto its top, beside the roof.
##
## Its origin is on the ground in the middle of its foot, against the wall; +Z
## points out of the wall. It's `height` tall: the height of the roof edge.

## How far it stands out from the wall.
const DEPTH := 1.5
## A lift (a level of boards and cross-bars) about this far apart.
const LIFT := 2.0
## You're held this far in from its sides at most.
const SIDE_IN := 0.3
const POST := 0.12
const BAR := 0.07

@export var width := 3.0:
	set(value):
		width = value
		_build()


## The middle of its face (where you climb) at height `y` (world space).
func point_at(y: float) -> Vector3:
	var foot := global_position + out_of_wall() * (DEPTH - RADIUS)
	return Vector3(foot.x, y, foot.z)


## Where you hold on near `at`: on its face, at that height, across it as far
## as `at` is (not past its sides).
func grab_point(at: Vector3) -> Vector3:
	var middle := point_at(at.y)
	var across := global_basis.x
	across = Vector3(across.x, 0.0, across.z).normalized()
	var side := width / 2.0 - SIDE_IN
	return middle + across * clampf((at - middle).dot(across), -side, side)


func _build() -> void:
	if not is_inside_tree():
		return
	if _parts:
		_parts.free()
	_parts = Node3D.new()
	add_child(_parts)
	# Solid all through (you climb its face, stand on its top).
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, height, DEPTH)
	shape.shape = box
	shape.position = Vector3(0.0, height / 2.0, DEPTH / 2.0)
	body.add_child(shape)
	_parts.add_child(body)
	# The frame: a post at each corner, and at each lift cross-bars round it,
	# boards across it, and a brace across its face (zig-zagging up).
	var bars: Array = [] # [middle, size, turn about z]
	var half := width / 2.0 - POST / 2.0
	for corner: Vector2 in [Vector2(-half, POST / 2.0), Vector2(half, POST / 2.0), Vector2(-half, DEPTH - POST / 2.0), Vector2(half, DEPTH - POST / 2.0)]:
		bars.append([Vector3(corner.x, height / 2.0, corner.y), Vector3(POST, height, POST), 0.0])
	var lifts := maxi(1, roundi(height / LIFT))
	var lift := height / lifts
	for i in range(1, lifts + 1):
		var y := i * lift
		bars.append([Vector3(0.0, y - BAR / 2.0, DEPTH - POST / 2.0), Vector3(width, BAR, BAR), 0.0])
		bars.append([Vector3(0.0, y - BAR / 2.0, POST / 2.0), Vector3(width, BAR, BAR), 0.0])
		bars.append([Vector3(0.0, y - 0.03, DEPTH / 2.0), Vector3(width - 2.0 * POST, 0.06, DEPTH - 2.0 * POST), 0.0])
		var slope := atan2(lift, width - POST) * (1.0 if i % 2 == 0 else -1.0)
		bars.append([Vector3(0.0, y - lift / 2.0, DEPTH - POST / 2.0), Vector3(Vector2(width - POST, lift).length(), BAR, BAR), slope])
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for bar: Array in bars:
		var mesh := BoxMesh.new()
		mesh.size = bar[1]
		tool.append_from(mesh, 0, Transform3D(Basis(Vector3.BACK, bar[2]), bar[0]))
	var frame := MeshInstance3D.new()
	frame.mesh = tool.commit()
	frame.material_override = MATERIAL
	_parts.add_child(frame)
