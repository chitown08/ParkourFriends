@tool
class_name GrindRail
extends Node3D
## A rail you can land on and grind, like a skateboarder. It can be straight
## (just set end_point) or any shape (give it a `curve`: bends, dips and rises,
## like a roller coaster, trolley tracks, a sign's edge or a sagging wire).
## Wherever you are on it, its slope there pulls you downhill; push along it to
## go up (more slowly) or along a flat stretch. The ride itself is the
## player's Grind state.
##
## Places on the rail are measured in metres along it from its start (the
## curve's first point, or this node for a straight rail). The rail moves with
## its node, so a moving rail carries you along.

## Where a straight rail ends, relative to this node (used when there's no `curve`).
@export var end_point := Vector3(0, -6, -40):
	set(value):
		end_point = value
		_rebuild()
## The rail's shape, relative to this node. Leave empty for a straight rail to end_point.
@export var curve: Curve3D:
	set(value):
		curve = value
		_rebuild()

const RAIL_RADIUS := 0.08
## The rail's tube is drawn with this many sides...
const SIDES := 8
## ...and a ring at least every this many metres along it.
const RING_SPACING := 0.5

var _rail: MeshInstance3D
var _path: Curve3D


func _ready() -> void:
	add_to_group(&"grind_rails")
	_rebuild()


## How long the rail is (metres).
func length() -> float:
	return _shape().get_baked_length()


## The point `distance` metres along the rail from its start (world space).
func point_at_distance(distance: float) -> Vector3:
	return to_global(_shape().sample_baked(clampf(distance, 0.0, length()), true))


## Which way the rail runs at `distance` (toward its end; unit, world space).
func direction_at(distance: float) -> Vector3:
	var step := minf(0.25, length() / 2.0)
	var a := clampf(distance - step, 0.0, length() - 2.0 * step)
	return (point_at_distance(a + 2.0 * step) - point_at_distance(a)).normalized()


## How far along the rail (metres from its start) the point nearest `point` is.
func closest_distance(point: Vector3) -> float:
	return _shape().get_closest_offset(to_local(point))


## Its two ends (world space).
func start() -> Vector3:
	return point_at_distance(0.0)


func end() -> Vector3:
	return point_at_distance(length())


## The higher end of the rail (world space).
func top() -> Vector3:
	return start() if start().y >= end().y else end()


## The lower end of the rail (world space).
func bottom() -> Vector3:
	return end() if start().y >= end().y else start()


## The point along the rail at `t` (0 = its higher end, 1 = its lower end).
func point_at(t: float) -> Vector3:
	return point_at_distance(_from_top(clampf(t, 0.0, 1.0) * length()))


## How far along the rail (0..1 from its higher end) the point nearest `point` is.
func closest_t(point: Vector3) -> float:
	return _from_top(closest_distance(point)) / length()


## Turns a distance from the start into one from the higher end (and back).
func _from_top(distance: float) -> float:
	return distance if start().y >= end().y else length() - distance


func _shape() -> Curve3D:
	if _path == null:
		_rebuild()
	return _path


func _rebuild() -> void:
	if curve and curve.point_count >= 2:
		_path = curve
	else:
		_path = Curve3D.new()
		_path.add_point(Vector3.ZERO)
		_path.add_point(end_point)
	_path.bake_interval = 0.2
	if is_inside_tree():
		_build_visual()


## A tube along the rail.
func _build_visual() -> void:
	if _rail == null:
		_rail = MeshInstance3D.new()
		add_child(_rail)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.5, 0.95) # Blue: grind it.
	material.metallic = 0.5
	material.roughness = 0.3
	material.cull_mode = BaseMaterial3D.CULL_DISABLED # (Either way round the tube is wound.)
	var rings := maxi(int(ceil(_path.get_baked_length() / RING_SPACING)), 1)
	var tube := SurfaceTool.new()
	tube.begin(Mesh.PRIMITIVE_TRIANGLES)
	var last_side := Vector3.ZERO
	for i in rings + 1:
		var distance := _path.get_baked_length() * i / rings
		var at := _path.sample_baked(distance, true)
		var ahead := _path.sample_baked(minf(distance + 0.1, _path.get_baked_length()), true)
		var behind := _path.sample_baked(maxf(distance - 0.1, 0.0), true)
		var along := (ahead - behind).normalized()
		# Keep the rings from twisting: carry the side direction along.
		var side := last_side if last_side != Vector3.ZERO else along.cross(Vector3.UP)
		if side.length() < 0.01:
			side = along.cross(Vector3.RIGHT)
		side = (side - along * side.dot(along)).normalized()
		last_side = side
		var up := side.cross(along)
		for k in SIDES:
			var angle := TAU * k / SIDES
			var normal := side * cos(angle) + up * sin(angle)
			tube.set_normal(normal)
			tube.add_vertex(at + normal * RAIL_RADIUS)
	for i in rings:
		for k in SIDES:
			var a := i * SIDES + k
			var b := i * SIDES + (k + 1) % SIDES
			var c := a + SIDES
			var d := b + SIDES
			tube.add_index(a)
			tube.add_index(b)
			tube.add_index(c)
			tube.add_index(b)
			tube.add_index(d)
			tube.add_index(c)
	_rail.mesh = tube.commit()
	_rail.material_override = material
