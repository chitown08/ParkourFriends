extends GameTest
## Downtown: tall modern towers packed close, east of the old town across the
## boulevard (tools/gen_district.gd: DOWNTOWN_WIDTH): scaffolding up them
## (levels/scaffold.gd), grind rails and rope bridges across the gaps, catch
## nets (levels/catch_net.gd) under the roofs, walkways between insides.

const GENERATOR := preload("res://tools/gen_district.gd")

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


func test_downtown_is_across_the_boulevard_and_packed_close() -> void:
	var towers := _towers()
	expect(towers.size() >= 25, "lots of towers downtown, %d" % towers.size())
	var old_town := _old_town()
	for tower in towers:
		var box := ReachMap._bounds(tower)
		expect(box.position.x >= old_town.end.x + GENERATOR.AVENUE - 0.1,
				"%s is east of the old town, across the boulevard (%.0f; the old town ends at %.0f)" % [tower.name, box.position.x, old_town.end.x])
	# Each tower's nearest neighbour is an alley or a street away: jump it, or leap it.
	var widest := 0.0
	for tower in towers:
		var nearest := INF
		var mine := _footprint(tower)
		for other in towers:
			if other != tower:
				nearest = minf(nearest, _rect_gap(mine, _footprint(other)))
		widest = maxf(widest, nearest)
		expect(nearest >= GENERATOR.ALLEY - 0.1 and nearest <= GENERATOR.STREET + 0.1, "%s is %.1f m from the next tower" % [tower.name, nearest])
	var ground := ReachMap._bounds(main.level.get_node("Street/Ground"))
	expect(ground.end.x > towers.map(func(t: CSGShape3D) -> float: return ReachMap._bounds(t).end.x).max() + 10.0, "and the street runs on under them")


func test_towers_rise_to_the_spire() -> void:
	var spire := _top(main.level.get_node("Buildings/Spire"))
	expect(spire.end.y >= 130.0, "the spire is %.0f m tall" % spire.end.y)
	var heights: Array[float] = []
	for tower in _towers():
		var top := _top(tower).end.y
		heights.append(top)
		expect(top >= 12 * GENERATOR.STOREY - 0.1, "%s is a tower, %.0f m" % [tower.name, top])
		if tower.name.begins_with("Tower0_"):
			expect(top <= GENERATOR.EDGE_STOREYS * GENERATOR.STOREY + 0.1, "%s, by the boulevard, steps up from the old town (%.0f m)" % [tower.name, top])
	expect(heights.max() == spire.end.y, "the spire is tallest of all")
	for b: Node in main.level.get_node("Buildings").get_children():
		if b is CSGShape3D and not (b in _towers()):
			expect(ReachMap._bounds(b).end.y < spire.end.y - 60.0, "%s is well under the spire" % b.name)
	# Some have a lower part (a wing, or the spire's terrace), with a drainpipe up from it.
	var stepped := _towers().filter(func(t: CSGShape3D) -> bool: return t.has_node("Upper"))
	expect(stepped.size() >= 6, "some towers step up from a lower part, %d" % stepped.size())
	for tower: CSGShape3D in stepped:
		var pipe := main.level.get_node_or_null("WaysUp/%s_Pipe" % tower.name) as Drainpipe
		expect(pipe != null and absf(pipe.global_position.y - ReachMap._bounds(tower).end.y) < 0.1 \
				and absf(pipe.top() - ReachMap._bounds(tower.get_node("Upper")).end.y) < 0.1,
				"%s: a drainpipe from its lower roof to its top" % tower.name)


func test_nothing_sci_fi() -> void:
	var area := _downtown_area()
	for vent: AirVent in main.level.get_node("AirVents").get_children():
		expect(not area.has_point(Vector2(vent.global_position.x, vent.global_position.z)), "no sky lifts downtown (%s)" % vent.name)
	for thing: Node in main.level.get_node("Bridges").get_children():
		expect(thing.name.begins_with("RopeBridge") or thing.name.begins_with("Walkway"), "%s: no long glass bridges, just rope bridges and walkways" % thing.name)


func test_every_tower_top_alone() -> void:
	var map := ReachMap.build(main.level, SUPERHUMAN)
	var alone := map.solve(map.place_under(main.level.get_node("SpawnPoint").global_position + Vector3.UP), 1)
	for tower in _towers():
		var top: CSGShape3D = tower.get_node("Upper") if tower.has_node("Upper") else tower
		var name := "%s/Upper" % tower.name if top != tower else str(tower.name)
		var tops := _places(map, name).filter(func(spot: ReachMap.Spot) -> bool: return absf(spot.y - ReachMap._bounds(top).end.y) < 0.1)
		expect(not tops.is_empty() and tops.any(func(spot: ReachMap.Spot) -> bool: return alone.has(spot)), "%s's top: you can get there alone" % tower.name)


func test_scaffolding_up_every_glass_tower_from_the_street() -> void:
	# (Stone towers have rows of ledges instead: tests/test_facades.gd.)
	var map := ReachMap.build(main.level, SUPERHUMAN)
	var ground := map.place_named("Ground")
	var grabbed := 0
	var stone := load("res://materials/stone.tres")
	for tower in _towers():
		var scaffold := main.level.get_node_or_null("WaysUp/%s_Scaffold" % tower.name) as Scaffold
		var has_insides := tower.get_children().any(func(c: Node) -> bool: return c is CSGShape3D and (c as CSGShape3D).operation == CSGShape3D.OPERATION_SUBTRACTION)
		if tower.material == stone and not has_insides:
			expect(scaffold == null, "%s is stone: no scaffolding" % tower.name)
			continue
		expect(scaffold != null, "%s has scaffolding" % tower.name)
		if scaffold == null:
			continue
		expect(absf(scaffold.global_position.y) < 0.01, "%s's stands in the street" % tower.name)
		expect(Scaffold.MATERIAL == load("res://materials/grid_climb.tres"), "and it's yellow (climb)")
		var roof := map.place_under(Vector3(scaffold.global_position.x, scaffold.top() + 0.5, scaffold.global_position.z) - scaffold.out_of_wall())
		expect(roof != null and absf(roof.y - scaffold.top()) < 0.1 and roof.name.begins_with(str(tower.name)),
				"%s's goes up to its roof (%s)" % [tower.name, roof.name if roof else "none"])
		expect(map.links.any(func(link: ReachMap.Link) -> bool: return link.from == ground and link.to == roof and link.how == "scaffolding"),
				"%s's: up it from the street" % tower.name)
		if map.links.any(func(link: ReachMap.Link) -> bool: return link.to == roof and link.how.begins_with("scaffolding (grabbed")):
			grabbed += 1
	expect(grabbed >= 10, "most of them you can jump onto from a lower roof next door, %d" % grabbed)


func test_jump_across_a_gap_onto_scaffolding_and_climb_it() -> void:
	var map := ReachMap.build(main.level, SUPERHUMAN)
	# A running jump (not a leap) from a roof across an alley, too low to grab the top from.
	var picked: ReachMap.Link
	var scaffold: Scaffold
	for link in map.links:
		if link.how != "scaffolding (grabbed from a jump)" or link.to.y - link.from.y < 7.0 or not link.from.name.begins_with("Tower"):
			continue
		for s: Scaffold in main.level.get_node("WaysUp").find_children("*", "Scaffold", false, false):
			if map.place_under(Vector3(s.global_position.x, s.top() + 0.5, s.global_position.z) - s.out_of_wall()) == link.to \
					and ReachMap._distance_to(link.from.area, Vector2(s.global_position.x, s.global_position.z)) < GENERATOR.ALLEY + 0.5:
				picked = link
				scaffold = s
		if picked:
			break
	expect(picked != null, "a lower roof across an alley from scaffolding")
	if picked == null:
		return
	var out := scaffold.out_of_wall()
	# Off to one side of its middle: you can grab it anywhere across its face.
	var across := Vector3(out.z, 0.0, -out.x)
	var face := scaffold.point_at(picked.from.y) + across * 1.1
	var edge := ReachMap._closest_in(picked.from.area, Vector2(face.x, face.z))
	await place(Vector3(edge.x, picked.from.y + 0.05, edge.y) + out * 4.0, yaw_for(-out))
	states_entered.clear()
	Input.action_press(&"move_forward")
	var jumped := false
	for i in 60 * 30:
		await ticks(1)
		if not jumped and (player.global_position - Vector3(edge.x, 0.0, edge.y)).dot(-out) > -0.6:
			Input.action_press(&"jump")
			jumped = true
		if player.is_on_floor() and player.global_position.y > scaffold.top() - 0.3:
			break
	release_all()
	expect(&"PipeClimb" in states_entered, "grabbed the scaffolding mid-jump (went %s)" % [states_entered.slice(0, 8)])
	expect(player.is_on_floor() and player.global_position.y > scaffold.top() - 0.3,
			"and climbed it to the top, %.0f m (from %s, at %s)" % [scaffold.top(), picked.from.name, player.global_position])


func test_grind_rails_run_down_across_gaps() -> void:
	var rails: Array = main.level.get_node("GrindRails").get_children().filter(func(r: Node) -> bool: return r.name.begins_with("RailTower") or r.name.begins_with("RailSpire"))
	expect(rails.size() == GENERATOR.RAILS, "%d grind rails downtown" % rails.size())
	var map := ReachMap.build(main.level, SUPERHUMAN)
	for rail: GrindRail in rails:
		var drop := rail.top().y - rail.bottom().y
		expect(drop >= GENERATOR.RAIL_DROP.x * GENERATOR.STOREY - 0.1 and drop <= GENERATOR.RAIL_DROP.y * GENERATOR.STOREY + 0.1, "%s drops %.1f m" % [rail.name, drop])
		expect(rad_to_deg(atan(drop / Vector2(rail.top().x - rail.bottom().x, rail.top().z - rail.bottom().z).length())) < 35.0, "%s isn't too steep" % rail.name)
		expect(map.links.any(func(link: ReachMap.Link) -> bool: return link.how == "grind rail" and link.from.y - link.to.y > 3.0 \
				and absf(link.from.y - (rail.top().y - GENERATOR.RAIL_ABOVE)) < 0.1), "%s: on it from the higher roof, down to the lower" % rail.name)


func test_rope_bridges_join_towers_across_streets() -> void:
	var map := ReachMap.build(main.level, SUPERHUMAN)
	var decks := _rope_bridges()
	expect(decks.size() == GENERATOR.ROPE_BRIDGES, "%d rope bridges" % decks.size())
	for part: Node in main.level.get_node("Bridges").get_children():
		if part.name.begins_with("RopeBridge"):
			expect((part as CSGBox3D).material == CatchNet.MATERIAL, "%s is rope netting" % part.name)
			expect((part as CSGBox3D).use_collision == not part.name.contains("_Rope"), "%s: you walk on its deck, not its hand-ropes" % part.name)
	for deck in decks:
		var ends := _two_towers(str(deck.name).trim_prefix("RopeBridge"))
		var on_it := map.place_named(str(deck.name))
		expect(on_it != null, "%s: you can stand on it" % deck.name)
		if on_it == null:
			continue
		var between := func(from: String, to: String) -> bool:
			return map.links.any(func(link: ReachMap.Link) -> bool: return link.from.name.begins_with(from) and link.to == on_it) \
				and map.links.any(func(link: ReachMap.Link) -> bool: return link.from == on_it and link.to.name.begins_with(to))
		expect(between.call(ends[0], ends[1]) and between.call(ends[1], ends[0]), "%s: from %s across to %s, and back" % [deck.name, ends[0], ends[1]])
		for rope in 2:
			var middle := main.level.get_node("Bridges/%s_Rope%d_%d" % [deck.name, rope + 1, GENERATOR.ROPE_SEGMENTS / 2]) as CSGBox3D
			var end := main.level.get_node("Bridges/%s_Rope%d_1" % [deck.name, rope + 1]) as CSGBox3D
			expect(middle.global_position.y < end.global_position.y - 0.2, "%s: its hand-ropes sag" % deck.name)


func test_walk_across_a_rope_bridge() -> void:
	var deck := _rope_bridges()[0]
	var flat := Vector3.RIGHT if deck.size.x > deck.size.z else Vector3.BACK
	var length := maxf(deck.size.x, deck.size.z)
	var top := deck.global_position.y + deck.size.y / 2.0
	var start := deck.global_position - flat * (length / 2.0 + 2.0)
	var end := deck.global_position + flat * (length / 2.0 + 2.0)
	await place(Vector3(start.x, top + 0.05, start.z), yaw_for(flat))
	Input.action_press(&"move_forward")
	var made_it := false
	for i in 60 * 8:
		await ticks(1)
		if (player.global_position - end).dot(flat) > 0.0 and player.is_on_floor() and absf(player.global_position.y - top) < 0.2:
			made_it = true
			break
	release_all()
	expect(made_it, "walked across %s (at %s)" % [deck.name, player.global_position])


func test_catch_nets_hang_out_over_alleys_under_a_roof() -> void:
	var nets: Array = main.level.get_node("Nets").get_children()
	expect(nets.size() == GENERATOR.NETS, "%d catch nets" % nets.size())
	var map := ReachMap.build(main.level, SUPERHUMAN)
	for net: CatchNet in nets:
		var out := net.out_of_wall()
		var far := net.global_position + out * (net.size.y + 1.3) + Vector3.DOWN * 0.5
		expect(map.is_solid(far), "%s reaches nearly across its alley" % net.name)
		var roof := map.place_under(net.global_position - out * 1.0 + Vector3.UP * (net.rise + 1.0))
		expect(roof != null and absf(roof.y - net.global_position.y - GENERATOR.NET_BELOW * GENERATOR.STOREY) < 0.1, "%s is %d storeys under its roof" % [net.name, GENERATOR.NET_BELOW])
		var on := map.place_under(net.global_position + out * net.size.y / 2.0 + Vector3.UP * 0.5)
		expect(map.links.any(func(link: ReachMap.Link) -> bool: return link.from == on and link.to == roof and link.how == "catch net"), "%s bounces you back up to it" % net.name)
	expect(CatchNet.MATERIAL == load("res://materials/net.tres"), "nets are rope (rainbow netting)")


func test_fall_into_a_catch_net_and_bounce_back_onto_the_roof() -> void:
	var net := main.level.get_node("Nets").get_child(0) as CatchNet
	var out := net.out_of_wall()
	var roof := net.global_position.y + GENERATOR.NET_BELOW * GENERATOR.STOREY
	# Falling past the roof's edge (a jump across the alley that fell short), facing the wall.
	release_all()
	player.global_position = net.global_position + out * net.size.y / 2.0 + Vector3.UP * (GENERATOR.NET_BELOW * GENERATOR.STOREY + 2.0)
	player.velocity = Vector3.ZERO
	player.change_state(&"Air")
	player.reset_physics_interpolation()
	player.camera_rig.yaw = yaw_for(-out)
	var lowest := INF
	var bounced := false
	var peak := -INF # (Of the bounce itself: up to where it starts coming down.)
	for i in 60 * 6:
		await ticks(1)
		lowest = minf(lowest, player.global_position.y)
		if bounced and peak == -INF and player.velocity.y <= 0.0:
			peak = player.global_position.y
		if not bounced and player.velocity.y > 5.0 and lowest < roof - 5.0:
			bounced = true
			Input.action_press(&"move_forward") # In toward the wall.
		if player.state.name == &"Hang":
			Input.action_press(&"jump")
		if bounced and player.is_on_floor() and player.global_position.y > roof - 0.2:
			break
	release_all()
	expect(lowest < roof - GENERATOR.NET_BELOW * GENERATOR.STOREY + 1.0 and lowest > net.global_position.y - 0.5, "fell into the net (down to %.1f; the net's at %.1f)" % [lowest, net.global_position.y])
	expect(peak > roof - 0.1, "the bounce alone throws you up over the roof's edge (to %.1f; the roof's at %.1f)" % [peak, roof])
	expect(bounced and player.is_on_floor() and player.global_position.y > roof - 0.2, "and it bounced you back onto the roof, %.0f m (at %s, %s)" % [roof, player.global_position, player.state.name])


func test_walkways_join_two_towers_insides() -> void:
	var map := ReachMap.build(main.level, SUPERHUMAN)
	var alone := map.solve(map.place_under(main.level.get_node("SpawnPoint").global_position + Vector3.UP), 1)
	var walkways: Array = main.level.get_node("Bridges").get_children().filter(func(p: Node) -> bool:
			return p.name.begins_with("Walkway") and not p.name.contains("_Roof") and not p.name.contains("_Glass"))
	expect(walkways.size() == GENERATOR.WALKWAYS, "%d walkways" % walkways.size())
	for walkway: CSGBox3D in walkways:
		var names := _two_towers(str(walkway.name).trim_prefix("Walkway"))
		var a: String = names[0]
		var b: String = names[1]
		var deck := map.place_named(str(walkway.name))
		var rooms := [map.place_named(a + "/Room"), map.place_named(b + "/Room")]
		expect(deck != null and rooms.all(func(r: ReachMap.Spot) -> bool: return r != null and absf(r.y - deck.y) < 0.1),
				"%s: a floor inside each tower, level with it" % walkway.name)
		if deck == null or rooms.has(null):
			continue
		for room: ReachMap.Spot in rooms:
			expect(map.links.any(func(l: ReachMap.Link) -> bool: return l.from == room and l.to == deck) \
					and map.links.any(func(l: ReachMap.Link) -> bool: return l.from == deck and l.to == room), "%s: between it and %s, both ways" % [walkway.name, room.name])
		expect(alone.has(deck), "%s: you can get there alone" % walkway.name)
		# In from a lower roof next door, across an alley, level with the floor.
		expect(map.links.any(func(l: ReachMap.Link) -> bool: return l.to in rooms and l.from.name.begins_with("Tower") and not l.from.name.contains("/") \
				and absf(l.from.y - deck.y) < 0.1 and l.how in ["jump", "leap"]), "%s: jump in from a roof beside it" % walkway.name)
		expect(main.level.get_node("Bridges/%s_Glass1" % walkway.name).material == load("res://materials/glass.tres"), "%s has glass sides" % walkway.name)


func test_jump_from_a_roof_into_a_walkway_floor() -> void:
	var map := ReachMap.build(main.level, SUPERHUMAN)
	var walkway: Node = main.level.get_node("Bridges").get_children().filter(func(p: Node) -> bool: return p.name.begins_with("Walkway"))[0]
	var names := _two_towers(str(walkway.name).trim_prefix("Walkway"))
	var rooms := [map.place_named(names[0] + "/Room"), map.place_named(names[1] + "/Room")]
	var links := map.links.filter(func(l: ReachMap.Link) -> bool: return l.to in rooms and l.how in ["jump", "leap"] and l.from.name.begins_with("Tower") and not l.from.name.contains("/"))
	expect(not links.is_empty(), "a roof to jump in from")
	if links.is_empty():
		return
	links.sort_custom(func(a: ReachMap.Link, b: ReachMap.Link) -> bool: return a.how == "jump" and b.how != "jump") # (Across the alley first.)
	var link: ReachMap.Link = links[0]
	# Run at the room square on, from the roof's edge nearest it.
	var room: Rect2 = link.to.area
	var from: Rect2 = link.from.area
	var way := Vector2.ZERO
	if from.end.x <= room.position.x: way = Vector2.RIGHT
	elif from.position.x >= room.end.x: way = Vector2.LEFT
	elif from.end.y <= room.position.y: way = Vector2.DOWN
	else: way = Vector2.UP
	var opening := _opening_toward(link.to.node.get_parent(), Vector3(-way.x, 0.0, -way.y), link.to.y)
	expect(opening != Vector3.INF, "an opening in that wall")
	if opening == Vector3.INF:
		return
	var edge := ReachMap._closest_in(from, Vector2(opening.x, opening.z))
	var flat := Vector3(way.x, 0.0, way.y)
	await place(Vector3(edge.x, link.from.y + 0.05, edge.y) - flat * 3.0, yaw_for(flat)) # (Clutter keeps further back.)
	states_entered.clear()
	Input.action_press(&"move_forward")
	var leap := link.how == "leap"
	if leap: # (Free-running, holding jump: a readied leap, taking off at the edge.)
		Input.action_press(&"free_run")
		await ticks(3)
		Input.action_press(&"jump")
	var jumped := leap
	var made_it := false
	for i in 60 * 6:
		await ticks(1)
		if not jumped and (player.global_position - Vector3(edge.x, 0.0, edge.y)).dot(flat) > -0.6:
			Input.action_press(&"jump")
			jumped = true
		if player.is_on_floor() and room.has_point(Vector2(player.global_position.x, player.global_position.z)) and absf(player.global_position.y - link.to.y) < 0.3:
			made_it = true
			break
	release_all()
	expect(made_it, "%s from %s across into %s (at %s, went %s)" % [link.how, link.from.name, link.to.name, player.global_position, states_entered.slice(0, 10)])


# --- Helpers ----------------------------------------------------------------------------

## The two towers' names in "<one>_<other>" (each "Spire" or "Tower<column>_<row>").
static func _two_towers(names: String) -> Array[String]:
	var first := "Spire" if names.begins_with("Spire") else names.substr(0, names.find("_", names.find("_") + 1))
	return [first, names.substr(first.length() + 1)]


## A tower's top part, or all of it (from above, and up).
func _top(tower: CSGShape3D) -> AABB:
	return ReachMap._bounds(tower.get_node("Upper") if tower.has_node("Upper") else tower)


## Downtown's towers (the buildings named Tower..., and the spire).
func _towers() -> Array[CSGShape3D]:
	var found: Array[CSGShape3D] = []
	for b: Node in main.level.get_node("Buildings").get_children():
		if b is CSGShape3D and (b.name.begins_with("Tower") or b.name == "Spire"):
			found.append(b)
	return found


## The old town, from above (every building but downtown's).
func _old_town() -> AABB:
	var box := AABB()
	var first := true
	var towers := _towers()
	for b: Node in main.level.get_node("Buildings").get_children():
		if b is CSGShape3D and not (b in towers):
			box = ReachMap._bounds(b) if first else box.merge(ReachMap._bounds(b))
			first = false
	return box


func _downtown_area() -> Rect2:
	var area := Rect2()
	var first := true
	for tower in _towers():
		area = _footprint(tower) if first else area.merge(_footprint(tower))
		first = false
	return area


func _footprint(shape: CSGShape3D) -> Rect2:
	var box := ReachMap._bounds(shape)
	return Rect2(box.position.x, box.position.z, box.size.x, box.size.z)


func _rect_gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var dz := maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	return Vector2(dx, dz).length()


## The places called `name` or pieces of it (`name#2`...).
func _places(map: ReachMap, name: String) -> Array:
	return map.places.filter(func(spot: ReachMap.Spot) -> bool: return spot.name == name or spot.name.begins_with(name + "#"))


## The middle (at floor level `y`) of an opening cut in `building`'s wall facing `out`, or INF.
func _opening_toward(building: CSGShape3D, out: Vector3, y: float) -> Vector3:
	var box := ReachMap._bounds(building)
	for cut: Node in building.get_children():
		if not (cut is CSGBox3D and (cut as CSGBox3D).operation == CSGShape3D.OPERATION_SUBTRACTION and str(cut.name).begins_with("Opening")):
			continue
		var at := (cut as CSGBox3D).global_position
		var wall := box.get_center() + Vector3(out.x * box.size.x, 0.0, out.z * box.size.z) / 2.0
		if absf((at - wall).dot(out)) < 1.0:
			return Vector3(at.x, y, at.z)
	return Vector3.INF


## The rope bridges' decks.
func _rope_bridges() -> Array[CSGBox3D]:
	var found: Array[CSGBox3D] = []
	for part: Node in main.level.get_node("Bridges").get_children():
		if part.name.begins_with("RopeBridge") and not part.name.contains("_Rope"):
			found.append(part)
	return found


func test_busy_roofs_still_leave_room_to_land() -> void:
	var on_towers := 0
	for thing: CSGBox3D in main.level.get_node("RoofClutter").get_children():
		if not (thing.name.begins_with("Tower") or thing.name.begins_with("Spire")):
			continue
		on_towers += 1
		var tower := main.level.get_node("Buildings/" + str(thing.name).get_slice("_Vault", 0).get_slice("_Hut", 0).trim_suffix("Wing")) as CSGShape3D
		var top: CSGShape3D = tower.get_node("Upper") if tower.has_node("Upper") and not str(thing.name).contains("Wing_") else tower
		var roof := ReachMap._bounds(top)
		var feet := thing.global_position.y - thing.size.y / 2.0
		expect(absf(feet - roof.end.y) < 0.05, "%s stands on %s's roof" % [thing.name, tower.name])
		var footprint := Rect2(thing.global_position.x - thing.size.x / 2.0, thing.global_position.z - thing.size.z / 2.0, thing.size.x, thing.size.z)
		expect(_footprint(top).grow(-GENERATOR.DOWNTOWN_EDGE_CLEAR + 0.01).encloses(footprint), "%s keeps %.1f m from the edges, to land jumps" % [thing.name, GENERATOR.DOWNTOWN_EDGE_CLEAR])
	expect(on_towers >= 50, "the roofs are busy, %d things on them" % on_towers)
