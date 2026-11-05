extends GameTest
## The middle of buildings: rows of window ledges up stone buildings (levels/
## ledges.gd) to catch when you botch a jump and climb ledge by ledge, and New
## York-style fire escapes (levels/stairs.gd): iron decks at every storey round
## a corner, stairs climbing along them from the street to the roof.

const GENERATOR := preload("res://tools/gen_district.gd")
const STONE := preload("res://materials/stone.tres")
const CLIMB := preload("res://materials/grid_climb.tres")
const IRON := preload("res://materials/iron.tres")

## Running along a fire escape deck this far out from the middle of it, toward the wall.
const DECK_HUG := 0.3

var states_entered: Array[StringName] = []


func before_each() -> void:
	await super()
	main.leave_game()
	await ticks(5)
	main.start_solo("rooftop_district")
	await ticks(10)
	player = main.get_node("Players/1")
	player.set_profile(SUPERHUMAN)
	player.state_changed.connect(func(new_state: StringName) -> void: states_entered.append(new_state))


# --- Ledges ------------------------------------------------------------------

func test_stone_buildings_have_a_ledge_at_every_storey() -> void:
	var stone := _buildings().filter(func(b: CSGShape3D) -> bool: return b.material == STONE)
	var old_town := stone.filter(func(b: CSGShape3D) -> bool: return b.name.begins_with("Block"))
	expect(old_town.size() >= 10, "plenty of the old town is stone, %d buildings" % old_town.size())
	expect(stone.size() - old_town.size() >= 8, "and plenty of downtown, %d towers" % (stone.size() - old_town.size()))
	expect(Ledges.MATERIAL == CLIMB, "ledges are yellow (climb)")
	for b: CSGShape3D in stone:
		if _has_insides(b):
			continue # (Downtown's with walkways in: their openings.)
		var rows := _ledges_of(b)
		var wanted := 4 - _walls_climbed(b) # (Not along its fire escape.)
		expect(rows.size() >= wanted, "%s has ledges along its walls, %d of %d" % [b.name, rows.size(), wanted])
		for row in rows:
			var heights := Array(row.heights)
			expect(heights[0] <= GENERATOR.STOREY + 0.01 or b.has_node("Upper"),
					"%s starts a storey up" % row.name)
			for k in range(1, heights.size()):
				expect_near(heights[k] - heights[k - 1], GENERATOR.STOREY, 0.01, "%s: a row every storey" % row.name)
			expect_near(row.top - heights[-1], GENERATOR.STOREY, 0.01, "%s: the last a storey under its roof" % row.name)


func test_glass_towers_have_a_ledge_every_few_storeys_and_scaffolding() -> void:
	var glass := _buildings().filter(func(b: CSGShape3D) -> bool: return (b.name.begins_with("Tower") or b.name == "Spire") and b.material != STONE)
	expect(glass.size() >= 10, "most of downtown is glass, %d towers" % glass.size())
	var banded := 0
	for b: CSGShape3D in glass:
		for row in _ledges_of(b):
			banded += 1
			for h in row.heights:
				expect(is_zero_approx(fmod(h / GENERATOR.STOREY, GENERATOR.GLASS_LEDGE_EVERY)), "%s: only every %d storeys (%.1f m)" % [row.name, GENERATOR.GLASS_LEDGE_EVERY, h])
	expect(banded >= 20, "glass towers have rows to catch a fall, %d" % banded)
	# Scaffolding up glass towers, not stone ones (their ledges are the way up).
	for s: Scaffold in main.level.get_node("WaysUp").find_children("*", "Scaffold", false, false):
		var tower := main.level.get_node("Buildings/" + str(s.name).trim_suffix("_Scaffold")) as CSGShape3D
		expect(tower.material != STONE or _has_insides(tower), "%s: stone towers don't need scaffolding" % s.name)


func test_every_stone_roof_is_reachable_up_its_ledges() -> void:
	var map := ReachMap.shared(main.level, SUPERHUMAN)
	var up_ledges := {}
	for link in map.links:
		if link.how.begins_with("ledges") and link.to.y - link.from.y > 6.0:
			up_ledges[link.to] = true
	for b: CSGShape3D in _buildings():
		if b.material != STONE or _has_insides(b):
			continue
		var top := ReachMap._bounds(b.get_node("Upper") if b.has_node("Upper") else b)
		var roof := map.place_under(top.get_center() + Vector3.UP * (top.size.y / 2.0 + 0.5))
		expect(roof != null and up_ledges.has(roof), "%s's roof should be a ledge climb up" % b.name)


func test_climb_ledges_from_the_street_to_the_roof() -> void:
	var row := _street_row()
	expect(row != null, "an old-town stone wall onto the street")
	if row == null:
		return
	var out := row.out_of_wall()
	var piece: Vector2 = row.pieces()[0]
	var foot := row.point_at((piece.x + piece.y) / 2.0, 0.05) + out * 4.0
	var top := row.global_position.y + row.top
	await place(foot, yaw_for(-out))
	Input.action_press(&"free_run")
	for i in 60 * 20:
		await ticks(1)
		if player.is_on_floor() and player.global_position.y > top - 0.2:
			break
	release_all()
	expect(states_entered.count(&"Hang") >= row.heights.size() - 1, "should hang from ledge after ledge, went through %s" % [states_entered])
	expect(player.global_position.y > top - 0.2, "and leap up them to the roof (%.1f m), at %s" % [top, player.global_position])


func test_fall_past_a_wall_of_ledges_and_catch_one() -> void:
	var row := _street_row()
	var out := row.out_of_wall()
	var piece: Vector2 = row.pieces()[0]
	var top := row.global_position.y + row.top
	# Falling fast past the wall, pushing to it: the ledge above out of reach,
	# the next one down a little way under your feet.
	var start := row.point_at((piece.x + piece.y) / 2.0, top - GENERATOR.STOREY - SUPERHUMAN.ledge_max_height - 0.3) + out * 0.7
	release_all()
	player.camera_rig.yaw = yaw_for(-out)
	player.global_position = start
	player.velocity = Vector3.DOWN * 15.0
	player.change_state(&"Air")
	player.reset_physics_interpolation()
	Input.action_press(&"move_forward")
	for i in 60:
		await ticks(1)
		if player.state.name == &"Hang":
			break
	release_all()
	expect_state(&"Hang")
	var below: float = player.state.ledge().position.y if player.state.name == &"Hang" else INF
	expect(below < start.y and below > start.y - 2.0 * GENERATOR.STOREY, "caught the next ledge down (at %.1f m, falling from %.1f m)" % [below, start.y])
	# Shimmy along it.
	var along := row.along_wall()
	var was := player.global_position
	player.camera_rig.yaw = yaw_for(-out)
	var right := Vector3.UP.cross(out)
	await hold(&"move_right" if right.dot(along) > 0.0 else &"move_left", 60)
	expect_state(&"Hang")
	expect((player.global_position - was).length() > 1.5, "and shimmy along it, moved %.1f m" % (player.global_position - was).length())


func test_botch_a_jump_at_a_tall_wall_and_catch_a_ledge() -> void:
	var map := ReachMap.shared(main.level, SUPERHUMAN)
	# A running jump across an alley downtown, at a stone wall far too tall to grab the top of.
	var picked: ReachMap.Link
	var row: Ledges
	for link in map.links:
		if link.how != "ledges (caught from a jump)" or link.to.y - link.from.y < 3.0 * GENERATOR.STOREY or not link.from.name.begins_with("Tower"):
			continue
		for r: Ledges in main.level.get_node("Ledges").get_children():
			var piece: Vector2 = r.pieces()[0]
			var face := r.point_at((piece.x + piece.y) / 2.0, link.from.y)
			if r.heights.size() > 4 and absf(r.global_position.y + r.top - link.to.y) < 0.3 \
					and ReachMap._distance_to(link.from.area, Vector2(face.x, face.z)) < GENERATOR.ALLEY + 0.5:
				picked = link
				row = r
				break
		if picked:
			break
	expect(picked != null, "a lower roof across an alley from a stone tower")
	if picked == null:
		return
	var out := row.out_of_wall()
	var piece: Vector2 = row.pieces()[0]
	var face := row.point_at((piece.x + piece.y) / 2.0, picked.from.y)
	var edge := ReachMap._closest_in(picked.from.area, Vector2(face.x, face.z))
	await place(Vector3(edge.x, picked.from.y + 0.05, edge.y) + out * 3.0, yaw_for(-out))
	states_entered.clear()
	Input.action_press(&"move_forward")
	var jumped := false
	var caught_at := INF
	for i in 60 * 4:
		await ticks(1)
		if not jumped and (player.global_position - Vector3(edge.x, 0.0, edge.y)).dot(-out) > -0.6:
			Input.action_press(&"jump")
			jumped = true
		if player.state.name == &"Hang":
			caught_at = player.global_position.y
			break
	release_all()
	expect(caught_at < picked.to.y - 2.0 * GENERATOR.STOREY, "caught a ledge, well under the roof (%.1f m, jumping from %.1f m; went %s)" % [caught_at, picked.from.y, states_entered.slice(0, 8)])
	# Then leap up ledge by ledge to the top.
	for i in 60:
		if player.is_on_floor():
			break
		await tap(&"jump")
		await ticks(25)
	expect(player.is_on_floor() and player.global_position.y > picked.to.y - 0.3,
			"and leapt up the ledges to the roof (%.0f m, at %s)" % [picked.to.y, player.global_position])


func test_ledges_a_ledge_leap_apart_and_no_further() -> void:
	# The checker's rule (game/reach/rules/ledges.gd) and the game agree on
	# how far apart ledges can be: a ledge leap apart, and a bit more (all the
	# way up, or just one gap in the middle). Each case: the steps up from the
	# floor to each ledge and on to the top, and whether you get there.
	var near := SUPERHUMAN.ledge_leap_height - 0.2
	var far := SUPERHUMAN.ledge_leap_height + 0.6
	for case: Array in [[[3.5, near, near, near, near], true], [[far, far, far, far, far], false], [[3.5, 3.5, far, 3.5, 3.5], false]]:
		var spacing := "%s" % [case[0]]
		var wall: Node3D = await _test_wall(case[0])
		var map := ReachMap.build(wall, SUPERHUMAN) # (Just the test wall and its floor.)
		var floor_place := map.place_under(Vector3(0.0, 501.0, 506.0))
		var top := map.place_under(Vector3(0.0, 600.0, 500.0))
		var linked := map.links.any(func(l: ReachMap.Link) -> bool: return l.from == floor_place and l.to == top and l.how == "ledges")
		expect(linked == case[1], "the checker says ledges %s apart %s" % [spacing, "climb" if case[1] else "don't"])
		await place(Vector3(0.0, 500.55, 504.0), yaw_for(Vector3.FORWARD))
		states_entered.clear()
		Input.action_press(&"free_run")
		for i in 60 * 8:
			await ticks(1)
			if player.is_on_floor() and player.global_position.y > top.y - 0.3:
				break
		release_all()
		var made := player.is_on_floor() and player.global_position.y > top.y - 0.3
		expect(made == case[1], "in the game, ledges %s apart %s, at %s (went %s)" % [spacing, "climb" if case[1] else "don't", player.global_position, states_entered.slice(0, 12)])
		wall.free()
		await ticks(5)


# --- Fire escapes ------------------------------------------------------------

func test_every_block_has_a_fire_escape_round_its_walls() -> void:
	var blocks := {}
	for b: CSGShape3D in _buildings():
		var flights := _flights_of(b)
		if flights.is_empty():
			continue
		blocks[b.name.get_slice("_", 0)] = true
		var roof := ReachMap._bounds(b).end.y
		expect(flights.size() == roundi(roof / GENERATOR.STOREY), "%s: a flight a storey, street to roof (%d)" % [b.name, flights.size()])
		expect_near(flights[0].bottom().y, 0.0, 0.01, "%s: from the street" % b.name)
		for k in flights.size():
			expect_near(flights[k].top().y, (k + 1) * GENERATOR.STOREY, 0.01, "%s: each a storey up" % flights[k].name)
		var top := main.level.get_node("FireEscapes/%s_Top" % b.name) as CSGBox3D
		expect(top != null and absf(ReachMap._bounds(top).end.y - roof) < 0.01, "%s: a landing level with the roof" % b.name)
		# Decks at every storey along each wall it climbs.
		var walls := {}
		for f in flights:
			walls[f.toward_wall().snapped(Vector3.ONE * 0.01)] = true
		var decks: Array = main.level.get_node("FireEscapes").get_children().filter(func(n: Node) -> bool: return n.name.begins_with(b.name + "_Deck"))
		expect(decks.size() == walls.size() * (flights.size() - 1), "%s: a deck every storey on each of its %d walls, %d decks" % [b.name, walls.size(), decks.size()])
		expect(decks.all(func(d: CSGBox3D) -> bool: return d.material == IRON), "%s: iron decks" % b.name)
	expect(blocks.size() == 24 and not blocks.has("Museum"), "all 24 blocks but the museum's have one, %d do" % blocks.size())
	var round_corner := _buildings().filter(func(b: CSGShape3D) -> bool: return _walls_climbed(b) > 1)
	expect(round_corner.size() >= 5, "some go on round a corner, %d" % round_corner.size())


func test_fire_escape_stairs_are_a_way_up() -> void:
	var map := ReachMap.shared(main.level, SUPERHUMAN)
	var stairs := map.links.filter(func(l: ReachMap.Link) -> bool: return l.how == "fire escape stairs")
	var flights: Array = main.level.get_node("FireEscapes").find_children("*", "Stairs", false, false)
	expect(stairs.size() == flights.size(), "each of the %d flights leads up a storey, %d do" % [flights.size(), stairs.size()])
	for link: ReachMap.Link in stairs:
		expect_near(link.to.y - link.from.y, GENERATOR.STOREY, 0.05, "%s to %s: a storey" % [link.from.name, link.to.name])


func test_run_up_a_fire_escape_to_the_roof() -> void:
	# The tallest that goes round a corner, and the tallest (with free-run).
	var all := _buildings().filter(func(b: CSGShape3D) -> bool: return not _flights_of(b).is_empty())
	all.sort_custom(func(a: CSGShape3D, b: CSGShape3D) -> bool: return _flights_of(a).size() > _flights_of(b).size())
	var cornered: Array = all.filter(func(b: CSGShape3D) -> bool: return _walls_climbed(b) > 1)
	for run: Array in [[cornered[0], false], [all[0], true]]:
		var b: CSGShape3D = run[0]
		var roof := ReachMap._bounds(b).end.y
		expect(await _climb_fire_escape(b, run[1]), "should run up %s's fire escape (%d flights%s) to the roof, ended at %v" % [
				b.name, _flights_of(b).size(), ", free-running" if run[1] else "", player.global_position])
		expect(not &"WallRun" in states_entered and not &"Hang" in states_entered, "just running up the stairs, went %s" % [states_entered.slice(0, 10)])
		expect(player.global_position.y > roof - 0.2, "on the roof")


func test_no_wall_running_along_a_fire_escape_deck() -> void:
	# Free-running along a deck beside the wall, the next deck just overhead:
	# no room to run up the wall, so you just run (or jump) along it.
	var tried := 0
	for deck: Node in main.level.get_node("FireEscapes").get_children():
		if not (deck is CSGBox3D and deck.name.contains("_Deck") and deck.name.ends_with("_2")) or tried >= 3:
			continue
		var box := deck as CSGBox3D
		var b := main.level.get_node("Buildings/" + str(deck.name).get_slice("_Deck", 0)) as CSGShape3D
		var along_x := box.size.x > box.size.z
		var along := Vector3.RIGHT if along_x else Vector3.BACK
		var to_wall := _flat(b.global_position - box.global_position)
		to_wall = (Vector3(0, 0, signf(to_wall.z)) if along_x else Vector3(signf(to_wall.x), 0, 0))
		var length: float = box.size.x if along_x else box.size.z
		if length < 14.0:
			continue
		tried += 1
		var top := box.global_position.y + box.size.y / 2.0
		var start := box.global_position - along * (length / 2.0 - 2.0) + to_wall * (DECK_HUG)
		await place(Vector3(start.x, top + 0.05, start.z), yaw_for(along))
		states_entered.clear()
		Input.action_press(&"free_run")
		# Drifting into the wall a little, and jumping along the way.
		player.camera_rig.yaw = yaw_for(along.rotated(Vector3.UP, deg_to_rad(8.0) * signf(along.cross(to_wall).y)))
		for i in 75:
			await ticks(1)
			if i == 30:
				Input.action_press(&"jump")
		release_all()
		expect(not &"WallRun" in states_entered, "%s: no wall run along the deck, went %s" % [deck.name, states_entered.slice(0, 10)])
	expect(tried >= 2, "fire escape decks long enough to run along, %d" % tried)


# --- Helpers -----------------------------------------------------------------

func _buildings() -> Array[CSGShape3D]:
	var found: Array[CSGShape3D] = []
	for b: Node in main.level.get_node("Buildings").get_children():
		if b is CSGShape3D:
			found.append(b)
	return found


func _ledges_of(b: CSGShape3D) -> Array[Ledges]:
	var found: Array[Ledges] = []
	for row: Ledges in main.level.get_node("Ledges").get_children():
		if row.name.begins_with(b.name + "_Ledges"):
			found.append(row)
	return found


func _has_insides(b: CSGShape3D) -> bool:
	return b.get_children().any(func(c: Node) -> bool: return c is CSGShape3D and (c as CSGShape3D).operation == CSGShape3D.OPERATION_SUBTRACTION)


## An old-town stone wall with nothing in front of it for 6 m (the street).
func _street_row() -> Ledges:
	for row: Ledges in main.level.get_node("Ledges").get_children():
		if not row.name.begins_with("Block") or row.gaps.size() > 0:
			continue
		var piece: Vector2 = row.pieces()[0]
		var at := row.point_at((piece.x + piece.y) / 2.0, 1.0) + row.out_of_wall() * 0.6
		if player.raycast(at, at + row.out_of_wall() * 6.0).is_empty():
			return row
	return null


func _flights_of(b: CSGShape3D) -> Array[Stairs]:
	var found: Array[Stairs] = []
	var k := 1
	while main.level.has_node("FireEscapes/%s_Flight%d" % [b.name, k]):
		found.append(main.level.get_node("FireEscapes/%s_Flight%d" % [b.name, k]))
		k += 1
	return found


func _walls_climbed(b: CSGShape3D) -> int:
	var walls := {}
	for f in _flights_of(b):
		walls[f.toward_wall().snapped(Vector3.ONE * 0.01)] = true
	return walls.size()


## Runs up `b`'s fire escape from the street (steering along the flights, and
## along the decks round the corner), onto its roof. Says if you got there.
func _climb_fire_escape(b: CSGShape3D, free_run: bool) -> bool:
	var flights := _flights_of(b)
	var points: Array[Vector3] = []
	for k in flights.size():
		var f := flights[k]
		var up := _flat(f.top() - f.bottom()).normalized()
		if k > 0 and not flights[k - 1].toward_wall().is_equal_approx(f.toward_wall()):
			# Round the corner on the deck: in off the last flight, to the corner, along to this one.
			var before := flights[k - 1]
			var deck_out := before.toward_wall() * absf(before.landing_in)
			var then := f.bottom() + f.toward_wall() * absf(f.landing_in)
			var corner_at := before.top() + deck_out
			corner_at += _flat(before.top() - before.bottom()).normalized() * _flat(then - corner_at).dot(_flat(before.top() - before.bottom()).normalized())
			points.append(before.top() + deck_out + up * 0.0)
			points.append(corner_at)
			points.append(then)
		points.append(f.bottom() - up * 0.5)
		points.append(f.top() + up * 0.8)
	var roof := ReachMap._bounds(b)
	points.append(Vector3(roof.get_center().x, roof.end.y, roof.get_center().z))
	var start := flights[0].bottom() - _flat(flights[0].top() - flights[0].bottom()).normalized() * 6.0
	await place(Vector3(start.x, 0.05, start.z), yaw_for(_flat(points[0] - start)))
	states_entered.clear()
	Input.action_press(&"move_forward")
	if free_run:
		Input.action_press(&"free_run")
	var next := 0
	for i in 60 * 40:
		await ticks(1)
		var to := _flat(points[next] - player.global_position)
		if to.length() < 0.7 and next < points.size() - 1:
			next += 1
			to = _flat(points[next] - player.global_position)
		player.camera_rig.yaw = yaw_for(to)
		if player.is_on_floor() and player.global_position.y > roof.end.y - 0.2 and _footprint(b).has_point(Vector2(player.global_position.x, player.global_position.z)):
			release_all()
			return true
	release_all()
	return false


func _footprint(shape: CSGShape3D) -> Rect2:
	var box := ReachMap._bounds(shape)
	return Rect2(box.position.x, box.position.z, box.size.x, box.size.z)


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Way up in the sky (out of the city's way): a floor, and on it a stone wall
## 10 m wide with rows of ledges up its south face, `steps` apart (from the
## floor to each, and the last up to its top). Returns its root (free it after).
func _test_wall(steps: Array) -> Node3D:
	var root := Node3D.new()
	main.level.add_child(root)
	var ground := CSGBox3D.new()
	ground.size = Vector3(30.0, 1.0, 30.0)
	ground.position = Vector3(0.0, 500.0, 505.0)
	ground.use_collision = true
	root.add_child(ground)
	var heights := PackedFloat32Array()
	var height := 0.0
	for step: float in steps:
		height += step
		heights.append(height)
	heights.remove_at(heights.size() - 1) # (The last step is up to the top.)
	var wall := CSGBox3D.new()
	wall.size = Vector3(10.0, height, 4.0)
	wall.position = Vector3(0.0, 500.5 + height / 2.0, 498.0)
	wall.use_collision = true
	root.add_child(wall)
	var rows := Ledges.new()
	rows.position = Vector3(-5.0, 500.5, 500.0) # (+X along the wall, +Z out of it: south.)
	rows.length = 10.0
	rows.heights = heights
	rows.top = height
	root.add_child(rows)
	await ticks(3)
	return root
