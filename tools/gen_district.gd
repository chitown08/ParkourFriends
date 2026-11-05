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

## Fire escapes (New York style, levels/stairs.gd): an iron deck along the
## wall at every storey, wrapping round a corner, and flights of stairs just
## outside the decks, climbing from the street along the walls (a landing
## between each) to a landing beside the roof. One per block, on its lowest
## building (alley steps take you up the rest). Towers don't get one.
const DECK := 1.5 ## How far the decks stick out of the wall...
const FLIGHT := Vector2(5.0, 1.2) ## ...each flight (run, width), outside them...
const LANDING := 1.5 ## ...with a landing this long between flights...
const TOP_LANDING := 2.5 ## ...and one this long at the top, level with the roof.
const FIRE_ESCAPE_END := 1.0 ## Flights keep this far from the wall's ends...
const AROUND_CORNER := 3.0 ## ...and start this far round a corner.

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

## Shapes (b.roof, see _pick_shapes()): of the rest (not towers, not a block's
## lowest, not a flat roof facing an avenue), some (STYLE_SHAPE_CHANCE) aren't
## plain boxes or sloped. Like sloped roofs, they get none of the flat roofs'
## things (fire escapes, rails, clutter...).
## "round": a rotunda (a cylinder) on a squarish lot, or rounded at both ends
## on a long one. Some rotundas have a dome.
const ROTUNDA_ASPECT := 1.4
const ROTUNDA_DOME_CHANCE := 0.5
## "domed": a shallow dome on the roof, its middle this much of its radius
## under the roof (so it's never steeper than you can run up), no bigger than
## DOME_MAX, leaving a ring of roof round it.
const DOME_SINK := 0.75
const DOME_MAX := 12.0
## "stepped": one or two tiers on top, each set back this far and two storeys tall.
const SETBACK := 4.0
const TIER_STOREYS := 2
## "courtyard": a yard down through the middle, the building a ring this deep
## round it, with an arch through to it from one side.
const COURT_RING := 8.0
const ARCH := Vector2(6.0, 5.0)
## "winged": an L, a corner cut out, this much of each side.
const NOTCH := 0.45
## "turned": turned this much (degrees, either way) in its lot, as big as fits.
const TURN_DEGREES := Vector2(12.0, 25.0)
## "leaning": tilted this much (degrees) toward one of its sides: its top
## slopes down that way (not enough to slide off: ReachMap.STAND_SLOPE) and that
## wall leans out over the street (not too far to scramble up: ReachMap.WALL_LEAN).
const LEAN_DEGREES := 6.0
## "curved": its long sides wave in and out (this far, at most), this many
## times along (a museum's curving walls).
const WAVE := 3.5
const WAVES := 1.5
## "cantilever": its top storeys stick out this far over a street (not an
## avenue, nor the road round the district: rails, tubes and the tunnel).
const CANTILEVER := 3.0
const CANTILEVER_STOREYS := 2
## Smallest lot (its shorter side) each shape needs.
const SHAPE_MIN := {"round": 14.0, "domed": 16.0, "stepped": 18.0, "winged": 18.0, "courtyard": 26.0,
		"turned": 14.0, "leaning": 16.0, "curved": 18.0, "cantilever": 14.0}
## Styles: the blocks in MODERN (the south-east quarter, past both avenues)
## are modern (and denser: each split in four lots), the rest the old town. Each style has its own shapes (dealt out
## in turn, see _pick_shapes()), and this much of its buildings that could
## have one get one.
const MODERN := Rect2i(3, 3, 2, 2)
const STYLE_SHAPES := {
	"old": ["round", "domed", "stepped", "winged", "courtyard"],
	"modern": ["turned", "leaning", "curved", "cantilever", "round"],
}
const STYLE_SHAPE_CHANCE := {"old": 0.5, "modern": 1.0}

## The museum (after the Canadian Museum of History: curved layers like rock
## laid down by a glacier, a great hall, copper domes) fills block MUSEUM_BLOCK
## (in the south-west quarter, facing the road round the district). Round its
## hall (a drum MUSEUM_HALL across and tall, with a flattened dome on top) are
## terraces, each an outline spun round the hall: from the street (or the
## terrace below) a slope you can run up curves over into a flat top. Each
## terrace: [name, which way it faces (degrees: 0 east, -90 south), how far
## round it goes (degrees), its foot (out from the hall's middle), the run of
## its slope in, how high it rises, its base].
const MUSEUM_BLOCK := Vector2i(1, 4)
const MUSEUM_MIDDLE := Vector2(30.0, 12.0) ## The hall's middle, in the block.
const MUSEUM_HALL := Vector2(7.0, 24.0) ## (Radius, height.)
const MUSEUM_DOME := Vector2(6.5, 4.0) ## (Radius across, up.)
const MUSEUM_DOME_SINK := 2.6 ## Its middle this far under the hall's top: never steeper than you can run up.
const MUSEUM_TERRACES := [
	["Gallery", -90.0, 76.0, 46.0, 16.6, 10.0, 0.0],
	["Upper", -90.0, 56.0, 26.0, 13.3, 8.0, 10.0],
	["WestWing", 180.0, 50.0, 26.0, 9.0, 5.0, 0.0],
	["EastWing", 0.0, 50.0, 26.0, 9.0, 5.0, 0.0],
]
## A terrace's slope is steepest at its foot, this much of the way up, then
## curves over into its top.
const MUSEUM_CURVE_FROM := 0.65

## Downtown: tall modern towers packed close, east of the old town across a
## boulevard (an avenue wide), DOWNTOWN_WIDTH across, over the old town's rows
## DOWNTOWN_ROWS (first, last). Each tower is TOWER_LOT wide each way (random),
## most an alley from the next (a running jump), STREET_CHANCE of them a street
## (a readied leap): you run it high up, roof to roof, rarely down in the
## street. They get taller toward the middle (DOWNTOWN_STOREYS: at the edge,
## in the middle; give or take DOWNTOWN_JITTER); the column by the boulevard
## stays under EDGE_STOREYS, and the spire, in the middle, is tallest of all
## (a terrace round it SPIRE_SETBACK wide, at SPIRE_BASE storeys). WING_CHANCE
## of the others have a lower part on one side (a wing, WING_PART of it,
## WING_DROP storeys under the top), with a drainpipe from it up to the top.
const DOWNTOWN_WIDTH := 150.0
const DOWNTOWN_ROWS := Vector2i(1, 3)
const TOWER_LOT := Vector2(16.0, 24.0)
const STREET_CHANCE := 0.3
const DOWNTOWN_STOREYS := Vector2i(14, 30)
const DOWNTOWN_JITTER := 3
const EDGE_STOREYS := 18
const SPIRE_STOREYS := 40
const SPIRE_BASE := 30
const SPIRE_SETBACK := 4.0
const WING_CHANCE := 0.35
const WING_PART := Vector2(0.35, 0.5)
const WING_DROP := Vector2i(3, 6)
## Ways round downtown:
## - yellow scaffolding (levels/scaffold.gd) up every tower from the street,
##   SCAFFOLD_WIDTH wide, on a wall facing a lower neighbour if it has one
##   (jump across from its roof and grab on);
## - blue grind rails (RAILS of them) from a roof across a gap down to one
##   RAIL_DROP storeys lower, from RAIL_IN in from the edge of each (high,
##   low), RAIL_ABOVE over them;
## - rope bridges (ROPE_BRIDGES) across the streets between towers the same height,
##   ROPE_WIDTH wide, sagging ROPE_SAG in the middle;
## - catch nets (levels/catch_net.gd; NETS of them, NET_WIDTH wide, out over
##   an alley nearly to the far side), NET_BELOW storeys under a roof;
## - covered walkways (WALKWAYS, WALKWAY_WIDTH wide) across alleys between
##   two towers' insides: a floor in each (two storeys tall, openings all
##   round) level with a lower roof next door, to jump in from.
## Nothing goes within GAP_CORNER of a wall's corner.
const SCAFFOLD_WIDTH := 3.0
const RAILS := 10
const RAIL_DROP := Vector2i(1, 3)
const RAIL_IN := Vector2(8.0, 6.0)
const RAIL_ABOVE := 0.6
const ROPE_BRIDGES := 5
const ROPE_WIDTH := 2.5
const ROPE_SAG := 0.5
const ROPE_SEGMENTS := 6
const ROPE_THICK := 0.15
const NETS := 8
const NET_WIDTH := 8.0
const NET_BELOW := 3
const WALKWAYS := 2
const WALKWAY_WIDTH := 4.0
## The floors they join have openings this big (wide, tall) all round: tall
## enough to jump in through at full height.
const MID_OPENING := Vector2(6.0, 6.0)
const GAP_CORNER := 3.0
## Downtown's roofs are busier than the old town's: things this close to the
## edge, and one per this many square metres (see _write_roof_clutter()).
const DOWNTOWN_EDGE_CLEAR := 3.5
const DOWNTOWN_AREA_PER_ITEM := 35.0


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
## counting the five above and downtown's (see _downtown_relic_spots(): on its
## tallest tops, in its walkways, two floating high). The generator tries a relic on spots all over (see
## _relic_candidates()), asks the reachability checker what each takes, and
## keeps this many of each (the rings round a relic say which).
const RELICS_WANTED := {1: 20, 2: 10, 3: 5, 4: 3}
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
const PLATFORM_DEPTH := 3.0 ## (How far each sticks out from the wall.)
const PLATFORM_RUN := 5.0 ## climb of blocks (at least this long) round the inside walls.

# Ways back up: every flat-roofed building without a fire escape (towers
# aside) gets a yellow drainpipe or a column of window sills up one wall, and
# every block an orange air vent on the pavement that blows you up to a roof.
const PIPE_CHANCE := 0.6 ## (The rest get sills.)
const WAY_UP_CORNER := 3.0 ## Kept at least this far from a wall's corners.
const SILL := Vector3(2.5, 0.3, 0.5) ## (Along the wall, thick, out from it.)
const VENT_OUT := 1.5 ## The vent's middle is this far out from the wall...
const VENT_LIFT := 1.0 ## ...and it blows you this far above the roof.
## Window ledges (levels/ledges.gd): stone buildings (b.facade "stone", in
## sandstone) have a row of ledges along every wall at every storey: catch one
## when you botch a jump, leap up them to the roof. Some of the old town's
## plain flat-roofed buildings (no insides to run through), and some of
## downtown's towers (no scaffolding needed); downtown's glass towers get a row
## every few storeys (somewhere to catch a fall, not a way up).
const STONE_CHANCE := 0.6
const STONE_TOWER_CHANCE := 0.4
const GLASS_LEDGE_EVERY := 4
const LEDGE_CLEAR := 2.0 ## Rows stop this far either side of a drainpipe or scaffolding.
## Lifts (levels/lift.gd): counterweight hoists up some tall old-town
## buildings (this many, this tall at least), and a window-washer's gondola up
## every glass tower downtown. Each keeps this much of its wall clear.
const HOISTS := 6
const HOIST_MIN_STOREYS := 6
const HOIST_CLEAR := 5.5
const GONDOLA_CLEAR := 4.0

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
## Downtown's relics' names (see _downtown_relic_spots()).
var _downtown_relics: Array[String] = []
## What's in downtown's gaps already, from above (see _gap_spot()); where its
## walkways' middles are (at the floor), and its rope bridges' (the lowest point).
var _gap_things: Array[Rect2] = []
var _walkway_spots: Array[Vector3] = []
var _rope_bridge_spots: Array[Vector3] = []
## What each relic takes (players), by name, once measured: written as its rings.
var _needed := {}
## Where the pillars stand (clutter keeps clear).
var _pillar_spots: Array[Vector2] = []
## Where drainpipes and sill columns go up walls (launchers keep clear).
var _way_up_spots: Array[Vector2] = []
## Where launchers stand against walls (ledges keep clear).
var _launcher_rects: Array[Rect2] = []
var _out := PackedStringArray()


func _init() -> void:
	var at := 0.0
	for i in BLOCKS:
		_starts.append(at)
		at += BLOCK + (AVENUE if i == AVENUE_AFTER else STREET)
	_plaza_middle = _starts[AVENUE_AFTER] + BLOCK + AVENUE / 2.0
	_generate.call_deferred() # (Once the scene tree is up: measuring needs it.)


## Writes the district a few times: first with a relic on every spot that might
## hold one, to ask the reachability checker what each takes; then with just
## the ones picked to make up RELICS_WANTED (again till that adds up); then
## once more, marking each with the players it takes (players_needed: its rings).
func _generate() -> void:
	var candidates := _relic_candidates(_all_buildings())
	_extra_relics = candidates
	_write_scene()
	var measured := _measure()
	# (Measured with every candidate there, some take fewer or more players than
	# they will alone: a pillar left out was a stepping stone. So pick, measure
	# what was picked, and pick again until it adds up.)
	for attempt in 6:
		_extra_relics = candidates
		_extra_relics = _pick_relics(measured)
		_write_scene()
		_needed = _measure()
		if _needed.keys().all(func(name: String) -> bool: return measured.get(name) == _needed[name]):
			break
		measured.merge(_needed, true)
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
	buildings.append_array(_downtown())
	_pick_shapes(buildings)
	_pick_interiors(buildings)
	_pick_facades(buildings)
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
	_launcher_rects.clear()
	var buildings := _all_buildings()

	_write_header()
	_write_ground()
	for b in buildings:
		match b.roof:
			"pitched": _write_terrace(b)
			"round": _write_round(b)
			"turned", "leaning", "curved": _write_modern(b)
			"museum": _write_museum(b)
			"downtown": _write_tower(b)
			_:
				_box(b.name, "Buildings", b.x + b.w / 2.0, b.storeys * STOREY / 2.0, b.z + b.d / 2.0,
						b.w, b.storeys * STOREY, b.d, "36_stone" if b.facade == "stone" else "4_building")
				_write_shape(b)
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
	var downtown := _write_downtown(buildings)
	var rails := 0
	for i in BLOCKS:
		rails += 1 if _write_rail(buildings, i, true) else 0
		rails += 1 if _write_rail(buildings, i, false) else 0
	var launchers := _write_launchers(buildings)
	var hoists := _write_hoists(buildings)
	var ledges := _write_facades(buildings) # (After the ways up and launchers: the rows keep clear of them.)
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
	var relics := 6 + _downtown_relics.size() + _write_extra_relics(buildings) # (The five fixed ones, the tunnel's and downtown's.)
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
	return "Wrote %s: %d buildings, %d towers, %d fire escapes, %d drainpipes or sills, %d walls of ledges, %d hoists, %d air vents, %d rails, %d launchers, %d pipes, %d interiors, %d relics, %d items, %d group runs, %d roof things, %d street things; downtown: %s (seed %d)" % [
			OUTPUT, buildings.size(), buildings.filter(func(b: Dictionary) -> bool: return b.tower).size(),
			staircases, ways_up, ledges, hoists, vents, rails, launchers, pipes, interiors, relics, items, runs, roof_things, street_things, downtown, SEED]


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
	if MODERN.has_point(Vector2i(bx, bz)):
		pattern = 0.75 # (Modern blocks are denser: four lots each.)
	if pattern < 0.15 or Vector2i(bx, bz) == MUSEUM_BLOCK:
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
				"w": r.size.x, "d": r.size.y, "storeys": storeys, "tower": tower, "block": Vector2i(bx, bz), "roof": "flat", "fire_escape": false, "interior": "", "dome": 0.0, "tiers": 0, "side": "", "shapeable": false,
				"style": "modern" if MODERN.has_point(Vector2i(bx, bz)) else "old", "turn": 0.0, "facade": ""})
	if Vector2i(bx, bz) == MUSEUM_BLOCK:
		buildings[0].merge({"name": "Museum", "roof": "museum", "tower": false, "storeys": ceili(MUSEUM_HALL.y / STOREY)}, true)
		return buildings
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
		# (Rails and tubes cross the avenues between flat roofs: those stay.)
		b.shapeable = b.roof != "flat" or not _on_avenue(b)
	return buildings



## Gives some of the buildings that could have one (b.shapeable: of each
## style, STYLE_SHAPE_CHANCE of them) a shape other than a box, from their
## style's STYLE_SHAPES, dealt out in turn (the next that fits the lot) so
## there's some of each; and works out each one's details: b.dome (the dome's
## radius, 0 for none), b.tiers, b.side (the arch's, the cut-out corner's, the
## side it leans or sticks out toward), b.turn (degrees).
func _pick_shapes(buildings: Array[Dictionary]) -> void:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([SEED, "shapes"])
	for style: String in STYLE_SHAPES:
		var shapeable := buildings.filter(func(b: Dictionary) -> bool: return b.shapeable and b.style == style)
		_shuffle(shapeable, dice)
		var kinds: Array = STYLE_SHAPES[style]
		var turn := 0
		for b: Dictionary in shapeable.slice(0, roundi(shapeable.size() * STYLE_SHAPE_CHANCE[style])):
			var shortest := minf(b.w, b.d)
			for i in kinds.size():
				var kind: String = kinds[(turn + i) % kinds.size()]
				if shortest >= SHAPE_MIN[kind] and (kind != "cantilever" or not _street_sides(b).is_empty()):
					b.roof = kind
					turn += i + 1
					break
			match b.roof:
				"round":
					if maxf(b.w, b.d) / shortest <= ROTUNDA_ASPECT and dice.randf() < ROTUNDA_DOME_CHANCE:
						b.dome = minf(_round_radius(b) - 1.5, DOME_MAX)
				"domed":
					b.dome = minf(shortest / 2.0 - 1.0, DOME_MAX)
				"stepped":
					b.tiers = 2 if shortest - 4.0 * SETBACK >= 10.0 else 1
				"courtyard":
					b.side = ["N", "S", "W", "E"][dice.randi() % 4]
				"winged":
					b.side = ["NW", "NE", "SW", "SE"][dice.randi() % 4]
				"turned":
					b.turn = dice.randf_range(TURN_DEGREES.x, TURN_DEGREES.y) * (1.0 if dice.randf() < 0.5 else -1.0)
				"leaning":
					b.side = ["N", "S", "W", "E"][dice.randi() % 4]
				"cantilever":
					var sides := _street_sides(b)
					b.side = sides[dice.randi() % sides.size()]


## The sides of `b` ("N", "S", "W", "E": N is toward -z, W toward -x) on the
## edge of its block facing a street between blocks (not an avenue, nor the
## road round the district).
func _street_sides(b: Dictionary) -> Array[String]:
	var area := _block_rect(b.block)
	var sides: Array[String] = []
	var inner := func(index: int, after: bool) -> bool: # (Is there a street, not the avenue, after/before block `index`?)
		var gap := index if after else index - 1
		return gap >= 0 and gap < BLOCKS - 1 and gap != AVENUE_AFTER
	if is_equal_approx(b.z, area.position.y) and inner.call(b.block.y, false):
		sides.append("N")
	if is_equal_approx(b.z + b.d, area.end.y) and inner.call(b.block.y, true):
		sides.append("S")
	if is_equal_approx(b.x, area.position.x) and inner.call(b.block.x, false):
		sides.append("W")
	if is_equal_approx(b.x + b.w, area.end.x) and inner.call(b.block.x, true):
		sides.append("E")
	return sides


## A round building's radius (or its rounded ends').
func _round_radius(b: Dictionary) -> float:
	return minf(b.w, b.d) / 2.0 - 0.5


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


## Adds a fire escape (see DECK) to the block's lowest building it fits on
## (trying the next lowest if not), starting from a street-facing wall and
## going on round a corner if it needs to. Returns false if none fits.
func _write_staircase(buildings: Array[Dictionary], block: Vector2i) -> bool:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([SEED, block.x, block.y, "stairs"])
	var area := _block_rect(block)
	var candidates := buildings.filter(func(b: Dictionary) -> bool: return b.block == block and b.roof == "flat" and not b.tower)
	# (Lowest first, but not one with insides if another will do: the decks
	# run the length of the walls, where its doors would go.)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.storeys < b.storeys if (a.interior == "") == (b.interior == "") else a.interior == "")
	for b: Dictionary in candidates:
		var options := [] # [walls round b, the one to start on, the flights]
		for clockwise in [true, false]:
			var walls := _walls_round(b, clockwise)
			for i in 4:
				var outside: Vector2 = walls[i][0] + walls[i][1] * walls[i][3] / 2.0 + walls[i][2]
				if area.has_point(outside):
					continue # (Start from the street.)
				var flights := _plan_flights(walls, i, b.storeys)
				if not flights.is_empty():
					options.append([walls, i, flights])
		if options.is_empty():
			continue
		var pick: Array = options[dice.randi() % options.size()]
		_write_fire_escape(b, pick[0], pick[2])
		b.fire_escape = true
		return true
	return false


## The walls of `b` in order round it (clockwise from above, or not), each
## [its first corner, the way along it, the way out of the building, its length].
func _walls_round(b: Dictionary, clockwise: bool) -> Array:
	var corners := [Vector2(b.x, b.z), Vector2(b.x + b.w, b.z), Vector2(b.x + b.w, b.z + b.d), Vector2(b.x, b.z + b.d)]
	if not clockwise:
		corners.reverse()
	var middle := _middle(b)
	var walls := []
	for i in 4:
		var from: Vector2 = corners[i]
		var to: Vector2 = corners[(i + 1) % 4]
		var along := (to - from).normalized()
		var out := Vector2(along.y, -along.x)
		if out.dot((from + to) / 2.0 - middle) < 0.0:
			out = -out
		walls.append([from, along, out, from.distance_to(to)])
	return walls


## Where a fire escape's flights go, one a storey from the street up to the
## roof, starting on wall `start` of `walls` (see _walls_round()) and going on
## to the next if they run out of room: [which wall, how far along it] each.
## Empty if they don't fit on two walls.
func _plan_flights(walls: Array, start: int, storeys: int) -> Array:
	var flights := []
	var wall := start
	var at := FIRE_ESCAPE_END
	while flights.size() < storeys:
		var last := flights.size() == storeys - 1
		if at + FLIGHT.x + (TOP_LANDING if last else LANDING) <= walls[wall][3] - FIRE_ESCAPE_END:
			flights.append([wall, at])
			at += FLIGHT.x + LANDING
			continue
		wall = (wall + 1) % 4
		if wall == (start + 2) % 4:
			return []
		at = AROUND_CORNER
	return flights


## The fire escape on `b`: its decks along every wall the `flights` are on,
## at every storey (each reaching round the corner to the next), and the
## flights themselves with their landings.
func _write_fire_escape(b: Dictionary, walls: Array, flights: Array) -> void:
	var used := {}
	for flight: Array in flights:
		used[flight[0]] = true
	b["escape_outs"] = used.keys().map(func(i: int) -> Vector2: return walls[i][2])
	for i: int in used:
		var wall: Array = walls[i]
		var corner: Vector2 = wall[0]
		var along: Vector2 = wall[1]
		var out: Vector2 = wall[2]
		var length: float = wall[3] + (DECK if used.has((i + 1) % 4) else 0.0) # (Round the corner to the next.)
		var middle := corner + along * length / 2.0 + out * DECK / 2.0
		var size := along.abs() * length + out.abs() * DECK
		for k in range(1, b.storeys):
			_box("%s_Deck%d_%d" % [b.name, i, k], "FireEscapes", middle.x, k * STOREY - 0.1, middle.y, size.x, 0.2, size.y, "35_iron")
		_fire_escapes.append(Rect2(corner, Vector2.ZERO).expand(corner + along * wall[3] + out * (DECK + FLIGHT.y)))
	for k in flights.size():
		var wall: Array = walls[flights[k][0]]
		var along: Vector2 = wall[1]
		var out: Vector2 = wall[2]
		var at: float = flights[k][1]
		var foot: Vector2 = wall[0] + along * at + out * (DECK + FLIGHT.y / 2.0)
		# Up along the wall; +Z out of it (or into it: then the decks are the other way).
		var x := Vector3(along.x, 0.0, along.y)
		var z := x.cross(Vector3.UP)
		var landing_in := (DECK + FLIGHT.y) / 2.0 * (1.0 if z.dot(Vector3(out.x, 0.0, out.y)) > 0.0 else -1.0)
		_out.append("\n[node name=\"%s_Flight%d\" type=\"Node3D\" parent=\"FireEscapes\"]\ntransform = Transform3D(%s, 0, %s, 0, 1, 0, %s, 0, %s, %s, %s, %s)\nscript = ExtResource(\"34_stairs\")\nrun = %s\nrise = %s\nwidth = %s\nlanding_in = %s" % [
				b.name, k + 1, _num(x.x), _num(z.x), _num(x.z), _num(z.z), _num(foot.x), _num(k * STOREY), _num(foot.y),
				_num(FLIGHT.x), _num(STOREY), _num(FLIGHT.y), _num(landing_in)])
		# A landing after it, outside the deck; at the top, one across both, by the roof.
		var last := k == flights.size() - 1
		var length := TOP_LANDING if last else LANDING
		var depth := DECK + FLIGHT.y if last else FLIGHT.y
		var middle: Vector2 = wall[0] + along * (at + FLIGHT.x + length / 2.0) + out * ((DECK + FLIGHT.y) - depth / 2.0)
		var size := along.abs() * length + out.abs() * depth
		_box("%s_%s" % [b.name, "Top" if last else "Landing%d" % (k + 1)], "FireEscapes", middle.x, (k + 1) * STOREY - 0.1, middle.y,
				size.x, 0.2, size.y, "35_iron")


## A drainpipe or a column of window sills up one wall of `b` (flat roofs
## without a fire escape only, towers aside). Returns false if it gets none.
func _write_way_up(b: Dictionary) -> bool:
	if b.tower or b.roof != "flat" or b.fire_escape:
		return false
	if b.facade == "stone":
		return true # (Its ledges: see _write_facades().)
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
## up yet), and so do sloped roofs; downtown's get them on their top and on a
## wing, some of the vaults long (ducts). Returns how many it placed.
func _write_roof_clutter(b: Dictionary) -> int:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([SEED, b.name, "roof"])
	if b.roof == "downtown":
		var count := _clutter_on(b.name, b.upper, b.storeys * STOREY, dice, [], true)
		if b.side != "":
			count += _clutter_on(b.name + "Wing", _wing(b), b.base * STOREY, dice, [], true)
		return count
	if b.tower or b.roof != "flat":
		return 0
	return _clutter_on(b.name, Rect2(b.x, b.z, b.w, b.d), b.storeys * STOREY, dice, b.get("keep_clear", []))


## A downtown tower's wing (the part of it outside its top part), from above.
static func _wing(b: Dictionary) -> Rect2:
	var upper: Rect2 = b.upper
	match b.side:
		"N": return Rect2(b.x, b.z, b.w, upper.position.y - b.z)
		"S": return Rect2(b.x, upper.end.y, b.w, b.z + b.d - upper.end.y)
		"W": return Rect2(b.x, b.z, upper.position.x - b.x, b.d)
	return Rect2(upper.end.x, b.z, b.x + b.w - upper.end.x, b.d)


## Clutter (see _write_roof_clutter()) on a roof `area` (from above) at height
## `roof`, called after `name`, kept off `keep_clear`; `busy` (downtown): closer
## to the edges, more of them, some vaults long (ducts).
func _clutter_on(name: String, area: Rect2, roof: float, dice: RandomNumberGenerator, keep_clear: Array, busy := false) -> int:
	var inner := area.grow(-(DOWNTOWN_EDGE_CLEAR if busy else ROOF_EDGE_CLEAR))
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return 0
	var wanted := mini(int(inner.get_area() / (DOWNTOWN_AREA_PER_ITEM if busy else ROOF_AREA_PER_ITEM)) + dice.randi_range(0, 1), MAX_ROOF_ITEMS)
	var placed: Array[Rect2] = []
	for attempt in wanted * 6:
		if placed.size() >= wanted:
			break
		var hut := dice.randf() < 0.3
		var size := (HUT if hut else VAULT_BOX) * Vector3(dice.randf_range(0.8, 1.2), dice.randf_range(0.9, 1.1), dice.randf_range(0.8, 1.2))
		if busy and not hut and dice.randf() < 0.5:
			size.x *= 2.5 # (A duct: still only its depth to vault.)
		if dice.randf() < 0.5:
			size = Vector3(size.z, size.y, size.x) # Turned the other way.
		var middle := Vector2(dice.randf_range(inner.position.x, inner.end.x), dice.randf_range(inner.position.y, inner.end.y))
		var footprint := Rect2(middle - Vector2(size.x, size.z) / 2.0, Vector2(size.x, size.z))
		if not inner.encloses(footprint) or not _clear_of(footprint, placed) \
				or keep_clear.any(func(r: Rect2) -> bool: return r.intersects(footprint)):
			continue
		placed.append(footprint)
		_box("%s_%s%d" % [name, "Hut" if hut else "Vault", placed.size()], "RoofClutter",
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


## What's added to (or cut out of) plain box `b` for its shape (see _pick_shape()).
func _write_shape(b: Dictionary) -> void:
	if b.roof == "sawtooth":
		_write_sawtooth(b)
	if b.roof in ["flat", "sawtooth"]:
		return
	_mark_shape(b)
	var height: float = b.storeys * STOREY
	var middle := _middle(b)
	var centre := Vector3(middle.x, height / 2.0, middle.y)
	match b.roof:
		"domed":
			_write_dome(b)
		"stepped":
			var tier := TIER_STOREYS * STOREY
			for k in range(1, b.tiers + 1):
				_shape_node("CSGBox3D", "Tier%d" % k, "Buildings/" + b.name, Vector3(0, height / 2.0 + (k - 0.5) * tier, 0),
						"size = Vector3(%s, %s, %s)" % [_num(b.w - 2.0 * SETBACK * k), _num(tier), _num(b.d - 2.0 * SETBACK * k)])
		"courtyard":
			_cut(b, "Courtyard", centre, Vector3(b.w - 2.0 * COURT_RING, height + 2.0, b.d - 2.0 * COURT_RING))
			# The arch: from the street right through the ring into the yard.
			var at: Vector2
			match b.side:
				"N": at = Vector2(middle.x, b.z + COURT_RING / 2.0)
				"S": at = Vector2(middle.x, b.z + b.d - COURT_RING / 2.0)
				"W": at = Vector2(b.x + COURT_RING / 2.0, middle.y)
				"E": at = Vector2(b.x + b.w - COURT_RING / 2.0, middle.y)
			var size := Vector2(ARCH.x, COURT_RING + 1.0) if b.side in ["N", "S"] else Vector2(COURT_RING + 1.0, ARCH.x)
			_cut(b, "Arch" + b.side, Vector3(at.x, (ARCH.y - 0.5) / 2.0, at.y), Vector3(size.x, ARCH.y + 0.5, size.y))
			_doorways.append(Rect2(at - size / 2.0, size)) # (The pavement keeps clear in front of it.)
		"winged":
			# The corner cut out (from just outside the walls, to cut cleanly).
			var cut := Vector2(b.w * NOTCH + 1.0, b.d * NOTCH + 1.0)
			var x: float = b.x - 1.0 + cut.x / 2.0 if "W" in b.side else b.x + b.w + 1.0 - cut.x / 2.0
			var z: float = b.z - 1.0 + cut.y / 2.0 if "N" in b.side else b.z + b.d + 1.0 - cut.y / 2.0
			_cut(b, "Notch", Vector3(x, height / 2.0, z), Vector3(cut.x, height + 2.0, cut.y))
		"cantilever":
			# Its top storeys, from 1 m in from its wall to CANTILEVER out past it.
			var drop := CANTILEVER_STOREYS * STOREY
			var out: Vector3 = {"N": Vector3.FORWARD, "S": Vector3.BACK, "W": Vector3.LEFT, "E": Vector3.RIGHT}[b.side]
			var along_x := absf(out.x) > 0.5
			var size := Vector3(CANTILEVER + 1.0, drop, b.d) if along_x else Vector3(b.w, drop, CANTILEVER + 1.0)
			var depth: float = b.w if along_x else b.d
			_shape_node("CSGBox3D", "Overhang", "Buildings/" + b.name, out * (depth / 2.0 + CANTILEVER / 2.0 - 0.5) + Vector3(0, height / 2.0 - drop / 2.0, 0),
					"size = Vector3(%s, %s, %s)" % [_num(size.x), _num(size.y), _num(size.z)])


## A round building (see ROTUNDA_ASPECT): a cylinder on a squarish lot (maybe
## with a dome), or on a long one a box with a half-round end each way.
func _write_round(b: Dictionary) -> void:
	var height: float = b.storeys * STOREY
	var middle := _middle(b)
	var centre := Vector3(middle.x, height / 2.0, middle.y)
	var r := _round_radius(b)
	var cylinder := "radius = %s\nheight = %s\nsides = 48" % [_num(r), _num(height)]
	var long := maxf(b.w, b.d)
	if long / minf(b.w, b.d) <= ROTUNDA_ASPECT:
		_shape_node("CSGCylinder3D", b.name, "Buildings", centre, cylinder, true)
		_mark_shape(b)
		if b.dome > 0.0:
			_write_dome(b)
		return
	var along := Vector3.RIGHT if b.w > b.d else Vector3.BACK
	var size := along * (long - 2.0 * r) + (Vector3.ONE - along - Vector3.UP) * 2.0 * r + Vector3.UP * height
	_box(b.name, "Buildings", centre.x, centre.y, centre.z, size.x, size.y, size.z, "4_building")
	_mark_shape(b)
	for end in [-1.0, 1.0]:
		_shape_node("CSGCylinder3D", "End%d" % (1 if end < 0.0 else 2), "Buildings/" + b.name, along * end * (long / 2.0 - r), cylinder)


## A shallow dome (radius b.dome) in the middle of `b`'s roof, its middle
## sunk DOME_SINK of that under it.
func _write_dome(b: Dictionary) -> void:
	var height: float = b.storeys * STOREY
	_shape_node("CSGSphere3D", "Dome", "Buildings/" + b.name, Vector3(0, height / 2.0 - DOME_SINK * b.dome, 0),
			"radius = %s\nradial_segments = 48\nrings = 24" % _num(b.dome))


## A modern building that isn't square in its lot (see _pick_shapes()):
## - "turned" in it (b.turn degrees), as big as fits;
## - "leaning" LEAN_DEGREES toward its b.side (its foot sunk into the ground,
##   narrowed so its top still stays over its lot);
## - "curved": an outline pushed up, its long sides waving in and out.
func _write_modern(b: Dictionary) -> void:
	var height: float = b.storeys * STOREY
	var middle := _middle(b)
	match b.roof:
		"turned":
			var angle := deg_to_rad(b.turn)
			var room := Vector2(b.w - 1.0, b.d - 1.0)
			var c := cos(absf(angle))
			var s := sin(absf(angle))
			var fit := minf(room.x / (room.x * c + room.y * s), room.y / (room.x * s + room.y * c))
			_node("CSGBox3D", b.name, "Buildings", Transform3D(Basis(Vector3.UP, angle), Vector3(middle.x, height / 2.0, middle.y)),
					"size = Vector3(%s, %s, %s)" % [_num(room.x * fit), _num(height), _num(room.y * fit)])
		"leaning":
			var lean := _leaning(b)
			var size: Vector3 = lean.size
			_node("CSGBox3D", b.name, "Buildings", lean.transform, "size = Vector3(%s, %s, %s)" % [_num(size.x), _num(size.y), _num(size.z)])
		"curved":
			var along_x: bool = b.w >= b.d
			var length: float = (b.w if along_x else b.d) - 1.0
			var breadth: float = (b.d if along_x else b.w) - 1.0
			var dice := RandomNumberGenerator.new()
			dice.seed = hash([SEED, b.name, "curved"])
			var outline := PackedStringArray()
			var points := 24
			for side in [1.0, -1.0]:
				var phase := dice.randf_range(0.0, TAU)
				for i in points + 1:
					var t := float(i) / points if side > 0.0 else 1.0 - float(i) / points
					var inward := WAVE * (0.5 + 0.5 * sin(TAU * WAVES * t + phase))
					var a := (t - 0.5) * length
					var c: float = side * (breadth / 2.0 - inward)
					var p := Vector2(a, c) if along_x else Vector2(c, a)
					outline.append("%s, %s" % [_num(p.x), _num(p.y)])
			# (Its outline's x, y are the world's x, z; it's pushed out along its -z: up.)
			_node("CSGPolygon3D", b.name, "Buildings", Transform3D(Basis(Vector3.RIGHT, Vector3.BACK, Vector3.DOWN), Vector3(middle.x, 0.0, middle.y)),
					"polygon = PackedVector2Array(%s)\ndepth = %s" % [", ".join(outline), _num(height)])
	_mark_shape(b)


## A leaning building's box: {transform, size, top (the middle of its top)}.
## It leans LEAN_DEGREES toward b.side, pivoting under the ground (its foot
## sunk all along), as deep that way as lets it span its lot from the foot of
## its back wall to the top of its front one.
func _leaning(b: Dictionary) -> Dictionary:
	var height: float = b.storeys * STOREY
	var middle := _middle(b)
	var lean := deg_to_rad(LEAN_DEGREES)
	var toward: Vector3 = {"N": Vector3.FORWARD, "S": Vector3.BACK, "W": Vector3.LEFT, "E": Vector3.RIGHT}[b.side]
	var along_x := absf(toward.x) > 0.5
	var depth: float = (b.w if along_x else b.d) - 1.0 # (Its lot, the way it leans.)
	var across: float = (b.d if along_x else b.w) - 1.0
	var thick := (depth - height * tan(lean)) * cos(lean)
	var sink := thick / 2.0 * sin(lean) + 0.5
	var length := (height + sink) / cos(lean)
	var axis := Vector3.UP.cross(toward)
	var up := Vector3.UP.rotated(axis, lean)
	var pivot := Vector3(middle.x, -sink, middle.y) + toward * (-depth / 2.0 + thick / 2.0 / cos(lean) - sink * tan(lean))
	return {"transform": Transform3D(Basis(axis, lean), pivot + up * length / 2.0),
			"size": Vector3(thick, length, across) if along_x else Vector3(across, length, thick),
			"top": pivot + up * length}


## The museum (see MUSEUM_TERRACES): its hall (the building itself, a drum),
## the dome on it and the terraces round it (added into it).
func _write_museum(b: Dictionary) -> void:
	var hall := _museum_middle(b)
	_node("CSGCylinder3D", b.name, "Buildings", Transform3D(Basis.IDENTITY, Vector3(hall.x, MUSEUM_HALL.y / 2.0, hall.y)),
			"radius = %s\nheight = %s\nsides = 48" % [_num(MUSEUM_HALL.x), _num(MUSEUM_HALL.y)])
	_mark_shape(b)
	var inside: String = "Buildings/" + b.name
	_out.append("\n[node name=\"Dome\" type=\"CSGSphere3D\" parent=\"%s\"]\ntransform = Transform3D(1, 0, 0, 0, %s, 0, 0, 0, 1, 0, %s, 0)\nradius = %s\nradial_segments = 48\nrings = 24\nmaterial = ExtResource(\"4_building\")" % [
			inside, _num(MUSEUM_DOME.y / MUSEUM_DOME.x), _num(MUSEUM_HALL.y / 2.0 - MUSEUM_DOME_SINK), _num(MUSEUM_DOME.x)])
	for terrace: Array in MUSEUM_TERRACES:
		# Spun from its x toward its -z: turned so it's centred on the way it faces.
		var turn := deg_to_rad(float(terrace[1]) - float(terrace[2]) / 2.0)
		var points := PackedStringArray()
		for p in _terrace_outline(terrace):
			points.append("%s, %s" % [_num(p.x), _num(p.y)])
		var basis := Basis(Vector3.UP, turn)
		var numbers := PackedStringArray()
		for value: float in [basis.x.x, basis.y.x, basis.z.x, basis.x.y, basis.y.y, basis.z.y, basis.x.z, basis.y.z, basis.z.z]:
			numbers.append(str(snappedf(value, 0.0001)))
		_out.append("\n[node name=\"%s\" type=\"CSGPolygon3D\" parent=\"%s\"]\ntransform = Transform3D(%s, 0, %s, 0)\npolygon = PackedVector2Array(%s)\nmode = 1\nspin_degrees = %s\nspin_sides = %d\nmaterial = ExtResource(\"4_building\")" % [
				terrace[0], inside, ", ".join(numbers), _num(-MUSEUM_HALL.y / 2.0), ", ".join(points), _num(terrace[2]), ceili(terrace[2] / 3.0)])


## The museum hall's middle (x, z).
func _museum_middle(b: Dictionary) -> Vector2:
	return Vector2(b.x, b.z) + MUSEUM_MIDDLE


## A terrace's outline, side-on (x: out from the hall's middle, y: up): its
## slope from its foot, steepest there (no steeper than a slope you can run
## up), curving over into its top from MUSEUM_CURVE_FROM of the way in, then
## flat in to the hall.
func _terrace_outline(terrace: Array) -> PackedVector2Array:
	var foot: float = terrace[3]
	var run: float = terrace[4]
	var rise: float = terrace[5]
	var base: float = terrace[6]
	var bend := MUSEUM_CURVE_FROM
	var whole := bend + (1.0 - bend) / 2.0 # (How far up it'd get at its steepest all the way: its shape, rise 1.)
	# (Into the hall a little, and on a terrace below, down into it.)
	var bottom := base - 0.5 if base > 0.0 else 0.0
	var outline := PackedVector2Array([Vector2(MUSEUM_HALL.x - 1.0, bottom), Vector2(foot, bottom)])
	if bottom < base:
		outline.append(Vector2(foot, base))
	var steps := 16
	for i in range(1, steps + 1):
		var t := float(i) / steps
		var up := t if t <= bend else bend + ((1.0 - bend) * (1.0 - bend) - (1.0 - t) * (1.0 - t)) / (2.0 * (1.0 - bend))
		outline.append(Vector2(foot - t * run, base + rise * up / whole))
	outline.append(Vector2(MUSEUM_HALL.x - 1.0, base + rise))
	return outline


## The steepest a museum terrace's slope gets (degrees).
static func terrace_steepest(terrace: Array) -> float:
	var whole := MUSEUM_CURVE_FROM + (1.0 - MUSEUM_CURVE_FROM) / 2.0
	return rad_to_deg(atan(terrace[5] / (terrace[4] * whole)))


## A CSG shape node on its own (with collision, unless not `collision`), anywhere and turned any way.
func _node(type: String, name: String, parent: String, transform: Transform3D, properties: String, material := "4_building", collision := true) -> void:
	var r := transform.basis
	var o := transform.origin
	var numbers := PackedStringArray()
	for value: float in [r.x.x, r.y.x, r.z.x, r.x.y, r.y.y, r.z.y, r.x.z, r.y.z, r.z.z]:
		numbers.append(str(snappedf(value, 0.0001)))
	for value: float in [o.x, o.y, o.z]:
		numbers.append(_num(value))
	_out.append("\n[node name=\"%s\" type=\"%s\" parent=\"%s\"]\ntransform = Transform3D(%s)\n%s%s\nmaterial = ExtResource(\"%s\")" % [
			name, type, parent, ", ".join(numbers), "use_collision = true\n" if collision else "", properties, material])


## A CSG shape node (`type`) at `at` (in its parent), with `properties`; on
## its own (`solid`: with collision), or added into its parent.
func _shape_node(type: String, name: String, parent: String, at: Vector3, properties: String, solid := false) -> void:
	_out.append("\n[node name=\"%s\" type=\"%s\" parent=\"%s\"]\ntransform = %s\n%s%s\nmaterial = ExtResource(\"4_building\")" % [
			name, type, parent, _at(at.x, at.y, at.z), "use_collision = true\n" if solid else "", properties])


## Notes `b`'s shape on the building just written (tests tell them apart by it).
func _mark_shape(b: Dictionary) -> void:
	_out[_out.size() - 1] += "\nmetadata/shape = \"%s\"" % b.roof


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


# --- Downtown (see DOWNTOWN_WIDTH) ---------------------------------------------

## Where downtown is, from above: across the boulevard from the old town.
func _downtown_rect() -> Rect2:
	var west := _starts[BLOCKS - 1] + BLOCK + AVENUE - _plaza_middle
	var north := _starts[DOWNTOWN_ROWS.x] - _plaza_middle
	var south := _starts[DOWNTOWN_ROWS.y] + BLOCK - _plaza_middle
	return Rect2(west, north, DOWNTOWN_WIDTH, south - north)


## Downtown's towers: like the old town's buildings (b.roof "downtown"), and
## b.lot (its column and row), b.base (the storeys of its lower part: a wing,
## or the spire's terrace; b.storeys if it has none), b.upper (its top part,
## from above: all of it if it has no lower part), b.side (a wing's side).
func _downtown() -> Array[Dictionary]:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([SEED, "downtown"])
	var area := _downtown_rect()
	var columns := _lots(area.position.x, area.size.x, dice)
	var rows := _lots(area.position.y, area.size.y, dice)
	var middle := area.get_center()
	var far := (area.size / 2.0).length()
	var towers: Array[Dictionary] = []
	var spire: Dictionary = {}
	for i in columns.size():
		for j in rows.size():
			var lot := Rect2(columns[i][0], rows[j][0], columns[i][1], rows[j][1])
			var inward := 1.0 - lot.get_center().distance_to(middle) / far
			var storeys := roundi(lerpf(DOWNTOWN_STOREYS.x, DOWNTOWN_STOREYS.y, inward)) + dice.randi_range(-DOWNTOWN_JITTER, DOWNTOWN_JITTER)
			if i == 0:
				storeys = mini(storeys, EDGE_STOREYS)
			var b := {"name": "Tower%d_%d" % [i, j], "x": lot.position.x, "z": lot.position.y, "w": lot.size.x, "d": lot.size.y,
					"storeys": storeys, "tower": false, "block": Vector2i(-1, -1), "roof": "downtown", "fire_escape": false,
					"interior": "", "dome": 0.0, "tiers": 0, "side": "", "shapeable": false, "style": "downtown", "turn": 0.0, "facade": "",
					"lot": Vector2i(i, j), "base": storeys, "upper": lot}
			if dice.randf() < WING_CHANCE:
				b.side = ["N", "S", "W", "E"][dice.randi() % 4]
				b.base = storeys - dice.randi_range(WING_DROP.x, WING_DROP.y)
				b.upper = _cut_off(lot, b.side, dice.randf_range(WING_PART.x, WING_PART.y))
			towers.append(b)
			if spire.is_empty() or lot.get_center().distance_to(middle) < _middle(spire).distance_to(middle):
				spire = b
	spire.merge({"name": "Spire", "storeys": SPIRE_STOREYS, "base": SPIRE_BASE, "side": "",
			"upper": Rect2(spire.x, spire.z, spire.w, spire.d).grow(-SPIRE_SETBACK)}, true)
	return towers


## Lots along one side of downtown: [start, length] each, TOWER_LOT long, an
## alley or a street apart, as many as fit in `length` from `start`.
func _lots(start: float, length: float, dice: RandomNumberGenerator) -> Array:
	var lots := []
	var at := start
	while true:
		var size := dice.randf_range(TOWER_LOT.x, TOWER_LOT.y)
		if at + size > start + length:
			break
		lots.append([at, size])
		at += size + (STREET if dice.randf() < STREET_CHANCE else ALLEY)
	return lots


## `r` less `part` (0..1) of it on its `side` (N is toward -z, W toward -x).
static func _cut_off(r: Rect2, side: String, part: float) -> Rect2:
	match side:
		"N": return Rect2(r.position.x, r.position.y + r.size.y * part, r.size.x, r.size.y * (1.0 - part))
		"S": return Rect2(r.position, Vector2(r.size.x, r.size.y * (1.0 - part)))
		"W": return Rect2(r.position.x + r.size.x * part, r.position.y, r.size.x * (1.0 - part), r.size.y)
	return Rect2(r.position, Vector2(r.size.x * (1.0 - part), r.size.y))


## A downtown tower: its lower part (all of it, up to b.base), and its top part
## (b.upper, from there up to b.storeys) added into it, "<name>/Upper".
func _write_tower(b: Dictionary) -> void:
	var base: float = b.base * STOREY
	_box(b.name, "Buildings", b.x + b.w / 2.0, base / 2.0, b.z + b.d / 2.0, b.w, base, b.d, _tower_material(b))
	if b.base < b.storeys:
		var upper: Rect2 = b.upper
		var top: float = b.storeys * STOREY
		var at := upper.get_center() - _middle(b)
		_box("Upper", "Buildings/" + b.name, at.x, top / 2.0, at.y, upper.size.x, top - base, upper.size.y, _tower_material(b), false)


## How many storeys tall tower `b` is at `p` (from above): its top part's, its
## lower part's, or -1 if it's not there.
static func _storeys_at(b: Dictionary, p: Vector2) -> int:
	if (b.upper as Rect2).has_point(p):
		return b.storeys
	return b.base if Rect2(b.x, b.z, b.w, b.d).has_point(p) else -1


## The gaps between downtown's towers, an alley or a street wide: {a, b (the
## towers either side: a to the west or north), across_x (b is east of a),
## from, to (a's wall and b's, along the way across), span (where they face
## each other, along the walls: from, to)}.
func _downtown_gaps(towers: Array) -> Array:
	var at := {}
	for b: Dictionary in towers:
		at[b.lot] = b
	var gaps := []
	for b: Dictionary in towers:
		for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			var other: Dictionary = at.get(b.lot + step, {})
			if other.is_empty():
				continue
			var across_x := step.x == 1
			gaps.append({"a": b, "b": other, "across_x": across_x,
					"from": b.x + b.w if across_x else b.z + b.d, "to": other.x if across_x else other.z,
					"span": Vector2(b.z, b.z + b.d) if across_x else Vector2(b.x, b.x + b.w)})
	return gaps


## A point in (or beside) `gap`: `across` along the way across it, `along` along its walls.
static func _gap_point(gap: Dictionary, across: float, along: float) -> Vector2:
	return Vector2(across, along) if gap.across_x else Vector2(along, across)


## The strip across `gap` (wall to wall), `half` either side of `along`.
static func _gap_strip(gap: Dictionary, along: float, half: float) -> Rect2:
	return Rect2(_gap_point(gap, gap.from, along - half), Vector2.ZERO).expand(_gap_point(gap, gap.to, along + half))


## How many storeys tall the wall of `gap`'s tower `side` ("a" or "b") is at `along`.
static func _wall_storeys(gap: Dictionary, side: String, along: float) -> int:
	return _storeys_at(gap[side], _gap_point(gap, gap.from - 0.5 if side == "a" else gap.to + 0.5, along))


## Whether that wall is the same height all along from `along - half` to `along + half`.
static func _wall_level(gap: Dictionary, side: String, along: float, half: float) -> bool:
	var storeys := _wall_storeys(gap, side, along)
	return _wall_storeys(gap, side, along - half) == storeys and _wall_storeys(gap, side, along + half) == storeys


## Somewhere along `gap` for something `half` wide each way (in from the
## corners, clear of what's in the gap already) that `fits` (called with the
## spot along it); NAN if nowhere does.
func _gap_spot(gap: Dictionary, half: float, dice: RandomNumberGenerator, fits: Callable) -> float:
	var span: Vector2 = gap.span
	var low := span.x + GAP_CORNER + half
	var high := span.y - GAP_CORNER - half
	if low > high:
		return NAN
	for attempt in 12:
		var along := dice.randf_range(low, high)
		var strip := _gap_strip(gap, along, half)
		if _gap_things.any(func(r: Rect2) -> bool: return r.grow(1.0).intersects(strip)) or not fits.call(along):
			continue
		return along
	return NAN


## A thing against a wall at `at`, its +Z pointing `out` of the wall (from above).
func _wall_node(name: String, parent: String, script: String, at: Vector3, out: Vector2, properties: String) -> void:
	_out.append("\n[node name=\"%s\" type=\"Node3D\" parent=\"%s\"]\ntransform = Transform3D(%s, 0, %s, 0, 1, 0, %s, 0, %s, %s, %s, %s)\nscript = ExtResource(\"%s\")\n%s" % [
			name, parent, _num(out.y), _num(out.x), _num(-out.x), _num(out.y), _num(at.x), _num(at.y), _num(at.z), script, properties])


## Downtown's ways round (see SCAFFOLD_WIDTH). Says how many of each.
func _write_downtown(buildings: Array[Dictionary]) -> String:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([SEED, "downtown ways"])
	var towers := buildings.filter(func(b: Dictionary) -> bool: return b.roof == "downtown")
	var gaps := _downtown_gaps(towers)
	_gap_things.clear()
	_walkway_spots.clear()
	_rope_bridge_spots.clear()
	var pipes := 0
	for b: Dictionary in towers:
		pipes += 1 if _write_tower_pipe(b, dice) else 0
	var walkways := _write_walkways(gaps, dice) # (First: they need the right towers.)
	var scaffolds := 0
	for b: Dictionary in towers:
		scaffolds += 1 if _write_scaffold(b, gaps, dice) else 0
	var rails := _write_downtown_rails(gaps, dice)
	var bridges := _write_rope_bridges(gaps, dice)
	var nets := _write_nets(gaps, dice)
	var gondola_dice := RandomNumberGenerator.new() # (Its own: the rest stays put.)
	gondola_dice.seed = hash([SEED, "gondolas"])
	var gondolas := 0
	for b: Dictionary in towers:
		gondolas += 1 if _write_gondola(b, gaps, gondola_dice) else 0
	return "%d towers, %d scaffolds, %d gondolas, %d drainpipes, %d rails, %d rope bridges, %d catch nets, %d walkways" % [
			towers.size(), scaffolds, gondolas, pipes, rails, bridges, nets, walkways]


## A window-washer's gondola (levels/lift.gd) up glass tower `t` from the
## street, on a wall that goes all the way up to its top, onto a gap. False if
## none fits (or it's stone: its ledges are its way up).
func _write_gondola(t: Dictionary, gaps: Array, dice: RandomNumberGenerator) -> bool:
	if t.facade != "glass":
		return false
	var sides := []
	for gap: Dictionary in gaps:
		if gap.a == t or gap.b == t:
			sides.append([gap, "a" if gap.a == t else "b"])
	_shuffle(sides, dice)
	# Up a wall that goes all the way to its top if one's onto a gap, else the
	# tallest that is (a wing's, the spire's terrace: its drainpipe goes on up).
	var best := [] # [gap, side, along, storeys]
	for full in [true, false]:
		for side: Array in sides:
			var gap: Dictionary = side[0]
			var mine: String = side[1]
			var along := _gap_spot(gap, GONDOLA_CLEAR / 2.0, dice, func(at: float) -> bool:
					return _wall_level(gap, mine, at, GONDOLA_CLEAR / 2.0) and (not full or _wall_storeys(gap, mine, at) == t.storeys))
			if is_nan(along):
				continue
			var storeys := _wall_storeys(gap, mine, along)
			if best.is_empty() or storeys > best[3]:
				best = [gap, mine, along, storeys]
		if not best.is_empty():
			break
	if best.is_empty():
		return false
	var gap: Dictionary = best[0]
	var at := _gap_point(gap, gap.from if best[1] == "a" else gap.to, best[2])
	var out := _gap_point(gap, 1.0 if best[1] == "a" else -1.0, 0.0)
	_way_up_spots.append(at)
	_wall_node("%s_Gondola" % t.name, "WaysUp", "37_lift", Vector3(at.x, 0.0, at.y), out,
			"kind = \"gondola\"\nheight = %s" % _num(best[3] * STOREY))
	_gap_things.append(_gap_strip(gap, best[2], GONDOLA_CLEAR / 2.0))
	return true


## Counterweight hoists (levels/lift.gd) up tall old-town buildings from the
## street (see HOISTS): one per block at most, on a street-facing wall, clear
## of fire escapes, drainpipes and launchers. Says how many.
func _write_hoists(buildings: Array[Dictionary]) -> int:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([SEED, "hoists"])
	var candidates := buildings.filter(func(b: Dictionary) -> bool:
			return b.roof == "flat" and not b.tower and b.style == "old" and b.storeys >= HOIST_MIN_STOREYS and b.interior == "" and b.block != Vector2i(-1, -1)) # (Not one with insides: its openings would have to move.)
	_shuffle(candidates, dice)
	var blocks := {}
	var count := 0
	for b: Dictionary in candidates:
		if count >= HOISTS or blocks.has(b.block):
			continue
		var area := _block_rect(b.block)
		for wall: Array in _walls(b):
			var outside: Vector2 = wall[0] + wall[1] * wall[3] / 2.0 + wall[2] * 3.0
			if area.has_point(outside) or wall[2] in b.get("escape_outs", []) or wall[3] < HOIST_CLEAR + 2.0 * WAY_UP_CORNER:
				continue # (Onto a street, not where its fire escape is, long enough.)
			var at: Vector2 = wall[0] + wall[1] * wall[3] / 2.0
			var footprint := Rect2(at - wall[1] * HOIST_CLEAR / 2.0, Vector2.ZERO).expand(at + wall[1] * HOIST_CLEAR / 2.0 + wall[2] * 3.0)
			if _fire_escapes.any(func(r: Rect2) -> bool: return r.grow(1.0).intersects(footprint)) \
					or _way_up_spots.any(func(spot: Vector2) -> bool: return footprint.grow(1.5).has_point(spot)):
				continue
			_fire_escapes.append(footprint) # (Pavement clutter keeps clear...)
			_launcher_rects.append(footprint) # (...and so do ledges.)
			_way_up_spots.append(at)
			# (Its counterweight hangs beside it along the wall, along its +X:
			# the two either side of `at`.)
			var x := Vector2(wall[2].y, -wall[2].x)
			_wall_node("%s_Hoist" % b.name, "WaysUp", "37_lift", Vector3(at.x - x.x, 0.0, at.y - x.y), wall[2],
					"height = %s" % _num(b.storeys * STOREY))
			blocks[b.block] = true
			count += 1
			break
	return count


## A drainpipe up a tower's top part from its lower part's roof (if it has one).
func _write_tower_pipe(b: Dictionary, dice: RandomNumberGenerator) -> bool:
	if b.base >= b.storeys:
		return false
	var upper: Rect2 = b.upper
	var footprint := Rect2(b.x, b.z, b.w, b.d)
	var walls := _walls({"x": upper.position.x, "z": upper.position.y, "w": upper.size.x, "d": upper.size.y}).filter(func(wall: Array) -> bool:
			var outside: Vector2 = wall[0] + wall[1] * wall[3] / 2.0 + wall[2] * 1.0
			return footprint.has_point(outside)) # (With the lower roof in front of it.)
	var wall: Array = walls[dice.randi() % walls.size()]
	var at: Vector2 = wall[0] + wall[1] * dice.randf_range(WAY_UP_CORNER, wall[3] - WAY_UP_CORNER)
	_way_up_spots.append(at)
	_wall_node("%s_Pipe" % b.name, "WaysUp", "16_pipe", Vector3(at.x, b.base * STOREY, at.y), wall[2],
			"height = %s" % _num((b.storeys - b.base) * STOREY))
	return true


## Scaffolding up tower `t` from the street: on a wall facing a lower
## neighbour (the least lower), else any wall onto a gap. False if none fits.
func _write_scaffold(t: Dictionary, gaps: Array, dice: RandomNumberGenerator) -> bool:
	if t.facade == "stone" and t.interior == "":
		return false # (Its ledges are the way up.)
	var sides := [] # [gap, which side of it `t` is]
	for gap: Dictionary in gaps:
		if gap.a == t or gap.b == t:
			sides.append([gap, "a" if gap.a == t else "b"])
	_shuffle(sides, dice)
	var best := [] # [gap, side, along, how much lower the neighbour is]
	for lower_only in [true, false]:
		for side: Array in sides:
			var gap: Dictionary = side[0]
			var mine: String = side[1]
			var theirs := "b" if mine == "a" else "a"
			var along := _gap_spot(gap, SCAFFOLD_WIDTH / 2.0, dice, func(at: float) -> bool:
					return _wall_level(gap, mine, at, SCAFFOLD_WIDTH / 2.0) and (not lower_only or _wall_storeys(gap, theirs, at) < _wall_storeys(gap, mine, at)))
			if is_nan(along):
				continue
			var drop := _wall_storeys(gap, mine, along) - _wall_storeys(gap, theirs, along)
			if best.is_empty() or drop < best[3]:
				best = [gap, mine, along, drop]
		if not best.is_empty():
			break
	if best.is_empty():
		return false
	var gap: Dictionary = best[0]
	var along: float = best[2]
	var at := _gap_point(gap, gap.from if best[1] == "a" else gap.to, along)
	var out := _gap_point(gap, 1.0 if best[1] == "a" else -1.0, 0.0)
	_way_up_spots.append(at) # (Openings keep clear of it.)
	_wall_node("%s_Scaffold" % t.name, "WaysUp", "30_scaffold", Vector3(at.x, 0.0, at.y), out,
			"height = %s\nwidth = %s" % [_num(_wall_storeys(gap, best[1], along) * STOREY), _num(SCAFFOLD_WIDTH)])
	_gap_things.append(_gap_strip(gap, along, SCAFFOLD_WIDTH / 2.0))
	return true


## Grind rails across gaps, from a roof down to one RAIL_DROP storeys lower
## (each tower that tall all the way in to the rail's end on it).
func _write_downtown_rails(gaps: Array, dice: RandomNumberGenerator) -> int:
	var order := gaps.duplicate()
	_shuffle(order, dice)
	var count := 0
	for gap: Dictionary in order:
		if count >= RAILS:
			break
		var along := _gap_spot(gap, 1.5, dice, _rail_fits.bind(gap))
		if is_nan(along):
			continue
		var a_high := _wall_storeys(gap, "a", along) > _wall_storeys(gap, "b", along)
		var high: Dictionary = gap.a if a_high else gap.b
		var low: Dictionary = gap.b if a_high else gap.a
		var toward := 1.0 if a_high else -1.0 # (Along the way across, from high to low.)
		var start_across: float = (gap.from if a_high else gap.to) - toward * RAIL_IN.x
		var end_across: float = (gap.to if a_high else gap.from) + toward * RAIL_IN.y
		var start_flat := _gap_point(gap, start_across, along)
		var end_flat := _gap_point(gap, end_across, along)
		var start := Vector3(start_flat.x, _wall_storeys(gap, "a" if a_high else "b", along) * STOREY + RAIL_ABOVE, start_flat.y)
		var end := Vector3(end_flat.x, _wall_storeys(gap, "b" if a_high else "a", along) * STOREY + RAIL_ABOVE, end_flat.y)
		var offset := end - start
		_out.append("\n[node name=\"Rail%s_%s\" parent=\"GrindRails\" instance=ExtResource(\"8_rail\")]\ntransform = %s\nend_point = Vector3(%s, %s, %s)" % [
				high.name, low.name, _at(start.x, start.y, start.z), _num(offset.x), _num(offset.y), _num(offset.z)])
		var way := (end_flat - start_flat).normalized()
		_rail_paths.append([start_flat - way * RAIL_RUN_UP, end_flat + way * RAIL_LANDING])
		_gap_things.append(_gap_strip(gap, along, 1.5))
		count += 1
	return count


## Whether a rail fits across `gap` at `along` (see _write_downtown_rails()).
static func _rail_fits(along: float, gap: Dictionary) -> bool:
	var drop := absi(_wall_storeys(gap, "a", along) - _wall_storeys(gap, "b", along))
	if drop < RAIL_DROP.x or drop > RAIL_DROP.y:
		return false
	var high := "a" if _wall_storeys(gap, "a", along) > _wall_storeys(gap, "b", along) else "b"
	for side: String in ["a", "b"]:
		var into: float = (RAIL_IN.x if side == high else RAIL_IN.y) + 2.0
		var inner: float = gap.from - into if side == "a" else gap.to + into
		if _storeys_at(gap[side], _gap_point(gap, inner, along)) != _wall_storeys(gap, side, along):
			return false
	return true


## Rope bridges across streets between towers the same height: a level deck
## of rope netting from roof to roof (a little onto each), and a hand-rope
## either side, sagging ROPE_SAG in the middle (just to look at: no collision).
func _write_rope_bridges(gaps: Array, dice: RandomNumberGenerator) -> int:
	var order := gaps.duplicate()
	_shuffle(order, dice)
	var count := 0
	var half := ROPE_WIDTH / 2.0
	for gap: Dictionary in order:
		if count >= ROPE_BRIDGES:
			break
		if gap.to - gap.from < STREET - 0.1:
			continue
		var along := _gap_spot(gap, half, dice, func(at: float) -> bool:
				return _wall_level(gap, "a", at, half) and _wall_level(gap, "b", at, half) and _wall_storeys(gap, "a", at) == _wall_storeys(gap, "b", at))
		if is_nan(along):
			continue
		var name := "RopeBridge%s_%s" % [gap.a.name, gap.b.name]
		var y := _wall_storeys(gap, "a", along) * STOREY
		var middle := _gap_point(gap, (gap.from + gap.to) / 2.0, along)
		var deck := _gap_size(gap, gap.to - gap.from + 1.0, ROPE_THICK, ROPE_WIDTH)
		_box(name, "Bridges", middle.x, y - ROPE_THICK / 2.0, middle.y, deck.x, deck.y, deck.z, "31_net")
		for side in [1, 2]:
			var points: Array[Vector3] = []
			for k in ROPE_SEGMENTS + 1:
				var t := float(k) / ROPE_SEGMENTS
				var flat := _gap_point(gap, lerpf(gap.from - 0.5, gap.to + 0.5, t), along + (half if side == 2 else -half))
				points.append(Vector3(flat.x, y + 1.0 - ROPE_SAG * 4.0 * t * (1.0 - t), flat.y))
			for k in ROPE_SEGMENTS:
				var way := (points[k + 1] - points[k]).normalized()
				var across := Vector3(_gap_point(gap, 0.0, 1.0).x, 0.0, _gap_point(gap, 0.0, 1.0).y)
				_node("CSGBox3D", "%s_Rope%d_%d" % [name, side, k + 1], "Bridges", Transform3D(Basis(across, way.cross(across), way), (points[k] + points[k + 1]) / 2.0),
						"size = Vector3(0.06, 0.06, %s)" % _num(points[k].distance_to(points[k + 1])), "31_net", false)
		_rope_bridge_spots.append(Vector3(middle.x, y, middle.y))
		_gap_things.append(_gap_strip(gap, along, half))
		count += 1
	return count


## Catch nets out over alleys, under a roof (the other side's wall higher than the net).
func _write_nets(gaps: Array, dice: RandomNumberGenerator) -> int:
	var order := gaps.duplicate()
	_shuffle(order, dice)
	var count := 0
	var half := NET_WIDTH / 2.0
	for gap: Dictionary in order:
		if count >= NETS:
			break
		if gap.to - gap.from > ALLEY + 0.1:
			continue
		var mine := "a" if dice.randf() < 0.5 else "b"
		var theirs := "b" if mine == "a" else "a"
		var along := _gap_spot(gap, half, dice, func(at: float) -> bool:
				var level := _wall_storeys(gap, mine, at) - NET_BELOW
				return _wall_level(gap, mine, at, half) and _wall_storeys(gap, theirs, at - half) > level and _wall_storeys(gap, theirs, at + half) > level)
		if is_nan(along):
			continue
		var at := _gap_point(gap, gap.from if mine == "a" else gap.to, along)
		var out := _gap_point(gap, 1.0 if mine == "a" else -1.0, 0.0)
		var y: float = (_wall_storeys(gap, mine, along) - NET_BELOW) * STOREY
		_wall_node("Net%s_%d" % [gap[mine].name, count + 1], "Nets", "32_catch_net", Vector3(at.x, y, at.y), out,
				"size = Vector2(%s, %s)\nrise = %s" % [_num(NET_WIDTH), _num(gap.to - gap.from - 1.0), _num(NET_BELOW * STOREY + VENT_LIFT)])
		_gap_things.append(_gap_strip(gap, along, half))
		count += 1
	return count


## Covered walkways across alleys, between floors inside the towers either
## side (b.interior "mid", b.floor: its storey, b.walkway: [the side it's on,
## along]), level with a lower roof next to one of them, across an alley.
func _write_walkways(gaps: Array, dice: RandomNumberGenerator) -> int:
	var order := gaps.duplicate()
	_shuffle(order, dice)
	var count := 0
	var half := WALKWAY_WIDTH / 2.0
	for gap: Dictionary in order:
		if count >= WALKWAYS:
			break
		var a: Dictionary = gap.a
		var b: Dictionary = gap.b
		if gap.to - gap.from > ALLEY + 0.1 or a.base < a.storeys or b.base < b.storeys \
				or a.interior != "" or b.interior != "" or "Spire" in [a.name, b.name]:
			continue
		var level := _walkway_level(gap, gaps)
		if level < 0:
			continue
		var along := _gap_spot(gap, half + 1.0, dice, func(_at: float) -> bool: return true)
		if is_nan(along):
			continue
		a.merge({"interior": "mid", "floor": level, "walkway": ["E" if gap.across_x else "S", along]}, true)
		b.merge({"interior": "mid", "floor": level, "walkway": ["W" if gap.across_x else "N", along]}, true)
		var floor_y := level * STOREY
		var name := "Walkway%s_%s" % [a.name, b.name]
		var middle := (_gap_point(gap, gap.from, along) + _gap_point(gap, gap.to, along)) / 2.0
		var length: float = gap.to - gap.from + 2.0 * WALL # (Through the walls, to the floors inside.)
		var deck := _gap_size(gap, length, 0.5, WALKWAY_WIDTH)
		_box(name, "Bridges", middle.x, floor_y - 0.25, middle.y, deck.x, deck.y, deck.z, "4_building")
		var roof := _gap_size(gap, length, 0.4, WALKWAY_WIDTH)
		_box(name + "_Roof", "Bridges", middle.x, floor_y + MID_OPENING.y + 0.2, middle.y, roof.x, roof.y, roof.z, "4_building")
		for side in [1, 2]:
			var glass := _gap_size(gap, gap.to - gap.from, MID_OPENING.y, 0.1)
			var at := middle + _gap_point(gap, 0.0, (half - 0.05) * (-1.0 if side == 1 else 1.0))
			_box("%s_Glass%d" % [name, side], "Bridges", at.x, floor_y + MID_OPENING.y / 2.0, at.y, glass.x, glass.y, glass.z, "28_glass")
		_walkway_spots.append(Vector3(middle.x, floor_y, middle.y))
		_gap_things.append(_gap_strip(gap, along, half + 1.0))
		count += 1
	return count


## The storey a walkway across `gap` would be at: level with a lower roof
## across an alley from one of its towers (8 storeys up at least, 4 under
## both towers' tops), or -1 if there's none.
static func _walkway_level(gap: Dictionary, gaps: Array) -> int:
	var a: Dictionary = gap.a
	var b: Dictionary = gap.b
	for next: Dictionary in gaps:
		if next == gap or next.to - next.from > ALLEY + 0.1:
			continue
		for sides: Array in [["a", "b"], ["b", "a"]]:
			var mine: Dictionary = next[sides[0]]
			var theirs: Dictionary = next[sides[1]]
			if (mine != a and mine != b) or theirs == a or theirs == b:
				continue
			var storeys := _wall_storeys(next, sides[1], (next.span.x + next.span.y) / 2.0)
			if storeys >= 8 and a.storeys >= storeys + 4 and b.storeys >= storeys + 4:
				return storeys
	return -1


## A box's size in `gap`: `across` the way across it, `up`, `along` its walls.
static func _gap_size(gap: Dictionary, across: float, up: float, along: float) -> Vector3:
	return Vector3(across, up, along) if gap.across_x else Vector3(along, up, across)


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
[ext_resource type="Material" path="res://materials/glass.tres" id="28_glass"]
[ext_resource type="Material" path="res://materials/grid_tower.tres" id="29_tower"]
[ext_resource type="Script" path="res://levels/scaffold.gd" id="30_scaffold"]
[ext_resource type="Material" path="res://materials/net.tres" id="31_net"]
[ext_resource type="Script" path="res://levels/catch_net.gd" id="32_catch_net"]
[ext_resource type="Script" path="res://levels/ledges.gd" id="33_ledges"]
[ext_resource type="Script" path="res://levels/stairs.gd" id="34_stairs"]
[ext_resource type="Material" path="res://materials/iron.tres" id="35_iron"]
[ext_resource type="Material" path="res://materials/stone.tres" id="36_stone"]
[ext_resource type="Script" path="res://levels/lift.gd" id="37_lift"]

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

[node name="Interiors" type="Node3D" parent="."]

[node name="Bridges" type="Node3D" parent="."]

[node name="Nets" type="Node3D" parent="."]

[node name="Ledges" type="Node3D" parent="."]""")


## The street (one slab under everything) and the subway line down the north-south avenue.
func _write_ground() -> void:
	var low := _starts[0] - _plaza_middle - EDGE
	var high := _starts[BLOCKS - 1] + BLOCK - _plaza_middle + EDGE
	var east := _downtown_rect().end.x + EDGE # (Downtown, across the boulevard.)
	_box("Ground", "Street", (low + east) / 2.0, -1.0, (low + high) / 2.0, east - low, 2.0, high - low, "3_ground")
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
	# And on a tower downtown: in the column by the boulevard, the row nearest the middle.
	var edge := buildings.filter(func(b: Dictionary) -> bool: return b.roof == "downtown" and b.lot.x == 0)
	var middle_z := _downtown_rect().get_center().y
	edge.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(_middle(a).y - middle_z) < absf(_middle(b).y - middle_z))
	var top: Rect2 = edge[0].upper
	_checkpoint("CheckpointDowntown", Vector3(top.get_center().x, edge[0].storeys * STOREY, top.get_center().y))


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

	_downtown_relics.clear()
	for relic: Array in _downtown_relic_spots(buildings):
		_relic(relic[0], relic[1], relic[2])
		_downtown_relics.append(relic[0])


## Downtown's relics (always there, like the five above): [name, where, on a
## roof]. On the tallest towers' tops (the spire's first); floating high over
## the spire (a toss up from it); in the middle of each walkway; and floating
## high over the first rope bridge (a toss up from it).
func _downtown_relic_spots(buildings: Array[Dictionary]) -> Array:
	var spots := []
	var towers := buildings.filter(func(b: Dictionary) -> bool: return b.roof == "downtown")
	towers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.storeys > b.storeys)
	for b: Dictionary in towers.slice(0, 4):
		var top: Rect2 = b.upper
		spots.append(["RelicTop" + b.name, Vector3(top.get_center().x, b.storeys * STOREY + RELIC_HOVER, top.get_center().y), true])
	var spire: Dictionary = towers[0]
	spots.append(["RelicOverSpire", Vector3(_middle(spire).x, spire.storeys * STOREY + FLOAT_HEIGHT, _middle(spire).y), false])
	for i in _walkway_spots.size():
		spots.append(["RelicWalkway%d" % (i + 1), _walkway_spots[i] + Vector3.UP * RELIC_HOVER, false])
	if not _rope_bridge_spots.is_empty():
		spots.append(["RelicOverRopeBridge", _rope_bridge_spots[0] + Vector3.UP * FLOAT_HEIGHT, false])
	return spots


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
	# On the shapes (next): over a dome's top, on the top tier, on a round
	# roof, hanging over a courtyard (jump out off the roof to it), on the top
	# of the modern ones (at the tip of a cantilever, out over the street).
	var shape_ones := []
	for b: Dictionary in buildings:
		var middle := _middle(b)
		var roof: float = b.storeys * STOREY
		var height := -1.0
		if b.dome > 0.0:
			height = roof + b.dome * (1.0 - DOME_SINK) + RELIC_HOVER
		else:
			match b.roof:
				"stepped": height = roof + b.tiers * TIER_STOREYS * STOREY + RELIC_HOVER
				"round": height = roof + RELIC_HOVER
				"courtyard": height = roof - 1.0
				"turned", "curved": height = roof + RELIC_HOVER
				"leaning":
					var top: Vector3 = _leaning(b).top
					middle = Vector2(top.x, top.z)
					height = top.y + RELIC_HOVER
				"cantilever":
					var out: Vector3 = {"N": Vector3.FORWARD, "S": Vector3.BACK, "W": Vector3.LEFT, "E": Vector3.RIGHT}[b.side]
					var depth: float = b.w if absf(out.x) > 0.5 else b.d
					middle += Vector2(out.x, out.z) * (depth / 2.0 + CANTILEVER - 1.5)
					height = roof + RELIC_HOVER
				"museum":
					# On the dome's crown; and on a terrace's top, either side.
					middle = _museum_middle(b)
					height = MUSEUM_HALL.y + MUSEUM_DOME.y - MUSEUM_DOME_SINK + RELIC_HOVER
					for terrace: Array in MUSEUM_TERRACES.slice(0, 2):
						var crest: float = terrace[3] - terrace[4]
						var angle := deg_to_rad(terrace[1] + terrace[2] / 2.0 - 5.0) # (Near its end: clear of the terrace on it.)
						var at := middle + Vector2(cos(angle), -sin(angle)) * (crest + MUSEUM_HALL.x) / 2.0
						shape_ones.append({"name": "RelicMuseum" + terrace[0], "at": Vector3(at.x, terrace[6] + terrace[5] + RELIC_HOVER, at.y), "pillar": 0.0, "on": ""})
		if height > 0.0:
			shape_ones.append({"name": "RelicOn" + b.name, "at": Vector3(middle.x, height, middle.y), "pillar": 0.0, "on": b.name})
		# And one high over its top: floating over a dome, else on a tall pillar.
		if b.roof in SHAPE_MIN and b.roof != "courtyard" or b.roof == "museum":
			var top := height - RELIC_HOVER if height > 0.0 else roof
			var spot := _middle(b) + Vector2(2.0, 2.0) # (Off the middle: room round a pillar.)
			if b.dome > 0.0 or b.roof in ["winged", "leaning", "museum"]:
				shape_ones.append({"name": "RelicOver" + b.name, "at": Vector3(middle.x, top + FLOAT_HEIGHT, middle.y), "pillar": 0.0, "on": b.name})
			else:
				var pillar: float = PILLAR_HEIGHTS[3]
				shape_ones.append({"name": "RelicOver" + b.name, "at": Vector3(spot.x, top + pillar + RELIC_HOVER, spot.y), "pillar": pillar, "base": top, "on": b.name})
	candidates = inside_ones + shape_ones + candidates
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
	for fixed: String in ["RelicSky", "RelicRail", "RelicFarCorner", "RelicHighRoof", "RelicSubway", "RelicTunnel"] + _downtown_relics:
		have[needed[fixed]] = have.get(needed[fixed], 0) + 1
	var picked := []
	var used := {} # (One to a building.)
	for candidate: Dictionary in _extra_relics:
		var players: int = needed.get(candidate.name, 0)
		if candidate.on != "" and used.has(candidate.on):
			continue
		if needed.has(candidate.name) and RELICS_WANTED.has(players) and have.get(players, 0) < RELICS_WANTED[players]:
			used[candidate.on] = true
			have[players] = have.get(players, 0) + 1
			picked.append(candidate)
	return picked


## Writes _extra_relics (and their pillars), skipping any on a roof that has a
## marker or a fixed relic already (not one of these: while measuring them
## all, a building can have more than one). Returns how many it wrote.
func _write_extra_relics(buildings: Array[Dictionary]) -> int:
	var count := 0
	var markers := _marker_spots.duplicate()
	for candidate: Dictionary in _extra_relics:
		var b: Dictionary = {}
		for building in buildings:
			if building.name == candidate.on:
				b = building
		if not b.is_empty() and markers.any(func(spot: Vector2) -> bool: return Rect2(b.x, b.z, b.w, b.d).has_point(spot)):
			continue
		var at: Vector3 = candidate.at
		if candidate.pillar > 0.0:
			var roof: float = candidate.get("base", b.storeys * STOREY) # (On a tier, the top one.)
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
## ring on the free roof nearest the spawn (or the next nearest, if that
## one's route runs out of roofs: see _run_route()); then a white gate on each of the
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
	# Starting from the free roof nearest the spawn, or the next nearest if
	# that one's route runs out of roofs before it has all its gates.
	var starts := free.filter(func(b: Dictionary) -> bool: return b != spawn_roof)
	starts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _middle(a).distance_to(_marker_spots[0]) < _middle(b).distance_to(_marker_spots[0]))
	var route: Array[Dictionary] = []
	for start: Dictionary in starts:
		var tried := _run_route(start, flat)
		if tried.size() > route.size():
			route = tried
		if route.size() > RUN_GATES:
			break
	var start: Dictionary = route[0]
	var gates: Array[Vector3] = []
	for i in range(1, route.size()):
		var here: Dictionary = route[i - 1]
		var best: Dictionary = route[i]
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


## A group run's roofs from `start`: up to RUN_GATES more, each the one (of
## `flat`) across an alley or street from the last (up two storeys at most,
## down three) that goes furthest on and away from the start by a short hop.
func _run_route(start: Dictionary, flat: Array) -> Array[Dictionary]:
	var route: Array[Dictionary] = [start]
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
	return route


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
			_launcher_rects.append(footprint) # (The ledges too.)
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


## Which buildings are stone, with ledges (see STONE_CHANCE): of the old
## town's plain flat-roofed buildings with no insides, and of downtown's towers
## (the rest of those are glass).
func _pick_facades(buildings: Array[Dictionary]) -> void:
	for b in buildings:
		var dice := RandomNumberGenerator.new()
		dice.seed = hash([SEED, b.name, "facade"])
		var roll := dice.randf()
		if b.roof == "downtown":
			b.facade = "stone" if roll < STONE_TOWER_CHANCE and b.name != "Spire" else "glass"
		elif b.roof == "flat" and b.style == "old" and not b.tower and b.interior == "":
			b.facade = "stone" if roll < STONE_CHANCE else ""


func _tower_material(b: Dictionary) -> String:
	return "36_stone" if b.facade == "stone" else "29_tower"


## The rows of ledges up stone buildings' walls (every storey), and glass
## towers' (every few). Not where the fire escape is, nor (downtown) on towers
## with insides to run through (their openings); clear of drainpipes and
## scaffolding. Says how many walls got them.
func _write_facades(buildings: Array[Dictionary]) -> int:
	var count := 0
	for b in buildings:
		if b.facade == "" or b.interior != "":
			continue
		if b.roof != "downtown":
			for wall: Array in _walls(b):
				if wall[2] in b.get("escape_outs", []):
					continue
				count += 1 if _write_ledges("%s_Ledges%d" % [b.name, count], wall, 0.0, wall[3], 0.0, range(1, b.storeys), b.storeys) else 0
			continue
		# Downtown: up its lower part's walls (all the way, where the top part's
		# wall carries on above), and up the top part's walls from its lower roof.
		var every: int = 1 if b.facade == "stone" else GLASS_LEDGE_EVERY
		var upper: Rect2 = b.upper
		var top_walls := _walls({"x": upper.position.x, "z": upper.position.y, "w": upper.size.x, "d": upper.size.y})
		var winged: bool = b.base < b.storeys
		for wall: Array in _walls(b):
			var on := Vector2(INF, -INF) # (Where the top part's wall carries this one on up.)
			for top: Array in top_walls:
				var corner: Vector2 = top[0]
				if winged and top[2] == wall[2] and absf((corner - wall[0]).dot(wall[2])) < 0.01:
					var from: float = (corner - wall[0]).dot(wall[1])
					on = Vector2(from, from + top[3])
			var pieces := [[0.0, wall[3], b.base]]
			if on.x < on.y:
				pieces = [[0.0, on.x, b.base], [on.x, on.y, b.storeys], [on.y, wall[3], b.base]]
			for piece: Array in pieces:
				if piece[1] - piece[0] < Ledges.SHORTEST:
					continue
				var heights := range(1, piece[2]).filter(func(k: int) -> bool: return k % every == 0)
				count += 1 if _write_ledges("%s_Ledges%d" % [b.name, count], wall, piece[0], piece[1], 0.0, heights, piece[2]) else 0
		if winged:
			for top: Array in top_walls:
				var outside: Vector2 = top[0] + top[1] * top[3] / 2.0 + top[2] * 1.0
				if not Rect2(b.x, b.z, b.w, b.d).has_point(outside):
					continue # (Carried on from the lower part's wall: done.)
				var heights := range(b.base + 1, b.storeys).filter(func(k: int) -> bool: return k % every == 0)
				count += 1 if _write_ledges("%s_Ledges%d" % [b.name, count], top, 0.0, top[3], 0.0, heights, b.storeys) else 0
	return count


## A row of ledges at each of `storeys` along `wall` (see _walls()), from
## `from` to `to` along it, up to a roof `top` storeys up; clear of drainpipes
## and scaffolding (and downtown's things in the gaps). False if it gets none.
func _write_ledges(name: String, wall: Array, from: float, to: float, base: float, storeys: Array, top: int) -> bool:
	if storeys.is_empty():
		return false
	var out: Vector2 = wall[2]
	# Its +X runs along the wall with +Z out (see levels/ledges.gd): from this
	# end of the wall, or the other.
	var along := Vector2(out.y, -out.x)
	var start: Vector2 = wall[0] + wall[1] * from
	if along.dot(wall[1]) < 0.0:
		start = wall[0] + wall[1] * to
	var length := to - from
	var gaps := PackedVector2Array()
	var front := Rect2(start, Vector2.ZERO).expand(start + along * length + out * 1.0)
	for spot in _way_up_spots:
		if front.grow(0.1).has_point(spot):
			var at := (spot - start).dot(along)
			gaps.append(Vector2(at - LEDGE_CLEAR, at + LEDGE_CLEAR))
	for thing in _gap_things + _launcher_rects:
		var both := front.intersection(thing)
		if both.has_area():
			var a := (both.position - start).dot(along)
			var b := (both.end - start).dot(along)
			gaps.append(Vector2(minf(a, b) - 0.5, maxf(a, b) + 0.5))
	var heights := PackedFloat32Array()
	for k: int in storeys:
		heights.append(k * STOREY)
	_wall_node(name, "Ledges", "33_ledges", Vector3(start.x, base, start.y), out,
			"length = %s\nheights = PackedFloat32Array(%s)\ngaps = PackedVector2Array(%s)\ntop = %s" % [
			_num(length), ", ".join(Array(heights).map(func(h: float) -> String: return _num(h))),
			", ".join(Array(gaps).map(func(g: Vector2) -> String: return "%s, %s" % [_num(g.x), _num(g.y)])), _num(top * STOREY)])
	return true


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
		"mid": # (Downtown: a floor partway up, two storeys tall, a walkway out of one side.)
			var floor_y: float = b.floor * STOREY
			_hole(b, "Room", floor_y, floor_y + 2.0 * STOREY, WALL)
			var side: String = b.walkway[0]
			_openings(b, "Opening", floor_y, MID_OPENING, THROUGH_SPACING, [side])
			var along: float = b.walkway[1]
			var at: Vector3 = {"N": Vector3(along, 0.0, b.z), "S": Vector3(along, 0.0, b.z + b.d),
					"W": Vector3(b.x, 0.0, along), "E": Vector3(b.x + b.w, 0.0, along)}[side]
			at.y = floor_y + MID_OPENING.y / 2.0
			var through := WALL * 3.0
			_cut(b, "Walkway", at, Vector3(WALKWAY_WIDTH, MID_OPENING.y, through) if side in ["N", "S"] else Vector3(through, MID_OPENING.y, WALKWAY_WIDTH))
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
	var depth := PLATFORM_DEPTH
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
	return Rect2(start, Vector2.ZERO).expand(start + (slot[1] as Vector2) * length + (slot[2] as Vector2) * PLATFORM_DEPTH)


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


## True if one of `b`'s walls faces across an avenue.
func _on_avenue(b: Dictionary) -> bool:
	var side := AVENUE / 2.0 # (The avenues run either side of the plaza's middle lines.)
	for edge: float in [b.x, b.x + b.w, b.z, b.z + b.d]:
		if is_equal_approx(absf(edge), side):
			return true
	return false
