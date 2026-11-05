extends GameTest
## Balconies downtown (tools/gen_district.gd: BALCONY): in pairs facing each
## other across alleys, partway up the towers, a short jump apart.

const GENERATOR := preload("res://tools/gen_district.gd")


func before_each() -> void:
	await super()
	main.leave_game()
	await ticks(5)
	main.start_solo("rooftop_district")
	await ticks(10)
	player = main.get_node("Players/1")
	player.set_profile(SUPERHUMAN)


func test_balconies_face_each_other_across_alleys() -> void:
	var pairs := _pairs()
	expect(pairs.size() >= 10, "balconies in pairs across alleys, %d pairs" % pairs.size())
	for pair: Array in pairs:
		var a: CSGBox3D = pair[0]
		var b: CSGBox3D = pair[1]
		var top := a.global_position.y + a.size.y / 2.0
		expect(absf(top - (b.global_position.y + b.size.y / 2.0)) < 0.01, "%s: level with its partner" % a.name)
		expect(GENERATOR.BALCONY_STOREYS.any(func(k: int) -> bool: return absf(top - k * GENERATOR.STOREY) < 0.01), "%s: at storey 8, 16 or 24 (%.1f m)" % [a.name, top])
		var gap := _gap(a, b)
		expect(gap > 1.0 and gap < 2.5, "%s: a short jump from its partner, %.1f m" % [a.name, gap])
		# Its tower goes on up over it.
		var over := player.raycast(a.global_position + Vector3.UP * 2.0, a.global_position + Vector3.UP * 2.0 - _out(a) * 1.5)
		expect(not over.is_empty(), "%s: against its tower's wall, which goes on up" % a.name)


func test_jump_from_one_to_the_other() -> void:
	var map := ReachMap.shared(main.level, SUPERHUMAN)
	for pair: Array in _pairs():
		var a := map.place_named(pair[0].name)
		var b := map.place_named(pair[1].name)
		expect(a != null and b != null and map.links.any(func(l: ReachMap.Link) -> bool: return l.from == a and l.to == b), "the checker: from %s across to its partner" % pair[0].name)
	# And in the game.
	var pair: Array = _pairs()[0]
	var from: CSGBox3D = pair[0]
	var to: CSGBox3D = pair[1]
	var across := _out(from)
	await place(from.global_position + Vector3.UP * (from.size.y / 2.0 + 0.05) - across * 0.5, yaw_for(across))
	Input.action_press(&"move_forward")
	await tap(&"jump")
	for i in 60 * 2:
		await ticks(1)
		if player.state.name == &"Hang":
			await tap(&"jump")
		if player.is_on_floor() and _on(to):
			break
	release_all()
	expect(player.is_on_floor() and _on(to), "jumped across to %s, at %s" % [to.name, player.global_position])


## True if you're standing on `balcony`.
func _on(balcony: CSGBox3D) -> bool:
	var off := player.global_position - balcony.global_position
	return absf(off.y - balcony.size.y / 2.0) < 0.3 and absf(off.x) < balcony.size.x / 2.0 + 0.3 and absf(off.z) < balcony.size.z / 2.0 + 0.3


## Every balcony with its partner across the alley ("...A", "...B").
func _pairs() -> Array:
	var found := []
	var parent: Node = main.level.get_node("Balconies")
	for node in parent.get_children():
		if str(node.name).ends_with("A"):
			var partner: Node = parent.get_node_or_null(str(node.name).trim_suffix("A") + "B")
			if partner:
				found.append([node, partner])
	return found


## The way out of its wall (toward its partner): its short side.
func _out(balcony: CSGBox3D) -> Vector3:
	var partner_name := str(balcony.name).trim_suffix("A") + "B" if str(balcony.name).ends_with("A") else str(balcony.name).trim_suffix("B") + "A"
	var partner := main.level.get_node("Balconies/" + partner_name) as Node3D
	var way := partner.global_position - balcony.global_position
	return Vector3(signf(way.x), 0, 0) if absf(way.x) > absf(way.z) else Vector3(0, 0, signf(way.z))


func _gap(a: CSGBox3D, b: CSGBox3D) -> float:
	var ra := Rect2(a.global_position.x - a.size.x / 2.0, a.global_position.z - a.size.z / 2.0, a.size.x, a.size.z)
	var rb := Rect2(b.global_position.x - b.size.x / 2.0, b.global_position.z - b.size.z / 2.0, b.size.x, b.size.z)
	var dx := maxf(0.0, maxf(ra.position.x - rb.end.x, rb.position.x - ra.end.x))
	var dz := maxf(0.0, maxf(ra.position.y - rb.end.y, rb.position.y - ra.end.y))
	return Vector2(dx, dz).length()
