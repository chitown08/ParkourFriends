class_name Trail
extends Node3D
## A cosmetic that streams out behind you so friends can spot you from far
## away: a banner or streamer flying from a pole on your back, or a scarf's tail.
## (Cosmetics.wear() sets one up; see docs/COSMETICS_GUIDE.md.)
##
## The model is made straight and flat. Here it's bent along a chain of points
## that follows you like a tail: it lags behind as you move, sags a little,
## catches a light breeze, ripples, and keeps out of your body. It's only for
## looks, so every screen runs its own (nothing goes over the network).

## How each kind of trail moves (accelerations in m/s²):
##   gravity  how much it sags
##   breeze   a steady push out behind you, so it flies even when you stand still
##   ripple   the side-to-side wave running down it (bigger the faster you go)
##   wave     how many ripples fit along it
##   drag     how quickly it stops swinging (0..1, the share of its speed lost each 1/60 s)
const KINDS := {
	&"banner": {"gravity": 2.5, "breeze": 5.0, "ripple": 14.0, "wave": 1.5, "drag": 0.1},
	&"streamer": {"gravity": 2.0, "breeze": 3.0, "ripple": 14.0, "wave": 1.2, "drag": 0.08},
	&"scarf": {"gravity": 7.0, "breeze": 2.0, "ripple": 10.0, "wave": 1.0, "drag": 0.12},
}
## Points along the chain (more bend more smoothly).
const SEGMENTS := 10
## How much of the pull on each link is handed back to the one before (0..1).
const HAND_BACK := 0.9
## The ripple at full strength from this speed (m/s).
const FULL_RIPPLE_SPEED := 12.0
## How fast the ripples travel down it.
const RIPPLE_RATE := 7.0
## The body it keeps out of: a capsule round this bone (the middle of the
## body), this far up and down it, this fat.
const BODY_BONE := "mixamorig_Spine"
const BODY_HALF_HEIGHT := 0.35
const BODY_RADIUS := 0.48
## Jumps further than this in one frame (a respawn) lay it out afresh.
const TELEPORT := 5.0
## It's also laid out afresh for its first few frames, until the character has
## its pose (on its very first frame it may still be in its rest pose).
const SETTLE_FRAMES := 3

## Where the chain starts (it follows this node).
var anchor: Node3D
## The character's skeleton: which way it faces, and where its body is.
var body: Skeleton3D
var kind := &"banner"
## How long it is (metres) and how far its edge reaches either side of its
## middle line (half its width).
var length := 2.0
var half_width := 0.2

var _points := PackedVector3Array()
var _previous := PackedVector3Array()
## Where the points were before the last physics step (drawn part way between).
var _last_step := PackedVector3Array()
var _sides: Array[Vector3] = []
var _time := 0.0
var _frames_to_settle := SETTLE_FRAMES
var _skeleton: Skeleton3D
var _mesh: MeshInstance3D


## Builds the trail from `model` (a PackedScene), whose `along` direction runs
## from the end that attaches to the free end, and whose `up` direction is
## kept up (both in the model's own axes).
func build(model: PackedScene, along: Vector3, up: Vector3) -> void:
	# The chain lives in the world, not on the character.
	top_level = true
	global_transform = Transform3D.IDENTITY
	_skeleton = Skeleton3D.new()
	add_child(_skeleton)
	var segment := length / SEGMENTS
	var skin := Skin.new()
	for i in SEGMENTS + 1:
		_skeleton.add_bone("Trail%d" % i)
		skin.add_bind(i, Transform3D(Basis(), Vector3(0, 0, -i * segment)))

	# The model's own axes into the trail's: along -> +z, up -> +y.
	along = along.normalized()
	up = up.normalized()
	var to_trail := Basis(up.cross(along), up, along).transposed()
	var source := model.instantiate() as Node3D
	var meshes := source.find_children("*", "MeshInstance3D", true, false)
	var low := Vector3.INF
	var high := -Vector3.INF
	for node: MeshInstance3D in meshes:
		var to_root := _to_root(node, source)
		for s in node.mesh.get_surface_count():
			for v: Vector3 in node.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				var p := to_trail * (to_root * v)
				low = low.min(p)
				high = high.max(p)
	var scale := length / (high.z - low.z)
	var start := Vector3((low.x + high.x) / 2.0, (low.y + high.y) / 2.0, low.z)
	half_width = (high.y - low.y) / 2.0 * scale

	var mesh := ArrayMesh.new()
	for node: MeshInstance3D in meshes:
		var to_root := _to_root(node, source)
		for s in node.mesh.get_surface_count():
			var arrays := node.mesh.surface_get_arrays(s)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var bones := PackedInt32Array()
			var weights := PackedFloat32Array()
			for i in vertices.size():
				var p := (to_trail * (to_root * vertices[i]) - start) * scale
				vertices[i] = p
				if i < normals.size():
					normals[i] = (to_trail * (to_root.basis * normals[i])).normalized()
				# Each point bends with the two chain points either side of it.
				var at := clampf(p.z / segment, 0.0, SEGMENTS - 0.001)
				var bone := int(at)
				for b in [bone, bone + 1, 0, 0]:
					bones.append(b)
				for w in [1.0 - (at - bone), at - bone, 0.0, 0.0]:
					weights.append(w)
			arrays[Mesh.ARRAY_VERTEX] = vertices
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_TANGENT] = null # Turned; Godot doesn't need them for these.
			arrays[Mesh.ARRAY_BONES] = bones
			arrays[Mesh.ARRAY_WEIGHTS] = weights
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var material := node.get_active_material(s)
			if material is BaseMaterial3D:
				material = material.duplicate()
				material.cull_mode = BaseMaterial3D.CULL_DISABLED # Thin cloth: both sides show.
			mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	source.free()
	_mesh = MeshInstance3D.new()
	_mesh.mesh = mesh
	_mesh.skin = skin
	_skeleton.add_child(_mesh)
	_mesh.skeleton = _mesh.get_path_to(_skeleton)
	_lay_out()


## It moves in step with physics (that's when you move), and is drawn part
## way between steps, the way the game draws your body (physics interpolation).
func _physics_process(delta: float) -> void:
	if anchor == null or body == null or not anchor.is_inside_tree():
		return
	_time += delta
	if _frames_to_settle > 0 or _root().distance_to(_points[0]) > TELEPORT:
		_frames_to_settle -= 1
		_lay_out()
	_last_step = _points.duplicate()
	_simulate(delta)


func _process(_delta: float) -> void:
	if _points.is_empty():
		return
	var between := Engine.get_physics_interpolation_fraction() if get_tree().physics_interpolation else 1.0
	var drawn := PackedVector3Array()
	for i in _points.size():
		drawn.append(_last_step[i].lerp(_points[i], between) if i < _last_step.size() else _points[i])
	_pose(drawn)


## Where the chain starts: the anchor, or for a banner, half its width below
## the top of the pole (its edge hangs down the pole).
func _root() -> Vector3:
	return anchor.global_position + (Vector3.DOWN * half_width if kind == &"banner" else Vector3.ZERO)


## The way out behind the character.
func _behind() -> Vector3:
	var back := -body.global_basis.z
	back.y = 0.0
	return back.normalized() if back.length() > 0.01 else Vector3.BACK


## Straight out the way it would settle (behind you and down).
func _lay_out() -> void:
	var settings: Dictionary = KINDS[kind]
	var settle: Vector3 = Vector3.DOWN * settings.gravity + _behind() * settings.breeze
	var out := settle.normalized() * (length / SEGMENTS)
	_points.resize(SEGMENTS + 1)
	_sides.resize(SEGMENTS + 1)
	for i in SEGMENTS + 1:
		_points[i] = _root() + out * i
		_sides[i] = Vector3.UP.cross(out).normalized()
	_previous = _points.duplicate()


func _simulate(delta: float) -> void:
	var settings: Dictionary = KINDS[kind]
	var root := _root()
	var speed := (root - _points[0]).length() / maxf(delta, 0.001)
	var ripple: float = settings.ripple * (0.25 + 0.75 * clampf(speed / FULL_RIPPLE_SPEED, 0.0, 1.0))
	var push: Vector3 = Vector3.DOWN * settings.gravity + _behind() * settings.breeze
	var keep := pow(1.0 - float(settings.drag), delta * 60.0)
	_previous[0] = _points[0]
	_points[0] = root
	for i in range(1, _points.size()):
		var along := float(i) / SEGMENTS
		var wave: float = sin(_time * RIPPLE_RATE - along * TAU * settings.wave)
		var moving := (_points[i] - _previous[i]) * keep
		_previous[i] = _points[i]
		_points[i] += moving + (push + _sides[i] * wave * ripple * along) * delta * delta
	# Keep each link its length: the root end leads and the rest follow. Pulling
	# a point along also hands some of that pull back to the one before it, so
	# the free end doesn't lag and curl (Müller's "dynamic follow the leader").
	var segment := length / SEGMENTS
	var pulled := PackedVector3Array()
	pulled.resize(_points.size())
	for i in range(1, _points.size()):
		var point := _keep_out_of_body(_points[i])
		var gap := point - _points[i - 1]
		var placed := _points[i - 1] + (gap.normalized() if gap.length() > 0.0001 else _behind()) * segment
		pulled[i] = placed - _points[i]
		_points[i] = placed
	for i in range(1, _points.size() - 1):
		_previous[i] += pulled[i + 1] * HAND_BACK


func _keep_out_of_body(point: Vector3) -> Vector3:
	var bone := body.find_bone(BODY_BONE)
	var middle := body.global_transform * body.get_bone_global_pose(bone).origin if bone != -1 else body.global_position
	var axis := body.global_basis.y.normalized()
	var on_axis := middle + axis * clampf((point - middle).dot(axis), -BODY_HALF_HEIGHT, BODY_HALF_HEIGHT)
	var out := point - on_axis
	if out.length() >= BODY_RADIUS:
		return point
	return on_axis + (out.normalized() if out.length() > 0.001 else _behind()) * BODY_RADIUS


## Lines each bone up with the chain (`points`, where it's drawn): pointing
## down it, kept as upright as it can be.
func _pose(points: PackedVector3Array) -> void:
	var box := AABB(points[0], Vector3.ZERO)
	for i in points.size():
		var ahead := points[mini(i + 1, SEGMENTS)] - points[maxi(i - 1, 0)]
		var forward := ahead.normalized() if ahead.length() > 0.001 else _behind()
		var up := Vector3.UP - forward * forward.dot(Vector3.UP)
		up = up.normalized() if up.length() > 0.05 else -_behind()
		var side := up.cross(forward)
		_sides[i] = side
		_skeleton.set_bone_pose_position(i, points[i])
		_skeleton.set_bone_pose_rotation(i, Basis(side, up, forward).get_rotation_quaternion())
		box = box.expand(points[i])
	# It's drawn in the world, far from where the model was made: tell Godot where.
	_mesh.custom_aabb = box.grow(half_width + 0.5)


## Where the free end is (for tests).
func tip() -> Vector3:
	return _points[SEGMENTS]


## The chain's points (for tests).
func points() -> PackedVector3Array:
	return _points


func _to_root(node: Node3D, root: Node3D) -> Transform3D:
	var transform := Transform3D()
	var at: Node = node
	while at != root:
		transform = (at as Node3D).transform * transform
		at = at.get_parent()
	return transform
