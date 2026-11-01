extends SceneTree
## Generates levels/rooftop_district.tscn: a 5 x 5 block district of grey-box
## buildings, cut into four quarters by two 24 m avenues that cross at a plaza.
## The north-south avenue carries the subway line.
##
## Every random choice comes from SEED, and each block rolls its own dice (from
## the seed and the block's position), so the same seed always builds the same
## city and tweaking one rule only changes what it touches.
##
## Usage (from the project folder):
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/gen_district.gd
## Note: re-running this overwrites any changes made to that scene in the editor.

const OUTPUT := "res://levels/rooftop_district.tscn"
const SEED := 42

## The gap language, in metres (tuned for the superhuman profile).
const ALLEY := 5.0 ## A running jump.
const STREET := 10.0 ## A readied leap.
const AVENUE := 24.0 ## A grind rail, the glider, or down to the street and back up.

const BLOCK := 60.0 ## Each block is a square this wide, split into buildings by alleys.
const BLOCKS := 5 ## Blocks along each side.
const AVENUE_AFTER := 2 ## The avenues run between block 2 and block 3 (counting from 0).
const STOREY := 3.5 ## Metres per storey.
const MIN_STOREYS := 4
const MAX_STOREYS := 8
const TOWER_CHANCE := 0.1 ## Chance a building is a landmark tower...
const TOWER_STOREYS := Vector2i(12, 16) ## ...this many storeys tall.
## Buildings across an alley differ by at most this many storeys (towers aside),
## so you can always leap and grab your way up to the taller one.
const MAX_ALLEY_STEP := 2
const EDGE := 20.0 ## Street around the outside of the district.

## Fire escapes: a staircase of solid steps (one storey each) along a street-facing
## wall, up to one storey below the roof. One per block, on its lowest building
## (alley steps take you up the rest). Towers don't get one.
const STEP_RUN := 6.0 ## Length of each step along the wall...
const MIN_STEP_RUN := 4.5 ## ...squeezed down to this on a short wall.
const STEP_DEPTH := 3.0 ## How far each step sticks out into the street.

## Grind rails cross the avenues, from a taller roof down to a lower one: they
## start just past the taller roof's edge, a little below it (run off onto it),
## and end over the lower roof (you're flung off onto it).
const RAIL_START_OUT := 1.0
const RAIL_START_DROP := 0.4
const RAIL_END_IN := 3.0
const RAIL_END_RISE := 0.7
const RAIL_MARGIN := 4.0 ## Keeps rails this far from a roof's corners.

## Clutter: things to vault, climb and weave through. Colour says what it's
## for: red to vault, yellow to climb, grey is just in the way.
## On roofs: air-con boxes (red) and stairwell huts (grey)...
const VAULT_BOX := Vector3(2.5, 1.1, 1.5) ## Typical size (each one varies a bit).
const HUT := Vector3(3.5, 2.8, 3.5)
const ROOF_EDGE_CLEAR := 6.0 ## Nothing this close to a roof's edge: room to land a jump.
const ROOF_AREA_PER_ITEM := 250.0 ## About one thing per this many square metres of roof.
const MAX_ROOF_ITEMS := 6
const ITEM_SPACING := 3.0 ## Room to run between things.
## ...and along the pavements: benches and bins (red), phone booths (yellow).
const BENCH := Vector3(2.0, 0.6, 0.7) ## (Length along the kerb, height, depth.)
const BIN := Vector3(0.8, 1.1, 0.8)
const PHONE_BOOTH := Vector3(1.2, 2.6, 1.2)
const KERB_OUT := 1.5 ## How far out from the buildings the pavement things stand.
const STREET_SPACING := Vector2(8.0, 16.0) ## Gap between pavement things (random in this range).
const FIRE_ESCAPE_CLEAR := 10.0 ## Pavement stays clear this far around a fire escape (room to run at it).
## Rail run-ups and landings stay clear this wide, this far onto each roof.
const RAIL_CLEAR_WIDTH := 3.0
const RAIL_RUN_UP := 10.0
const RAIL_LANDING := 12.0
const MARKER_CLEAR := 4.0 ## And this far around the spawn and checkpoints.

## Sloped roofs, sprinkled through the city: slide down them for speed and hop
## off the bottom. Never on towers, and only flat roofs get fire escapes, rails,
## checkpoints, relics and clutter (each block's lowest building stays flat).
const PITCHED_CHANCE := 0.25
const SAWTOOTH_CHANCE := 0.15
## Pitched ("old town"): the building becomes a terrace of narrow houses along
## its longer side, each with its own roof, the ridge across the row. Running
## along it: up, over the ridge, slide down, hop to the next house. Some have a
## lane between them, some touch (a valley between their roofs).
const HOUSE_WIDTH := 8.0 ## About this wide (each varies a bit).
const LANE := 1.5
const LANE_CHANCE := 0.5
const PITCH_DEGREES := Vector2(28.0, 36.0)
## Sawtooth ("industrial"): teeth along the longer side, each a long gentle
## slope up to a steep glass face down. Against the grain you slide down each
## slope and skim over the next face; with it, you run up and drop off.
const TOOTH := 5.0 ## About this long...
const TOOTH_RISE := 1.2 ## ...and this tall (low enough for free-run to flow-vault each face).
const GLASS_DEGREES := 75.0

## The launch plaza: a launch roof in each avenue arm (a low building whose roof
## slopes down to a lip), its lip this far from the middle of the plaza, all
## launching toward the middle (see levels/ramp.gd).
const RAMP_DISTANCE := 13.0

## Relics, each in a spot that asks for something different (see _write_relics),
## and the drop-off in the middle of the plaza, where every relic comes back to.
## The sky relic floats this high over the plaza: higher than any launch reaches
## alone, but in reach if a friend launching with you tosses you on the way up.
## (It can be caught from further away than other relics: items/data/relic_sky.tres.)
const SKY_RELIC_HEIGHT := 18.0
## The others hover this far above where you stand: chest height, so running
## (or grinding) into one picks it up.
const RELIC_HOVER := 1.0
## How far in from the roof's edge the far-corner relic sits.
const CORNER_RELIC_IN := 6.0

## Where each block starts, along x (columns) and z (rows), before centring.
var _starts: Array[float] = []
## Places clutter mustn't go: rail paths as [from, to] (seen from above), the
## spawn and checkpoints, and fire escape footprints (Rect2s, for the pavement).
var _rail_paths: Array = []
var _marker_spots: Array[Vector2] = []
var _fire_escapes: Array[Rect2] = []
## Every rail as [start, end].
var _rails: Array = []
## The plaza (where the avenues cross) is the origin of the world.
var _plaza_middle := 0.0
var _out := PackedStringArray()


func _init() -> void:
	var at := 0.0
	for i in BLOCKS:
		_starts.append(at)
		at += BLOCK + (AVENUE if i == AVENUE_AFTER else STREET)
	_plaza_middle = _starts[AVENUE_AFTER] + BLOCK + AVENUE / 2.0

	var buildings: Array[Dictionary] = []
	for bx in BLOCKS:
		for bz in BLOCKS:
			buildings.append_array(_block(bx, bz))

	_write_header()
	_write_ground()
	for b in buildings:
		if b.roof == "pitched":
			_write_terrace(b)
			continue
		_box(b.name, "Buildings", b.x + b.w / 2.0, b.storeys * STOREY / 2.0, b.z + b.d / 2.0,
				b.w, b.storeys * STOREY, b.d, "4_building")
		if b.roof == "sawtooth":
			_write_sawtooth(b)
	var staircases := 0
	for bx in BLOCKS:
		for bz in BLOCKS:
			staircases += 1 if _write_staircase(buildings, Vector2i(bx, bz)) else 0
	var rails := 0
	for i in BLOCKS:
		rails += 1 if _write_rail(buildings, i, true) else 0
		rails += 1 if _write_rail(buildings, i, false) else 0
	_write_ramps()
	_write_markers(buildings)
	_write_relics(buildings)
	var roof_things := 0
	for b in buildings:
		roof_things += _write_roof_clutter(b)
	var street_things := 0
	for bx in BLOCKS:
		for bz in BLOCKS:
			street_things += _write_street_clutter(Vector2i(bx, bz))

	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	file.store_string("\n".join(_out) + "\n")
	file.close()
	print("Wrote %s: %d buildings, %d towers, %d fire escapes, %d rails, %d roof things, %d street things (seed %d)" % [
			OUTPUT, buildings.size(), buildings.filter(func(b: Dictionary) -> bool: return b.tower).size(),
			staircases, rails, roof_things, street_things, SEED])
	quit()


## Splits block (bx, bz) into buildings and picks their heights.
func _block(bx: int, bz: int) -> Array[Dictionary]:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([SEED, bx, bz])
	var whole := Rect2(_starts[bx] - _plaza_middle, _starts[bz] - _plaza_middle, BLOCK, BLOCK)
	var parts: Array[Rect2] = []
	var pattern := dice.randf()
	if pattern < 0.15:
		parts = [whole]
	elif pattern < 0.4:
		parts = _split(whole, dice.randf_range(0.35, 0.65), true)
	elif pattern < 0.65:
		parts = _split(whole, dice.randf_range(0.35, 0.65), false)
	elif pattern < 0.85:
		for half in _split(whole, dice.randf_range(0.4, 0.6), true):
			parts.append_array(_split(half, dice.randf_range(0.4, 0.6), false))
	else:
		var halves := _split(whole, dice.randf_range(0.4, 0.6), true)
		parts = [halves[0]]
		parts.append_array(_split(halves[1], dice.randf_range(0.4, 0.6), false))

	var buildings: Array[Dictionary] = []
	for i in parts.size():
		var tower := dice.randf() < TOWER_CHANCE
		var storeys := dice.randi_range(TOWER_STOREYS.x, TOWER_STOREYS.y) if tower \
				else dice.randi_range(MIN_STOREYS, MAX_STOREYS)
		var r := parts[i]
		buildings.append({"name": "Block%d%d_%d" % [bx, bz, i], "x": r.position.x, "z": r.position.y,
				"w": r.size.x, "d": r.size.y, "storeys": storeys, "tower": tower, "block": Vector2i(bx, bz), "roof": "flat"})
	_limit_alley_steps(buildings)
	var lowest := buildings[0]
	for b in buildings:
		if b.storeys < lowest.storeys:
			lowest = b
	for b in buildings:
		var roll := dice.randf()
		if b.tower or b == lowest:
			continue
		if roll < PITCHED_CHANCE:
			b.roof = "pitched"
		elif roll < PITCHED_CHANCE + SAWTOOTH_CHANCE:
			b.roof = "sawtooth"
	return buildings


## Cuts `r` in two with an alley, `at` (0..1) of the way across (along x if `along_x`).
func _split(r: Rect2, at: float, along_x: bool) -> Array[Rect2]:
	if along_x:
		var first := r.size.x * at - ALLEY / 2.0
		return [Rect2(r.position, Vector2(first, r.size.y)),
				Rect2(r.position + Vector2(first + ALLEY, 0), Vector2(r.size.x - first - ALLEY, r.size.y))]
	var first := r.size.y * at - ALLEY / 2.0
	return [Rect2(r.position, Vector2(r.size.x, first)),
			Rect2(r.position + Vector2(0, first + ALLEY), Vector2(r.size.x, r.size.y - first - ALLEY))]


## Lowers buildings until no alley has a step bigger than MAX_ALLEY_STEP (towers aside).
func _limit_alley_steps(buildings: Array[Dictionary]) -> void:
	var changed := true
	while changed:
		changed = false
		for a in buildings:
			for b in buildings:
				if a.tower or b.tower or not _across_alley(a, b):
					continue
				if a.storeys > b.storeys + MAX_ALLEY_STEP:
					a.storeys = b.storeys + MAX_ALLEY_STEP
					changed = true


## True if `a` and `b` face each other across an alley.
func _across_alley(a: Dictionary, b: Dictionary) -> bool:
	var gap_x := maxf(b.x - (a.x + a.w), a.x - (b.x + b.w))
	var gap_z := maxf(b.z - (a.z + a.d), a.z - (b.z + b.d))
	var overlap_x := minf(a.x + a.w, b.x + b.w) - maxf(a.x, b.x)
	var overlap_z := minf(a.z + a.d, b.z + b.d) - maxf(a.z, b.z)
	return (absf(gap_x - ALLEY) < 0.1 and overlap_z > 2.0) or (absf(gap_z - ALLEY) < 0.1 and overlap_x > 2.0)


## Adds a fire escape to the block's lowest building that has a long enough
## street-facing wall (trying the next lowest if not). Returns false if none fits.
func _write_staircase(buildings: Array[Dictionary], block: Vector2i) -> bool:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([SEED, block.x, block.y, "stairs"])
	var area := _block_rect(block)
	var candidates := buildings.filter(func(b: Dictionary) -> bool: return b.block == block and b.roof == "flat" and not b.tower)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.storeys < b.storeys)
	for b: Dictionary in candidates:
		var steps: int = b.storeys - 1
		# Each street-facing wall: [a corner, the way along the wall, the way out into the street].
		var walls := []
		if is_equal_approx(b.z, area.position.y):
			walls.append([Vector2(b.x, b.z), Vector2.RIGHT, Vector2.UP])
		if is_equal_approx(b.z + b.d, area.end.y):
			walls.append([Vector2(b.x, b.z + b.d), Vector2.RIGHT, Vector2.DOWN])
		if is_equal_approx(b.x, area.position.x):
			walls.append([Vector2(b.x, b.z), Vector2.DOWN, Vector2.LEFT])
		if is_equal_approx(b.x + b.w, area.end.x):
			walls.append([Vector2(b.x + b.w, b.z), Vector2.DOWN, Vector2.RIGHT])
		walls = walls.filter(func(w: Array) -> bool:
				return (b.w if w[1] == Vector2.RIGHT else b.d) >= steps * MIN_STEP_RUN)
		if walls.is_empty():
			continue
		var wall: Array = walls[dice.randi() % walls.size()]
		var length: float = b.w if wall[1] == Vector2.RIGHT else b.d
		var run := minf(STEP_RUN, length / steps)
		var along: Vector2 = wall[1]
		var start: Vector2 = wall[0]
		if dice.randf() < 0.5: # Climb from the other end.
			start += along * length
			along = -along
		var out: Vector2 = wall[2]
		var far_corner := start + along * steps * run + out * STEP_DEPTH
		_fire_escapes.append(Rect2(start, Vector2.ZERO).expand(far_corner))
		for k in range(1, steps + 1):
			var middle := start + along * (k - 0.5) * run + out * STEP_DEPTH / 2.0
			var size := along.abs() * run + out.abs() * STEP_DEPTH
			_box("%s_Step%d" % [b.name, k], "FireEscapes", middle.x, k * STOREY / 2.0, middle.y,
					size.x, k * STOREY, size.y, "7_climb")
		return true
	return false


## Adds a grind rail across one of the avenues, at row (or column) `i`, from the
## taller of the two facing roofs down to the other. `across_x` is the
## north-south avenue (the rail runs east or west). Returns false if the roofs
## there are the same height or nowhere fits.
func _write_rail(buildings: Array[Dictionary], i: int, across_x: bool) -> bool:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([SEED, i, "rail", across_x])
	var near := Vector2i(AVENUE_AFTER, i) if across_x else Vector2i(i, AVENUE_AFTER)
	var far := near + (Vector2i.RIGHT if across_x else Vector2i.DOWN)
	var side := -AVENUE / 2.0 # The near side of the avenue (it's centred on the plaza).
	var lane_start := _block_rect(near).position.y if across_x else _block_rect(near).position.x
	for attempt in 8:
		var lane := lane_start + dice.randf_range(RAIL_MARGIN, BLOCK - RAIL_MARGIN)
		var a := _facing(buildings, near, side, lane, across_x)
		var b := _facing(buildings, far, -side, lane, across_x)
		if a.is_empty() or b.is_empty() or a.storeys == b.storeys:
			continue
		var high := a if a.storeys > b.storeys else b
		var low := b if high == a else a
		var toward := 1.0 if high == a else -1.0 # Along the axis, from high to low.
		var high_edge := side if high == a else -side
		var low_edge := -high_edge
		var start_along := high_edge + toward * RAIL_START_OUT
		var end_along := low_edge + toward * RAIL_END_IN
		var start_y: float = high.storeys * STOREY - RAIL_START_DROP
		var end_y: float = low.storeys * STOREY + RAIL_END_RISE
		var start := Vector3(start_along, start_y, lane) if across_x else Vector3(lane, start_y, start_along)
		var end := Vector3(end_along, end_y, lane) if across_x else Vector3(lane, end_y, end_along)
		var name := "Rail%s%d" % ["EW" if across_x else "NS", i]
		var offset := end - start
		var way := Vector2(offset.x, offset.z).normalized()
		_rails.append([start, end])
		_rail_paths.append([Vector2(start.x, start.z) - way * (RAIL_START_OUT + RAIL_RUN_UP),
				Vector2(end.x, end.z) + way * RAIL_LANDING])
		_out.append("\n[node name=\"%s\" parent=\"GrindRails\" instance=ExtResource(\"8_rail\")]\ntransform = %s\nend_point = Vector3(%s, %s, %s)" % [
				name, _at(start.x, start.y, start.z), _num(offset.x), _num(offset.y), _num(offset.z)])
		return true
	return false


## The building in `block` whose wall is at `edge` (across the axis) and covers
## `lane` (along the wall) with RAIL_MARGIN to spare, or {} if there's an alley there.
func _facing(buildings: Array[Dictionary], block: Vector2i, edge: float, lane: float, across_x: bool) -> Dictionary:
	for b in buildings:
		if b.block != block or b.tower or b.roof != "flat":
			continue
		var low_side: float = b.x if across_x else b.z
		var high_side: float = (b.x + b.w) if across_x else (b.z + b.d)
		var from: float = b.z if across_x else b.x
		var to: float = (b.z + b.d) if across_x else (b.x + b.w)
		var at_edge := is_equal_approx(low_side, edge) or is_equal_approx(high_side, edge)
		if at_edge and lane > from + RAIL_MARGIN and lane < to - RAIL_MARGIN:
			return b
	return {}


## Scatters vault boxes and stairwell huts over a roof, clear of its edges,
## each other, rail run-ups and landings, and markers. Towers stay bare (no way
## up yet), and so do sloped roofs. Returns how many it placed.
func _write_roof_clutter(b: Dictionary) -> int:
	if b.tower or b.roof != "flat":
		return 0
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([SEED, b.name, "roof"])
	var inner := Rect2(b.x, b.z, b.w, b.d).grow(-ROOF_EDGE_CLEAR)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return 0
	var roof: float = b.storeys * STOREY
	var wanted := mini(int(inner.get_area() / ROOF_AREA_PER_ITEM) + dice.randi_range(0, 1), MAX_ROOF_ITEMS)
	var placed: Array[Rect2] = []
	for attempt in wanted * 6:
		if placed.size() >= wanted:
			break
		var hut := dice.randf() < 0.3
		var size := (HUT if hut else VAULT_BOX) * Vector3(dice.randf_range(0.8, 1.2), dice.randf_range(0.9, 1.1), dice.randf_range(0.8, 1.2))
		if dice.randf() < 0.5:
			size = Vector3(size.z, size.y, size.x) # Turned the other way.
		var middle := Vector2(dice.randf_range(inner.position.x, inner.end.x), dice.randf_range(inner.position.y, inner.end.y))
		var footprint := Rect2(middle - Vector2(size.x, size.z) / 2.0, Vector2(size.x, size.z))
		if not inner.encloses(footprint) or not _clear_of(footprint, placed):
			continue
		placed.append(footprint)
		_box("%s_%s%d" % [b.name, "Hut" if hut else "Vault", placed.size()], "RoofClutter",
				middle.x, roof + size.y / 2.0, middle.y, size.x, size.y, size.z, "4_building" if hut else "9_vault")
	return placed.size()


## Lines the pavements around a block with benches, bins and phone booths,
## clear of its fire escape. Returns how many it placed.
func _write_street_clutter(block: Vector2i) -> int:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([SEED, block.x, block.y, "street"])
	var area := _block_rect(block)
	# Each side: [a corner, the way along it, the way out into the street, its name].
	var sides := [[area.position, Vector2.RIGHT, Vector2.UP, "N"],
			[Vector2(area.position.x, area.end.y), Vector2.RIGHT, Vector2.DOWN, "S"],
			[area.position, Vector2.DOWN, Vector2.LEFT, "W"],
			[Vector2(area.end.x, area.position.y), Vector2.DOWN, Vector2.RIGHT, "E"]]
	var count := 0
	for side: Array in sides:
		var at := dice.randf_range(3.0, STREET_SPACING.y)
		var n := 0
		while at < BLOCK - 3.0:
			var roll := dice.randf()
			var kind := "Bench" if roll < 0.45 else ("Bin" if roll < 0.8 else "Booth")
			var shape: Vector3 = {"Bench": BENCH, "Bin": BIN, "Booth": PHONE_BOOTH}[kind]
			var along: Vector2 = side[1]
			var out: Vector2 = side[2]
			var middle: Vector2 = side[0] + along * at + out * (KERB_OUT + shape.z / 2.0)
			var size := along.abs() * shape.x + out.abs() * shape.z
			var footprint := Rect2(middle - size / 2.0, size)
			at += dice.randf_range(STREET_SPACING.x, STREET_SPACING.y)
			if _fire_escapes.any(func(r: Rect2) -> bool: return r.grow(FIRE_ESCAPE_CLEAR).intersects(footprint)):
				continue
			n += 1
			_box("Block%d%d_%s%s%d" % [block.x, block.y, side[3], kind, n], "StreetClutter",
					middle.x, shape.y / 2.0, middle.y, size.x, shape.y, size.y, "7_climb" if kind == "Booth" else "9_vault")
		count += n
	return count


## True if `footprint` keeps ITEM_SPACING from everything in `placed`, and is
## clear of rail paths and markers.
func _clear_of(footprint: Rect2, placed: Array[Rect2]) -> bool:
	var roomy := footprint.grow(ITEM_SPACING)
	if placed.any(func(r: Rect2) -> bool: return roomy.intersects(r)):
		return false
	for spot in _marker_spots:
		if footprint.grow(MARKER_CLEAR).has_point(spot):
			return false
	var middle := footprint.get_center()
	var reach := footprint.size.length() / 2.0 + RAIL_CLEAR_WIDTH
	for path: Array in _rail_paths:
		if Geometry2D.get_closest_point_to_segment(middle, path[0], path[1]).distance_to(middle) < reach:
			return false
	return true


## Four ramps round the plaza, one in each avenue arm, all launching toward
## the middle. (A ramp launches toward its -Z; `yaw` turns it to face the middle.)
func _write_ramps() -> void:
	var ramps := {"North": [Vector3(0, 0, -RAMP_DISTANCE), PI], "South": [Vector3(0, 0, RAMP_DISTANCE), 0.0],
			"East": [Vector3(RAMP_DISTANCE, 0, 0), PI / 2.0], "West": [Vector3(-RAMP_DISTANCE, 0, 0), -PI / 2.0]}
	for side: String in ramps:
		var at: Vector3 = ramps[side][0]
		var basis := Basis(Vector3.UP, ramps[side][1])
		_out.append("
[node name=\"Ramp%s\" type=\"Node3D\" parent=\"Ramps\"]
transform = Transform3D(%s, 0, %s, 0, 1, 0, %s, 0, %s, %s, 0, %s)
script = ExtResource(\"10_ramp\")
material = ExtResource(\"11_ramp\")" % [
				side, _num(basis.x.x), _num(basis.z.x), _num(basis.x.z), _num(basis.z.z), _num(at.x), _num(at.z)])


## A pitched-roof building: a terrace of houses along its longer side (see PITCHED_CHANCE).
func _write_terrace(b: Dictionary) -> void:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([SEED, b.name, "terrace"])
	var along_x: bool = b.w >= b.d
	var length: float = b.w if along_x else b.d
	var count := maxi(1, roundi(length / HOUSE_WIDTH))
	var lanes: Array[float] = []
	var sizes: Array[float] = []
	var lanes_total := 0.0
	var sizes_total := 0.0
	for i in count:
		sizes.append(dice.randf_range(0.8, 1.2))
		sizes_total += sizes[i]
		if i < count - 1:
			lanes.append(LANE if dice.randf() < LANE_CHANCE else 0.0)
			lanes_total += lanes[i]
	var height: float = b.storeys * STOREY
	var at := 0.0
	for i in count:
		var width := sizes[i] / sizes_total * (length - lanes_total)
		var rise := width / 2.0 * tan(deg_to_rad(dice.randf_range(PITCH_DEGREES.x, PITCH_DEGREES.y)))
		var house := "%s_House%d" % [b.name, i]
		if along_x:
			_box(house, "Buildings", b.x + at + width / 2.0, height / 2.0, b.z + b.d / 2.0, width, height, b.d, "4_building")
		else:
			# (Counted from the far end, as _roof() lays them that way along z.)
			_box(house, "Buildings", b.x + b.w / 2.0, height / 2.0, b.z + b.d - at - width / 2.0, b.w, height, width, "4_building")
		_roof(house + "_Roof", b, along_x, at, height,
				PackedVector2Array([Vector2(0, 0), Vector2(width / 2.0, rise), Vector2(width, 0)]))
		at += width + (lanes[i] if i < lanes.size() else 0.0)


## A sawtooth roof along the building's longer side (see SAWTOOTH_CHANCE).
func _write_sawtooth(b: Dictionary) -> void:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([SEED, b.name, "sawtooth"])
	var along_x: bool = b.w >= b.d
	var length: float = b.w if along_x else b.d
	var count := maxi(1, roundi(length / TOOTH))
	var tooth := length / count
	var glass := TOOTH_RISE / tan(deg_to_rad(GLASS_DEGREES))
	var profile := PackedVector2Array([Vector2(0, 0)])
	for i in count:
		profile.append(Vector2((i + 1) * tooth - glass, TOOTH_RISE))
		profile.append(Vector2((i + 1) * tooth, 0))
	if dice.randf() < 0.5: # The grain runs the other way.
		var flipped := PackedVector2Array()
		for i in range(profile.size() - 1, -1, -1):
			flipped.append(Vector2(length - profile[i].x, profile[i].y))
		profile = flipped
	_roof(b.name + "_Roof", b, along_x, 0.0, b.storeys * STOREY, profile)


## A sloped roof on building `b`: `profile` is its outline seen side-on (along
## the building, then up), from `start` metres along it, laid on top at
## `height` and stretched right across the building.
func _roof(name: String, b: Dictionary, along_x: bool, start: float, height: float, profile: PackedVector2Array) -> void:
	var points := PackedStringArray()
	for p in profile:
		points.append("%s, %s" % [_num(p.x), _num(p.y)])
	# A CSGPolygon3D's outline is in its x and y, pushed out along -z. Along x
	# it's as it is; along z, it's turned so x runs toward -z and it's pushed out toward -x.
	var transform := "Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)" % [_num(b.x + start), _num(height), _num(b.z + b.d)] if along_x \
			else "Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, %s, %s, %s)" % [_num(b.x + b.w), _num(height), _num(b.z + b.d - start)]
	_out.append("\n[node name=\"%s\" type=\"CSGPolygon3D\" parent=\"Roofs\"]\ntransform = %s\nuse_collision = true\npolygon = PackedVector2Array(%s)\ndepth = %s\nmaterial = ExtResource(\"4_building\")" % [
			name, transform, ", ".join(points), _num(b.d if along_x else b.w)])


func _block_rect(block: Vector2i) -> Rect2:
	return Rect2(_starts[block.x] - _plaza_middle, _starts[block.y] - _plaza_middle, BLOCK, BLOCK)


func _write_header() -> void:
	_out.append("""[gd_scene format=3]

[ext_resource type="Script" path="res://levels/level.gd" id="1_level"]
[ext_resource type="PackedScene" path="res://levels/checkpoint.tscn" id="2_checkpoint"]
[ext_resource type="Material" path="res://materials/grid_ground.tres" id="3_ground"]
[ext_resource type="Material" path="res://materials/grid_platform.tres" id="4_building"]
[ext_resource type="Material" path="res://materials/grid_track.tres" id="5_track"]
[ext_resource type="AudioStream" path="res://audio/music/test_level.mp3" id="6_music"]
[ext_resource type="Material" path="res://materials/grid_climb.tres" id="7_climb"]
[ext_resource type="PackedScene" path="res://levels/grind_rail.tscn" id="8_rail"]
[ext_resource type="Material" path="res://materials/grid_vault.tres" id="9_vault"]
[ext_resource type="Script" path="res://levels/ramp.gd" id="10_ramp"]
[ext_resource type="Material" path="res://materials/grid_ramp.tres" id="11_ramp"]
[ext_resource type="PackedScene" path="res://items/world_item.tscn" id="12_item"]
[ext_resource type="Resource" path="res://items/data/relic.tres" id="13_relic"]
[ext_resource type="PackedScene" path="res://levels/drop_off.tscn" id="14_dropoff"]
[ext_resource type="Resource" path="res://items/data/relic_sky.tres" id="15_relic_sky"]

[sub_resource type="ProceduralSkyMaterial" id="ProceduralSkyMaterial_sky"]
sky_top_color = Color(0.32, 0.5, 0.78, 1)
sky_horizon_color = Color(0.7, 0.76, 0.84, 1)
ground_bottom_color = Color(0.45, 0.55, 0.7, 1)
ground_horizon_color = Color(0.7, 0.76, 0.84, 1)

[sub_resource type="Sky" id="Sky_main"]
sky_material = SubResource("ProceduralSkyMaterial_sky")

[sub_resource type="Environment" id="Environment_main"]
background_mode = 2
sky = SubResource("Sky_main")
ambient_light_source = 3
tonemap_mode = 2
ssao_enabled = true
fog_enabled = true
fog_light_color = Color(0.7, 0.76, 0.84, 1)
fog_density = 0.0015

[node name="RooftopDistrict" type="Node3D"]
script = ExtResource("1_level")
kill_height = -20.0
music = ExtResource("6_music")

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Environment_main")

[node name="Sun" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.866, -0.383, 0.3214, 0, 0.6428, 0.766, -0.5, -0.6634, 0.5567, 0, 120, 0)
shadow_enabled = true
directional_shadow_max_distance = 250.0

[node name="Street" type="Node3D" parent="."]

[node name="Buildings" type="Node3D" parent="."]

[node name="Roofs" type="Node3D" parent="."]

[node name="FireEscapes" type="Node3D" parent="."]

[node name="GrindRails" type="Node3D" parent="."]

[node name="Ramps" type="Node3D" parent="."]

[node name="RoofClutter" type="Node3D" parent="."]

[node name="StreetClutter" type="Node3D" parent="."]

[node name="Checkpoints" type="Node3D" parent="."]

[node name="Labels" type="Node3D" parent="."]

[node name="Relics" type="Node3D" parent="."]""")


## The street (one slab under everything) and the subway line down the north-south avenue.
func _write_ground() -> void:
	var low := _starts[0] - _plaza_middle - EDGE
	var high := _starts[BLOCKS - 1] + BLOCK - _plaza_middle + EDGE
	_box("Ground", "Street", (low + high) / 2.0, -1.0, (low + high) / 2.0, high - low, 2.0, high - low, "3_ground")
	# Two tracks, flush with the street (no collision, so nothing to trip on).
	for side in [-3.0, 3.0]:
		_box("Track%s" % ("West" if side < 0 else "East"), "Street", side, 0.01, (low + high) / 2.0,
				1.6, 0.02, high - low - 2.0 * EDGE, "5_track", false)


## The spawn (on the roof at the plaza's south-west corner, looking north up
## the subway avenue), a checkpoint on the spawn roof, and one in each quarter.
func _write_markers(buildings: Array[Dictionary]) -> void:
	var corner := Vector2i(AVENUE_AFTER, AVENUE_AFTER + 1)
	var spawn_roof: Dictionary = _nearest(buildings.filter(func(b: Dictionary) -> bool:
			return b.block == corner and b.roof == "flat" and not b.tower), Vector2(0, 0))
	var spawn := _roof_spot(spawn_roof)
	_marker_spots.append(Vector2(spawn.x, spawn.z))
	_out.append("\n[node name=\"SpawnPoint\" type=\"Marker3D\" parent=\".\"]\ntransform = %s" % _at(spawn.x, spawn.y + 0.05, spawn.z))
	_checkpoint("CheckpointSpawn", spawn + Vector3(0, 0, 4))
	_label("LabelSpawn", spawn + Vector3(-3, 3, -2),
			"ROOFTOP DISTRICT (seed %d)\\nalleys 5 m, streets 10 m, avenues 24 m\\nR = back to your last checkpoint" % SEED)
	var quarters := {"NW": Vector2i(1, 1), "NE": Vector2i(3, 1), "SW": Vector2i(1, 3), "SE": Vector2i(3, 3)}
	for quarter: String in quarters:
		var in_block := buildings.filter(func(b: Dictionary) -> bool:
				return b.block == quarters[quarter] and b.roof == "flat" and not b.tower)
		in_block.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.storeys > b.storeys)
		_checkpoint("Checkpoint" + quarter, _roof_spot(in_block[0]))


## The drop-off in the middle of the plaza, and five relics:
## - Sky: floating over the plaza; launch off a ramp with a friend, who tosses you.
## - Rail: over the grind rail nearest the plaza; grab it as you ride across.
## - Far corner: on the roof in the district's far corner from the spawn; explore.
## - High roof: on the tallest roof nearest the plaza (not a tower, nor one with
##   a checkpoint or another relic); climb.
## - Subway: down on the tracks at the far end of the subway line; the street.
## Clutter keeps clear of the roof ones (they count as markers).
func _write_relics(buildings: Array[Dictionary]) -> void:
	_out.append("\n[node name=\"DropOff\" parent=\".\" instance=ExtResource(\"14_dropoff\")]\ntransform = %s" % _at(0, 0, 0))
	_relic("RelicSky", Vector3(0, SKY_RELIC_HEIGHT, 0), false, "15_relic_sky")

	var rail: Array = _rails[0]
	for r: Array in _rails:
		if _flat_middle(r).length() < _flat_middle(rail).length():
			rail = r
	_relic("RelicRail", (rail[0] + rail[1]) / 2.0 + Vector3.UP * RELIC_HOVER)

	# The spawn is at the plaza's south-west corner, so the far corner is north-east.
	var far_block := Vector2i(BLOCKS - 1, 0)
	var corner := Vector2(_block_rect(far_block).end.x, _block_rect(far_block).position.y)
	var far := _nearest(buildings.filter(func(b: Dictionary) -> bool:
			return b.block == far_block and b.roof == "flat" and not b.tower), corner)
	var spot := Vector2(far.x + far.w - CORNER_RELIC_IN, far.z + CORNER_RELIC_IN)
	_relic("RelicFarCorner", Vector3(spot.x, far.storeys * STOREY + RELIC_HOVER, spot.y), true)

	var climbable := buildings.filter(func(b: Dictionary) -> bool:
			return not b.tower and b.roof == "flat" and not _marker_spots.any(func(marker: Vector2) -> bool:
				return Rect2(b.x, b.z, b.w, b.d).has_point(marker)))
	climbable.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a.storeys > b.storeys or (a.storeys == b.storeys and _middle(a).length() < _middle(b).length()))
	_relic("RelicHighRoof", _roof_spot(climbable[0]) + Vector3.UP * RELIC_HOVER, true)

	_relic("RelicSubway", Vector3(0, RELIC_HOVER, _block_rect(Vector2i(0, 0)).position.y + 2.0))


func _relic(name: String, at: Vector3, on_roof := false, data := "13_relic") -> void:
	if on_roof:
		_marker_spots.append(Vector2(at.x, at.z))
	_out.append("\n[node name=\"%s\" parent=\"Relics\" instance=ExtResource(\"12_item\")]\ntransform = %s\nitem = ExtResource(\"%s\")" % [
			name, _at(at.x, at.y, at.z), data])


func _flat_middle(rail: Array) -> Vector2:
	var middle: Vector3 = (rail[0] + rail[1]) / 2.0
	return Vector2(middle.x, middle.z)


func _nearest(buildings: Array, to: Vector2) -> Dictionary:
	var best: Dictionary = buildings[0]
	for b: Dictionary in buildings:
		if _middle(b).distance_to(to) < _middle(best).distance_to(to):
			best = b
	return best


func _middle(b: Dictionary) -> Vector2:
	return Vector2(b.x + b.w / 2.0, b.z + b.d / 2.0)


func _roof_spot(b: Dictionary) -> Vector3:
	return Vector3(b.x + b.w / 2.0, b.storeys * STOREY, b.z + b.d / 2.0)


func _box(name: String, parent: String, cx: float, cy: float, cz: float,
		sx: float, sy: float, sz: float, material: String, collision := true) -> void:
	_out.append("\n[node name=\"%s\" type=\"CSGBox3D\" parent=\"%s\"]\ntransform = %s\n%ssize = Vector3(%s, %s, %s)\nmaterial = ExtResource(\"%s\")" % [
			name, parent, _at(cx, cy, cz), "use_collision = true\n" if collision else "", _num(sx), _num(sy), _num(sz), material])


func _checkpoint(name: String, at: Vector3) -> void:
	_marker_spots.append(Vector2(at.x, at.z))
	_out.append("\n[node name=\"%s\" parent=\"Checkpoints\" instance=ExtResource(\"2_checkpoint\")]\ntransform = %s" % [name, _at(at.x, at.y, at.z)])


func _label(name: String, at: Vector3, text: String) -> void:
	_out.append("\n[node name=\"%s\" type=\"Label3D\" parent=\"Labels\"]\ntransform = %s\nbillboard = 1\npixel_size = 0.02\ntext = \"%s\"\nfont_size = 64\noutline_size = 16" % [name, _at(at.x, at.y, at.z), text])


func _at(x: float, y: float, z: float) -> String:
	return "Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)" % [_num(x), _num(y), _num(z)]


## Rounds to the centimetre so the scene file stays tidy.
func _num(value: float) -> String:
	return str(snappedf(value, 0.01))
