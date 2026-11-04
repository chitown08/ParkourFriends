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
const DOORWAY_CLEAR := 3.0 ## And this far in front of doorways.
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
## How many relics the district gets for each number of players they take,
## counting the five above. The generator tries a relic on spots all over (see
## _relic_candidates()), asks the reachability checker what each takes, and
## keeps this many of each (the rings round a relic say which).
const RELICS_WANTED := {1: 14, 2: 8, 3: 5, 4: 3}
## Relics inside: a warehouse's this high (a friend's toss up), and only
## this many top floors get one.
const INSIDE_TOSS_HEIGHT := 9.0
const INSIDE_TOP_FLOORS := 3
## Relics on pillars stand on roofs: this wide, and this tall for what they're
## meant to take (the checker has the last word).
const PILLAR := 2.5
const PILLAR_HEIGHTS := {1: 7.0, 2: 11.0, 3: 12.5, 4: 14.0}
## Roof clutter keeps this far from a pillar (it'd be a step up it).
const PILLAR_CLEAR := 7.0
## Some relics float this high over a roof (a toss gets you there).
const FLOAT_HEIGHT := 9.5
## Group runs (see levels/group_run.gd): white gates this many, this high over
## the roof you land on and this far in from its edge; gold gates float this high
## over a roof on the route (a toss gets one of you through).
const RUN_GATES := 5
const GATE_HEIGHT := 1.8
const GATE_IN := 4.0
const GOLD_GATE_HEIGHT := 9.5
## Launchers (levels/launcher.gd): wall ramps (this many, this long and tall,
## along the street side of buildings this many storeys tall: a new way up)
## and quarter-pipes (this many, at the foot of a wall, launching you up it).
const WALL_RAMPS := 4
const WALL_RAMP := Vector2(12.0, 5.0)
const WALL_RAMP_STOREYS := Vector2i(4, 5)
const QUARTER_PIPES := 2
const QUARTER_PIPE_STOREYS := 4
## Pipes (levels/pipe.gd): a glass tube across each avenue, joining two roofs
## the same height (where the rails can't: they need one higher), this far
## into each roof and this wide (one you can loop free-running); and one big
## road tunnel on the ring road round the district, with a relic on its
## ceiling (a loop at full flow).
const TUBE_IN := 3.0
const TUBE_RADIUS := 3.0
const TUBE_MIN_STOREYS := 5
const TUNNEL := Vector2(40.0, 4.5) ## (Length, radius.)
## Interiors (see _pick_interiors()): about a quarter of the buildings are
## hollow, built for running through (wide, tall, open).
const WALL := 0.5 ## Outer walls this thick...
const ROOF_SLAB := 1.0 ## ...and the roof.
const WAREHOUSES := 4 ## Big halls, floor to roof: 4-5 storeys, at least this wide...
const WAREHOUSE_MIN := 20.0
const WAREHOUSE_DOOR := Vector2(8.0, 6.0) ## ...with a loading door (wide, tall) in each wall.
const THROUGH_FLOORS := 7 ## Top floors you run through: 6+ storeys, two storeys tall...
const THROUGH_MIN := 14.0
const THROUGH_OPENING := Vector2(6.0, 4.5) ## ...with an opening this big about every
const THROUGH_SPACING := 12.0 ## this far along each wall (at floor level).
const TOWER_DOOR := Vector2(6.0, 5.0) ## Towers: a doorway in each wall, and a
const PLATFORM_RUN := 5.0 ## climb of blocks (at least this long) round the inside walls.

# Ways back up: every flat-roofed building without a fire escape (towers
# aside) gets a yellow drainpipe or a column of window sills up one wall, and
# every block an orange air vent on the pavement that blows you up to a roof.
const PIPE_CHANCE := 0.6 ## (The rest get sills.)
const WAY_UP_CORNER := 3.0 ## Kept at least this far from a wall's corners.
const SILL := Vector3(2.5, 0.3, 0.5) ## (Along the wall, thick, out from it.)
const VENT_OUT := 1.5 ## The vent's middle is this far out from the wall...
const VENT_LIFT := 1.0 ## ...and it blows you this far above the roof.

## Where each block starts, along x (columns) and z (rows), before centring.
var _starts: Array[float] = []
## Places clutter mustn't go: rail paths as [from, to] (seen from above), the
## spawn and checkpoints, and fire escape footprints (Rect2s, for the pavement).
var _rail_paths: Array = []
var _marker_spots: Array[Vector2] = []
var _fire_escapes: Array[Rect2] = []
## Doorways and openings at street level: the pavement keeps clear in front.
var _doorways: Array[Rect2] = []
## Every rail as [start, end].
var _rails: Array = []
## The plaza (where the avenues cross) is the origin of the world.
var _plaza_middle := 0.0
## The relics beyond the five fixed ones, as dictionaries (see _relic_candidates()).
var _extra_relics: Array = []
## What each relic takes (players), by name, once measured: written as its rings.
var _needed := {}
## Where the pillars stand (clutter keeps clear).
var _pillar_spots: Array[Vector2] = []
## Where drainpipes and sill columns go up walls (launchers keep clear).
var _way_up_spots: Array[Vector2] = []
var _out := PackedStringArray()


func _init() -> void:
	var at := 0.0
	for i in BLOCKS:
		_starts.append(at)
		at += BLOCK + (AVENUE if i == AVENUE_AFTER else STREET)
	_plaza_middle = _starts[AVENUE_AFTER] + BLOCK + AVENUE / 2.0
	_generate.call_deferred() # (Once the scene tree is up: measuring needs it.)


## Writes the district three times: first with a relic on every spot that might
## hold one, to ask the reachability checker what each takes; then with just
## the ones picked to make up RELICS_WANTED; then once more, marking each with
## the players it takes (players_needed: its rings).
func _generate() -> void:
	_extra_relics = _relic_candidates(_all_buildings())
	_write_scene()
	_extra_relics = _pick_relics(_measure())
	_write_scene()
	_needed = _measure()
	var summary := _write_scene()
	var tiers := {}
	for relic_name: String in _needed:
		if not relic_name.begins_with("Relic"):
			continue # (Group runs' gates and rewards.)
		tiers[_needed[relic_name]] = tiers.get(_needed[relic_name], 0) + 1
	print("%s\nRelics by players they take: %s (wanted %s)" % [summary, tiers, RELICS_WANTED])
	quit()


## Every building in the district (each call builds them afresh: writing the
## scene marks them, e.g. which has a fire escape).
func _all_buildings() -> Array[Dictionary]:
	var buildings: Array[Dictionary] = []
	for bx in BLOCKS:
		for bz in BLOCKS:
			buildings.append_array(_block(bx, bz))
	_pick_interiors(buildings)
	return buildings


## Writes the scene file (with _extra_relics), and says what's in it.
func _write_scene() -> String:
	_out.clear()
	_rail_paths.clear()
	_marker_spots.clear()
	_fire_escapes.clear()
	_doorways.clear()
	_rails.clear()
	_pillar_spots.clear()
	_way_up_spots.clear()
	var buildings := _all_buildings()

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
	var ways_up := 0
	for b in buildings:
		ways_up += 1 if _write_way_up(b) else 0
	var vents := 0
	for bx in BLOCKS:
		for bz in BLOCKS:
			vents += 1 if _write_air_vent(buildings, Vector2i(bx, bz)) else 0
	var rails := 0
	for i in BLOCKS:
		rails += 1 if _write_rail(buildings, i, true) else 0
		rails += 1 if _write_rail(buildings, i, false) else 0
	var launchers := _write_launchers(buildings)
	var pipes := _write_pipes(buildings)
	# (After the ways up the outside: openings keep clear of them.)
	var interiors := 0
	for b in buildings:
		if b.interior != "":
			_write_interior(b)
			interiors += 1
	_write_ramps()
	_write_markers(buildings)
	var runs := _write_runs(buildings) # (Before the relics: a run takes its roofs first.)
	_write_relics(buildings)
	var relics := 6 + _write_extra_relics(buildings) # (The five fixed ones and the tunnel's.)
	var items := _write_items(buildings)
	_write_relic_board(buildings)
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
	return "Wrote %s: %d buildings, %d towers, %d fire escapes, %d drainpipes or sills, %d air vents, %d rails, %d launchers, %d pipes, %d interiors, %d relics, %d items, %d group runs, %d roof things, %d street things (seed %d)" % [
			OUTPUT, buildings.size(), buildings.filter(func(b: Dictionary) -> bool: return b.tower).size(),
			staircases, ways_up, vents, rails, launchers, pipes, interiors, relics, items, runs, roof_things, street_things, SEED]


## What the reachability checker says each relic in the scene just written
## takes (players, from the spawn; 0 if nobody can get there), by name.
func _measure() -> Dictionary:
	var level := (ResourceLoader.load(OUTPUT, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate() as Node3D
	root.add_child(level)
	var map := ReachMap.build(level, load("res://player/profiles/superhuman.tres"))
	var start := map.place_under(level.get_node("SpawnPoint").global_position + Vector3.UP)
	var needed := {}
	for target in map.targets:
		needed[target.name] = map.players_needed(target, start, [&"flow"], 6)
	root.remove_child(level)
	level.free()
	return needed


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
				"w": r.size.x, "d": r.size.y, "storeys": storeys, "tower": tower, "block": Vector2i(bx, bz), "roof": "flat", "fire_escape": false, "interior": ""})
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
		b.fire_escape = true
		for k in range(1, steps + 1):
			var middle := start + along * (k - 0.5) * run + out * STEP_DEPTH / 2.0
			var size := along.abs() * run + out.abs() * STEP_DEPTH
			_box("%s_Step%d" % [b.name, k], "FireEscapes", middle.x, k * STOREY / 2.0, middle.y,
					size.x, k * STOREY, size.y, "7_climb")
		return true
	return false


## A drainpipe or a column of window sills up one wall of `b` (flat roofs
## without a fire escape only, towers aside). Returns false if it gets none.
func _write_way_up(b: Dictionary) -> bool:
	if b.tower or b.roof != "flat" or b.fire_escape:
		return false
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([SEED, b.name, "way up"])
	var walls := _walls(b)
	var wall: Array = walls[dice.randi() % walls.size()]
	var at: Vector2 = wall[0] + wall[1] * dice.randf_range(WAY_UP_CORNER, wall[3] - WAY_UP_CORNER)
	_way_up_spots.append(at)
	var out: Vector2 = wall[2]
	var height: float = b.storeys * STOREY
	if dice.randf() < PIPE_CHANCE:
		# Its +Z points out of the wall.
		_out.append("\n[node name=\"%s_Pipe\" type=\"Node3D\" parent=\"WaysUp\"]\ntransform = Transform3D(%s, 0, %s, 0, 1, 0, %s, 0, %s, %s, 0, %s)\nscript = ExtResource(\"16_pipe\")\nheight = %s" % [
				b.name, _num(out.y), _num(out.x), _num(-out.x), _num(out.y), _num(at.x), _num(at.y), _num(height)])
		return true
	# A sill under each storey's window, up to the one below the roof (a
	# storey apart: a ledge leap reaches each from the one below).
	var middle := at + out * SILL.z / 2.0
	var size := (wall[1] as Vector2).abs() * SILL.x + out.abs() * SILL.z
	for k in range(1, b.storeys):
		_box("%s_Sill%d" % [b.name, k], "WaysUp", middle.x, k * STOREY - SILL.y / 2.0, middle.y,
				size.x, SILL.y, size.y, "7_climb")
	return true


## An air vent on the pavement beside one of the block's flat-roofed buildings
## (towers aside), blowing you up to its roof. Returns false if none fits.
func _write_air_vent(buildings: Array[Dictionary], block: Vector2i) -> bool:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([SEED, block.x, block.y, "vent"])
	var area := _block_rect(block)
	var candidates := buildings.filter(func(b: Dictionary) -> bool: return b.block == block and b.roof == "flat" and not b.tower)
	for attempt in 10:
		if candidates.is_empty():
			return false
		var b: Dictionary = candidates[dice.randi() % candidates.size()]
		# Street-facing walls only (the pavement).
		var walls := _walls(b).filter(func(w: Array) -> bool:
				var outside: Vector2 = w[0] + w[1] * w[3] / 2.0 + w[2]
				return not area.has_point(outside))
		if walls.is_empty():
			continue
		var wall: Array = walls[dice.randi() % walls.size()]
		var at: Vector2 = wall[0] + wall[1] * dice.randf_range(WAY_UP_CORNER, wall[3] - WAY_UP_CORNER) + wall[2] * VENT_OUT
		var footprint := Rect2(at - Vector2.ONE * AirVent.SIZE / 2.0, Vector2.ONE * AirVent.SIZE)
		if _fire_escapes.any(func(r: Rect2) -> bool: return r.grow(2.0).intersects(footprint)):
			continue
		_fire_escapes.append(footprint) # Keeps the pavement clutter clear of it.
		_out.append("\n[node name=\"Block%d%d_Vent\" type=\"Node3D\" parent=\"AirVents\"]\ntransform = %s\nscript = ExtResource(\"17_vent\")\nrise = %s" % [
				block.x, block.y, _at(at.x, 0.0, at.y), _num(b.storeys * STOREY + VENT_LIFT)])
		return true
	return false


## The four walls of `b`: [a corner, the way along it, the way out of the building, its length].
func _walls(b: Dictionary) -> Array:
	return [[Vector2(b.x, b.z), Vector2.RIGHT, Vector2.UP, b.w],
			[Vector2(b.x, b.z + b.d), Vector2.RIGHT, Vector2.DOWN, b.w],
			[Vector2(b.x, b.z), Vector2.DOWN, Vector2.LEFT, b.d],
			[Vector2(b.x + b.w, b.z), Vector2.DOWN, Vector2.RIGHT, b.d]]


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
			if _fire_escapes.any(func(r: Rect2) -> bool: return r.grow(FIRE_ESCAPE_CLEAR).intersects(footprint)) \
					or _doorways.any(func(r: Rect2) -> bool: return r.grow(DOORWAY_CLEAR).intersects(footprint)):
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
	for spot in _pillar_spots:
		if footprint.grow(PILLAR_CLEAR).has_point(spot):
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
[ext_resource type="Script" path="res://levels/drainpipe.gd" id="16_pipe"]
[ext_resource type="Script" path="res://levels/air_vent.gd" id="17_vent"]
[ext_resource type="Resource" path="res://items/data/glider.tres" id="18_glider"]
[ext_resource type="Resource" path="res://items/data/bat.tres" id="19_bat"]
[ext_resource type="Resource" path="res://items/data/crate.tres" id="20_crate"]
[ext_resource type="Resource" path="res://items/data/test_balloon.tres" id="22_balloon"]
[ext_resource type="Script" path="res://levels/group_run.gd" id="23_run"]
[ext_resource type="Script" path="res://levels/run_gate.gd" id="24_gate"]
[ext_resource type="Script" path="res://levels/relic_board.gd" id="25_board"]
[ext_resource type="Script" path="res://levels/launcher.gd" id="26_launcher"]
[ext_resource type="Script" path="res://levels/pipe.gd" id="27_pipe"]

[sub_resource type="ProceduralSkyMaterial" id="ProceduralSkyMaterial_sky"]
sky_top_color = Color(0.22, 0.46, 0.85, 1)
sky_horizon_color = Color(0.78, 0.86, 0.95, 1)
ground_bottom_color = Color(0.5, 0.52, 0.56, 1)
ground_horizon_color = Color(0.78, 0.86, 0.95, 1)

[sub_resource type="Sky" id="Sky_main"]
sky_material = SubResource("ProceduralSkyMaterial_sky")

[sub_resource type="Environment" id="Environment_main"]
background_mode = 2
sky = SubResource("Sky_main")
ambient_light_source = 2
ambient_light_color = Color(0.85, 0.88, 0.92, 1)
ambient_light_energy = 0.55
tonemap_mode = 2
ssao_enabled = true
fog_enabled = true
fog_light_color = Color(0.82, 0.88, 0.95, 1)
fog_density = 0.001

[node name="RooftopDistrict" type="Node3D"]
script = ExtResource("1_level")
kill_height = -20.0
music = ExtResource("6_music")
music_folder = "res://audio/music/rooftop_test/"

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Environment_main")

[node name="Sun" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.866, -0.383, 0.3214, 0, 0.6428, 0.766, -0.5, -0.6634, 0.5567, 0, 120, 0)
light_energy = 1.0
shadow_enabled = true
directional_shadow_max_distance = 250.0

[node name="Street" type="Node3D" parent="."]

[node name="Buildings" type="Node3D" parent="."]

[node name="Roofs" type="Node3D" parent="."]

[node name="FireEscapes" type="Node3D" parent="."]

[node name="WaysUp" type="Node3D" parent="."]

[node name="AirVents" type="Node3D" parent="."]

[node name="GrindRails" type="Node3D" parent="."]

[node name="Ramps" type="Node3D" parent="."]

[node name="RoofClutter" type="Node3D" parent="."]

[node name="StreetClutter" type="Node3D" parent="."]

[node name="Checkpoints" type="Node3D" parent="."]

[node name="Labels" type="Node3D" parent="."]

[node name="Pillars" type="Node3D" parent="."]

[node name="Relics" type="Node3D" parent="."]

[node name="Items" type="Node3D" parent="."]

[node name="Runs" type="Node3D" parent="."]

[node name="Launchers" type="Node3D" parent="."]

[node name="Pipes" type="Node3D" parent="."]

[node name="Interiors" type="Node3D" parent="."]""")


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
	_out.append("\n[node name=\"%s\" parent=\"Relics\" instance=ExtResource(\"12_item\")]\ntransform = %s\nitem = ExtResource(\"%s\")\nplayers_needed = %d" % [
			name, _at(at.x, at.y, at.z), data, _needed.get(name, 0)])


## Every spot that might hold a relic besides the five fixed ones: on each big
## enough flat roof one of a mix (hovering over the roof, on a pillar of each
## height, or floating high above it), and a few down on the streets. Each is
## {"name", "at" (the relic), "pillar" (its height, 0 for none), "on" (the building's name, or "")}.
func _relic_candidates(buildings: Array[Dictionary]) -> Array:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([SEED, "relics"])
	var roofs := buildings.filter(func(b: Dictionary) -> bool:
			return b.roof == "flat" and not b.tower and b.w >= 14.0 and b.d >= 14.0)
	_shuffle(roofs, dice)
	var kinds := ["roof", "pillar 4", "pillar 3", "float", "pillar 2", "pillar 1", "pillar 4", "pillar 3"]
	var candidates := []
	for i in roofs.size():
		var b: Dictionary = roofs[i]
		var kind: String = kinds[i % kinds.size()]
		var roof: float = b.storeys * STOREY
		# Off the middle a little (where a pillar won't block anything).
		var spot := _middle(b) + Vector2(dice.randf_range(-2.0, 2.0), dice.randf_range(-2.0, 2.0))
		var pillar: float = PILLAR_HEIGHTS[int(kind.get_slice(" ", 1))] if kind.begins_with("pillar") else 0.0
		var height: float = pillar + RELIC_HOVER if kind != "float" else FLOAT_HEIGHT
		candidates.append({"name": "Relic" + b.name, "at": Vector3(spot.x, roof + height, spot.y), "pillar": pillar, "on": b.name})
	# Inside (first: picked before roofs): up in the air in a warehouse (a
	# toss up from the floor), level with the climb halfway up a tower's atrium
	# but out over the middle, and in the middle of a few top floors.
	var inside_ones := []
	var top_floors := 0
	for b: Dictionary in buildings:
		var inside := _middle(b)
		var height := -1.0
		match b.interior:
			"warehouse": height = INSIDE_TOSS_HEIGHT
			"atrium": height = (b.storeys / 2) * STOREY + RELIC_HOVER
			"through":
				if top_floors < INSIDE_TOP_FLOORS:
					top_floors += 1
					height = (b.storeys - 2) * STOREY + RELIC_HOVER
		if height > 0.0:
			inside_ones.append({"name": "RelicInside" + b.name, "at": Vector3(inside.x, height, inside.y), "pillar": 0.0, "on": ""})
	candidates = inside_ones + candidates
	# Down in the streets between blocks.
	for i in 6:
		var block := Vector2i(dice.randi_range(0, BLOCKS - 2), dice.randi_range(0, BLOCKS - 1))
		if block.x == AVENUE_AFTER:
			continue # (That street is the avenue.)
		var area := _block_rect(block)
		var at := Vector3(area.end.x + STREET / 2.0, RELIC_HOVER, area.position.y + dice.randf_range(8.0, BLOCK - 8.0))
		candidates.append({"name": "RelicStreet%d" % i, "at": at, "pillar": 0.0, "on": ""})
	return candidates


## The relics to keep, from the candidates measured (`needed`: players each
## takes, by name): enough of each to make up RELICS_WANTED with the fixed five.
func _pick_relics(needed: Dictionary) -> Array:
	var have := {}
	for fixed in ["RelicSky", "RelicRail", "RelicFarCorner", "RelicHighRoof", "RelicSubway", "RelicTunnel"]:
		have[needed[fixed]] = have.get(needed[fixed], 0) + 1
	var picked := []
	for candidate: Dictionary in _extra_relics:
		var players: int = needed.get(candidate.name, 0)
		if needed.has(candidate.name) and RELICS_WANTED.has(players) and have.get(players, 0) < RELICS_WANTED[players]:
			have[players] = have.get(players, 0) + 1
			picked.append(candidate)
	return picked


## Writes _extra_relics (and their pillars), skipping any on a roof that has a
## marker or a fixed relic already. Returns how many it wrote.
func _write_extra_relics(buildings: Array[Dictionary]) -> int:
	var count := 0
	for candidate: Dictionary in _extra_relics:
		var b: Dictionary = {}
		for building in buildings:
			if building.name == candidate.on:
				b = building
		if not b.is_empty() and _marker_spots.any(func(spot: Vector2) -> bool: return Rect2(b.x, b.z, b.w, b.d).has_point(spot)):
			continue
		var at: Vector3 = candidate.at
		if candidate.pillar > 0.0:
			var roof: float = b.storeys * STOREY
			_box("Pillar" + b.name, "Pillars", at.x, roof + candidate.pillar / 2.0, at.z, PILLAR, candidate.pillar, PILLAR, "4_building")
			_pillar_spots.append(Vector2(at.x, at.z))
		_relic(candidate.name, at, not b.is_empty())
		count += 1
	return count


## Items to try out, around the district (they go back home if left lying
## about): bats and balloons in the plaza, gliders on the tallest roofs
## (glide across the avenues), balloons on others, crates in the streets.
## Returns how many it wrote.
func _write_items(buildings: Array[Dictionary]) -> int:
	var items := [["Bat1", "19_bat", Vector3(6, 0.5, -6)], ["Bat2", "19_bat", Vector3(-6, 0.5, -6)],
			["Balloon4", "22_balloon", Vector3(-6, 0.5, 6)], ["Balloon5", "22_balloon", Vector3(6, 0.5, 6)]]
	var free := buildings.filter(func(b: Dictionary) -> bool:
			return b.roof == "flat" and not b.tower and not _marker_spots.any(func(spot: Vector2) -> bool:
				return Rect2(b.x, b.z, b.w, b.d).has_point(spot)))
	free.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.storeys > b.storeys or (a.storeys == b.storeys and a.name < b.name))
	for i in mini(free.size(), 6):
		var b: Dictionary = free[i]
		var spot := _middle(b) + Vector2(3.0, 3.0)
		var glider := i < 3
		items.append(["%s%d" % ["Glider" if glider else "Balloon", i % 3 + 1], "18_glider" if glider else "22_balloon",
				Vector3(spot.x, b.storeys * STOREY + 0.5, spot.y)])
	for i in 3:
		var area := _block_rect(Vector2i(i + 1 if i + 1 != AVENUE_AFTER else 0, 1))
		items.append(["Crate%d" % (i + 1), "20_crate", Vector3(area.position.x + 20.0, 0.5, area.end.y + 3.0)])
	for item: Array in items:
		var at: Vector3 = item[2]
		_marker_spots.append(Vector2(at.x, at.z))
		_out.append("\n[node name=\"%s\" parent=\"Items\" instance=ExtResource(\"12_item\")]\ntransform = %s\nitem = ExtResource(\"%s\")" % [
				item[0], _at(at.x, at.y, at.z), item[1]])
	return items.size()


## Shuffles `list` with `dice` (so the same seed always gives the same order).
func _shuffle(list: Array, dice: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := dice.randi_range(0, i)
		var swap: Variant = list[i]
		list[i] = list[j]
		list[j] = swap


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


## The group runs (see levels/group_run.gd). For now one, "Warm-up": its start
## ring on the free roof nearest the spawn; then a white gate on each of the
## next RUN_GATES roofs, hopping across alleys and streets (up two storeys at
## most: a readied leap), each just in from the edge you land on; two gold gates floating
## high over roofs on the way; and its relics at the finish. Returns how many.
func _write_runs(buildings: Array[Dictionary]) -> int:
	var flat := buildings.filter(func(b: Dictionary) -> bool:
			return b.roof == "flat" and not b.tower and b.w >= 12.0 and b.d >= 12.0)
	var free := flat.filter(func(b: Dictionary) -> bool:
			return not _marker_spots.any(func(spot: Vector2) -> bool: return Rect2(b.x, b.z, b.w, b.d).grow(2.0).has_point(spot)) \
				and not _pillar_spots.any(func(spot: Vector2) -> bool: return Rect2(b.x, b.z, b.w, b.d).has_point(spot)))
	var spawn_roof := _nearest(flat, _marker_spots[0]) # (The spawn is the first marker.)
	var start: Dictionary = _nearest(free.filter(func(b: Dictionary) -> bool: return b != spawn_roof), _marker_spots[0])
	var route: Array[Dictionary] = [start]
	var gates: Array[Vector3] = []
	for i in RUN_GATES:
		var here: Dictionary = route.back()
		var best: Dictionary = {}
		var best_score := -INF
		for b: Dictionary in flat:
			if b in route or b.storeys - here.storeys > MAX_ALLEY_STEP or here.storeys - b.storeys > 3:
				continue
			var across := _gap_between(here, b)
			if across < 3.0 or across > STREET + 0.5:
				continue
			var score: float = _middle(b).distance_to(_middle(start)) - across # On and away, by short hops.
			if score > best_score:
				best_score = score
				best = b
		if best.is_empty():
			break
		route.append(best)
		# Just in from the edge you land on, over the roof.
		var r := Rect2(best.x, best.z, best.w, best.d).grow(-GATE_IN)
		var spot := Vector2(clampf(_middle(here).x, r.position.x, r.end.x), clampf(_middle(here).y, r.position.y, r.end.y))
		gates.append(Vector3(spot.x, best.storeys * STOREY + GATE_HEIGHT, spot.y))
	var origin := Vector3(_middle(start).x, start.storeys * STOREY, _middle(start).y)
	_marker_spots.append(Vector2(origin.x, origin.z))
	_out.append("\n[node name=\"Run1\" type=\"Node3D\" parent=\"Runs\"]\ntransform = %s\nscript = ExtResource(\"23_run\")\ntitle = \"Warm-up\"" % _at(origin.x, origin.y, origin.z))
	_out.append("\n[node name=\"Gates\" type=\"Node3D\" parent=\"Runs/Run1\"]")
	var from := origin
	for i in gates.size():
		_gate("Gate%d" % (i + 1), gates[i] - origin, gates[i] - from, false)
		from = gates[i]
	var golds := []
	for i in [1, 3]:
		if i < route.size():
			var b: Dictionary = route[i]
			golds.append(Vector3(_middle(b).x, b.storeys * STOREY + GOLD_GATE_HEIGHT, _middle(b).y))
	for i in golds.size():
		_gate("Gold%d" % (i + 1), golds[i] - origin, Vector3.FORWARD, true)
	_out.append("\n[node name=\"Rewards\" type=\"Node3D\" parent=\"Runs/Run1\"]")
	var finish: Vector3 = gates.back() if not gates.is_empty() else origin
	var rewards := ["Finish"]
	for i in golds.size():
		rewards.append("Gold%d" % (i + 1))
	for i in rewards.size():
		var at := finish - origin + Vector3((i - (rewards.size() - 1) / 2.0) * 1.5, RELIC_HOVER - GATE_HEIGHT, 0.0)
		_out.append("\n[node name=\"%s\" parent=\"Runs/Run1/Rewards\" instance=ExtResource(\"12_item\")]\ntransform = %s\nitem = ExtResource(\"13_relic\")\nlocked = true" % [
				rewards[i], _at(at.x, at.y, at.z)])
	for gate: Vector3 in gates + golds:
		_marker_spots.append(Vector2(gate.x, gate.z))
	return 1


## A gate at `at` (from its run's start), facing along `along`.
func _gate(name: String, at: Vector3, along: Vector3, gold: bool) -> void:
	var yaw := atan2(-along.x, -along.z) # (A gate faces -Z: turned to face along.)
	var c := cos(yaw)
	var s := sin(yaw)
	_out.append("\n[node name=\"%s\" type=\"Node3D\" parent=\"Runs/Run1/Gates\"]\ntransform = Transform3D(%s, 0, %s, 0, 1, 0, %s, 0, %s, %s, %s, %s)\nscript = ExtResource(\"24_gate\")%s" % [
			name, _num(c), _num(s), _num(-s), _num(c), _num(at.x), _num(at.y), _num(at.z), "\ngold = true" if gold else ""])


## How far apart two buildings are, seen from above (0 if they touch).
func _gap_between(a: Dictionary, b: Dictionary) -> float:
	var dx := maxf(0.0, maxf(a.x - (b.x + b.w), b.x - (a.x + a.w)))
	var dz := maxf(0.0, maxf(a.z - (b.z + b.d), b.z - (a.z + a.d)))
	return Vector2(dx, dz).length()


## The hub: the tower nearest the plaza. Its face looking toward the plaza
## gets the relic board (levels/relic_board.gd): a light per relic, lit when
## it's delivered, near the top where you can see it from all over.
func _write_relic_board(buildings: Array[Dictionary]) -> void:
	var towers := buildings.filter(func(b: Dictionary) -> bool: return b.tower)
	var hub: Dictionary = _nearest(towers, Vector2.ZERO)
	var middle := _middle(hub)
	var faces := [[Vector2(1, 0), hub.w / 2.0, hub.d], [Vector2(-1, 0), hub.w / 2.0, hub.d],
			[Vector2(0, 1), hub.d / 2.0, hub.w], [Vector2(0, -1), hub.d / 2.0, hub.w]]
	var best: Array = faces[0]
	for face: Array in faces:
		if (face[0] as Vector2).dot(-middle.normalized()) > (best[0] as Vector2).dot(-middle.normalized()):
			best = face
	var normal: Vector2 = best[0]
	var at: Vector2 = middle + normal * (best[1] + 0.05)
	var top: float = hub.storeys * STOREY - 3.0
	var yaw := atan2(-normal.x, -normal.y) # (The board faces -Z: turned to face out.)
	var c := cos(yaw)
	var s := sin(yaw)
	_out.append("\n[node name=\"RelicBoard\" type=\"Node3D\" parent=\".\"]\ntransform = Transform3D(%s, 0, %s, 0, 1, 0, %s, 0, %s, %s, %s, %s)\nscript = ExtResource(\"25_board\")\nwidth = %s" % [
			_num(c), _num(s), _num(-s), _num(c), _num(at.x), _num(top), _num(at.y), _num(best[2] - 4.0)])


## Wall ramps and quarter-pipes (see the constants above), on street-facing
## walls clear of fire escapes, drainpipes, sills and vents (and the pavement
## clutter keeps clear of them). Returns how many.
func _write_launchers(buildings: Array[Dictionary]) -> int:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([SEED, "launchers"])
	var candidates := buildings.filter(func(b: Dictionary) -> bool: return b.roof == "flat" and not b.tower)
	_shuffle(candidates, dice)
	var ramps := 0
	var pipes := 0
	var used := {}
	for b: Dictionary in candidates:
		var wants_ramp: bool = ramps < WALL_RAMPS and b.storeys >= WALL_RAMP_STOREYS.x and b.storeys <= WALL_RAMP_STOREYS.y
		var wants_pipe: bool = not wants_ramp and pipes < QUARTER_PIPES and b.storeys == QUARTER_PIPE_STOREYS
		if used.has(b.name) or not (wants_ramp or wants_pipe):
			continue
		for wall: Array in _walls(b):
			var along: Vector2 = wall[1]
			var out: Vector2 = wall[2]
			var middle: Vector2 = wall[0] + along * wall[3] / 2.0
			# A street out there (no building within 8 m), and the wall long enough.
			var street := middle + out * 8.0
			if wall[3] < WALL_RAMP.x + 6.0 or buildings.any(func(o: Dictionary) -> bool: return Rect2(o.x, o.z, o.w, o.d).has_point(street)):
				continue
			var footprint: Rect2
			var foot: Vector2
			var heading: Vector2 # (The way you run up it.)
			if wants_ramp:
				foot = middle - along * WALL_RAMP.x / 2.0 + out * 1.6
				heading = along
				footprint = Rect2(foot, Vector2.ZERO).expand(foot + along * WALL_RAMP.x).grow(1.6)
			else:
				foot = middle + out * 5.0
				heading = -out
				footprint = Rect2(foot, Vector2.ZERO).expand(middle).grow(1.6)
			if _fire_escapes.any(func(r: Rect2) -> bool: return r.grow(1.0).intersects(footprint)) \
					or _way_up_spots.any(func(spot: Vector2) -> bool: return footprint.grow(1.5).has_point(spot)):
				continue
			_fire_escapes.append(footprint) # (Keeps the pavement clutter clear.)
			var yaw := atan2(-heading.x, -heading.y)
			var c := cos(yaw)
			var s := sin(yaw)
			var shape := "length = %s\nheight = %s" % [_num(WALL_RAMP.x), _num(WALL_RAMP.y)] if wants_ramp else "curved = true"
			_out.append("\n[node name=\"%s_%s\" type=\"Node3D\" parent=\"Launchers\"]\ntransform = Transform3D(%s, 0, %s, 0, 1, 0, %s, 0, %s, %s, 0, %s)\nscript = ExtResource(\"26_launcher\")\n%s" % [
					b.name, "WallRamp" if wants_ramp else "QuarterPipe", _num(c), _num(s), _num(-s), _num(c), _num(foot.x), _num(foot.y), shape])
			used[b.name] = true
			if wants_ramp:
				ramps += 1
			else:
				pipes += 1
			break
	return ramps + pipes


## The glass tubes across the avenues and the road tunnel (see TUBE_IN and
## TUNNEL). Returns how many pipes.
func _write_pipes(buildings: Array[Dictionary]) -> int:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([SEED, "pipes"])
	var count := 0
	for across_x in [true, false]:
		var rows := range(BLOCKS)
		_shuffle(rows, dice)
		var done := false
		for i: int in rows:
			var near := Vector2i(AVENUE_AFTER, i) if across_x else Vector2i(i, AVENUE_AFTER)
			var far := near + (Vector2i.RIGHT if across_x else Vector2i.DOWN)
			var side := -AVENUE / 2.0
			var lane_start := _block_rect(near).position.y if across_x else _block_rect(near).position.x
			for attempt in 8:
				var lane := lane_start + dice.randf_range(RAIL_MARGIN + TUBE_RADIUS, BLOCK - RAIL_MARGIN - TUBE_RADIUS)
				var a := _facing(buildings, near, side, lane, across_x)
				var b := _facing(buildings, far, -side, lane, across_x)
				if a.is_empty() or b.is_empty() or a.storeys != b.storeys or a.storeys < TUBE_MIN_STOREYS:
					continue
				# Clear of the rails across here (and their run-ups).
				var from := Vector2(side - TUBE_IN, lane) if across_x else Vector2(lane, side - TUBE_IN)
				var to := Vector2(-side + TUBE_IN, lane) if across_x else Vector2(lane, -side + TUBE_IN)
				var footprint := Rect2(from, Vector2.ZERO).expand(to).grow(TUBE_RADIUS + 1.0)
				if _rail_paths.any(func(path: Array) -> bool: return footprint.grow(RAIL_CLEAR_WIDTH).intersects(Rect2(path[0], Vector2.ZERO).expand(path[1]))):
					continue
				var y: float = a.storeys * STOREY
				_write_pipe("Tube%s%d" % ["EW" if across_x else "NS", i], from, to, y, TUBE_RADIUS, true)
				# Keep the roofs' clutter out of the way in (and a run-up to it).
				var way := (to - from).normalized()
				_rail_paths.append([from - way * RAIL_RUN_UP, to + way * RAIL_RUN_UP])
				count += 1
				done = true
				break
			if done:
				break
	# The road tunnel: along the ring road, clear of anything on the pavement.
	var low := _starts[0] - _plaza_middle - EDGE
	var high := _starts[BLOCKS - 1] + BLOCK - _plaza_middle + EDGE
	for attempt in 20:
		var start_x := dice.randf_range(low + EDGE + 5.0, high - EDGE - 5.0 - TUNNEL.x)
		var z := high - EDGE / 2.0 # (The south side.)
		var from := Vector2(start_x, z)
		var to := Vector2(start_x + TUNNEL.x, z)
		var footprint := Rect2(from, Vector2.ZERO).expand(to).grow(TUNNEL.y + 1.0)
		if _fire_escapes.any(func(r: Rect2) -> bool: return r.intersects(footprint)):
			continue
		_write_pipe("RoadTunnel", from, to, 0.0, TUNNEL.y, false)
		_fire_escapes.append(footprint) # (Keeps the pavement clutter clear.)
		var middle := (from + to) / 2.0
		_relic("RelicTunnel", Vector3(middle.x, 2.0 * TUNNEL.y - 1.2, middle.y))
		count += 1
		break
	return count


## A pipe from `from` to `to` (seen from above), its floor at `y`.
func _write_pipe(name: String, from: Vector2, to: Vector2, y: float, radius: float, glass: bool) -> void:
	var heading := (to - from).normalized() # (A pipe runs along its -Z.)
	var yaw := atan2(-heading.x, -heading.y)
	var c := cos(yaw)
	var s := sin(yaw)
	_out.append("\n[node name=\"%s\" type=\"Node3D\" parent=\"Pipes\"]\ntransform = Transform3D(%s, 0, %s, 0, 1, 0, %s, 0, %s, %s, %s, %s)\nscript = ExtResource(\"27_pipe\")\nlength = %s\nradius = %s\nglass = %s" % [
			name, _num(c), _num(s), _num(-s), _num(c), _num(from.x), _num(y), _num(from.y), _num(from.distance_to(to)), _num(radius), "true" if glass else "false"])


## Which buildings are hollow inside (b.interior): every tower ("atrium": a
## climb up the inside to the roof), the WAREHOUSES biggest-enough 4-5 storey
## ones ("warehouse": one big hall, doors all round), and THROUGH_FLOORS of the
## 6+ storey ones ("through": a top floor you run through). Flat roofs only.
func _pick_interiors(buildings: Array[Dictionary]) -> void:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([SEED, "interiors"])
	var flat := buildings.filter(func(b: Dictionary) -> bool: return b.roof == "flat")
	for b: Dictionary in flat:
		if b.tower:
			b.interior = "atrium"
	var halls := flat.filter(func(b: Dictionary) -> bool:
			return not b.tower and b.storeys <= 5 and minf(b.w, b.d) >= WAREHOUSE_MIN)
	_shuffle(halls, dice)
	for b: Dictionary in halls.slice(0, WAREHOUSES):
		b.interior = "warehouse"
	var tall := flat.filter(func(b: Dictionary) -> bool:
			return not b.tower and b.storeys >= 6 and minf(b.w, b.d) >= THROUGH_MIN and b.interior == "")
	_shuffle(tall, dice)
	for b: Dictionary in tall.slice(0, THROUGH_FLOORS):
		b.interior = "through"


## Cuts `b`'s interior out of it (see _pick_interiors()) and fills it.
func _write_interior(b: Dictionary) -> void:
	var top: float = b.storeys * STOREY
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([SEED, b.name, "inside"])
	match b.interior:
		"atrium":
			_hole(b, "Room", 0.0, top - ROOF_SLAB, WALL) # (Down to the street: that's its floor.)
			_openings(b, "Door", 0.0, TOWER_DOOR, 1000.0, ["N"]) # (The climb starts along the north wall.)
			_write_platforms(b)
		"warehouse":
			_hole(b, "Room", 0.0, top - ROOF_SLAB, WALL)
			_openings(b, "Door", 0.0, WAREHOUSE_DOOR, 1000.0)
			_write_vaults(b, 0.0, 5, dice)
		"through":
			var floor_y: float = (b.storeys - 2) * STOREY
			_hole(b, "Room", floor_y, top - ROOF_SLAB, WALL)
			_openings(b, "Opening", floor_y, THROUGH_OPENING, THROUGH_SPACING)
			_write_vaults(b, floor_y, 3, dice)


## A room cut out of `b` from `bottom` to `top` (heights), `inset` in from its
## walls. (From the street, it goes a little below, to cut cleanly.)
func _hole(b: Dictionary, name: String, bottom: float, top: float, inset: float) -> void:
	if bottom <= 0.0:
		bottom = -0.5
	_cut(b, name, Vector3(b.x + b.w / 2.0, (bottom + top) / 2.0, b.z + b.d / 2.0),
			Vector3(b.w - 2.0 * inset, top - bottom, b.d - 2.0 * inset))


## Openings `size` (wide, tall) through each of `b`'s walls at height
## `bottom`: one in the middle of a wall, or more, about `spacing` apart.
func _openings(b: Dictionary, name: String, bottom: float, size: Vector2, spacing: float, skip: Array = []) -> void:
	var cut_y := bottom + size.y / 2.0
	var height := size.y
	if bottom <= 0.0: # (From the street: cut a little below.)
		cut_y = (size.y - 0.5) / 2.0
		height = size.y + 0.5
	var through := WALL * 3.0
	for side in ["N", "S", "W", "E"]:
		if side in skip:
			continue
		var along_x: bool = side in ["N", "S"]
		var length: float = b.w if along_x else b.d
		var count := clampi(int((length - size.x) / spacing) + 1, 1, 8)
		for i in count:
			# Its spot along the wall; a lone one slides along if the middle's taken.
			var tries: Array = [float(i + 1) / (count + 1)] if count > 1 else [0.5, 0.3, 0.7, 0.2, 0.8]
			for fraction: float in tries:
				var along: float = clampf(length * fraction, size.x / 2.0 + WALL, length - size.x / 2.0 - WALL)
				var at: Vector3
				match side:
					"N": at = Vector3(b.x + along, cut_y, b.z)
					"S": at = Vector3(b.x + along, cut_y, b.z + b.d)
					"W": at = Vector3(b.x, cut_y, b.z + along)
					"E": at = Vector3(b.x + b.w, cut_y, b.z + along)
				var cut_size := Vector3(size.x, height, through) if along_x else Vector3(through, height, size.x)
				var cut_rect := Rect2(at.x - cut_size.x / 2.0, at.z - cut_size.z / 2.0, cut_size.x, cut_size.z)
				if _fire_escapes.any(func(r: Rect2) -> bool: return r.grow(1.0).intersects(cut_rect)) \
						or _way_up_spots.any(func(spot: Vector2) -> bool: return cut_rect.grow(2.0).has_point(spot)):
					continue # (Not where a fire escape, drainpipe or sills come up: the way onto the roof.)
				_cut(b, "%s%s%d" % [name, side, i], at, cut_size)
				_doorways.append(cut_rect) # (The pavement keeps clear in front of it.)
				break


## A hole called `name` cut out of `b`, `size` big, centred at `at` (world).
func _cut(b: Dictionary, name: String, at: Vector3, size: Vector3) -> void:
	var local := at - Vector3(b.x + b.w / 2.0, b.storeys * STOREY / 2.0, b.z + b.d / 2.0)
	_out.append("\n[node name=\"%s\" type=\"CSGBox3D\" parent=\"Buildings/%s\"]\ntransform = %s\noperation = 2\nsize = Vector3(%s, %s, %s)\nmaterial = ExtResource(\"4_building\")" % [
			name, b.name, _at(local.x, local.y, local.z), _num(size.x), _num(size.y), _num(size.z)])


## A tower's climb: yellow platforms round its inside walls, each a storey
## above the last, like a fire escape on the inside, up to a hatch in the roof.
func _write_platforms(b: Dictionary) -> void:
	var x0: float = b.x + WALL
	var x1: float = b.x + b.w - WALL
	var z0: float = b.z + WALL
	var z1: float = b.z + b.d - WALL
	var depth := STEP_DEPTH
	# Round the walls (north, east, south, west), each starting past the last's corner.
	var walls := [[Vector2(x0 + depth, z0), Vector2.RIGHT, Vector2.DOWN, x1 - x0 - depth],
			[Vector2(x1, z0 + depth), Vector2.DOWN, Vector2.LEFT, z1 - z0 - depth],
			[Vector2(x1 - depth, z1), Vector2.LEFT, Vector2.UP, x1 - x0 - depth],
			[Vector2(x0, z1 - depth), Vector2.UP, Vector2.RIGHT, z1 - z0 - depth]]
	var slots := [] # [start, along, in, run]
	for wall: Array in walls:
		var count := maxi(1, int(wall[3] / PLATFORM_RUN))
		var run: float = wall[3] / count
		for i in count:
			slots.append([wall[0] + wall[1] * run * i, wall[1], wall[2], run])
	# Each a block a storey tall (so there's a face to grab, like a fire
	# escape's steps); the last comes up through a hatch in the roof, level with it.
	var top: float = b.storeys * STOREY
	var rect: Rect2
	var before: Rect2
	for k in range(1, b.storeys + 1):
		var slot: Array = slots[(k - 1) % slots.size()]
		before = rect
		rect = _slot_rect(slot, slot[3])
		_box("%s_Platform%d" % [b.name, k], "Interiors", rect.get_center().x, (k - 0.5) * STOREY, rect.get_center().y,
				rect.size.x, STOREY, rect.size.y, "7_climb")
	_cut(b, "Hatch", Vector3(rect.get_center().x, top - ROOF_SLAB / 2.0, rect.get_center().y),
			Vector3(rect.size.x, ROOF_SLAB + 1.0, rect.size.y))
	# And over the block before it, so there's room overhead to jump up onto the last.
	_cut(b, "HatchOver", Vector3(before.get_center().x, top - ROOF_SLAB / 2.0, before.get_center().y),
			Vector3(before.size.x, ROOF_SLAB + 1.0, before.size.y))


## The rectangle (from above) of a platform slot, `length` along it from its start.
func _slot_rect(slot: Array, length: float) -> Rect2:
	var start: Vector2 = slot[0]
	return Rect2(start, Vector2.ZERO).expand(start + (slot[1] as Vector2) * length + (slot[2] as Vector2) * STEP_DEPTH)


## A few red vault boxes about `b`'s room (its floor at `floor_y`), clear of
## the lanes from door to door through the middle.
func _write_vaults(b: Dictionary, floor_y: float, count: int, dice: RandomNumberGenerator) -> void:
	var middle := _middle(b)
	var placed: Array[Rect2] = []
	for i in count * 4:
		if placed.size() >= count:
			break
		var at := Vector2(dice.randf_range(b.x + 3.0, b.x + b.w - 3.0), dice.randf_range(b.z + 3.0, b.z + b.d - 3.0))
		if absf(at.x - middle.x) < 4.0 or absf(at.y - middle.y) < 4.0:
			continue # (The lanes through.)
		var size := Vector2(VAULT_BOX.x, VAULT_BOX.z) if dice.randf() < 0.5 else Vector2(VAULT_BOX.z, VAULT_BOX.x)
		var footprint := Rect2(at - size / 2.0, size)
		if placed.any(func(r: Rect2) -> bool: return r.grow(ITEM_SPACING).intersects(footprint)):
			continue
		placed.append(footprint)
		_box("%s_Vault%d" % [b.name, placed.size()], "Interiors", at.x, floor_y + VAULT_BOX.y / 2.0, at.y,
				size.x, VAULT_BOX.y, size.y, "9_vault")
