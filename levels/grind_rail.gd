@tool
class_name GrindRail
extends Node3D
## A rail you can land on and grind, like a skateboarder: it slides you down,
## or you can push your way (more slowly) up.
## The rail runs from this node's position to end_point (relative to the node);
## whichever end is higher is the top. The ride itself is the player's Grind state.

## Where the rail ends, relative to this node.
@export var end_point := Vector3(0, -6, -40):
	set(value):
		end_point = value
		if is_inside_tree():
			_build_visual()

const RAIL_RADIUS := 0.08

var _rail: MeshInstance3D


func _ready() -> void:
	add_to_group(&"grind_rails")
	_build_visual()


## The higher end of the rail (world space).
func top() -> Vector3:
	var a := global_position
	var b := to_global(end_point)
	return a if a.y >= b.y else b


## The lower end of the rail (world space).
func bottom() -> Vector3:
	var a := global_position
	var b := to_global(end_point)
	return b if a.y >= b.y else a


func length() -> float:
	return top().distance_to(bottom())


## Unit direction from the top end toward the bottom end (the way you slide).
func down_direction() -> Vector3:
	return (bottom() - top()).normalized()


## The point along the rail at `t` (0 = top end, 1 = bottom end).
func point_at(t: float) -> Vector3:
	return top().lerp(bottom(), clampf(t, 0.0, 1.0))


## How far along the rail (0..1 from the top) the point nearest `point` is.
func closest_t(point: Vector3) -> float:
	var along := bottom() - top()
	return clampf((point - top()).dot(along) / along.length_squared(), 0.0, 1.0)


func _build_visual() -> void:
	if _rail == null:
		_rail = MeshInstance3D.new()
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.75, 0.77, 0.8)
		material.metallic = 0.8
		material.roughness = 0.3
		var mesh := CylinderMesh.new()
		mesh.top_radius = RAIL_RADIUS
		mesh.bottom_radius = RAIL_RADIUS
		mesh.material = material
		_rail.mesh = mesh
		add_child(_rail)
	var mesh := _rail.mesh as CylinderMesh
	mesh.height = end_point.length()
	_rail.position = end_point * 0.5
	if end_point.length() > 0.001:
		_rail.basis = Basis(Quaternion(Vector3.UP, end_point.normalized()))
