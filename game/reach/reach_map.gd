class_name ReachMap
extends RefCounted
## Works out where players can get to in a level, and what it takes: alone,
## with full flow, with friends (a toss, a hanging chain...), with an item.
## Used by tests to check a level matches what we meant (nothing impossible,
## not everything solo) and by tools/reach_view.gd to draw it.
##
## How it works:
## - Spots: every walkable surface in the level is a place (a box's top, seen
##   from above, at its height), and every relic is a target.
## - Links: each way of getting around is a rule (a script in rules/, see
##   ReachRule) that adds links between spots, saying what the link needs:
##   friends who stay behind (a toss), friends already there (a hanging chain),
##   friends going together (a pack drafting), and abilities or items (full
##   flow, the glider).
## - solve() spreads a group of players out from the start along the links and
##   works out the most of them that can get to each spot.
##
## A new move or item: add a rule script to rules/. Numbers come from the
## movement profile, so changing how high you jump changes the answers.

const RULES_DIR := "res://game/reach/rules/"
## Surfaces smaller than this (square metres, from above) aren't places of
## their own (benches, bins, sills); rules can still use them.
const MIN_PLACE_AREA := 4.0
## Every jump needs this much more room than the gap (taking off a little
## early, your body's width, landing clear of the edge).
const JUMP_MARGIN := 1.0
## A scramble starts this far below the top of the jump into it (see scramble_height()).
const SCRAMBLE_LOSS := 0.4
## Moves at full flow (a flow jump, cracking the whip...) need a run-up: a place
## at least this long one way (a pillar top won't do).
const FLOW_RUN_UP := 10.0


## A place (a walkable surface) or a target (a relic) players can get to.
class Spot:
	var name: String
	## From above (x, z). Targets: a point, as a tiny rectangle.
	var area: Rect2
	## Its height: a place's surface, or a target's middle.
	var y: float
	var is_target := false
	## Targets: how close (from a player's middle) counts as touching it.
	var reach := 0.0
	var node: Node

	func middle() -> Vector3:
		var c := area.get_center()
		return Vector3(c.x, y, c.y)


## One way from one spot to another.
class Link:
	var from: Spot
	var to: Spot
	## What it is, for reports ("jump", "scramble", "toss"...).
	var how: String
	## Abilities or items it needs (&"flow", &"glider"...).
	var needs: Array[StringName] = []
	## Friends who must stay at `from` to help (a toss: the tosser).
	var helpers_here := 0
	## Friends who must already be at `to` (a hanging chain: those hanging).
	var helpers_there := 0
	## Players who must all be at `from` and go together (a pack's drafting
	## jump); they all arrive.
	var together := 0


var level: Node
var moves: MovementProfile
var places: Array[Spot] = []
var targets: Array[Spot] = []
var links: Array[Link] = []
## Rising and falling gravity of a jump (from the profile).
var rise_gravity: float
var fall_gravity: float


## Builds the map of `level` for players moving with `profile`.
static func build(level_: Node, profile: MovementProfile) -> ReachMap:
	var map := ReachMap.new()
	map.level = level_
	map.moves = profile
	map.rise_gravity = 2.0 * profile.jump_height / (profile.jump_time_to_peak * profile.jump_time_to_peak)
	map.fall_gravity = 2.0 * profile.jump_height / (profile.jump_time_to_fall * profile.jump_time_to_fall)
	map._find_places(level_)
	map._find_solids(level_)
	map._find_targets(level_)
	for file in DirAccess.get_files_at(RULES_DIR):
		if file.ends_with(".gd"):
			var rule: ReachRule = load(RULES_DIR + file).new()
			rule.add_links(map)
	return map


func add_link(from: Spot, to: Spot, how: String, needs: Array[StringName] = [], helpers_here := 0, helpers_there := 0, together := 0) -> void:
	if from == null or to == null or from == to:
		return
	if &"flow" in needs and maxf(from.area.size.x, from.area.size.y) < FLOW_RUN_UP:
		return # No room to get up to speed.
	if not path_clear(from, to):
		return # A wall or ceiling in the way.
	var link := Link.new()
	link.from = from
	link.to = to
	link.how = how
	link.needs = needs
	link.helpers_here = helpers_here
	link.helpers_there = helpers_there
	link.together = together
	links.append(link)


## The most of `players` players (starting together at `start`) who can get to
## each spot, using only `abilities`. Spots nobody can get to are left out.
func solve(start: Spot, players: int, abilities: Array[StringName] = [&"flow"]) -> Dictionary:
	var most := {start: players}
	var changed := true
	while changed:
		changed = false
		for link in links:
			if not most.has(link.from) or not link.needs.all(func(need: StringName) -> bool: return need in abilities):
				continue
			if most[link.from] < link.together:
				continue # Not enough of you there to run as a pack.
			var there: int = most.get(link.to, 0)
			var arrive: int = most[link.from] - link.helpers_here
			if link.helpers_there > 0 and there < link.helpers_there:
				continue # Not enough of you up there yet to help.
			if arrive > there:
				most[link.to] = arrive
				changed = true
	return most


## The fewest players (starting together at `start`) for at least one to get
## to `spot`, or 0 if even `max_players` can't.
func players_needed(spot: Spot, start: Spot, abilities: Array[StringName] = [&"flow"], max_players := 8) -> int:
	for players in range(1, max_players + 1):
		if solve(start, players, abilities).has(spot):
			return players
	return 0


func place_named(spot_name: String) -> Spot:
	for spot in places:
		if spot.name == spot_name:
			return spot
	return null


func target_named(spot_name: String) -> Spot:
	for spot in targets:
		if spot.name == spot_name:
			return spot
	return null


## The highest place under `at` (x, z) whose surface isn't above it.
func place_under(at: Vector3) -> Spot:
	var best: Spot = null
	for spot in places:
		if spot.area.grow(0.3).has_point(Vector2(at.x, at.z)) and spot.y <= at.y + 0.5 and (best == null or spot.y > best.y):
			best = spot
	return best


## How far apart two spots are, seen from above (0 if they touch or overlap).
static func gap(a: Spot, b: Spot) -> float:
	var dx := maxf(0.0, maxf(a.area.position.x - b.area.end.x, b.area.position.x - a.area.end.x))
	var dz := maxf(0.0, maxf(a.area.position.y - b.area.end.y, b.area.position.y - a.area.end.y))
	return Vector2(dx, dz).length()


## How far you travel across the ground, going `speed`, from leaving the
## ground on a jump `height` high until you've come back down to `rise`
## (above where you left; negative is below). -1 if you never get that high.
func air_distance(height: float, speed: float, rise: float) -> float:
	if rise > height:
		return -1.0
	return speed * (sqrt(2.0 * height / rise_gravity) + sqrt(2.0 * (height - rise) / fall_gravity))


## How high a wall scramble gets your feet: a jump `takeoff_height` high, then
## scrambling up from near the top of it (you meet the wall a little before the
## top: SCRAMBLE_LOSS, measured in the game).
func scramble_height(takeoff_height: float) -> float:
	return takeoff_height + moves.wall_scramble_speed * moves.wall_scramble_time - SCRAMBLE_LOSS


# --- Places: the tops of things ----------------------------------------------
# Anything solid is made of shapes: a box, a cylinder (a round building, a
# turret), a sphere (a dome), or a prism (an outline pushed out: a curved wall
# seen from above, a wedge seen side-on), turned or tilted any way. A building
# can be several of them joined (a wing, a tier set back on top, a dome on the
# roof: shapes added into it), with holes cut out (see _find_solids()). Each
# shape's top is a place:
# - a box's, square on: its top, less any hole cut down through it and
#   anything else of the building standing on it (split into rectangles where
#   it has to be);
# - an upright cylinder's: two rectangles crossed, about filling its circle;
# - a dome's: just its crown, DOME_CROWN below the very top (lower down it's
#   too steep to stand, or you'd slide down to the roof it's on anyway);
# - anything else's (turned, leaning, stretched, a prism): wherever it's flat
#   enough to stand, in rectangles (see _sloped_tops()).
# Named after the shape, or "<building>/<shape>" for one added into a building;
# a top split in pieces gives "#2", "#3"... to the smaller ones.

## A dome's crown (the place on top of it) is this far down from its very top.
const DOME_CROWN := 0.5


func _find_places(root: Node) -> void:
	for node in root.find_children("*", "CSGShape3D", true, false):
		var shape := node as CSGShape3D
		if shape is CSGBox3D and shape.operation == CSGShape3D.OPERATION_SUBTRACTION and shape.name.begins_with("Room"):
			_add_room_floor(shape)
			continue
		if not _is_part(shape):
			continue
		# [height, rectangle] of each bit of its top that's left uncovered.
		var pieces: Array = []
		for top: Array in _tops(shape):
			for area in _uncovered(top[1], top[0], shape):
				if area.get_area() >= MIN_PLACE_AREA:
					pieces.append([top[0], area])
		pieces.sort_custom(func(a: Array, b: Array) -> bool: return (a[1] as Rect2).get_area() > (b[1] as Rect2).get_area())
		var root_shape := _csg_root(shape)
		var base_name := str(shape.name) if shape == root_shape else "%s/%s" % [root_shape.name, shape.name]
		for i in pieces.size():
			var spot := Spot.new()
			spot.name = base_name if i == 0 else "%s#%d" % [base_name, i + 1]
			spot.area = pieces[i][1]
			spot.y = pieces[i][0]
			spot.node = shape
			places.append(spot)


## Whether `shape` is part of something you can stand on: a CSG shape with
## collision on its own, or one added into one (not a hole, nor in a hole).
static func _is_part(shape: CSGShape3D) -> bool:
	if shape.operation != CSGShape3D.OPERATION_UNION or not shape.is_visible_in_tree():
		return false
	var parent := shape.get_parent() as CSGShape3D
	return shape.use_collision if parent == null else _is_part(parent)


## The outermost CSG shape `shape` is part of (itself, on its own).
static func _csg_root(shape: CSGShape3D) -> CSGShape3D:
	while shape.get_parent() is CSGShape3D:
		shape = shape.get_parent()
	return shape


## The tops of `shape` you can stand on: [height, a rectangle (from above)]
## for each, or none (a lying-down cylinder, a steep roof...).
static func _tops(shape: CSGShape3D) -> Array:
	var scale := shape.global_basis.get_scale()
	var at := shape.global_position
	if shape is CSGBox3D and _square_on(shape):
		var box := _bounds(shape)
		return [[box.end.y, Rect2(box.position.x, box.position.z, box.size.x, box.size.z)]]
	if shape is CSGCylinder3D and not (shape as CSGCylinder3D).cone and _upright(shape) and is_equal_approx(scale.x, scale.z):
		var cylinder := shape as CSGCylinder3D
		var r := cylinder.radius * scale.x
		var long := r * cos(PI / 8.0)
		var short := r * sin(PI / 8.0)
		var y := at.y + cylinder.height * scale.y / 2.0
		return [[y, Rect2(at.x - long, at.z - short, 2.0 * long, 2.0 * short)],
				[y, Rect2(at.x - short, at.z - long, 2.0 * short, 2.0 * long)]]
	if shape is CSGSphere3D and is_equal_approx(scale.x, scale.y) and is_equal_approx(scale.x, scale.z):
		var r := (shape as CSGSphere3D).radius * scale.x
		if r <= DOME_CROWN:
			return []
		var half := sqrt(r * r - (r - DOME_CROWN) * (r - DOME_CROWN)) / sqrt(2.0) # (A square in the crown's circle.)
		return [[at.y + r - DOME_CROWN, Rect2(at.x - half, at.z - half, 2.0 * half, 2.0 * half)]]
	var volume := Volume.of(shape)
	return [] if volume == null else _sloped_tops(volume)


## Whether `shape` is square on to the world (not turned or tilted at all).
static func _square_on(shape: Node3D) -> bool:
	var b := shape.global_basis
	return absf(b.x.y) + absf(b.x.z) + absf(b.y.x) + absf(b.y.z) + absf(b.z.x) + absf(b.z.y) < 1e-4 \
			and b.x.x > 0.0 and b.y.y > 0.0 and b.z.z > 0.0


# Any other shape (turned in its lot, leaning, a stretched dome, a prism: a
# curved wall, a wedge), seen from above in squares TOP_CELL across: where its
# top is all no steeper than STAND_SLOPE (any steeper and you slide off it)
# and no more than TOP_BAND higher at one side of the square than the other,
# you can stand. Those squares are joined into rectangles of about the same
# height (each rectangle a place, at its highest: a tilted roof is several
# strips, a step up from one to the next), leaving out any narrower than
# TOP_WIDTH (a ridge, the top of a pipe).
const TOP_CELL := 0.5
const STAND_SLOPE := 10.0
const TOP_BAND := 0.5
const TOP_WIDTH := 1.5
const NO_BAND := -1000000


static func _sloped_tops(volume: Volume) -> Array:
	var b := volume.bounds
	var across := Vector2i(floori(b.size.x / TOP_CELL), floori(b.size.z / TOP_CELL))
	var flat_enough := cos(deg_to_rad(STAND_SLOPE))
	var corners := {}
	var at := func(x: float, z: float) -> Array:
		var hit := volume.top_at(x, z)
		return [] if hit.is_empty() or (hit[1] as Vector3).y < flat_enough else hit
	# Each square's height (its highest), or NAN where you can't stand.
	var heights := PackedFloat32Array()
	heights.resize(across.x * across.y)
	for j in across.y:
		for i in across.x:
			var samples: Array = []
			for corner in [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i, j + 1), Vector2i(i + 1, j + 1)]:
				if not corners.has(corner):
					corners[corner] = at.call(b.position.x + corner.x * TOP_CELL, b.position.z + corner.y * TOP_CELL)
				samples.append(corners[corner])
			samples.append(at.call(b.position.x + (i + 0.5) * TOP_CELL, b.position.z + (j + 0.5) * TOP_CELL))
			var high := -INF
			var low := INF
			for sample: Array in samples:
				if sample.is_empty():
					high = NAN
					break
				high = maxf(high, sample[0])
				low = minf(low, sample[0])
			heights[j * across.x + i] = high if not is_nan(high) and high - low <= TOP_BAND else NAN
	# Joined into rectangles: the biggest there is of squares at about the same
	# height, then the biggest of what's left, and so on.
	var bands := PackedInt32Array()
	bands.resize(heights.size())
	for k in heights.size():
		bands[k] = NO_BAND if is_nan(heights[k]) else floori(heights[k] / TOP_BAND)
	var least := ceili(TOP_WIDTH / TOP_CELL)
	var tops: Array = []
	while true:
		var best := _biggest_rectangle(bands, across, least)
		if best.get_area() * TOP_CELL * TOP_CELL < MIN_PLACE_AREA:
			break
		var y := -INF
		for j in range(best.position.y, best.end.y):
			for i in range(best.position.x, best.end.x):
				bands[j * across.x + i] = NO_BAND
				y = maxf(y, heights[j * across.x + i])
		tops.append([y, Rect2(b.position.x + best.position.x * TOP_CELL, b.position.z + best.position.y * TOP_CELL,
				best.size.x * TOP_CELL, best.size.y * TOP_CELL)])
	return tops


## The biggest rectangle (in squares, at least `least` each way) of squares
## all in the same band in `bands` (`across` wide; NO_BAND: none). For each
## row, how many squares the same go up from each square (a skyline), and the
## biggest rectangle under that skyline.
static func _biggest_rectangle(bands: PackedInt32Array, across: Vector2i, least: int) -> Rect2i:
	var best := Rect2i()
	var up := PackedInt32Array()
	up.resize(across.x)
	for j in across.y:
		for i in across.x:
			var mine := bands[j * across.x + i]
			up[i] = 0 if mine == NO_BAND else (up[i] + 1 if j > 0 and bands[(j - 1) * across.x + i] == mine else 1)
		# Runs of the same band along the row, each a skyline of its own.
		var i := 0
		while i < across.x:
			var mine := bands[j * across.x + i]
			var end := i + 1
			while end < across.x and bands[j * across.x + end] == mine:
				end += 1
			if mine != NO_BAND:
				var stack: Array[int] = []
				for k in range(i, end + 1):
					var tall := up[k] if k < end else 0
					while not stack.is_empty() and up[stack.back()] >= tall:
						var high := up[stack.pop_back()]
						var left: int = stack.back() + 1 if not stack.is_empty() else i
						var wide := k - left
						if high >= least and wide >= least and high * wide > best.get_area():
							best = Rect2i(left, j - high + 1, wide, high)
					stack.append(k)
			i = end
	return best


static func _upright(shape: Node3D) -> bool:
	return shape.global_basis.y.normalized().dot(Vector3.UP) > 0.99


## The bits of `area` (a top at height `y`, of `shape`) not covered: by a hole
## in its building cut down through it, or by another of the building's
## shapes standing on it or rising past it (a tier, a turret, a taller wing;
## not a dome: you run up that).
func _uncovered(area: Rect2, y: float, shape: CSGShape3D) -> Array[Rect2]:
	var pieces: Array[Rect2] = [area]
	var root_shape := _csg_root(shape)
	for node in [root_shape] + root_shape.find_children("*", "CSGShape3D", true, false):
		var other := node as CSGShape3D
		if other == shape or other is CSGSphere3D:
			continue
		var is_hole := other is CSGBox3D and other.operation == CSGShape3D.OPERATION_SUBTRACTION
		if not is_hole and not _is_part(other):
			continue
		var bounds := _bounds(other)
		if bounds.position.y > y + 0.05 or bounds.end.y <= y + 0.05:
			continue # (Not through this height.)
		var cut := Rect2(bounds.position.x, bounds.position.z, bounds.size.x, bounds.size.z)
		var left: Array[Rect2] = []
		for piece in pieces:
			left.append_array(_minus(piece, cut))
		pieces = left
	return pieces


## What's left of `a` with `b` taken out of it (up to four rectangles).
static func _minus(a: Rect2, b: Rect2) -> Array[Rect2]:
	if not a.intersects(b):
		return [a]
	var cut := a.intersection(b)
	var left: Array[Rect2] = []
	if cut.position.y > a.position.y: # (A strip the whole width, before it...)
		left.append(Rect2(a.position.x, a.position.y, a.size.x, cut.position.y - a.position.y))
	if cut.end.y < a.end.y: # (...and after it.)
		left.append(Rect2(a.position.x, cut.end.y, a.size.x, a.end.y - cut.end.y))
	if cut.position.x > a.position.x: # (And beside it, either side.)
		left.append(Rect2(a.position.x, cut.position.y, cut.position.x - a.position.x, cut.size.y))
	if cut.end.x < a.end.x:
		left.append(Rect2(cut.end.x, cut.position.y, a.end.x - cut.end.x, cut.size.y))
	return left.filter(func(r: Rect2) -> bool: return r.size.x > 0.01 and r.size.y > 0.01)


## A room cut out of a building (a "Room..." hole, see _find_solids()): its
## floor is a place, unless it goes right down to the ground (then the ground's
## the floor). Named "<building>/<room>".
func _add_room_floor(hole: CSGBox3D) -> void:
	var building := hole.get_parent() as CSGShape3D
	if building == null:
		return
	var room := _bounds(hole)
	if room.position.y <= _bounds(building).position.y + 0.1 or room.size.x * room.size.z < MIN_PLACE_AREA:
		return
	var spot := Spot.new()
	spot.name = "%s/%s" % [building.name, hole.name]
	spot.area = Rect2(room.position.x, room.position.z, room.size.x, room.size.z)
	spot.y = room.position.y
	spot.node = hole
	places.append(spot)


func _find_targets(root: Node) -> void:
	for node in root.find_children("*", "WorldItem", true, false):
		var item := node as WorldItem
		if item.item == null or not item.item.deliverable:
			continue
		var spot := Spot.new()
		spot.name = str(item.name)
		spot.is_target = true
		spot.area = Rect2(item.global_position.x, item.global_position.z, 0.0, 0.0)
		spot.y = item.global_position.y
		spot.reach = ItemCarrier.touch_range_of(item.item)
		spot.node = item
		targets.append(spot)
	# Group runs' gates too ("RunName/GateName"): you go through them like touching a relic.
	for node in root.find_children("*", "RunGate", true, false):
		var gate := node as RunGate
		var spot := Spot.new()
		spot.name = "%s/%s" % [gate.get_parent().get_parent().name, gate.name]
		spot.is_target = true
		spot.area = Rect2(gate.global_position.x, gate.global_position.z, 0.0, 0.0)
		spot.y = gate.global_position.y
		spot.reach = RunGate.RADIUS
		spot.node = gate
		targets.append(spot)


# --- Walls and ceilings in the way -------------------------------------------
# Buildings (CSG shapes in a "Buildings" node, or in the reach_solid group:
# boxes, upright cylinders, spheres, and those added into them) are solid,
# except for the holes cut out of them (rooms, doorways, windows, courtyards:
# child boxes that subtract). A link only counts if there's a way between its two spots
# that doesn't go through one (see path_clear()).

## Seen from above, the solids are sorted into squares this big (metres), for
## quick lookup.
const SOLID_CELL := 10.0
## How finely a path is checked (metres between points along it).
const PATH_STEP := 0.4
## How far up off a place your middle is (what a path runs from and to).
const PATH_MIDDLE := 0.9

## Something solid: a building, its shapes joined, less its holes.
class Solid:
	var parts: Array[Volume] = []
	var holes: Array[Volume] = []
	var bounds: AABB

## One shape of a solid: a box, a cylinder, a sphere, or a prism (an outline
## pushed out: a curved wall, a wedge). Worked out in its own space, so it can
## be turned, tilted or stretched any way (a building turned in its lot, a
## leaning tower, a flattened dome).
class Volume:
	## In the world.
	var bounds: AABB
	var kind := &"box"
	## From the world into its own space (where it's upright, its middle at 0).
	var to_local: Transform3D
	## Box: its size. Cylinder: radius in x, height in y. Sphere: radius in x.
	var size: Vector3
	## Prism: its outline (x, y), pushed out from z = 0 to z = -depth.
	var outline: PackedVector2Array
	var depth := 0.0

	static func of(shape: CSGShape3D) -> Volume:
		var volume := Volume.new()
		if shape is CSGBox3D:
			volume.size = (shape as CSGBox3D).size
		elif shape is CSGCylinder3D and not (shape as CSGCylinder3D).cone:
			volume.kind = &"cylinder"
			volume.size = Vector3((shape as CSGCylinder3D).radius, (shape as CSGCylinder3D).height, 0.0)
		elif shape is CSGSphere3D:
			volume.kind = &"sphere"
			volume.size = Vector3.ONE * (shape as CSGSphere3D).radius
		elif shape is CSGPolygon3D and (shape as CSGPolygon3D).mode == CSGPolygon3D.MODE_DEPTH and (shape as CSGPolygon3D).polygon.size() >= 3:
			volume.kind = &"prism"
			volume.outline = (shape as CSGPolygon3D).polygon
			volume.depth = (shape as CSGPolygon3D).depth
		else:
			return null # (A cone, a spun or swept shape: not yet.)
		volume.to_local = shape.global_transform.affine_inverse()
		volume.bounds = shape.global_transform * volume.local_box()
		return volume

	## The box round it in its own space.
	func local_box() -> AABB:
		match kind:
			&"cylinder": return AABB(Vector3(-size.x, -size.y / 2.0, -size.x), Vector3(2.0 * size.x, size.y, 2.0 * size.x))
			&"sphere": return AABB(-size, 2.0 * size)
			&"prism":
				var r := Rect2(outline[0], Vector2.ZERO)
				for p in outline:
					r = r.expand(p)
				return AABB(Vector3(r.position.x, r.position.y, -depth), Vector3(r.size.x, r.size.y, depth))
		return AABB(-size / 2.0, size)

	func has_point(point: Vector3) -> bool:
		if not bounds.has_point(point):
			return false
		var p := to_local * point
		match kind:
			&"cylinder": return absf(p.y) <= size.y / 2.0 and Vector2(p.x, p.z).length() < size.x
			&"sphere": return p.length() < size.x
			&"prism": return p.z < 0.0 and p.z > -depth and Geometry2D.is_point_in_polygon(Vector2(p.x, p.y), outline)
		return absf(p.x) <= size.x / 2.0 and absf(p.y) <= size.y / 2.0 and absf(p.z) <= size.z / 2.0

	## Where its top is straight under (x, z): [height, its surface's normal
	## there (pointing out)], or [] if it isn't under there.
	func top_at(x: float, z: float) -> Array:
		var start := Vector3(x, bounds.end.y + 1.0, z)
		var o := to_local * start
		var d := to_local.basis * Vector3.DOWN
		# The stretch of the line (as far down it as `t`) inside it, and the
		# normal (in its own space) where it goes in.
		var inside := [-INF, INF, Vector3.ZERO]
		match kind:
			&"box":
				for axis in 3:
					var out := Vector3.ZERO
					out[axis] = 1.0
					_slab(inside, o[axis], d[axis], -size[axis] / 2.0, size[axis] / 2.0, out)
			&"cylinder":
				_slab(inside, o.y, d.y, -size.y / 2.0, size.y / 2.0, Vector3.UP)
				_within(inside, Vector3(o.x, 0.0, o.z), Vector3(d.x, 0.0, d.z), size.x)
			&"sphere":
				_within(inside, o, d, size.x)
			&"prism":
				_slab(inside, o.z, d.z, -depth, 0.0, Vector3.BACK)
				_outline(inside, Vector2(o.x, o.y), Vector2(d.x, d.y))
		if inside[0] > inside[1] or inside[1] < 0.0 or inside[0] == -INF:
			return []
		var normal: Vector3 = (to_local.basis.transposed() * (inside[2] as Vector3)).normalized()
		return [start.y - inside[0], normal]

	## Narrows `inside` (see top_at()) to where a line (along `d`, at `o` when
	## t = 0, in one direction) is between `low` and `high`; `axis` points out
	## of the `high` side.
	static func _slab(inside: Array, o: float, d: float, low: float, high: float, axis: Vector3) -> void:
		if absf(d) < 1e-9:
			if o < low or o > high:
				inside[0] = INF
			return
		var t_low := (low - o) / d
		var t_high := (high - o) / d
		var enter := minf(t_low, t_high)
		if enter > inside[0]:
			inside[0] = enter
			inside[2] = -axis if t_low < t_high else axis
		inside[1] = minf(inside[1], maxf(t_low, t_high))

	## Narrows `inside` to where a line is within `r` of the middle (in the
	## directions it's given in: a cylinder's sides, a sphere).
	static func _within(inside: Array, o: Vector3, d: Vector3, r: float) -> void:
		var a := d.length_squared()
		var c := o.length_squared() - r * r
		if a < 1e-9:
			if c > 0.0:
				inside[0] = INF
			return
		var b := 2.0 * o.dot(d)
		var room := b * b - 4.0 * a * c
		if room < 0.0:
			inside[0] = INF
			return
		var enter := (-b - sqrt(room)) / (2.0 * a)
		if enter > inside[0]:
			inside[0] = enter
			inside[2] = (o + d * enter) / r
		inside[1] = minf(inside[1], (-b + sqrt(room)) / (2.0 * a))

	## Narrows `inside` to the first stretch where a line (seen along the
	## prism, in x and y) is in its outline.
	func _outline(inside: Array, o: Vector2, d: Vector2) -> void:
		if d.length_squared() < 1e-12:
			if not Geometry2D.is_point_in_polygon(o, outline):
				inside[0] = INF
			return
		# Where it crosses each edge, in order: in and out by turns.
		var crossings: Array = []
		for i in outline.size():
			var a := outline[i]
			var b := outline[(i + 1) % outline.size()]
			var edge := b - a
			var across := d.cross(edge)
			if absf(across) < 1e-12:
				continue
			var t := (a - o).cross(edge) / across
			var u := (a - o).cross(d) / across
			if u >= 0.0 and u < 1.0:
				var normal := Vector3(edge.y, -edge.x, 0.0).normalized()
				if normal.dot(Vector3(d.x, d.y, 0.0)) > 0.0:
					normal = -normal # (Pointing back the way the line comes from: out.)
				crossings.append([t, normal])
		crossings.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
		for i in range(0, crossings.size() - 1):
			var enter: float = crossings[i][0]
			var leave: float = crossings[i + 1][0]
			if not Geometry2D.is_point_in_polygon(o + d * (enter + leave) / 2.0, outline):
				continue
			if leave < inside[0] or enter > inside[1]:
				continue # (Not where it's between the ends.)
			if enter > inside[0]:
				inside[0] = enter
				inside[2] = crossings[i][1]
			inside[1] = minf(inside[1], leave)
			return
		inside[0] = INF

var _solids: Array[Solid] = []
var _solid_cells := {}


## Whether `point` is inside a building's solid part (not one of its holes).
func is_solid(point: Vector3) -> bool:
	return _solid_at(point) != null


## The solid `point` is inside (not in one of its holes), if any.
func _solid_at(point: Vector3) -> Solid:
	for solid: Solid in _solid_cells.get(_cell(point), []):
		if solid.parts.any(func(part: Volume) -> bool: return part.has_point(point)) \
				and not solid.holes.any(func(hole: Volume) -> bool: return hole.has_point(point)):
			return solid
	return null


## Whether a straight line from `a` to `b` stays clear of solids.
func segment_clear(a: Vector3, b: Vector3) -> bool:
	var steps := maxi(1, ceili(a.distance_to(b) / PATH_STEP))
	for i in steps + 1:
		if is_solid(a.lerp(b, float(i) / steps)):
			return false
	return true


## Whether there's a way from spot `from` to spot `to` that doesn't go through
## walls or ceilings: from somewhere along its edges (or just past them: you
## move as you jump), straight up to above the higher of the two, across, and
## down onto the other. Tries a few ways (along the edges facing each other,
## round the other's footprint when one is over the other).
func path_clear(from: Spot, to: Spot) -> bool:
	if _solids.is_empty():
		return true
	var start_y := from.y + (0.0 if from.is_target else PATH_MIDDLE)
	var end_y := to.y + (0.0 if to.is_target else PATH_MIDDLE)
	var peak := maxf(start_y, end_y) + 0.5
	var near := gap(from, to) + 8.0
	for s in _samples(from, to, near):
		var t := _closest_in(to.area, s) # (Coming down on the nearest bit of it.)
		# You take off from the place itself (with room overhead there), then on past its edge.
		var off := _closest_in(from.area, s)
		if segment_clear(Vector3(off.x, start_y, off.y), Vector3(off.x, peak, off.y)) \
				and segment_clear(Vector3(off.x, peak, off.y), Vector3(s.x, peak, s.y)) \
				and segment_clear(Vector3(s.x, start_y, s.y), Vector3(s.x, peak, s.y)) \
				and segment_clear(Vector3(s.x, peak, s.y), Vector3(t.x, peak, t.y)) \
				and segment_clear(Vector3(t.x, peak, t.y), Vector3(t.x, end_y, t.y)):
			return true
	return false


## A wall leaning out over you more than this (degrees from upright) can't be
## run up or grabbed from below: you meet its face before you get your hands to
## the edge. (The game takes a face more than about 17° off upright as a ceiling
## or a slope, not a wall: see Player.find_ledge().)
const WALL_LEAN := 15.0


## Whether, from `from` (beside `to`, lower), there's somewhere along `to`'s
## edge where the wall up to it doesn't lean out over you more than
## WALL_LEAN, from `depth` below its top up to it (for a scramble the whole
## way; to grab the edge from a jump, just the top of it).
func wall_up(from: Spot, to: Spot, depth: float) -> bool:
	if _solids.is_empty():
		return true
	var lean := tan(deg_to_rad(WALL_LEAN))
	var a := to.area
	# Each side of `to`: [one end, the other, pointing out].
	for side: Array in [[a.position, Vector2(a.end.x, a.position.y), Vector2.UP], [Vector2(a.end.x, a.position.y), a.end, Vector2.RIGHT],
			[Vector2(a.position.x, a.end.y), a.end, Vector2.DOWN], [a.position, Vector2(a.position.x, a.end.y), Vector2.LEFT]]:
		var length: float = (side[0] as Vector2).distance_to(side[1])
		var count := maxi(1, ceili(length / 3.0))
		for k in count:
			var along: Vector2 = (side[0] as Vector2).lerp(side[1], (k + 0.5) / count)
			var out: Vector2 = side[2]
			if _distance_to(from.area, along + out * 0.5) > gap(from, to) + 1.5:
				continue # (Not facing `from`.)
			var just_under := to.y - 0.1
			if not is_solid(Vector3(along.x, just_under, along.y)):
				return true # (Not a building: a box on a roof, say. Upright.)
			# The wall's real top edge (the place may stop a little short of it).
			var edge := along
			for step in 20:
				if not is_solid(Vector3(edge.x + out.x * 0.1, just_under, edge.y + out.y * 0.1)):
					break
				edge += out * 0.1
			# Down the wall: still there a little way in (it doesn't lean out), and
			# not a little way out (it doesn't lean back: a steep slope, not a wall).
			var building := _solid_at(Vector3(edge.x, just_under, edge.y))
			var below := minf(depth, to.y - from.y)
			var upright := true
			var down := 0.3
			while down < below:
				var inside := edge - out * (0.2 + down * lean)
				var outside := edge + out * (0.2 + down * lean)
				if _solid_at(Vector3(inside.x, to.y - down, inside.y)) != building or _solid_at(Vector3(outside.x, to.y - down, outside.y)) == building:
					upright = false
					break
				down += 0.5
			if upright:
				return true
	return false


## Where to set off from `from` toward `to`: the nearest point first, then
## along its edges (just inside and just past them), and round `to`'s
## footprint where it's over `from`, or round `from`'s where it's over `to`
## (only those within `near` of `to`).
func _samples(from: Spot, to: Spot, near: float) -> Array[Vector2]:
	var points: Array[Vector2] = [_closest_in(from.area, to.area.get_center())]
	for grow in [-0.25, 0.5]:
		points.append_array(_round(from.area.grow(grow)))
	# Onto something over `from` (a hatch, a tier, a dome's crown): from a
	# little way out round it (further, round something on top of it).
	for grow in [0.4, 2.0, 4.0, 6.0] if from.area.encloses(to.area) else [0.4, 2.0]:
		for point in _round(to.area.grow(grow)):
			if from.area.has_point(point):
				points.append(point)
	# And the other way: off something on top of `to`, landing a little way
	# out from it (running or jumping off it).
	if to.area.encloses(from.area):
		for grow in [2.0, 4.0, 6.0]:
			for point in _round(from.area.grow(grow)):
				if to.area.has_point(point):
					points.append(point)
	return points.filter(func(point: Vector2) -> bool: return _distance_to(to.area, point) <= near)


## Points round the edge of `area`, about every 3 m (a point's area: itself).
static func _round(area: Rect2) -> Array[Vector2]:
	var points: Array[Vector2] = []
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return [area.get_center()]
	var corners := [area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var count := maxi(1, ceili(a.distance_to(b) / 3.0))
		for k in count:
			points.append(a.lerp(b, float(k) / count))
	return points


static func _closest_in(area: Rect2, point: Vector2) -> Vector2:
	return Vector2(clampf(point.x, area.position.x, area.end.x), clampf(point.y, area.position.y, area.end.y))


static func _distance_to(area: Rect2, point: Vector2) -> float:
	return _closest_in(area, point).distance_to(point)


func _cell(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / SOLID_CELL), floori(point.z / SOLID_CELL))


func _find_solids(root: Node) -> void:
	for node in root.find_children("*", "CSGShape3D", true, false):
		var shape := node as CSGShape3D
		if shape.get_parent() is CSGShape3D or not shape.use_collision \
				or not (shape.get_parent().name == &"Buildings" or shape.is_in_group(&"reach_solid")):
			continue
		var solid := Solid.new()
		for part_node in [shape] + shape.find_children("*", "CSGShape3D", true, false):
			var part := part_node as CSGShape3D
			if _is_part(part):
				var volume := Volume.of(part)
				if volume != null:
					solid.parts.append(volume)
					solid.bounds = volume.bounds if solid.parts.size() == 1 else solid.bounds.merge(volume.bounds)
			elif part is CSGBox3D and part.operation == CSGShape3D.OPERATION_SUBTRACTION:
				solid.holes.append(Volume.of(part))
		if solid.parts.is_empty():
			continue
		_solids.append(solid)
		for x in range(floori(solid.bounds.position.x / SOLID_CELL), floori(solid.bounds.end.x / SOLID_CELL) + 1):
			for z in range(floori(solid.bounds.position.z / SOLID_CELL), floori(solid.bounds.end.z / SOLID_CELL) + 1):
				if not _solid_cells.has(Vector2i(x, z)):
					_solid_cells[Vector2i(x, z)] = []
				_solid_cells[Vector2i(x, z)].append(solid)


## The box round `shape` (any way it's turned), in the world.
static func _bounds(shape: CSGShape3D) -> AABB:
	var volume := Volume.of(shape)
	return volume.bounds if volume else AABB(shape.global_position, Vector3.ZERO)
