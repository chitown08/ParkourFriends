class_name Kite
extends Node3D
## A kite flying high behind you on a long string, from your back: big, so
## friends can spot you from across the city. (A trail cosmetic, kind "kite":
## Cosmetics.wear() sets one up; see docs/COSMETICS_GUIDE.md.)
##
## The kite is a point on the end of its string, pushed up (lift) and out
## behind you (the breeze, and the wind of your running) and pulled back to the
## string's length; it lags as you turn, sways and bobs. If something's in the
## way (a roof, a ceiling) the string is shorter, so it doesn't fly through. The
## kite faces back along its string, and fades to see-through when it's
## between the camera and you. Only for looks: every screen runs its own.

## How long the string is (metres), and the pushes on the kite (m/s²).
const STRING_LENGTH := 11.0
const LIFT := 24.0
const BREEZE := 8.0
const GRAVITY := 9.8
## Your running pushes it back this much per m/s you're going.
const RUN_WIND := 0.8
## How much it tips its face down toward you (0: stands straight up, 1: faces
## right down the string).
const UPRIGHT := 0.35
## How quickly it stops swinging (the share of its speed lost each 1/60 s).
const DRAG := 0.06
## The sway (side to side) and bob (up and down) it makes on its own (m/s²), and how fast.
const SWAY := 6.0
const SWAY_RATE := 0.9
const BOB := 3.0
const BOB_RATE := 1.7
## It keeps this far back from anything in the string's way.
const CLEAR := 1.0
## How see-through it gets in front of the camera, and how quickly it fades.
const FADED := 0.25
const FADE_RATE := 6.0
## The string: its colour, and how much it sags in the middle (per metre of string).
const STRING_COLOR := Color(0.95, 0.95, 0.9)
const SAG := 0.012
const STRING_POINTS := 12
## Jumps further than this in one frame (a respawn) lay it out afresh.
const TELEPORT := 8.0

## Where the string starts (on your back; it follows this node).
var anchor: Node3D
## The character's skeleton: which way it faces.
var body: Skeleton3D
## How big the kite is across (metres).
var size := 2.4

var _kite: Node3D
var _string: MeshInstance3D
var _materials: Array[BaseMaterial3D] = []
var _point := Vector3.ZERO
var _previous := Vector3.ZERO
var _last_step := Vector3.ZERO
var _last_root := Vector3.INF
var _alpha := 1.0
var _time := 0.0
var _settled := false


## Builds the kite from `model` (a PackedScene) whose `facing` direction (in
## its own axes) is the way its face looks (toward you, down the string) and
## whose `up` direction is the top of the kite.
func build(model: PackedScene, facing: Vector3, up: Vector3) -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_time = randf() * 10.0 # (So two kites don't sway in step.)
	var source := model.instantiate() as Node3D
	# Its own axes into the kite's: facing -> +z, up -> +y; centred, `size` across.
	facing = facing.normalized()
	up = (up - facing * up.dot(facing)).normalized()
	var to_kite := Basis(up.cross(facing), up, facing).transposed()
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		var b := _to_root(mesh, source) * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var across := maxf(box.size.x, maxf(box.size.y, box.size.z))
	var scale := size / maxf(across, 0.001)
	source.transform = Transform3D(to_kite.scaled(Vector3.ONE * scale), -(to_kite * box.get_center()) * scale)
	_kite = Node3D.new()
	add_child(_kite)
	_kite.add_child(source)
	# Its own copies of the materials, to fade.
	for mesh: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		for s in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(s)
			if material is BaseMaterial3D:
				material = material.duplicate()
				material.cull_mode = BaseMaterial3D.CULL_DISABLED # (Thin sail: both sides show.)
				mesh.set_surface_override_material(s, material)
				_materials.append(material)
	_string = MeshInstance3D.new()
	_string.mesh = ImmediateMesh.new()
	var line := StandardMaterial3D.new()
	line.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line.albedo_color = STRING_COLOR
	_string.material_override = line
	_string.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_string)


func _physics_process(delta: float) -> void:
	if anchor == null or body == null or not anchor.is_inside_tree():
		return
	_time += delta
	var root := anchor.global_position
	if not _settled or root.distance_to(_point) > STRING_LENGTH + TELEPORT:
		_lay_out(root)
	_last_step = _point
	# The air it flies in moves with you (the wind of your running lifts it,
	# rather than dragging it down behind you).
	var carried := root - _last_root if _last_root != Vector3.INF else Vector3.ZERO
	_last_root = root
	var running := Vector2(carried.x, carried.z).length() / maxf(delta, 0.001)
	var behind := _behind()
	var side := Vector3.UP.cross(behind)
	var push := Vector3.UP * (LIFT - GRAVITY + sin(_time * BOB_RATE) * BOB) \
			+ behind * (BREEZE + running * RUN_WIND) + side * sin(_time * SWAY_RATE) * SWAY
	var keep := pow(1.0 - DRAG, delta * 60.0)
	var moving := (_point - _previous - carried) * keep + carried
	_previous = _point
	_point += moving + push * delta * delta
	# On its string: no further than its length (or than what's in the way).
	var reach := _reach(root, _point)
	var out := _point - root
	if out.length() > reach:
		_point = root + out.normalized() * reach


func _process(delta: float) -> void:
	if not _settled or anchor == null or not anchor.is_inside_tree():
		return
	var between := Engine.get_physics_interpolation_fraction() if get_tree().physics_interpolation else 1.0
	var at := _last_step.lerp(_point, between)
	var root := anchor.global_position
	# Facing whoever's looking (the camera: a flat kite seen edge-on would
	# vanish, and it's there to be spotted from afar), stood up (tipped only a
	# little toward them), its top kept up.
	var camera := get_viewport().get_camera_3d()
	var facing := (camera.global_position if camera else root) - at
	facing.y *= UPRIGHT
	facing = facing.normalized() if facing.length() > 0.01 else -_behind()
	var up := Vector3.UP - facing * facing.dot(Vector3.UP)
	up = up.normalized() if up.length() > 0.05 else _behind()
	_kite.global_transform = Transform3D(Basis(up.cross(facing), up, facing), at)
	_draw_string(root, at)
	_fade(at, root, delta)


## Straight out where it would fly, behind you and up.
func _lay_out(root: Vector3) -> void:
	var out := (Vector3.UP * (LIFT - GRAVITY) + _behind() * BREEZE).normalized()
	_point = root + out * _reach(root, root + out * STRING_LENGTH)
	_previous = _point
	_last_root = root
	_last_step = _point
	_settled = true


## How far out the kite can be along the way from `root` to `to`: the string's
## length, or short of whatever's in the way.
func _reach(root: Vector3, to: Vector3) -> float:
	var way := (to - root).normalized() if root.distance_to(to) > 0.01 else Vector3.UP
	var query := PhysicsRayQueryParameters3D.create(root + way * 0.5, root + way * (STRING_LENGTH + size / 2.0))
	var players := get_tree().get_nodes_in_group(&"players")
	query.exclude = players.map(func(p: Node) -> RID: return (p as CollisionObject3D).get_rid())
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return STRING_LENGTH
	return maxf(root.distance_to(hit.position) - size / 2.0 - CLEAR, 1.0)


## The way out behind the character.
func _behind() -> Vector3:
	var back := -body.global_basis.z
	back.y = 0.0
	return back.normalized() if back.length() > 0.01 else Vector3.BACK


## A thin string from your back to the kite, sagging a little in the middle.
func _draw_string(from: Vector3, to: Vector3) -> void:
	var mesh := _string.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var sag := from.distance_to(to) * SAG
	for i in STRING_POINTS + 1:
		var t := float(i) / STRING_POINTS
		mesh.surface_add_vertex(from.lerp(to, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t))
	mesh.surface_end()


## See-through while it's between the camera and the character it belongs to.
func _fade(at: Vector3, root: Vector3, delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var wanted := 1.0
	if camera:
		var eye := camera.global_position
		var nearest := Geometry3D.get_closest_point_to_segment(at, eye, root)
		if nearest.distance_to(at) < size * 0.75 and eye.distance_to(at) < eye.distance_to(root) + size:
			wanted = FADED
	_alpha = move_toward(_alpha, wanted, FADE_RATE * delta)
	for material in _materials:
		material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if _alpha >= 0.999 else BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color.a = _alpha


## Where the kite is (for tests), and how see-through (1 = not at all).
func kite_position() -> Vector3:
	return _point


func alpha() -> float:
	return _alpha


func _to_root(node: Node3D, root: Node3D) -> Transform3D:
	var transform := Transform3D()
	var at: Node = node
	while at != root:
		transform = (at as Node3D).transform * transform
		at = at.get_parent()
	return transform
