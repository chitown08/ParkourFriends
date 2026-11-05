extends GameTest
## The rooftop district (built by tools/gen_district.gd), played with free-run
## and the superhuman profile. Gaps between buildings come in three sizes:
## alleys (5 m), streets (10 m) and avenues (24 m).

const LANE := 1.5 ## Between some of the houses in an old-town terrace.
const ALLEY := 5.0
const STREET := 10.0
const AVENUE := 24.0
const STOREY := 3.5

## Every state the player has entered since the test began, in order.
var states_entered: Array[StringName] = []
## From the last _free_run_over(): your highest feet, your speed running up to
## the thing, and your slowest just past it.
var _highest := -INF
var _speed_at_it := 0.0
var _slowest_past := INF


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


func test_its_the_default_world() -> void:
	expect(main.DEFAULT_WORLD == "rooftop_district", "the menu should start on the district")


func test_you_start_on_a_roof() -> void:
	await ticks(30)
	expect(player.is_on_floor(), "should be standing")
	var roof := _building_under(player.global_position)
	expect(roof != null, "should be standing on a building")
	expect(player.global_position.y > 10.0, "should be up high, at %.1f m" % player.global_position.y)


func test_every_gap_is_an_alley_a_street_or_an_avenue() -> void:
	var odd := []
	var counts := {LANE: 0, ALLEY: 0, STREET: 0, AVENUE: 0}
	var buildings := _buildings()
	for i in buildings.size():
		for j in range(i + 1, buildings.size()):
			var gap := _facing_gap(buildings[i], buildings[j])
			if gap < 0.0:
				continue
			var size := _gap_size(gap)
			if size > 0.0:
				counts[size] += 1
			else:
				odd.append("%s-%s %.2f m" % [buildings[i].name, buildings[j].name, gap])
	expect(odd.is_empty(), "gaps should only be 1.5 (between old-town houses), 5, 10 or 24 m: %s" % [odd])
	for size: float in counts:
		expect(counts[size] > 0, "there should be at least one %d m gap" % size)


func test_alleys_never_step_up_more_than_two_storeys() -> void:
	var too_tall := []
	var buildings := _buildings()
	for a in buildings:
		for b in buildings:
			if _is_tower(a) or _is_tower(b) or _gap_size(_facing_gap(a, b)) != ALLEY:
				continue
			var step := _top(b) - _top(a)
			if step > 7.01:
				too_tall.append("%s to %s: %.1f m" % [a.name, b.name, step])
	expect(too_tall.is_empty(), "alley steps should be 7 m (two storeys) or less: %s" % [too_tall])


func test_free_run_jumps_an_alley() -> void:
	expect(await _run_across(ALLEY, false, 25.0), "free-run should clear an alley")


func test_free_run_clears_a_street_with_a_long_run_up() -> void:
	expect(await _run_across(STREET, false, 25.0), "with flow built up, a plain jump should clear a street")


func test_from_a_short_run_up_a_street_needs_a_leap() -> void:
	expect(not await _run_across(STREET, false, 8.0), "from 8 m back, a plain jump should fall short")
	expect(await _run_across(STREET, true, 8.0), "but a readied leap should make it")


func test_falling_into_the_street_and_r_brings_you_back() -> void:
	await place(Vector3(0, 0.05, 0), FACE_NORTH) # The plaza.
	expect(player.is_on_floor() and player.global_position.y < 0.5, "should be in the plaza")
	await press_event(&"respawn")
	await ticks(5)
	expect(player.global_position.y > 10.0, "R should take you back up to a roof checkpoint")


func test_a_two_storey_alley_step_can_be_leapt_up() -> void:
	var pair := _pair_across(ALLEY, 2.0 * STOREY)
	expect(not pair.is_empty(), "the district should have a two-storey alley step to test")
	if pair.is_empty():
		return
	expect(await _run_across_pair(pair, true, 20.0), "a readied leap should get you up a two-storey step")


func test_rails_cross_the_avenues_downhill_onto_a_lower_roof() -> void:
	var rails := _avenue_rails()
	expect(rails.size() >= 6, "there should be rails across the avenues, %d" % rails.size())
	for rail: GrindRail in rails:
		var landing := _building_under(rail.bottom() + Vector3.DOWN * 0.7)
		expect(landing != null, "%s should end over a roof" % rail.name)
		var start := _building_under(rail.top() + Vector3.UP * 0.4 - _flat(rail.bottom() - rail.top()).normalized() * 2.0)
		expect(start != null, "%s should start just off a roof" % rail.name)
		if start and landing:
			expect(_top(start) > _top(landing), "%s should go from a taller roof to a lower one" % rail.name)


func test_running_off_a_roof_rides_a_rail_over_the_avenue() -> void:
	var rail: GrindRail = _avenue_rails()[0]
	var way := _flat(rail.bottom() - rail.top()).normalized()
	var landing := _building_under(rail.bottom() + Vector3.DOWN * 0.7)
	await place(rail.top() + Vector3.UP * 0.45 - way * 8.0, yaw_for(way))
	Input.action_press(&"move_forward")
	var grinding := false
	var landed := false
	for i in 60 * 8:
		await ticks(1)
		grinding = grinding or player.state.name == &"Grind"
		if grinding and player.is_on_floor() and _building_under(player.global_position) == landing:
			landed = true
			break
	release_all()
	expect(grinding, "should land on %s" % rail.name)
	expect(landed, "and ride it onto %s, ended at %v" % [landing.name, player.global_position])


func test_jump_on_a_rail_from_the_lower_roof_and_climb_it_back_up() -> void:
	# Stand under the low end, jump onto it facing up, and keep pushing.
	var rail: GrindRail = _avenue_rails()[0]
	var up := _flat(rail.top() - rail.bottom()).normalized()
	var start := _building_under(rail.top() + Vector3.UP * 0.4 + up * 2.0)
	var under := rail.bottom() + up * 1.5
	await place(Vector3(under.x, _top(_building_under(under)) + 0.05, under.z), yaw_for(up))
	await ticks(10)
	Input.action_press(&"move_forward")
	await tap(&"jump")
	var grinding := false
	var on_top := false
	for i in 60 * 10:
		await ticks(1)
		grinding = grinding or player.state.name == &"Grind"
		if grinding and player.is_on_floor() and _building_under(player.global_position) == start:
			on_top = true
			break
	release_all()
	expect(grinding, "should land on %s" % rail.name)
	expect(on_top, "and climb it up onto %s, ended at %v" % [start.name, player.global_position])


func test_clutter_colour_says_what_its_for() -> void:
	# Red is low enough to vault, yellow is a climb, grey huts are just in the way.
	var vault := load("res://materials/grid_vault.tres")
	var climb := load("res://materials/grid_climb.tres")
	var things := _clutter()
	expect(things.size() > 280, "roofs and pavements should be cluttered, %d things" % things.size())
	for thing in things:
		if thing.material == vault:
			expect(thing.size.y <= 1.3, "%s is red, so it should be low enough to vault (%.1f m)" % [thing.name, thing.size.y])
		elif thing.material == climb:
			expect(thing.size.y <= 3.0, "%s is yellow, so it should be climbable from a jump (%.1f m)" % [thing.name, thing.size.y])
		else:
			expect("Hut" in thing.name, "%s is grey, so it should be a stairwell hut" % thing.name)


func test_roof_clutter_leaves_room_to_land_and_ride_rails() -> void:
	for thing: CSGBox3D in main.level.get_node("RoofClutter").get_children().filter(func(t: Node) -> bool: return not (t.name.begins_with("Tower") or t.name.begins_with("Spire"))): # (Downtown's: tests/test_downtown.gd.)
		var roof := _building_under(thing.global_position + Vector3.DOWN * thing.size.y / 2.0)
		expect(roof != null and not _is_tower(roof), "%s should stand on a roof (not a tower)" % thing.name)
		if roof == null:
			continue
		var clear := _footprint(roof).grow(-6.0)
		expect(clear.encloses(_footprint(thing)), "%s should be 6 m from %s's edges, to land jumps" % [thing.name, roof.name])
		for rail: GrindRail in main.level.get_node("GrindRails").get_children():
			var way := _flat(rail.bottom() - rail.top()).normalized()
			var from := _flat(rail.top()) - way * 10.0
			var to := _flat(rail.bottom()) + way * 10.0
			var middle := _flat(thing.global_position)
			var nearest := Geometry3D.get_closest_point_to_segment(middle, from, to)
			expect(nearest.distance_to(middle) > _flat(thing.size).length() / 2.0 + 1.0,
					"%s shouldn't block %s's run-up or landing" % [thing.name, rail.name])
	for marker: Node3D in [main.level.get_node("SpawnPoint")] + main.level.get_node("Checkpoints").get_children():
		for thing in _clutter():
			expect(_flat(thing.global_position).distance_to(_flat(marker.global_position)) > 4.0,
					"%s shouldn't be on top of %s" % [thing.name, marker.name])


func test_street_clutter_stays_on_the_pavement_clear_of_fire_escapes() -> void:
	var steps: Array[Rect2] = []
	for step: Node in main.level.get_node("FireEscapes").get_children():
		if step is CSGBox3D: # (Its decks and landings.)
			steps.append(_footprint(step).grow(8.0))
	for thing: CSGBox3D in main.level.get_node("StreetClutter").get_children():
		expect(is_equal_approx(thing.global_position.y, thing.size.y / 2.0), "%s should stand on the street" % thing.name)
		var spot := _footprint(thing)
		expect(not steps.any(func(r: Rect2) -> bool: return r.intersects(spot)), "%s shouldn't be in the way of a fire escape (or the run-up to it)" % thing.name)
		expect(not _buildings().any(func(b: CSGBox3D) -> bool: return _footprint(b).grow(1.0).intersects(spot)),
				"%s should leave room to run between it and the buildings" % thing.name)
		expect(absf(thing.global_position.x) > 5.0, "%s shouldn't be on the subway tracks" % thing.name)


func test_free_run_vaults_a_roof_box_and_carries_on() -> void:
	# (One with room on its roof to run up to it and on past it.)
	var box: CSGBox3D = _clutter().filter(func(thing: CSGBox3D) -> bool:
			if not "Vault" in thing.name:
				return false
			var reach := _extent(thing, _short_way(thing)) + 9.0
			var floor_at := thing.global_position + Vector3.DOWN * thing.size.y / 2.0
			return _building_under(floor_at - _short_way(thing) * reach) != null and _building_under(floor_at + _short_way(thing) * reach) != null)[0]
	expect(await _free_run_over(box, _short_way(box), 8.0), "should go over %s" % box.name)
	expect(player.is_on_floor() and _building_under(player.global_position) != null,
			"should be back on the roof past %s, at %v" % [box.name, player.global_position])
	_expect_skimmed(box)


func test_free_run_vaults_a_bench() -> void:
	var bench := _clutter_named("Bench")
	expect(await _free_run_over(bench, _along_kerb(bench), 5.0), "should go over %s" % bench.name)
	expect(player.is_on_floor() and player.global_position.y < 0.2, "should be back on the street past %s (running along the pavement), at %v" % [bench.name, player.global_position])
	_expect_skimmed(bench)


func test_free_run_gets_over_a_phone_booth() -> void:
	var booth := _clutter_named("Booth")
	expect(await _free_run_over(booth, _along_kerb(booth), 5.0), "should go over %s" % booth.name)
	expect(player.is_on_floor() and player.global_position.y < 0.2, "should be back on the street past %s, at %v" % [booth.name, player.global_position])
	expect(not &"Vault" in states_entered, "a booth is too tall to skim: you climb it")


## A flow vault: only just over the top, without losing speed.
func _expect_skimmed(thing: CSGBox3D) -> void:
	expect(&"Vault" in states_entered and not &"Climb" in states_entered,
			"should skim over %s, not jump up onto it, went through %s" % [thing.name, states_entered])
	var over := _highest - _top(thing)
	expect(over > 0.0 and over < 0.4, "should only just clear %s, %.2f m over the top" % [thing.name, over])
	expect(_slowest_past > _speed_at_it * 0.9, "shouldn't lose speed: %.1f m/s at it, %.1f just past it" % [_speed_at_it, _slowest_past])


## Free-runs at `thing` heading `across`, from `run_up` metres away, until
## you're 2 m past it. Fails if you never get past; says if you went over the top.
func _free_run_over(thing: CSGBox3D, across: Vector3, run_up: float) -> bool:
	var floor_y := thing.global_position.y - thing.size.y / 2.0
	var start := _flat(thing.global_position) - across * (_extent(thing, across) + run_up)
	await place(start + Vector3.UP * (floor_y + 0.05), yaw_for(across))
	Input.action_press(&"free_run")
	Input.action_press(&"move_forward")
	states_entered.clear()
	var past := false
	_highest = -INF
	_speed_at_it = 0.0
	_slowest_past = INF
	for i in 60 * 4:
		await ticks(1)
		_highest = maxf(_highest, player.global_position.y)
		var beyond := (player.global_position - thing.global_position).dot(across) - _extent(thing, across)
		if beyond < -_extent(thing, across) * 2.0 - 3.0:
			_speed_at_it = player.get_horizontal_speed() # Still running up to it.
		elif beyond > 0.5:
			_slowest_past = minf(_slowest_past, player.get_horizontal_speed())
		if beyond > 2.0 and player.is_on_floor():
			past = true
			break
	release_all()
	expect(past, "should get past %s, ended at %v" % [thing.name, player.global_position])
	return _highest > _top(thing) - 0.2


## Across a box's short side.
func _short_way(thing: CSGBox3D) -> Vector3:
	return Vector3.RIGHT if thing.size.x < thing.size.z else Vector3.BACK


## Along the kerb a pavement thing stands by (its name says which side of the block).
func _along_kerb(thing: CSGBox3D) -> Vector3:
	var side := String(thing.name).get_slice("_", 1).left(1)
	return Vector3.RIGHT if side in ["N", "S"] else Vector3.BACK


## Roof and street things.
func _clutter() -> Array[CSGBox3D]:
	var found: Array[CSGBox3D] = []
	for group in ["RoofClutter", "StreetClutter"]:
		for child in main.level.get_node(group).get_children():
			found.append(child as CSGBox3D)
	return found


## The first clutter thing of a kind ("Vault", "Bench", "Booth"...).
func _clutter_named(kind: String) -> CSGBox3D:
	for thing in _clutter():
		if kind in thing.name:
			return thing
	return null


func test_four_ramps_launch_toward_the_middle_of_the_plaza() -> void:
	var ramps: Array[Node] = main.level.get_node("Ramps").get_children()
	expect(ramps.size() == 4, "one ramp in each avenue arm, %d" % ramps.size())
	for ramp: Ramp in ramps:
		var launches := -ramp.global_basis.z
		var to_middle := -_flat(ramp.global_position).normalized()
		expect(launches.dot(to_middle) > 0.99, "%s should launch toward the middle" % ramp.name)
		expect(ramp.material == load("res://materials/grid_ramp.tres"), "%s should be orange" % ramp.name)


func test_free_run_climbs_a_launch_roof_from_behind_and_slides_off_it() -> void:
	# From the avenue behind it, heading for the plaza: up the step, up the
	# back wall, slide down and launch.
	var ramp: Ramp = main.level.get_node("Ramps/RampSouth")
	var back := ramp.global_basis.z
	await place(ramp.global_position + back * (ramp.length + Ramp.STEP_DEPTH + 12.0) + Vector3.UP * 0.05, yaw_for(-back))
	states_entered.clear()
	var launched := [false]
	var on_launch := func() -> void: launched[0] = true
	player.launched_off_ramp.connect(on_launch)
	Input.action_press(&"free_run")
	for i in 60 * 6:
		await ticks(1)
		if launched[0]:
			break
	release_all()
	player.launched_off_ramp.disconnect(on_launch)
	expect(launched[0], "free-run should climb on and launch off it, went through %s" % [states_entered])
	expect(&"Slide" in states_entered, "sliding down the roof, went through %s" % [states_entered])


func test_crouch_walking_down_a_launch_roof_doesnt_launch_you() -> void:
	var peak := await _run_at_ramp({"crouch": true})
	var lip: float = main.level.get_node("Ramps/RampSouth").height
	expect(peak < lip + 0.5, "too slow for a launch: just drop off the lip, peak %.1f m" % peak)


func test_running_off_a_launch_roof_launches_you() -> void:
	var peak := await _run_at_ramp({})
	expect(peak > 9.0, "a full-speed run should launch you well up, peak %.1f m" % peak)


func test_sliding_off_it_launches_you_higher() -> void:
	var running := await _run_at_ramp({})
	var sliding := await _run_at_ramp({"slide": true})
	expect(sliding > running + 1.5, "sliding off should go higher than running off (%.1f m vs %.1f m)" % [sliding, running])
	expect(sliding > 12.0, "the big one, peak %.1f m" % sliding)


func test_free_run_slides_off_it_and_a_readied_leap_adds_height() -> void:
	var running := await _run_at_ramp({})
	var free_running := await _run_at_ramp({"free_run": true})
	expect(free_running > running + 1.5, "free-run should slide down it for the big launch (%.1f m vs %.1f m running)" % [free_running, running])
	var leaping := await _run_at_ramp({"free_run": true, "ready_leap": true})
	expect(leaping > running + 1.0, "a readied leap at the lip adds height to a running launch (%.1f m vs %.1f m)" % [leaping, running])


func test_you_can_steer_in_the_air_after_a_launch() -> void:
	var straight := await _run_at_ramp({})
	var straight_x := player.global_position.x
	await _run_at_ramp({"steer": &"move_left"})
	expect(player.global_position.x < straight_x - 2.0, "holding left in the air should carry you left, x %.1f vs %.1f" % [player.global_position.x, straight_x])


func test_thirty_eight_relics_and_a_drop_off_in_the_plaza() -> void:
	var relics: Array[Node] = main.level.get_node("Relics").get_children()
	expect(relics.size() == 38, "thirty-eight relics (eight downtown), %d" % relics.size())
	# (And 3 from the group run.)
	expect(main.hud.get_node("Relics").text == "Relics 0 / 41", "the counter should show them: %s" % main.hud.get_node("Relics").text)
	var drop_off: DropOff = main.level.get_node("DropOff")
	expect(_flat(drop_off.global_position).length() < 0.1 and absf(drop_off.global_position.y) < 0.1,
			"the drop-off should be in the middle of the plaza, on the street")


func test_relics_float_in_the_open() -> void:
	var solid: Array[CSGBox3D] = _buildings()
	solid.append_array(_clutter())
	for step in main.level.get_node("FireEscapes").get_children():
		if step is CSGBox3D: # (Not the flights of stairs.)
			solid.append(step)
	for thing in main.level.get_node("Interiors").get_children():
		solid.append(thing)
	for relic: WorldItem in main.level.get_node("Relics").get_children():
		for box in solid:
			var room := box.get_node_or_null("Room") as CSGBox3D
			if room:
				var in_room := (room.global_position - relic.global_position).abs() - room.size / 2.0
				if in_room.x < -1.0 and in_room.y < -0.5 and in_room.z < -1.0:
					continue # (Inside its room, clear of the walls, floor and ceiling.)
			var inside := (box.global_position - relic.global_position).abs() - box.size / 2.0
			expect(inside.x > 1.0 or inside.y > 0.5 or inside.z > 1.0, "%s should be clear of %s" % [relic.name, box.name])
	for roof_relic in ["RelicHighRoof", "RelicFarCorner"]:
		var relic: WorldItem = main.level.get_node("Relics/" + roof_relic)
		var under := _building_under(relic.global_position + Vector3.DOWN * 0.5)
		expect(under != null and absf(relic.global_position.y - _top(under) - 1.0) < 0.1, "%s should hover just over a roof" % roof_relic)
	# (Not counting roofs with something else on them: a checkpoint, the spawn, the far-corner relic.)
	var high: WorldItem = main.level.get_node("Relics/RelicHighRoof")
	var taken: Array[CSGBox3D] = []
	var markers: Array[Node3D] = [main.level.get_node("SpawnPoint"), main.level.get_node("Relics/RelicFarCorner")]
	markers.append_array(main.level.get_node("Checkpoints").get_children())
	for marker in markers:
		taken.append(_building_under(marker.global_position + Vector3.DOWN * 0.5))
	for b in _buildings():
		if not _is_tower(b) and _is_flat(b) and not b in taken:
			expect(_top(b) <= high.global_position.y - 1.0 + 0.01, "the high-roof relic should be on the tallest free flat roof, but %s is taller" % b.name)


func test_running_into_relics_on_roofs_and_the_street_picks_them_up() -> void:
	for relic_name in ["RelicHighRoof", "RelicFarCorner", "RelicSubway"]:
		var relic: WorldItem = main.level.get_node("Relics/" + relic_name)
		var feet := relic.global_position + Vector3.DOWN * 1.0
		await place(feet + Vector3(0, 0.05, 6), yaw_for(Vector3.FORWARD))
		Input.action_press(&"move_forward")
		await ticks(60)
		release_all()
		expect(relic.holder_name == "1", "running into %s should pick it up" % relic_name)
		relic.host_return_home() # Hands free for the next one.
		await ticks(5)


func test_riding_the_rail_grabs_the_rail_relic() -> void:
	var relic: WorldItem = main.level.get_node("Relics/RelicRail")
	var rail: GrindRail = null
	for r: GrindRail in main.level.get_node("GrindRails").get_children():
		if rail == null or r.point_at(r.closest_t(relic.global_position)).distance_to(relic.global_position) \
				< rail.point_at(rail.closest_t(relic.global_position)).distance_to(relic.global_position):
			rail = r
	var way := _flat(rail.bottom() - rail.top()).normalized()
	await place(rail.top() + Vector3.UP * 0.45 - way * 8.0, yaw_for(way))
	Input.action_press(&"move_forward")
	var grinding := false
	for i in 60 * 6:
		await ticks(1)
		grinding = grinding or player.state.name == &"Grind"
		if relic.holder_name == "1":
			break
	release_all()
	expect(grinding, "should ride %s" % rail.name)
	expect(relic.holder_name == "1", "riding the rail should grab the relic over it")


func test_the_sky_relic_is_out_of_reach_alone() -> void:
	var relic: WorldItem = main.level.get_node("Relics/RelicSky")
	var peak := await _run_at_ramp({"slide": true})
	expect(peak + 0.9 + ItemCarrier.touch_range_of(relic.item) < relic.global_position.y, "the biggest launch alone peaks at %.1f m: it shouldn't reach" % peak)
	expect(relic.is_at_home(), "the sky relic should still be up there")


func test_a_friends_toss_on_the_way_up_reaches_the_sky_relic() -> void:
	# The timing is forgiving: an early toss or a late one both get there.
	var relic: WorldItem = main.level.get_node("Relics/RelicSky")
	for toss_above in [7.0, 9.5]:
		await _run_at_ramp({"toss_above": toss_above})
		expect(relic.holder_name == "1", "launched, then tossed by a friend beside you at %.1f m up, you should catch the sky relic" % toss_above)
		relic.host_return_home()
		await ticks(5)


## Runs down the plaza's south launch roof from its back edge at full flow,
## with `how` options: slide (crouch once moving), crouch (crouch-walk),
## free_run, ready_leap (hold jump with free-run), steer (an action held once
## launched), toss_above (a friend launching beside you tosses you, toward the
## middle, once you rise past this height). Returns how high your feet got
## above the street once off the lip, and leaves you where you landed.
func _run_at_ramp(how: Dictionary) -> float:
	var ramp: Ramp = main.level.get_node("Ramps/RampSouth")
	var back := ramp.global_basis.z # From the lip back up the roof.
	var start := ramp.length - 0.6
	await place(ramp.global_position + back * start + Vector3.UP * (ramp.height + ramp.rise() * start / ramp.length + 0.1), yaw_for(-back))
	player.debug_full_flow = not how.get("crouch", false)
	var launched := [false]
	var on_launch := func() -> void: launched[0] = true
	player.launched_off_ramp.connect(on_launch)
	if how.get("free_run", false):
		Input.action_press(&"free_run")
	if how.get("ready_leap", false):
		Input.action_press(&"jump")
	if how.get("crouch", false):
		Input.action_press(&"crouch")
	Input.action_press(&"move_forward")
	var peak := 0.0
	var left_ground := false
	for i in 60 * 8:
		await ticks(1)
		var from_lip := (player.global_position - ramp.global_position).dot(-back)
		if from_lip > 0.0:
			peak = maxf(peak, player.global_position.y)
		if how.get("slide", false) and player.state.name == &"Ground" and player.get_horizontal_speed() >= player.slide_min_start_speed:
			Input.action_press(&"crouch")
		if launched[0] and how.has("steer"):
			Input.action_press(how["steer"])
		if launched[0] and how.has("toss_above") and player.global_position.y > how["toss_above"] and player.tossed_by.is_empty():
			player.apply_toss(player.toss_velocity(yaw_for(-back)), "Friend")
		left_ground = left_ground or from_lip > 0.5
		if left_ground and player.is_on_floor():
			break
	release_all()
	player.launched_off_ramp.disconnect(on_launch)
	player.debug_full_flow = false
	if not how.get("crouch", false):
		expect(launched[0], "should launch off the ramp (%s)" % [how])
	return peak


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)


## Finds two same-height buildings across a gap of `size`, runs at it with
## free-run from `run_up` metres back (holding jump near the edge if `leap`),
## and says whether you landed on the second.
func _run_across(size: float, leap: bool, run_up: float) -> bool:
	var pair := _pair_across(size)
	expect(not pair.is_empty(), "the district should have a %d m gap to test" % size)
	if pair.is_empty():
		return false
	return await _run_across_pair(pair, leap, run_up)


func _run_across_pair(pair: Array, leap: bool, run_up: float) -> bool:
	var from: CSGBox3D = pair[0]
	var to: CSGBox3D = pair[1]
	var direction: Vector3 = pair[2]
	run_up = minf(run_up, _extent(from, direction) * 2.0 - 2.0) # No further back than the roof goes.
	var edge := _edge_point(from, to, direction)
	await place(edge - direction * run_up + Vector3.UP * 0.05, yaw_for(direction))
	Input.action_press(&"free_run")
	Input.action_press(&"move_forward")
	var landed := false
	for i in 60 * 6:
		await ticks(1)
		if leap:
			var to_edge := (edge - player.global_position).dot(direction)
			if to_edge < 6.0:
				Input.action_press(&"jump")
		if player.is_on_floor() and _building_under(player.global_position) == to \
				and absf(player.global_position.y - _top(to)) < 0.2:
			landed = true
			break
		if player.global_position.y < minf(_top(from), _top(to)) - 3.0:
			break
	release_all()
	return landed


## [from, to, direction]: the first pair across a gap of `size` where `to` is
## `rise` metres higher than `from` (by default the same height: no help from
## dropping down) and they face each other along at least 12 m, with
## nothing in the way of a run-up to it.
func _pair_across(size: float, rise := 0.0) -> Array:
	var buildings := _buildings()
	for a in buildings:
		for b in buildings:
			if a == b or _is_tower(a) or _is_tower(b) or not _is_flat(a) or not _is_flat(b) or absf(_top(b) - _top(a) - rise) > 0.01:
				continue
			if _gap_size(_facing_gap(a, b)) != size or _overlap(a, b) < 12.0:
				continue
			var offset := b.global_position - a.global_position
			var direction := Vector3(signf(offset.x), 0, 0) if _gap_x(a, b) > _gap_z(a, b) \
					else Vector3(0, 0, signf(offset.z))
			if not _lane_clear(_edge_point(a, b, direction), direction):
				continue # A relic's pillar in the way of the run-up.
			return [a, b, direction]
	return []


func _buildings() -> Array[CSGBox3D]:
	var found: Array[CSGBox3D] = []
	for child in main.level.get_node("Buildings").get_children():
		if child is CSGBox3D and not child.has_meta(&"shape"): # (Plain boxes: not round, domed, stepped...)
			found.append(child as CSGBox3D)
	return found


func _building_under(at: Vector3) -> CSGBox3D:
	for b in _buildings():
		var half := b.size / 2.0
		var local := at - b.global_position
		if absf(local.x) <= half.x + 0.3 and absf(local.z) <= half.z + 0.3 and absf(at.y - _top(b)) < 1.0:
			return b
	return null


func _top(b: CSGBox3D) -> float:
	return b.global_position.y + b.size.y / 2.0


func _is_tower(b: CSGBox3D) -> bool:
	return b.size.y > 30.0


## False for an old-town house or a sawtooth shed (their roofs are in Roofs), or a
## building of another shape (a dome, tiers, a courtyard...: see gen_district.gd).
func _is_flat(b: CSGBox3D) -> bool:
	return not b.has_meta(&"shape") and main.level.get_node("Roofs").get_children().all(func(roof: Node) -> bool:
			return not String(roof.name).begins_with(b.name + "_"))


## How far `b`'s edge is from its middle along `direction`.
func _extent(b: CSGBox3D, direction: Vector3) -> float:
	return absf((b.size / 2.0).dot(direction.abs()))


## The middle of where `from` and `to` face each other, on `from`'s roof edge.
func _edge_point(from: CSGBox3D, to: CSGBox3D, direction: Vector3) -> Vector3:
	var side := Vector3(direction.z, 0, direction.x).abs()
	var lo := maxf((from.global_position - from.size / 2.0).dot(side), (to.global_position - to.size / 2.0).dot(side))
	var hi := minf((from.global_position + from.size / 2.0).dot(side), (to.global_position + to.size / 2.0).dot(side))
	var along := from.global_position + direction * _extent(from, direction)
	along -= side * along.dot(side)
	return Vector3(along.x, _top(from), along.z) + side * (lo + hi) / 2.0


func _gap_x(a: CSGBox3D, b: CSGBox3D) -> float:
	return absf(a.global_position.x - b.global_position.x) - (a.size.x + b.size.x) / 2.0


func _gap_z(a: CSGBox3D, b: CSGBox3D) -> float:
	return absf(a.global_position.z - b.global_position.z) - (a.size.z + b.size.z) / 2.0


## How far `a` and `b` overlap side-on (along the gap between them).
func _overlap(a: CSGBox3D, b: CSGBox3D) -> float:
	if _gap_x(a, b) > _gap_z(a, b):
		return -_gap_z(a, b)
	return -_gap_x(a, b)


## The gap between two buildings that face each other (nothing in between,
## side by side for at least 2 m), or -1 if they don't.
func _facing_gap(a: CSGBox3D, b: CSGBox3D) -> float:
	var gx := _gap_x(a, b)
	var gz := _gap_z(a, b)
	var gap := maxf(gx, gz)
	if gap < 0.1 or minf(gx, gz) > -2.0 or gap > AVENUE + 1.0:
		return -1.0
	# The open space between them, which no other building may be in.
	var ra := _footprint(a)
	var rb := _footprint(b)
	var lo := ra.end.min(rb.end)
	var hi := ra.position.max(rb.position)
	var between := Rect2(Vector2(lo.x, hi.y), Vector2(hi.x - lo.x, lo.y - hi.y)) if gx > gz \
			else Rect2(Vector2(hi.x, lo.y), Vector2(lo.x - hi.x, hi.y - lo.y))
	for c in _buildings():
		if c != a and c != b and _footprint(c).intersects(between.abs().grow(-0.1)):
			return -1.0
	return gap


func _footprint(b: CSGBox3D) -> Rect2:
	return Rect2(b.global_position.x - b.size.x / 2.0, b.global_position.z - b.size.z / 2.0, b.size.x, b.size.z)


## Which of the three gap sizes `gap` is (0 if none).
func _gap_size(gap: float) -> float:
	for size in [LANE, ALLEY, STREET, AVENUE]:
		if absf(gap - size) < 0.05:
			return size
	return 0.0


## True if no relic pillar stands within a body's reach of the 25 m run-up to `edge`.
func _lane_clear(edge: Vector3, direction: Vector3) -> bool:
	for pillar: CSGBox3D in main.level.get_node("Pillars").get_children():
		var flat := Vector2(pillar.global_position.x, pillar.global_position.z)
		var closest := Geometry2D.get_closest_point_to_segment(flat, Vector2(edge.x, edge.z),
				Vector2(edge.x, edge.z) - Vector2(direction.x, direction.z) * 25.0)
		if closest.distance_to(flat) < pillar.size.x / 2.0 + 1.5:
			return false
	return true


func test_relics_for_every_size_of_team_with_rings_to_say_which() -> void:
	var wanted: Dictionary = load("res://tools/gen_district.gd").RELICS_WANTED
	var count := {}
	for relic: WorldItem in main.level.get_node("Relics").get_children():
		count[relic.players_needed] = count.get(relic.players_needed, 0) + 1
		var rings := relic.find_children("Ring*", "MeshInstance3D", true, false).size()
		expect(rings == relic.players_needed, "%s takes %d player(s), so %d ring(s), has %d" % [relic.name, relic.players_needed, relic.players_needed, rings])
	for players: int in wanted:
		expect(count.get(players, 0) == wanted[players], "%d relic(s) for %d player(s), got %d (the checker's word: test_reach.gd)" % [wanted[players], players, count.get(players, 0)])


func test_items_to_try_lie_about_the_district() -> void:
	await ticks(60) # (Let them settle.)
	var kinds := {}
	for item: WorldItem in main.level.get_node("Items").get_children():
		kinds[item.item.id] = kinds.get(item.item.id, 0) + 1
		expect(item.state == WorldItem.State.IN_WORLD and item.global_position.y > -1.0, "%s should be lying about, at %s" % [item.name, item.global_position])
	for id: StringName in [&"glider", &"bat", &"crate", &"test_balloon"]:
		expect(kinds.get(id, 0) >= 2, "a few of each kind to try, %s: %d" % [id, kinds.get(id, 0)])


func test_no_signs_about() -> void:
	expect(main.level.get_node("Labels").get_child_count() == 0, "no labels or tips in the playground")


func test_the_hub_tower_lights_up_a_light_per_relic_delivered() -> void:
	var board: RelicBoard = main.level.get_node("RelicBoard")
	var to_plaza := -Vector3(board.global_position.x, 0, board.global_position.z).normalized()
	expect((-board.global_basis.z).dot(to_plaza) > 0.6, "the board looks out toward the plaza")
	expect(board.global_position.y > 30.0, "high up on the hub tower, %.0f m" % board.global_position.y)
	await ticks(2)
	expect(board.lit() == Vector2i(0, 41), "a light for every relic (the run's too), none lit yet: %s" % board.lit())
	var relic: WorldItem = main.level.get_node("Relics").get_child(0)
	relic.host_deliver()
	await ticks(2)
	expect(board.lit() == Vector2i(1, 41), "deliver one: its light comes on, %s" % board.lit())
	var rows := board.rows().map(func(row: Array) -> int: return row.size())
	expect(rows == [20, 10, 5, 3, 3], "rows by players each takes, then the run: %s" % [rows])


## The grind rails across the avenues (not downtown's).
func _avenue_rails() -> Array[GrindRail]:
	var found: Array[GrindRail] = []
	for rail: Node in main.level.get_node("GrindRails").get_children():
		if rail.name.begins_with("RailEW") or rail.name.begins_with("RailNS"):
			found.append(rail)
	return found
