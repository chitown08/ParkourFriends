extends GameTest
## The rooftop district (built by tools/gen_district.gd), played with free-run
## and the superhuman profile. Gaps between buildings come in three sizes:
## alleys (5 m), streets (10 m) and avenues (24 m).

const ALLEY := 5.0
const STREET := 10.0
const AVENUE := 24.0


func before_each() -> void:
	main = MAIN_SCENE.instantiate()
	add_child(main)
	main.start_solo("rooftop_district")
	await ticks(5)
	player = main.get_node_or_null("Players/1")
	expect(player != null, "the game should have created a player")
	if player:
		player.set_profile(SUPERHUMAN)


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


## Finds two same-height buildings across a gap of `size`, runs at it with
## free-run from `run_up` metres back (holding jump near the edge if `leap`),
## and says whether you landed on the second.
func _run_across(size: float, leap: bool, run_up: float) -> bool:
	var pair := _pair_across(size)
	expect(not pair.is_empty(), "the district should have a %d m gap to test" % size)
	if pair.is_empty():
		return false
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
		if player.global_position.y < _top(to) - 3.0:
			break
	release_all()
	return landed


## [from, to, direction]: the first pair across a gap of `size` where `to` is the
## same height as `from` (no help from dropping down) and they face each other
## along at least 12 m.
func _pair_across(size: float) -> Array:
	var buildings := _buildings()
	for a in buildings:
		for b in buildings:
			if a == b or _is_tower(a) or _is_tower(b) or absf(_top(b) - _top(a)) > 0.01:
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
