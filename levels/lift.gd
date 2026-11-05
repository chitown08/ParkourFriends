@tool
class_name Lift
extends Node3D
## A quick way up a building: step on, ride up, step off onto the roof. Two kinds:
##
## A **hoist** (old town): a rope over a pulley sticking out over the roof's
## edge, a platform on each end. Stand on the one down in the street and it
## winches you up, steadily. Or a friend on the roof jumps onto the other one
## (the counterweight, waiting level with the roof): it drops, and you shoot up
## and are flung over the edge onto the roof (they ride the drop to the street).
##
## A **gondola** (downtown's glass towers): a window-washer's cradle, wide enough
## for a few of you, up the tower to its roof, quickly.
##
## Empty, a lift goes back to the bottom (a hoist's counterweight back up).
## Every screen runs its own from where everyone is (nothing extra goes over
## the network), and the one who rides gets flung on their own screen.
##
## Its origin is on the ground against the wall, in the middle of where the
## rider's platform comes down; +Z points out of the wall. `height` is the
## roof's edge above it.

const PLATFORM_MATERIAL := preload("res://materials/grid_ramp.tres")
const FRAME_MATERIAL := preload("res://materials/iron.tres")
const ROPE_COLOR := Color(0.85, 0.8, 0.65)
## Platforms: how big (along the wall, out from it), how thick, and how far
## out from the wall their inner edge is.
const HOIST_PLATFORM := Vector2(1.6, 1.4)
const GONDOLA_PLATFORM := Vector2(3.2, 1.3)
const THICK := 0.2
const OFF_WALL := 0.15
## The counterweight hangs beside the rider's platform, this far along the wall.
const COUNTERWEIGHT_ALONG := 2.0
## How fast it goes (m/s): winching you up, a gondola, the counterweight's drop
## (pulling you up), and going back down empty.
const WINCH_SPEED := 6.0
const GONDOLA_SPEED := 12.0
const DROP_SPEED := 22.0
## The counterweight speeds up this fast (m/s²): a falling weight, so your
## friend rides it down rather than being left behind.
const DROP_ACCELERATION := 14.0
const RETURN_SPEED := 4.0
## Empty for this long (seconds) before it goes back down.
const WAIT := 1.0
## A rider shot up by the counterweight is flung this far over the roof's
## edge (metres up), drifting in toward the wall to come down on the roof.
const FLING_RISE := 5.0
const FLING_IN := 4.0
## Feet within this of a platform's top count as standing on it; for the
## counterweight, coming down onto it from up to this far above counts too.
const ON := 0.35
const LANDING_ON := 2.0
## The pulley beam: how far over the roof it stands.
const BEAM_ABOVE := 2.5

@export_enum("hoist", "gondola") var kind := "hoist":
	set(value):
		kind = value
		_build()
@export var height := 14.0:
	set(value):
		height = value
		_build()

## How far up the rider's platform is (0: at the bottom, 1: level with the roof).
var progress := 0.0
var _speed := 0.0
var _empty_for := 0.0
## Once the counterweight's dropping, it goes all the way.
var _dropping := false
var _parts: Node3D
var _rider_platform: AnimatableBody3D
var _counterweight: AnimatableBody3D
var _ropes: MeshInstance3D


func _ready() -> void:
	add_to_group(&"lifts")
	_build()


## Flat direction pointing out of the wall.
func out_of_wall() -> Vector3:
	var out := global_basis.z
	return Vector3(out.x, 0.0, out.z).normalized()


## The size of the rider's platform (along the wall, out from it).
func platform_size() -> Vector2:
	return GONDOLA_PLATFORM if kind == "gondola" else HOIST_PLATFORM


## The middle of the top of the rider's platform when it's at `at` (0..1), and the counterweight's.
func rider_top(at := progress) -> Vector3:
	return global_transform * Vector3(0.0, at * height, OFF_WALL + platform_size().y / 2.0)


func counterweight_top() -> Vector3:
	return global_transform * Vector3(COUNTERWEIGHT_ALONG, (1.0 - progress) * height, OFF_WALL + HOIST_PLATFORM.y / 2.0)


## How fast (m/s) a ride goes up, alone.
func ride_speed() -> float:
	return GONDOLA_SPEED if kind == "gondola" else WINCH_SPEED


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _rider_platform == null:
		return
	# (Moving fast, you're carried a frame behind it: allow for that.)
	var riders := _standing_on(rider_top(), platform_size(), ON, ON + absf(_speed) * delta * 2.0)
	var weights := _standing_on(counterweight_top(), HOIST_PLATFORM, LANDING_ON) if kind == "hoist" else []
	if not weights.is_empty() and progress < 1.0:
		_dropping = true # A friend on the counterweight: it drops, you shoot up.
	if _dropping:
		_speed = minf(maxf(_speed, 0.0) + DROP_ACCELERATION * delta, DROP_SPEED)
	elif not riders.is_empty() and progress < 1.0:
		_speed = ride_speed()
	elif riders.is_empty() and weights.is_empty():
		_empty_for += delta
		_speed = -RETURN_SPEED if _empty_for > WAIT else 0.0
	else:
		_speed = 0.0
	if not riders.is_empty() or not weights.is_empty():
		_empty_for = 0.0
	var was := progress
	progress = clampf(progress + _speed * delta / height, 0.0, 1.0)
	# Shot up by the counterweight to the top: flung over the edge onto the roof.
	if progress >= 1.0 and _dropping:
		_dropping = false
		if was < 1.0:
			for player: Player in riders:
				if player.is_local:
					player.ramp_launch(-out_of_wall(), FLING_IN, FLING_RISE, 0.0)
	_place_platforms()


## The players standing on a platform whose top's middle is at `top`, `size`
## big (or coming down onto it, up to `above` over it; or left a little
## behind it, up to `below` under it).
func _standing_on(top: Vector3, size: Vector2, above := ON, below := ON) -> Array:
	var found := []
	var along := global_basis.x.normalized()
	var out := out_of_wall()
	for player: Player in get_tree().get_nodes_in_group(&"players"):
		var off := player.global_position - top
		if absf(off.dot(along)) <= size.x / 2.0 + 0.2 and absf(off.dot(out)) <= size.y / 2.0 + 0.2 and off.y >= -below and off.y <= above:
			found.append(player)
	return found


func _place_platforms() -> void:
	_rider_platform.position = Vector3(0.0, progress * height - THICK / 2.0, OFF_WALL + platform_size().y / 2.0)
	if _counterweight:
		_counterweight.position = Vector3(COUNTERWEIGHT_ALONG, (1.0 - progress) * height - THICK / 2.0, OFF_WALL + HOIST_PLATFORM.y / 2.0)
	_draw_ropes()


func _build() -> void:
	if not is_inside_tree():
		return
	if _parts:
		_parts.free()
	_parts = Node3D.new()
	add_child(_parts)
	_rider_platform = _platform(platform_size())
	_counterweight = _platform(HOIST_PLATFORM) if kind == "hoist" else null
	# The beam over the roof's edge: the pulley (a hoist), or the gondola's davit.
	var beam := MeshInstance3D.new()
	var box := BoxMesh.new()
	var span := (COUNTERWEIGHT_ALONG + HOIST_PLATFORM.x) if kind == "hoist" else GONDOLA_PLATFORM.x
	box.size = Vector3(span, 0.25, 0.25)
	beam.mesh = box
	beam.material_override = FRAME_MATERIAL
	beam.position = Vector3((COUNTERWEIGHT_ALONG / 2.0) if kind == "hoist" else 0.0, height + BEAM_ABOVE, OFF_WALL + platform_size().y / 2.0)
	_parts.add_child(beam)
	for side: float in [-1.0, 1.0]: # Its posts, back over the roof.
		var post := MeshInstance3D.new()
		var post_box := BoxMesh.new()
		post_box.size = Vector3(0.15, BEAM_ABOVE, 0.15)
		post.mesh = post_box
		post.material_override = FRAME_MATERIAL
		post.position = beam.position + Vector3(side * span / 2.0, -BEAM_ABOVE / 2.0, -platform_size().y / 2.0 - OFF_WALL - 0.3)
		_parts.add_child(post)
	_ropes = MeshInstance3D.new()
	_ropes.mesh = ImmediateMesh.new()
	var rope := StandardMaterial3D.new()
	rope.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rope.albedo_color = ROPE_COLOR
	_ropes.material_override = rope
	_parts.add_child(_ropes)
	_place_platforms()


## A platform that carries whoever stands on it (an orange deck with a low rail).
func _platform(size: Vector2) -> AnimatableBody3D:
	var body := AnimatableBody3D.new()
	body.sync_to_physics = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, THICK, size.y)
	shape.shape = box
	body.add_child(shape)
	var deck := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box.size
	deck.mesh = mesh
	deck.material_override = PLATFORM_MATERIAL
	body.add_child(deck)
	# A rail round the outside (to look at: you can step off any side).
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for bar: Array in [[Vector3(0, 0.55, size.y / 2.0), Vector3(size.x, 0.05, 0.05)],
			[Vector3(-size.x / 2.0, 0.55, 0), Vector3(0.05, 0.05, size.y)], [Vector3(size.x / 2.0, 0.55, 0), Vector3(0.05, 0.05, size.y)],
			[Vector3(-size.x / 2.0, 0.3, size.y / 2.0), Vector3(0.05, 0.55, 0.05)], [Vector3(size.x / 2.0, 0.3, size.y / 2.0), Vector3(0.05, 0.55, 0.05)]]:
		var piece := BoxMesh.new()
		piece.size = bar[1]
		tool.append_from(piece, 0, Transform3D(Basis.IDENTITY, bar[0]))
	var rail := MeshInstance3D.new()
	rail.mesh = tool.commit()
	rail.material_override = FRAME_MATERIAL
	body.add_child(rail)
	_parts.add_child(body)
	return body


func _draw_ropes() -> void:
	if _ropes == null:
		return
	var mesh := _ropes.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var beam_y := height + BEAM_ABOVE
	var platforms := [_rider_platform] + ([_counterweight] if _counterweight else [])
	for platform: AnimatableBody3D in platforms:
		var at := platform.position
		var half: float = ((platform.get_child(0) as CollisionShape3D).shape as BoxShape3D).size.x / 2.0 - 0.1
		for side: float in [-1.0, 1.0]:
			mesh.surface_add_vertex(at + Vector3(side * half, 0.6, 0.0))
			mesh.surface_add_vertex(Vector3(at.x + side * half, beam_y, at.z))
	mesh.surface_end()
