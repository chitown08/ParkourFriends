extends GameTest
## Sloped roofs in the rooftop district (tools/gen_district.gd): old-town
## terraces of pitched-roof houses and sawtooth sheds. Free-run slides down
## the slopes for speed and hops on to the next one.

var states_entered: Array[StringName] = []


func before_each() -> void:
	main = MAIN_SCENE.instantiate()
	add_child(main)
	main.start_solo("rooftop_district")
	await ticks(5)
	player = main.get_node_or_null("Players/1")
	expect(player != null, "the game should have created a player")
	if player:
		player.set_profile(SUPERHUMAN)
		player.state_changed.connect(func(new_state: StringName) -> void: states_entered.append(new_state))


func test_some_roofs_are_pitched_and_some_are_sawtooth() -> void:
	var pitched := _roofs().filter(func(roof: CSGPolygon3D) -> bool: return "_House" in roof.name)
	var sawtooth := _roofs().filter(func(roof: CSGPolygon3D) -> bool: return not "_House" in roof.name)
	expect(pitched.size() >= 10, "there should be old-town houses about, %d" % pitched.size())
	expect(sawtooth.size() >= 3, "and some sawtooth sheds, %d" % sawtooth.size())
	for roof in _roofs():
		for p in roof.polygon:
			expect(p.y <= 4.0, "%s is too tall a roof (%.1f m)" % [roof.name, p.y])
		expect(roof.material == load("res://materials/grid_platform.tres"), "%s should be grey, like any building" % roof.name)


func test_nothing_is_put_on_a_sloped_roof() -> void:
	var things: Array[Node3D] = []
	for group in ["RoofClutter", "Checkpoints", "Relics", "FireEscapes"]:
		for child in main.level.get_node(group).get_children():
			things.append(child)
	for rail: GrindRail in main.level.get_node("GrindRails").get_children():
		things.append(rail)
	for roof in _roofs():
		var area := _roof_area(roof)
		for thing in things:
			var spot := Vector2(thing.global_position.x, thing.global_position.z)
			expect(not area.grow(0.5).has_point(spot), "%s shouldn't be on the sloped roof %s" % [thing.name, roof.name])
		var spawn: Vector3 = main.level.get_node("SpawnPoint").global_position
		expect(not area.has_point(Vector2(spawn.x, spawn.z)), "you shouldn't start on a sloped roof")


func test_free_run_slides_and_hops_along_an_old_town_terrace() -> void:
	var houses := _longest_terrace()
	expect(houses.size() >= 3, "there should be a terrace of three or more houses")
	var first: CSGPolygon3D = houses[0]
	var last: CSGPolygon3D = houses[-1]
	var axis := first.global_basis.x
	if (last.global_position - first.global_position).dot(axis) < 0.0:
		axis = -axis
	var start := _on_roof(first, _width(first) / 2.0) # Its ridge.
	var finish := (last.global_position - start).dot(axis) + _width(last) * 0.25
	var lowest := await _free_run_along(start, axis, finish, 60 * 8)
	expect(lowest > first.global_position.y - 0.3, "you shouldn't fall into a lane, lowest %.1f m (the eaves are at %.1f)" % [lowest, first.global_position.y])
	expect((player.global_position - start).dot(axis) > finish, "you should get to the far end of the terrace, %.1f of %.1f m" % [(player.global_position - start).dot(axis), finish])
	expect(&"Slide" in states_entered, "you should slide down the roofs, went through %s" % [states_entered])


func test_free_run_crosses_a_sawtooth_shed_either_way() -> void:
	var shed := _sawtooth_sheds()[0]
	var axis := shed.global_basis.x
	var length := _width(shed)
	var slid := false
	var skimmed := false
	for way in [1.0, -1.0]:
		var from_end := 1.5 if way > 0.0 else length - 1.5
		var start := _on_roof(shed, from_end)
		states_entered.clear()
		var finish := length - 3.0
		var lowest := await _free_run_along(start, axis * way, finish, 60 * 8)
		expect(lowest > shed.global_position.y - 0.3, "you shouldn't fall off the shed (%s), lowest %.1f m" % ["with the profile" if way > 0.0 else "against it", lowest])
		expect((player.global_position - start).dot(axis * way) > finish, "you should cross the shed (%s), got %.1f of %.1f m, went through %s" % ["with the profile" if way > 0.0 else "against it", (player.global_position - start).dot(axis * way), finish, states_entered])
		slid = slid or &"Slide" in states_entered
		skimmed = skimmed or &"Vault" in states_entered
	expect(slid and skimmed, "one way, you should slide down the long slopes and skim over the glass (slid %s, skimmed %s)" % [slid, skimmed])


func test_you_can_pull_yourself_up_from_hanging_off_a_sloped_roof() -> void:
	# The steepest house end on the outside of a terrace, and a sawtooth shed's
	# low end (the one whose slope rises gently from it).
	var steepest: CSGPolygon3D = null
	for roof in _roofs():
		if String(roof.name).ends_with("_House0_Roof") and (steepest == null or _pitch(roof) > _pitch(steepest)):
			steepest = roof
	var shed := _sawtooth_sheds()[0]
	var shed_end := 0.0 if shed.polygon[1].x > 1.0 else _width(shed)
	for eave: Array in [[steepest, 0.0], [shed, shed_end]]:
		var roof: CSGPolygon3D = eave[0]
		var along: float = eave[1]
		var out := -roof.global_basis.x if along == 0.0 else roof.global_basis.x
		var edge := _on_roof(roof, along)
		# Just below the edge, beside the wall, pushing into it: grab on as you drop.
		player.camera_rig.yaw = yaw_for(-out)
		player.global_position = edge + out * (player.body_radius + 0.15) + Vector3.DOWN * 1.6
		player.velocity = Vector3.ZERO
		player.change_state(&"Air")
		player.reset_physics_interpolation()
		Input.action_press(&"move_forward")
		for i in 60:
			await ticks(1)
			if player.state.name == &"Hang":
				break
		release_all()
		expect(player.state.name == &"Hang", "should catch hold of %s's edge, %s" % [roof.name, player.state.name])
		await tap(&"jump")
		for i in 60:
			await ticks(1)
			if player.state.name == &"Ground":
				break
		expect(player.is_on_floor() and player.global_position.y > edge.y - 0.1 and (player.global_position - edge).dot(-out) > 0.2,
				"should pull up onto %s (%.0f° slope), ended at %v in %s" % [roof.name, rad_to_deg(atan(_pitch(roof))), player.global_position, player.state.name])


## How steeply `roof` rises from its start (metres up per metre along).
func _pitch(roof: CSGPolygon3D) -> float:
	return roof.polygon[1].y / roof.polygon[1].x


## Free-runs from `start` along `axis` until you're `finish` metres along (on
## the floor). Returns the lowest your feet got.
func _free_run_along(start: Vector3, axis: Vector3, finish: float, max_ticks: int) -> float:
	await place(start + Vector3.UP * 0.1, yaw_for(axis))
	Input.action_press(&"free_run")
	var lowest := INF
	for i in max_ticks:
		await ticks(1)
		lowest = minf(lowest, player.global_position.y)
		if (player.global_position - start).dot(axis) > finish and player.is_on_floor():
			break
	release_all()
	return lowest


func _roofs() -> Array[CSGPolygon3D]:
	var found: Array[CSGPolygon3D] = []
	for child in main.level.get_node("Roofs").get_children():
		found.append(child as CSGPolygon3D)
	return found


## The houses (their roofs) of the terrace with the most houses, in order.
func _longest_terrace() -> Array:
	var terraces := {}
	for roof in _roofs():
		if "_House" in roof.name:
			var building := String(roof.name).get_slice("_House", 0)
			if not terraces.has(building):
				terraces[building] = []
			terraces[building].append(roof)
	var best: Array = []
	for building: String in terraces:
		if terraces[building].size() > best.size():
			best = terraces[building]
	best.sort_custom(func(a: CSGPolygon3D, b: CSGPolygon3D) -> bool:
			return int(String(a.name).get_slice("_House", 1)) < int(String(b.name).get_slice("_House", 1)))
	return best


func _sawtooth_sheds() -> Array[CSGPolygon3D]:
	var found: Array[CSGPolygon3D] = []
	for roof in _roofs():
		if not "_House" in roof.name:
			found.append(roof)
	return found


## How long a roof's outline is (along the building).
func _width(roof: CSGPolygon3D) -> float:
	var widest := 0.0
	for p in roof.polygon:
		widest = maxf(widest, p.x)
	return widest


## The point on `roof`'s surface `along` metres along its outline, midway across it.
func _on_roof(roof: CSGPolygon3D, along: float) -> Vector3:
	var outline := roof.polygon
	var height := 0.0
	for i in outline.size() - 1:
		var a := outline[i]
		var b := outline[i + 1]
		if along >= minf(a.x, b.x) and along <= maxf(a.x, b.x) and absf(b.x - a.x) > 0.001:
			height = lerpf(a.y, b.y, (along - a.x) / (b.x - a.x))
	return roof.global_position + roof.global_basis.x * along - roof.global_basis.z * roof.depth / 2.0 + Vector3.UP * height


## A roof's footprint, seen from above.
func _roof_area(roof: CSGPolygon3D) -> Rect2:
	var a := roof.global_position
	var b := a + roof.global_basis.x * _width(roof) - roof.global_basis.z * roof.depth
	return Rect2(Vector2(a.x, a.z), Vector2.ZERO).expand(Vector2(b.x, b.z))
