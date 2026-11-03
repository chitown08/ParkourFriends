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


func _find_places(root: Node) -> void:
	for node in root.find_children("*", "CSGBox3D", true, false):
		var box := node as CSGBox3D
		if not box.use_collision or not box.is_visible_in_tree():
			continue
		var size := box.size * box.global_basis.get_scale()
		if size.x * size.z < MIN_PLACE_AREA:
			continue
		var spot := Spot.new()
		spot.name = str(box.name)
		var corner := box.global_position - size / 2.0
		spot.area = Rect2(corner.x, corner.z, size.x, size.z)
		spot.y = box.global_position.y + size.y / 2.0
		spot.node = box
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
