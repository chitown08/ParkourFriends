extends GameTest
## The rooftop district (built by tools/gen_district.gd), played with free-run
## and the superhuman profile. Gaps between buildings come in three sizes:
## alleys (5 m), streets (10 m) and avenues (24 m).

const ALLEY := 5.0
const STREET := 10.0
const AVENUE := 24.0
const STOREY := 3.5

## Every state the player has entered since the test began, in order.
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
	var counts := {ALLEY: 0, STREET: 0, AVENUE: 0}
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
	expect(odd.is_empty(), "gaps should only be 5, 10 or 24 m: %s" % [odd])
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


func test_every_block_has_a_fire_escape_from_the_street() -> void:
	var climbed := {}
	for building in _buildings():
		var steps := _steps_of(building)
		if steps.is_empty():
			continue
		var block := building.name.get_slice("_", 0)
		climbed[block] = true
		expect_near(_top(steps[0]), STOREY, 0.01, "%s's fire escape should start one storey up" % building.name)
		expect_near(_top(steps[-1]), _top(building) - STOREY, 0.01, "and end one storey below its roof")
		for k in range(1, steps.size()):
			expect_near(_top(steps[k]) - _top(steps[k - 1]), STOREY, 0.01, "each step one storey up")
	expect(climbed.size() == 25, "all 25 blocks should have one, %d do" % climbed.size())


func test_fire_escapes_take_you_from_the_street_to_the_roof() -> void:
	# The squeezed-up one (shortest steps) and the tallest one.
	var all := _staircases()
	all.sort_custom(func(a: CSGBox3D, b: CSGBox3D) -> bool: return _step_run(a) < _step_run(b))
	var squeezed: CSGBox3D = all[0]
	all.sort_custom(func(a: CSGBox3D, b: CSGBox3D) -> bool: return _steps_of(a).size() > _steps_of(b).size())
	for building: CSGBox3D in [squeezed, all[0]]:
		expect(await _climb_fire_escape(building), "should climb %s's fire escape (%d steps of %.1f m) to the roof, ended at %v" % [
				building.name, _steps_of(building).size(), _step_run(building), player.global_position])


func test_rails_cross_the_avenues_downhill_onto_a_lower_roof() -> void:
	var rails: Array[Node] = main.level.get_node("GrindRails").get_children()
	expect(rails.size() >= 6, "there should be rails across the avenues, %d" % rails.size())
	for rail: GrindRail in rails:
		var landing := _building_under(rail.bottom() + Vector3.DOWN * 0.7)
		expect(landing != null, "%s should end over a roof" % rail.name)
		var start := _building_under(rail.top() + Vector3.UP * 0.4 - _flat(rail.bottom() - rail.top()).normalized() * 2.0)
		expect(start != null, "%s should start just off a roof" % rail.name)
		if start and landing:
			expect(_top(start) > _top(landing), "%s should go from a taller roof to a lower one" % rail.name)


func test_running_off_a_roof_rides_a_rail_over_the_avenue() -> void:
	var rail: GrindRail = main.level.get_node("GrindRails").get_child(0)
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
	var rail: GrindRail = main.level.get_node("GrindRails").get_child(0)
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


func test_hugging_the_wall_up_a_fire_escape_doesnt_turn_into_a_wall_run() -> void:
	# Running right beside the building's wall, or drifting into it, you should
	# still go up step by step - not wall-run into the next step and then kick
	# off away from the building.
	var all := _staircases()
	all.sort_custom(func(a: CSGBox3D, b: CSGBox3D) -> bool: return _steps_of(a).size() > _steps_of(b).size())
	for start: Array in [[1.0, 0.0], [0.0, 5.0]]: # [metres toward the wall, degrees into it]
		states_entered.clear()
		expect(await _climb_fire_escape(all[0], start[0], start[1]), "should climb %s's fire escape (%.1f m toward the wall, %.0f deg into it), ended at %v" % [
				all[0].name, start[0], start[1], player.global_position])
		expect(not &"WallRun" in states_entered, "and never wall-run on the way up (%.1f m, %.0f deg)" % start)


## Walks up to a building's fire escape from the street with free-run, climbs
## the steps, then turns to the wall for the roof. Says if you got onto the roof.
## `toward_wall` starts you that many metres off the middle of the steps toward
## the building, and `angle_in` aims you that many degrees into its wall.
func _climb_fire_escape(building: CSGBox3D, toward_wall := 0.0, angle_in := 0.0) -> bool:
	var steps := _steps_of(building)
	var along := _flat(steps[1].global_position - steps[0].global_position).normalized() if steps.size() > 1 \
			else Vector3.ZERO
	var to_wall := _flat(building.global_position - steps[0].global_position)
	to_wall = to_wall - along * to_wall.dot(along)
	to_wall = to_wall.normalized()
	var foot := steps[0].global_position - along * (_step_run(building) / 2.0 + 8.0) + to_wall * toward_wall
	var aim := along.rotated(Vector3.UP, deg_to_rad(angle_in) * signf(along.cross(to_wall).y))
	await place(Vector3(foot.x, 0.05, foot.z), yaw_for(aim))
	Input.action_press(&"free_run")
	Input.action_press(&"move_forward")
	for i in 60 * 15:
		await ticks(1)
		if player.is_on_floor() and player.global_position.y > _top(steps[-1]) - 0.2:
			player.camera_rig.yaw = yaw_for(to_wall) # Last step: turn to the wall.
		if player.is_on_floor() and _building_under(player.global_position) == building:
			release_all()
			return true
	release_all()
	return false


func _staircases() -> Array:
	return _buildings().filter(func(b: CSGBox3D) -> bool: return not _steps_of(b).is_empty())


## A building's fire escape steps, lowest first.
func _steps_of(building: CSGBox3D) -> Array[CSGBox3D]:
	var steps: Array[CSGBox3D] = []
	var k := 1
	while main.level.has_node("FireEscapes/%s_Step%d" % [building.name, k]):
		steps.append(main.level.get_node("FireEscapes/%s_Step%d" % [building.name, k]))
		k += 1
	return steps


## How long each step of a building's fire escape is.
func _step_run(building: CSGBox3D) -> float:
	var steps := _steps_of(building)
	return maxf(steps[0].size.x, steps[0].size.z) if steps[0].size.x != 3.0 and steps[0].size.z != 3.0 \
			else (steps[0].size.z if steps[0].size.x == 3.0 else steps[0].size.x)


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
## dropping down) and they face each other along at least 12 m.
func _pair_across(size: float, rise := 0.0) -> Array:
	var buildings := _buildings()
	for a in buildings:
		for b in buildings:
			if a == b or _is_tower(a) or _is_tower(b) or absf(_top(b) - _top(a) - rise) > 0.01:
				continue
			if _gap_size(_facing_gap(a, b)) != size or _overlap(a, b) < 12.0:
				continue
			var offset := b.global_position - a.global_position
			var direction := Vector3(signf(offset.x), 0, 0) if _gap_x(a, b) > _gap_z(a, b) \
					else Vector3(0, 0, signf(offset.z))
			return [a, b, direction]
	return []


func _buildings() -> Array[CSGBox3D]:
	var found: Array[CSGBox3D] = []
	for child in main.level.get_node("Buildings").get_children():
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
	if gap <= 0.0 or minf(gx, gz) > -2.0 or gap > AVENUE + 1.0:
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
	for size in [ALLEY, STREET, AVENUE]:
		if absf(gap - size) < 0.05:
			return size
	return 0.0
