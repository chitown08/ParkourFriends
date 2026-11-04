class_name StressCity
extends Level
## A throwaway city for finding out how big and tall a one-load world can go
## (see tools/bench_city.gd): size across, built in code as it loads, with
## everything thrown in. The old town round the west, rising to the hub tower
## in the middle (HUB_HEIGHT, a light on top), and the futuristic quarter to
## the east: towers up to TALL, two even taller, round ones, stepped ones,
## hollow ones with sky lobbies, glass bridges high over the avenues, and
## whole-block halls. Not checked by the reachability checker (too big for it
## yet), and not finished: there's no way up most of it, you spawn on the hub.
##
## Two ways of building it, to compare (set `mode` before loading):
## - "csg": like the rooftop district, each building its own CSG shape.
## - "baked": the buildings in each CHUNK joined and baked into one mesh and one
##   collision shape (how a finished city would ship), with an occluder in each
##   solid building so what's behind it isn't drawn (if `occluders`).

static var mode := "baked"
static var occluders := true
## How far across (metres).
static var size := 3000.0

const SEED := 7
const BLOCK := 60.0
const STREET := 10.0
const AVENUE := 24.0
const AVENUE_EVERY := 4 ## Every this many blocks, an avenue instead of a street.
const STOREY := 3.5
const CHUNK := 300.0
const HUB_HEIGHT := 150.0
const HUB_RADIUS := 24.0
const FUTURE_FROM := 250.0 ## The futuristic quarter: east of this.
const TALL := 200.0 ## Its tallest (most are well under)...
const TALLEST := [260.0, 300.0] ## ...bar these two.
const GLASS := Color(0.7, 0.88, 1.0, 0.3)

const BUILDING := preload("res://materials/grid_platform.tres")
const CLIMB := preload("res://materials/grid_climb.tres")
const GROUND := preload("res://materials/grid_ground.tres")

## What got built (for the benchmark's report).
var stats := {"buildings": 0, "hollow": 0, "round": 0, "bridges": 0, "halls": 0, "tallest": 0.0, "build_ms": 0}

var _glass: StandardMaterial3D
var _dice := RandomNumberGenerator.new()
var _starts: Array[float] = [] ## Where each block starts (along x and along z: the same).
var _lots := {} ## Block (Vector2i) -> [[Rect2, height], ...]
var _chunks := {} ## Vector2i -> CSGCombiner3D (baked mode).
var _buildings: Node3D
var _tallest_left: Array = TALLEST.duplicate()


func _ready() -> void:
	var started := Time.get_ticks_msec()
	_dice.seed = SEED
	_glass = StandardMaterial3D.new()
	_glass.albedo_color = GLASS
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass.metallic = 0.3
	_glass.roughness = 0.05
	_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	_buildings = Node3D.new()
	_buildings.name = "Buildings"
	add_child(_buildings)
	_lay_out()
	_ground()
	for bx in _starts.size():
		for bz in _starts.size():
			_block(Vector2i(bx, bz))
	_bridges()
	get_viewport().use_occlusion_culling = mode == "baked" and occluders
	stats.build_ms = Time.get_ticks_msec() - started
	if mode == "baked":
		_bake.call_deferred(started) # (Once the CSG has worked out its shapes: it does that a moment later.)


## Lines of blocks: from the west (or north) edge, a street between each and an
## avenue every AVENUE_EVERY, centred so a block sits on the middle (the hub's).
func _lay_out() -> void:
	var at := 0.0
	var i := 0
	while at + BLOCK < size - 40.0:
		_starts.append(at)
		i += 1
		at += BLOCK + (AVENUE if i % AVENUE_EVERY == 0 else STREET)
	var middle: float = _starts[_starts.size() / 2] + BLOCK / 2.0
	for k in _starts.size():
		_starts[k] -= middle


## The avenues' middle lines (the same along x and z): for the benchmark's flights.
static func avenues() -> Array[float]:
	var city := StressCity.new()
	city._lay_out()
	var lines: Array[float] = []
	for k in range(AVENUE_EVERY - 1, city._starts.size() - 1, AVENUE_EVERY):
		lines.append(city._starts[k] + BLOCK + AVENUE / 2.0)
	city.free()
	return lines


func _ground() -> void:
	var ground := CSGBox3D.new()
	ground.name = "Ground"
	ground.size = Vector3(size + 200.0, 2.0, size + 200.0)
	ground.position = Vector3(0, -1.0, 0)
	ground.material = GROUND
	ground.use_collision = true
	add_child(ground)


## Splits a block into lots and builds on each.
func _block(block: Vector2i) -> void:
	var r := Rect2(_starts[block.x], _starts[block.y], BLOCK, BLOCK)
	var middle := r.get_center()
	if r.has_point(Vector2.ZERO):
		_hub(middle)
		return
	var future := middle.x > FUTURE_FROM
	var roll := _dice.randf()
	if roll < 0.04:
		_hall(r) # A whole-block hall.
		return
	var parts: Array[Rect2] = []
	if roll < 0.25 or (future and roll < 0.55):
		parts = [r]
	elif roll < 0.6:
		parts = _split(r, _dice.randf_range(0.35, 0.65), _dice.randf() < 0.5)
	else:
		for half in _split(r, _dice.randf_range(0.4, 0.6), true):
			parts.append_array(_split(half, _dice.randf_range(0.4, 0.6), false))
	_lots[block] = []
	for lot in parts:
		var height := _future_height(lot) if future else _old_height(lot)
		_lots[block].append([lot, height])
		if future:
			_future_building(lot, height)
		else:
			_old_building(lot, height)


func _split(r: Rect2, at: float, along_x: bool) -> Array[Rect2]:
	var gap := 5.0
	if along_x:
		var first := r.size.x * at - gap / 2.0
		return [Rect2(r.position, Vector2(first, r.size.y)),
				Rect2(r.position + Vector2(first + gap, 0), Vector2(r.size.x - first - gap, r.size.y))]
	var first := r.size.y * at - gap / 2.0
	return [Rect2(r.position, Vector2(r.size.x, first)),
			Rect2(r.position + Vector2(0, first + gap), Vector2(r.size.x, r.size.y - first - gap))]


## Old town: 4-12 storeys, a bit taller toward the middle; now and then a tower.
func _old_height(lot: Rect2) -> float:
	var near := 1.0 - clampf(lot.get_center().length() / (size / 2.0), 0.0, 1.0)
	if _dice.randf() < 0.06:
		return _dice.randi_range(16, 26) * STOREY
	return roundi(_dice.randf_range(4.0, 8.0 + 4.0 * near)) * STOREY


## The futuristic quarter: mostly 40-120 m, some up to TALL, and the TALLEST two.
func _future_height(lot: Rect2) -> float:
	if not _tallest_left.is_empty() and minf(lot.size.x, lot.size.y) >= 50.0 and _dice.randf() < 0.05:
		return _tallest_left.pop_back()
	return 40.0 + pow(_dice.randf(), 2.0) * (TALL - 40.0)


func _old_building(lot: Rect2, height: float) -> void:
	var roll := _dice.randf()
	var short := minf(lot.size.x, lot.size.y)
	if roll < 0.08 and short >= 20.0 and height <= 6 * STOREY:
		var b := _box(lot, height)
		_hollow(b, lot, height, Vector2(8, 6), [])
		_cut(b, lot, "Door", Vector3(lot.get_center().x, 2.75, lot.position.y), Vector3(8, 6, 3))
		_cut(b, lot, "Door", Vector3(lot.get_center().x, 2.75, lot.end.y), Vector3(8, 6, 3))
		_cut(b, lot, "Door", Vector3(lot.position.x, 2.75, lot.get_center().y), Vector3(3, 6, 8))
		_cut(b, lot, "Door", Vector3(lot.end.x, 2.75, lot.get_center().y), Vector3(3, 6, 8))
	elif roll < 0.16 and short >= 16.0:
		var b := _box(lot, height)
		_shape(b, CSGSphere3D.new(), Vector3(0, height / 2.0 - 0.75 * (short / 2.0 - 1.0), 0), short / 2.0 - 1.0)
	elif roll < 0.22 and short >= 14.0:
		_round(lot, height, short / 2.0 - 0.5)
	else:
		_box(lot, height)


func _future_building(lot: Rect2, height: float) -> void:
	var roll := _dice.randf()
	var short := minf(lot.size.x, lot.size.y)
	if roll < 0.25 and short >= 16.0:
		_round(lot, height, short / 2.0 - 1.0)
	elif roll < 0.42:
		# Stepped: setbacks every 40-60 m.
		var b := _box(lot, minf(height, 50.0))
		var at := minf(height, 50.0)
		var inset := 0.0
		while at < height - 10.0 and short - 2.0 * (inset + 6.0) > 10.0:
			inset += 6.0
			var step := minf(_dice.randf_range(40.0, 60.0), height - at)
			var tier := CSGBox3D.new()
			tier.size = Vector3(lot.size.x - 2.0 * inset, step, lot.size.y - 2.0 * inset)
			tier.position = Vector3(0, at + step / 2.0 - minf(height, 50.0) / 2.0, 0)
			tier.material = BUILDING
			b.add_child(tier)
			at += step
		_tallest(at)
	elif roll < 0.6 and short >= 24.0:
		# Hollow, with sky lobbies: a floor every 40 m you can run through.
		var b := _box(lot, height)
		_hollow(b, lot, height, Vector2(12, 8), range(40, int(height) - 20, 40))
	else:
		_box(lot, height)


## The hub tower: round, HUB_HEIGHT tall, a beacon on top.
func _hub(middle: Vector2) -> void:
	var hub := _round(Rect2(middle - Vector2.ONE * HUB_RADIUS, Vector2.ONE * 2.0 * HUB_RADIUS), HUB_HEIGHT, HUB_RADIUS)
	hub.name = "Hub"
	var beacon := CSGCylinder3D.new()
	beacon.radius = 2.0
	beacon.height = 12.0
	beacon.position = Vector3(0, HUB_HEIGHT / 2.0 + 6.0, 0)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.85, 0.3)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.8, 0.2)
	glow.emission_energy_multiplier = 4.0
	beacon.material = glow
	hub.add_child(beacon)
	var light := OmniLight3D.new()
	light.position = Vector3(middle.x, HUB_HEIGHT + 14.0, middle.y)
	light.omni_range = 60.0
	light.light_color = Color(1.0, 0.85, 0.4)
	light.light_energy = 3.0
	add_child(light)


## A hall filling a whole block: 30 m tall, a big door each side, yellow climbs and a mezzanine inside.
func _hall(r: Rect2) -> void:
	var height := 30.0
	var b := _box(r, height)
	_hollow(b, r, height, Vector2(12, 10), [])
	var c := r.get_center()
	for door: Vector3 in [Vector3(c.x, 4.75, r.position.y), Vector3(c.x, 4.75, r.end.y)]:
		_cut(b, r, "Door", door, Vector3(12, 10, 3))
	for door: Vector3 in [Vector3(r.position.x, 4.75, c.y), Vector3(r.end.x, 4.75, c.y)]:
		_cut(b, r, "Door", door, Vector3(3, 10, 12))
	var mezzanine := CSGBox3D.new()
	mezzanine.size = Vector3(r.size.x - 2.0, 1.0, 12.0)
	mezzanine.position = Vector3(0, 12.0 - height / 2.0, r.size.y / 2.0 - 7.0)
	mezzanine.material = BUILDING
	b.add_child(mezzanine)
	for i in 4:
		var step := CSGBox3D.new()
		step.size = Vector3(5, 3.0 * (i + 1), 5)
		step.position = Vector3(-18.0 + i * 7.0, 1.5 * (i + 1) - height / 2.0, r.size.y / 2.0 - 16.0)
		step.material = CLIMB
		b.add_child(step)
	stats.halls += 1


## Hollows `b` out (walls 0.5 m, roof 1 m), and if `lobbies` (heights), puts
## a floor with a well in the middle at each, with openings `opening` big
## through each wall there (and at the street).
func _hollow(b: CSGBox3D, lot: Rect2, height: float, opening: Vector2, lobbies: Array) -> void:
	var room := CSGBox3D.new()
	room.operation = CSGShape3D.OPERATION_SUBTRACTION
	room.size = Vector3(lot.size.x - 1.0, height - 1.0 + 0.5, lot.size.y - 1.0)
	room.position = Vector3(0, -0.75, 0)
	b.add_child(room)
	for lobby in lobbies:
		var y := float(lobby)
		var floor_slab := CSGBox3D.new()
		floor_slab.size = Vector3(lot.size.x - 1.0, 1.0, lot.size.y - 1.0)
		floor_slab.position = Vector3(0, y - 0.5 - height / 2.0, 0)
		floor_slab.material = BUILDING
		var well := CSGBox3D.new()
		well.operation = CSGShape3D.OPERATION_SUBTRACTION
		well.size = Vector3(lot.size.x * 0.4, 2.0, lot.size.y * 0.4)
		floor_slab.add_child(well)
		b.add_child(floor_slab)
		var c := lot.get_center()
		var mid := y + opening.y / 2.0
		_cut(b, lot, "Opening", Vector3(c.x, mid, lot.position.y), Vector3(opening.x, opening.y, 3))
		_cut(b, lot, "Opening", Vector3(c.x, mid, lot.end.y), Vector3(opening.x, opening.y, 3))
		_cut(b, lot, "Opening", Vector3(lot.position.x, mid, c.y), Vector3(3, opening.y, opening.x))
		_cut(b, lot, "Opening", Vector3(lot.end.x, mid, c.y), Vector3(3, opening.y, opening.x))
	if not lobbies.is_empty():
		var c := lot.get_center()
		_cut(b, lot, "Door", Vector3(c.x, 2.75, lot.position.y), Vector3(opening.x, 6, 3))
		_cut(b, lot, "Door", Vector3(c.x, 2.75, lot.end.y), Vector3(opening.x, 6, 3))
	stats.hollow += 1


## A hole through `b` (on `lot`) at `at` (world), `cut_size` big.
func _cut(b: CSGBox3D, lot: Rect2, cut_name: String, at: Vector3, cut_size: Vector3) -> void:
	var hole := CSGBox3D.new()
	hole.name = cut_name
	hole.operation = CSGShape3D.OPERATION_SUBTRACTION
	hole.size = cut_size
	hole.position = at - Vector3(lot.get_center().x, b.size.y / 2.0, lot.get_center().y)
	b.add_child(hole)


## Glass bridges over the avenues in the futuristic quarter: between towers
## facing each other across one, somewhere along their height.
func _bridges() -> void:
	for k in range(AVENUE_EVERY - 1, _starts.size() - 1, AVENUE_EVERY):
		for across in _starts.size():
			for along_x in [true, false]:
				var a: Vector2i = Vector2i(k, across) if along_x else Vector2i(across, k)
				var b: Vector2i = a + (Vector2i.RIGHT if along_x else Vector2i.DOWN)
				if not (_lots.has(a) and _lots.has(b)) or _starts[a.x] + BLOCK / 2.0 < FUTURE_FROM:
					continue
				if _dice.randf() > 0.6:
					continue
				var lane := _starts[across] + _dice.randf_range(10.0, BLOCK - 10.0)
				var from := _facing(a, lane, along_x, true)
				var to := _facing(b, lane, along_x, false)
				if from.is_empty() or to.is_empty():
					continue
				var top := minf(from[1], to[1])
				if top < 50.0:
					continue
				var y := _dice.randf_range(30.0, top - 10.0)
				var edge: float = _starts[k] + BLOCK
				_bridge(edge, edge + AVENUE, lane, y, along_x)


## The lot in `block` whose wall faces the avenue (its far side if `far`) at `lane`: [rect, height].
func _facing(block: Vector2i, lane: float, along_x: bool, far: bool) -> Array:
	for lot: Array in _lots[block]:
		var r: Rect2 = lot[0]
		var edge := (r.end.x if far else r.position.x) if along_x else (r.end.y if far else r.position.y)
		var block_edge := (_starts[block.x] + (BLOCK if far else 0.0)) if along_x else (_starts[block.y] + (BLOCK if far else 0.0))
		var covers := (lane > r.position.y + 3.0 and lane < r.end.y - 3.0) if along_x else (lane > r.position.x + 3.0 and lane < r.end.x - 3.0)
		if is_equal_approx(edge, block_edge) and covers:
			return lot
	return []


func _bridge(from: float, to: float, lane: float, y: float, along_x: bool) -> void:
	var length := to - from + 2.0
	var middle := (from + to) / 2.0
	var deck := CSGBox3D.new()
	deck.size = Vector3(length, 0.4, 4.0) if along_x else Vector3(4.0, 0.4, length)
	deck.position = Vector3(middle, y - 0.2, lane) if along_x else Vector3(lane, y - 0.2, middle)
	deck.material = _glass
	for side in [-1.0, 1.0]:
		var rail := CSGBox3D.new()
		rail.size = Vector3(length, 1.1, 0.1) if along_x else Vector3(0.1, 1.1, length)
		rail.position = Vector3(0, 0.75, side * 1.95) if along_x else Vector3(side * 1.95, 0.75, 0)
		rail.material = _glass
		deck.add_child(rail)
	_place(deck, deck.position)
	stats.bridges += 1


## A plain box building on `lot`, `height` tall.
func _box(lot: Rect2, height: float) -> CSGBox3D:
	var b := CSGBox3D.new()
	b.size = Vector3(lot.size.x, height, lot.size.y)
	b.material = BUILDING
	_place(b, Vector3(lot.get_center().x, height / 2.0, lot.get_center().y))
	_occlude(b, lot, height)
	_tallest(height)
	return b


func _round(lot: Rect2, height: float, radius: float) -> CSGCylinder3D:
	var b := CSGCylinder3D.new()
	b.radius = radius
	b.height = height
	b.sides = 48
	b.material = BUILDING
	_place(b, Vector3(lot.get_center().x, height / 2.0, lot.get_center().y))
	_occlude(b, Rect2(lot.get_center() - Vector2.ONE * radius * 0.7, Vector2.ONE * radius * 1.4), height)
	_tallest(height)
	stats.round += 1
	return b


func _shape(parent: CSGShape3D, shape: CSGShape3D, at: Vector3, radius: float) -> void:
	(shape as CSGSphere3D).radius = radius
	(shape as CSGSphere3D).radial_segments = 48
	(shape as CSGSphere3D).rings = 24
	shape.material = BUILDING
	shape.position = at
	parent.add_child(shape)


## Puts a building (or bridge) at `at`: its own CSG shape with collision, or
## into its chunk to be baked.
func _place(shape: CSGShape3D, at: Vector3) -> void:
	stats.buildings += 1
	if mode == "csg":
		shape.use_collision = true
		_buildings.add_child(shape)
		shape.position = at
		return
	var chunk := Vector2i(floori(at.x / CHUNK), floori(at.z / CHUNK))
	if not _chunks.has(chunk):
		var combiner := CSGCombiner3D.new()
		_chunks[chunk] = combiner
		_buildings.add_child(combiner)
	(_chunks[chunk] as CSGCombiner3D).add_child(shape)
	shape.position = at


## An occluder inside a solid building (hiding what's behind it).
func _occlude(b: CSGShape3D, lot: Rect2, height: float) -> void:
	if mode != "baked" or not occluders or height < 15.0:
		return
	var occluder := OccluderInstance3D.new()
	var box := BoxOccluder3D.new()
	box.size = Vector3(lot.size.x - 2.0, height - 2.0, lot.size.y - 2.0)
	occluder.occluder = box
	occluder.position = Vector3(lot.get_center().x, height / 2.0, lot.get_center().y)
	occluder.set_meta(&"building", b)
	add_child(occluder)


func _tallest(height: float) -> void:
	stats.tallest = maxf(stats.tallest, height)


## Joins each chunk's buildings into one mesh and one collision shape. (Hollow
## buildings lose their occluders: you'd see through their openings.)
func _bake(started: int) -> void:
	for occluder: OccluderInstance3D in find_children("*", "OccluderInstance3D", false, false):
		var b: CSGShape3D = occluder.get_meta(&"building")
		if b.get_children().any(func(child: Node) -> bool: return child is CSGShape3D and (child as CSGShape3D).operation == CSGShape3D.OPERATION_SUBTRACTION):
			occluder.queue_free()
	for chunk: Vector2i in _chunks:
		var combiner: CSGCombiner3D = _chunks[chunk]
		var mesh := combiner.bake_static_mesh()
		var shape := combiner.bake_collision_shape()
		var view := MeshInstance3D.new()
		view.name = "Chunk%d_%d" % [chunk.x, chunk.y]
		view.mesh = mesh
		_buildings.add_child(view)
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		view.add_child(body)
		combiner.queue_free()
	stats.build_ms = Time.get_ticks_msec() - started
