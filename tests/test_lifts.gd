extends GameTest
## Lifts (levels/lift.gd): counterweight hoists up tall old-town buildings, a
## window-washer's gondola up every glass tower downtown; and kicking off a
## wall from a hang (player/states/hang.gd).

const GENERATOR := preload("res://tools/gen_district.gd")
const STONE := preload("res://materials/stone.tres")

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


func test_hoists_in_the_old_town_and_gondolas_up_glass_towers() -> void:
	var hoists := _lifts("hoist")
	expect(hoists.size() >= 5, "counterweight hoists about the old town, %d" % hoists.size())
	for hoist in hoists:
		expect(hoist.name.begins_with("Block") and hoist.height >= GENERATOR.HOIST_MIN_STOREYS * GENERATOR.STOREY - 0.1, "%s: up a tall old-town building (%.0f m)" % [hoist.name, hoist.height])
	var gondolas := _lifts("gondola")
	for tower: Node in main.level.get_node("Buildings").get_children():
		if not (tower is CSGShape3D and (tower.name.begins_with("Tower") or tower.name == "Spire")):
			continue
		var glass: bool = (tower as CSGShape3D).material != STONE
		var has := gondolas.any(func(g: Lift) -> bool: return g.name == tower.name + "_Gondola")
		expect(has == glass, "%s: %s" % [tower.name, "a gondola up it (glass)" if glass else "no gondola (stone: ledges)"])
	var spire := main.level.get_node_or_null("WaysUp/Spire_Gondola") as Lift
	expect(spire != null and spire.height >= 100.0, "one goes up the spire, to its terrace (%.0f m)" % (spire.height if spire else 0.0))


func test_every_lift_is_a_way_up_alone() -> void:
	var map := ReachMap.shared(main.level, SUPERHUMAN)
	var ground := map.place_named("Ground")
	for lift in _lifts():
		var top := lift.global_transform * Vector3(0.0, lift.height, 0.0)
		var roof := map.place_under(top - lift.out_of_wall() + Vector3.UP * 0.5)
		expect(map.links.any(func(l: ReachMap.Link) -> bool: return l.from == ground and l.to == roof and l.how == lift.kind),
				"%s: from the street to its roof" % lift.name)


func test_ride_a_gondola_up_a_tower() -> void:
	var gondola := main.level.get_node("WaysUp/Spire_Gondola") as Lift
	var ride := await _ride(gondola)
	expect(ride >= 0.0, "rode the gondola up and stepped onto the spire's roof (%.0f m), at %s" % [gondola.height, player.global_position])
	expect(ride < gondola.height / Lift.WINCH_SPEED * 0.6, "quickly (much faster than a hoist winches): %.1f s for %.0f m" % [ride, gondola.height])
	# Empty, it goes back down for the next one.
	for i in 60 * 40:
		await ticks(1)
		if gondola.progress <= 0.0:
			break
	expect(gondola.progress <= 0.0, "and goes back down empty (%.2f of the way up)" % gondola.progress)


func test_a_hoist_winches_you_up_alone() -> void:
	var hoist := _lifts("hoist")[0]
	var ride := await _ride(hoist)
	expect(ride >= 0.0, "winched up %s and stepped onto its roof (%.0f m), at %s" % [hoist.name, hoist.height, player.global_position])
	expect(ride > hoist.height / Lift.DROP_SPEED * 2.0, "steadily: %.1f s for %.0f m" % [ride, hoist.height])


func test_a_friend_on_the_counterweight_flings_you_onto_the_roof() -> void:
	var hoist := _lifts("hoist")[0]
	main.call_buddy()
	var buddy: Player = main.buddy
	buddy.ghost_of = null
	var top := hoist.rider_top(1.0)
	await place(hoist.rider_top(0.0) + Vector3.UP * 0.05, yaw_for(-hoist.out_of_wall()))
	await ticks(10) # (It starts winching you up...)
	# ...and your friend steps off the roof onto the counterweight.
	buddy.global_position = hoist.counterweight_top() + Vector3.UP * 0.05
	buddy.velocity = Vector3.ZERO
	buddy.reset_physics_interpolation()
	states_entered.clear()
	var highest := 0.0
	var landed := -1.0
	for i in 60 * 6:
		await ticks(1)
		highest = maxf(highest, player.global_position.y)
		if player.is_on_floor() and player.global_position.y > top.y - 0.3 and _on_roof(hoist):
			landed = i / 60.0
			break
	expect(highest > top.y + Lift.FLING_RISE * 0.6, "flung up over the edge (%.1f m, the roof's at %.1f m)" % [highest, top.y])
	expect(landed >= 0.0, "onto the roof, at %s (went %s)" % [player.global_position, states_entered.slice(0, 6)])
	expect(landed < hoist.height / Lift.WINCH_SPEED, "faster than winching up alone (%.1f s)" % landed)
	expect(buddy.global_position.y < 2.0, "and your friend rode the counterweight down to the street (at %.1f m)" % buddy.global_position.y)


func test_kick_off_a_wall_from_a_hang() -> void:
	# Hanging from a wall of window ledges: back and jump pushes you away from the wall.
	var row: Ledges
	for r: Ledges in main.level.get_node("Ledges").get_children():
		if r.name.begins_with("Block") and r.gaps.is_empty() and r.heights.size() >= 3:
			row = r
			break
	var out := row.out_of_wall()
	var piece: Vector2 = row.pieces()[0]
	var ledge_y: float = row.global_position.y + row.heights[1]
	var at := row.point_at((piece.x + piece.y) / 2.0, ledge_y)
	await place(at - Vector3.UP * SUPERHUMAN.hang_height + out * 0.6, yaw_for(-out))
	player.change_state(&"Hang", {"ledge": row.ledge_near(at)})
	await ticks(20)
	expect_state(&"Hang")
	states_entered.clear()
	var wall := row.point_at((piece.x + piece.y) / 2.0, 0.0)
	Input.action_press(&"move_back")
	Input.action_press(&"jump")
	await ticks(30)
	release_all()
	var away := (player.global_position - wall).dot(out)
	expect(away > 2.5, "kicked off, %.1f m out from the wall" % away)
	expect(not &"Hang" in states_entered.slice(states_entered.rfind(&"Air")), "and didn't catch the next ledge down")


# --- Helpers -----------------------------------------------------------------

func _lifts(kind := "") -> Array[Lift]:
	var found: Array[Lift] = []
	for node in main.level.get_node("WaysUp").get_children():
		if node is Lift and (kind == "" or (node as Lift).kind == kind):
			found.append(node)
	return found


## Steps onto `lift` from the street, rides it up and steps off onto its roof.
## Says how long the ride took (seconds), or -1 if you didn't get there.
func _ride(lift: Lift) -> float:
	await place(lift.rider_top(0.0) - lift.out_of_wall() * 0.0 + lift.out_of_wall() * 3.0 + Vector3.UP * 0.05, yaw_for(-lift.out_of_wall()))
	Input.action_press(&"move_forward")
	await ticks(25) # (Onto it.)
	release_all()
	var top := lift.rider_top(1.0)
	for i in 60 * 30:
		await ticks(1)
		if lift.progress >= 1.0:
			Input.action_press(&"move_forward") # (Up: step off onto the roof.)
		if player.is_on_floor() and _on_roof(lift):
			release_all()
			return i / 60.0
	release_all()
	return -1.0


## True if you're standing on `lift`'s roof (behind its wall, level with its top).
func _on_roof(lift: Lift) -> bool:
	var top := lift.global_transform * Vector3(0.0, lift.height, 0.0)
	return absf(player.global_position.y - top.y) < 0.3 and (player.global_position - top).dot(lift.out_of_wall()) < -0.2
