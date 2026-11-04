class_name LightTrail
extends MeshInstance3D
## A ribbon of light along where a player has been, like a light-cycle's: how
## you spot friends from across the city when they're too far off to see.
## Each bit lasts LIFETIME, fading out over its last FADE. It's drawn the
## player's colour, the same width on screen however far away (see
## materials/light_trail.gdshader), and faintly through walls. Every screen
## draws everyone's from where it sees them, so nothing extra goes over the
## network. (Settings.light_trails turns them off.)

const LIFETIME := 20.0
const FADE := 5.0
## A point every this far you go...
const SPACING := 0.75
## ...this high off your feet (your middle).
const HEIGHT := 0.9
## A jump further than this in one step (a respawn) starts a new trail.
const TELEPORT := 5.0
## How strong it shows through walls.
const THROUGH_WALLS := 0.5
const SHADER := preload("res://materials/light_trail.gdshader")
const THROUGH_SHADER := preload("res://materials/light_trail_through.gdshader")

var player: Node3D
var color := Color.WHITE:
	set(value):
		color = value
		if _material:
			_material.set_shader_parameter(&"color", value)
			_through.set_shader_parameter(&"color", value)

var _points := PackedVector3Array()
var _born := PackedFloat32Array()
## True where a new trail starts (after a respawn).
var _starts: Array[bool] = []
var _clock := 0.0
var _last := Vector3.INF
## The last point laid (even if it's faded since).
var _laid := Vector3.INF
var _material: ShaderMaterial
var _through: ShaderMaterial
var _mesh := ImmediateMesh.new()


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_through = ShaderMaterial.new()
	_through.shader = THROUGH_SHADER
	_through.set_shader_parameter(&"strength", THROUGH_WALLS)
	_material.next_pass = _through
	material_override = _material
	color = color


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_clock += delta
	var at := player.global_position + Vector3.UP * HEIGHT
	if _last == Vector3.INF or at.distance_to(_last) > TELEPORT:
		_add(at, true)
	elif at.distance_to(_laid) >= SPACING:
		_add(at, _points.is_empty()) # (Once it's all faded, the next is a new trail.)
	_last = at
	var old := 0
	while old < _born.size() and _clock - _born[old] > LIFETIME:
		old += 1
	if old > 0:
		_points = _points.slice(old)
		_born = _born.slice(old)
		_starts = _starts.slice(old)
	visible = Settings.light_trails


func _add(at: Vector3, start: bool) -> void:
	_laid = at
	_points.append(at)
	_born.append(_clock)
	_starts.append(start)


func _process(_delta: float) -> void:
	_mesh.clear_surfaces()
	if not visible or _points.is_empty():
		return
	# Up to where the player is now (between points).
	var points := _points.duplicate()
	var born := _born.duplicate()
	var starts := _starts.duplicate()
	if player and _last != Vector3.INF and _last.distance_to(points[points.size() - 1]) > 0.05:
		points.append(_last)
		born.append(_clock)
		starts.append(false)
	if points.size() < 2 or not starts.slice(1).has(false):
		return
	var box := AABB(points[0], Vector3.ZERO)
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, points.size()):
		box = box.expand(points[i])
		if starts[i]:
			continue # (A gap: where you respawned.)
		var a := points[i - 1]
		var b := points[i]
		var along := (b - a).normalized()
		var fade_a := clampf((LIFETIME - (_clock - born[i - 1])) / FADE, 0.0, 1.0)
		var fade_b := clampf((LIFETIME - (_clock - born[i])) / FADE, 0.0, 1.0)
		for corner: Array in [[a, -1.0, fade_a], [a, 1.0, fade_a], [b, 1.0, fade_b], [a, -1.0, fade_a], [b, 1.0, fade_b], [b, -1.0, fade_b]]:
			_mesh.surface_set_normal(along)
			_mesh.surface_set_uv(Vector2(corner[1], 0.0))
			_mesh.surface_set_color(Color(1.0, 1.0, 1.0, corner[2]))
			_mesh.surface_add_vertex(corner[0])
	_mesh.surface_end()
	# (The shader widens it with distance: room for that.)
	custom_aabb = box.grow(10.0)


## The trail's points, oldest first (for tests).
func points() -> PackedVector3Array:
	return _points


## How many separate trails there are (a respawn starts another; for tests).
func pieces() -> int:
	return _starts.count(true)
