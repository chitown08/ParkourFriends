extends GameTest
## Zip lines (levels/zip_line.gd, player/states/zip.gd): from towers down to
## lower roofs downtown, and from the boulevard's towers down into the old town.

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


func test_zip_lines_downtown_and_across_the_boulevard() -> void:
	var lines := _lines()
	var into_old_town := lines.filter(func(l: ZipLine) -> bool: return l.name.contains("_Block"))
	expect(lines.size() - into_old_town.size() >= 4, "zip lines between towers, %d" % (lines.size() - into_old_town.size()))
	expect(into_old_town.size() >= 2, "and down across the boulevard into the old town, %d" % into_old_town.size())
	for line in lines:
		expect(line.start_point().y > line.end_point().y + 4.0, "%s runs downhill" % line.name)
		# Nothing in the way of you hanging under it (but at its two ends, over its roofs).
		var steps := ceili(line.length())
		for i in range(4, steps - 3):
			var a := line.point_at(line.length() * i / steps) + Vector3.DOWN * 1.0
			var b := a + Vector3.DOWN * (ZipLine.HANDS + 0.2)
			expect(player.raycast(a, b).is_empty(), "%s: clear under it %.0f m along" % [line.name, line.length() * i / steps])


func test_every_zip_line_is_a_way_down() -> void:
	var map := ReachMap.shared(main.level, SUPERHUMAN)
	for line in _lines():
		var top := map.place_under(line.global_position + Vector3.UP * 0.5)
		var bottom := map.place_under(line.global_transform * line.end + Vector3.UP * 0.5)
		expect(map.links.any(func(l: ReachMap.Link) -> bool: return l.from == top and l.to == bottom and l.how == "zip line"),
				"%s: from its high roof to its low one" % line.name)


func test_ride_a_zip_line_down_onto_the_lower_roof() -> void:
	# One between towers, and one across the boulevard.
	var lines := _lines()
	for line: ZipLine in [lines.filter(func(l: ZipLine) -> bool: return not l.name.contains("_Block"))[0],
			lines.filter(func(l: ZipLine) -> bool: return l.name.contains("_Block"))[0]]:
		var way := Vector3(line.direction().x, 0.0, line.direction().z).normalized()
		await place(line.global_position - way * 1.0 + Vector3.UP * 0.05, yaw_for(way))
		states_entered.clear()
		Input.action_press(&"move_forward")
		await tap(&"jump")
		var landed := false
		var low := line.global_transform * line.end
		for i in 60 * 15:
			await ticks(1)
			if player.is_on_floor() and absf(player.global_position.y - low.y) < 0.5 and &"Zip" in states_entered:
				landed = true
				break
		release_all()
		expect(&"Zip" in states_entered, "%s: grabbed it with a jump from beside its pole (went %s)" % [line.name, states_entered.slice(0, 6)])
		expect(landed, "%s: and rode it down onto the low roof (%.0f m), at %s" % [line.name, low.y, player.global_position])


func test_jump_to_let_go_partway() -> void:
	var line := _lines()[0]
	var way := Vector3(line.direction().x, 0.0, line.direction().z).normalized()
	await place(line.global_position - way * 1.0 + Vector3.UP * 0.05, yaw_for(way))
	Input.action_press(&"move_forward")
	await tap(&"jump")
	release_all()
	for i in 60:
		await ticks(1)
		if player.state.name == &"Zip":
			break
	expect_state(&"Zip")
	await ticks(20)
	var along: float = line.closest_distance(player.global_position + Vector3.UP * ZipLine.HANDS)
	await tap(&"jump")
	await ticks(2)
	expect(player.state.name == &"Air", "jumping lets go, %.0f m down it (in %s)" % [along, player.state.name])
	expect(player.velocity.dot(line.direction()) > 5.0, "keeping your speed (%.1f m/s)" % player.velocity.dot(line.direction()))


func _lines() -> Array[ZipLine]:
	var found: Array[ZipLine] = []
	for node in main.level.get_node("WaysUp").get_children():
		if node is ZipLine:
			found.append(node)
	return found
