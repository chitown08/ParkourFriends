@tool
class_name Zipline
extends Node3D
## A cable you can grab and slide down (downhill only). The cable runs from
## this node's position to end_point (relative to the node); whichever end is
## higher is the top. The ride itself is the player's Zipline state.

## Where the cable ends, relative to this node.
@export var end_point := Vector3(0, -6, -40):
	set(value):
		end_point = value
		if is_inside_tree():
			_build_visual()

const CABLE_RADIUS := 0.06

var _cable: MeshInstance3D


func _ready() -> void:
	add_to_group(&"ziplines")
	_build_visual()


## The higher end of the cable (world space).
func top() -> Vector3:
	var a := global_position
	var b := to_global(end_point)
	return a if a.y >= b.y else b


## The lower end of the cable (world space).
func bottom() -> Vector3:
	var a := global_position
	var b := to_global(end_point)
	return b if a.y >= b.y else a


func length() -> float:
	return top().distance_to(bottom())


## Unit direction from the top end toward the bottom end (the way you slide).
func down_direction() -> Vector3:
	return (bottom() - top()).normalized()


## The point along the cable at `t` (0 = top end, 1 = bottom end).
func point_at(t: float) -> Vector3:
	return top().lerp(bottom(), clampf(t, 0.0, 1.0))


## How far along the cable (0..1 from the top) the point nearest `point` is.
func closest_t(point: Vector3) -> float:
	var along := bottom() - top()
	return clampf((point - top()).dot(along) / along.length_squared(), 0.0, 1.0)


func _build_visual() -> void:
	if _cable == null:
		_cable = MeshInstance3D.new()
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.15, 0.15, 0.18)
		material.metallic = 0.6
		var mesh := CylinderMesh.new()
		mesh.top_radius = CABLE_RADIUS
		mesh.bottom_radius = CABLE_RADIUS
		mesh.material = material
		_cable.mesh = mesh
		add_child(_cable)
	var mesh := _cable.mesh as CylinderMesh
	mesh.height = end_point.length()
	_cable.position = end_point * 0.5
	if end_point.length() > 0.001:
		_cable.basis = Basis(Quaternion(Vector3.UP, end_point.normalized()))
