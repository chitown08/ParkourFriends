extends GameTest
## Slopes you run up: steeper than you'd stand around on (ReachMap.STAND_SLOPE)
## but no steeper than ReachMap.RUN_SLOPE. In the game you can run up to about
## 45° (steeper, you slide back down), so the checker's 40° is a little under.
## Also terraces spun round in an arc (a CSGPolygon3D spun: the museum's).
## Built high above the test course.

const FLOOR_Y := 600.0
const RISE := 6.0
## The terraces: spun round (from +x toward -z) this far, about the middle at
## TERRACE_AT; from TERRACE_FOOT out from it, a slope rises RISE to the top at
## TERRACE_TOP, flat in to TERRACE_BACK.
const TERRACE_AT := Vector3(0, FLOOR_Y, 60)
const TERRACE_SPIN := 90.0
const TERRACE_FOOT := 30.0
const TERRACE_TOP := 22.0
const TERRACE_BACK := 12.0

var states_entered: Array[StringName] = []


func before_each() -> void:
	await super()
	player.set_profile(SUPERHUMAN)
	player.state_changed.connect(func(new_state: StringName) -> void: states_entered.append(new_state))
	var ground := _box("SlopeGround", main.level, Vector3(0, FLOOR_Y - 0.5, 0), Vector3(300, 1, 200))
	ground.remove_from_group(&"reach_solid")
	for degrees: float in [30.0, 40.0, 46.0]:
		_wedge("Wedge%d" % degrees, _wedge_x(degrees), deg_to_rad(degrees))
	# A 30° one with a slab across it (1 m deep, 1.2 m over its middle, so 0.9
	# to 1.5 m over the slope under it): no room to run up.
	var low := _wedge("Low", 60.0, deg_to_rad(30.0))
	_box("Slab", main.level, Vector3(56, FLOOR_Y + RISE / 2.0 + 1.2 + 0.25, low.position.z - RISE / tan(deg_to_rad(30.0)) / 2.0), Vector3(8, 0.5, 1))
	# A 30° one rising half way, then a step up (a wall) to its top.
	var stepped := _wedge("Stepped", -20.0, deg_to_rad(30.0))
	var run := RISE / 2.0 / tan(deg_to_rad(30.0))
	stepped.polygon = PackedVector2Array([Vector2(0, 0), Vector2(run, RISE / 2.0), Vector2(run, RISE), Vector2(run + 8.0, RISE), Vector2(run + 8.0, 0)])
	# The terraces.
	var terraces := _shape(CSGPolygon3D.new(), "Terraces", main.level, TERRACE_AT) as CSGPolygon3D
	terraces.mode = CSGPolygon3D.MODE_SPIN
	terraces.spin_degrees = TERRACE_SPIN
	terraces.spin_sides = 24
	terraces.polygon = PackedVector2Array([Vector2(TERRACE_BACK, 0), Vector2(TERRACE_FOOT, 0), Vector2(TERRACE_TOP, RISE), Vector2(TERRACE_BACK, RISE)])
	# A little tower standing on its top, halfway round.
	var tower := CSGBox3D.new()
	tower.name = "Tower"
	tower.size = Vector3(4, 4, 4)
	terraces.add_child(tower)
	tower.global_position = _tower_at()
	await ticks(3)


# --- The checker ------------------------------------------------------------------------

func test_run_up_a_slope_not_too_steep() -> void:
	var map := ReachMap.build(main.level, SUPERHUMAN)
	expect(_run_up(map, "SlopeGround", "Wedge30"), "30°: run up it")
	expect(_run_up(map, "SlopeGround", "Wedge40"), "40°: run up it")
	expect(not _run_up(map, "SlopeGround", "Wedge46"), "46°: too steep")
	expect(map.links.any(func(link: ReachMap.Link) -> bool: return link.how == "run down" and link.from.name == "Wedge30" and link.to.name == "SlopeGround"),
			"and back down")


func test_no_running_up_under_a_slab() -> void:
	var map := ReachMap.build(main.level, SUPERHUMAN)
	expect(map.place_named("Low") != null, "its top is a place")
	expect(not _run_up(map, "SlopeGround", "Low"), "no room under the slab")


func test_a_step_is_no_slope() -> void:
	var map := ReachMap.build(main.level, SUPERHUMAN)
	expect(map.place_named("Stepped") != null, "its top is a place")
	expect(not _run_up(map, "SlopeGround", "Stepped"), "you can't run up a wall at the top of a slope")


func test_a_slope_is_no_place_to_stand() -> void:
	var map := ReachMap.build(main.level, SUPERHUMAN)
	for spot: ReachMap.Spot in map.places:
		if spot.name.begins_with("Wedge30"):
			expect_near(spot.y, FLOOR_Y + RISE, 0.01, "%s is its flat top, not on the slope" % spot.name)


func test_terraces_spun_round() -> void:
	var map := ReachMap.build(main.level, SUPERHUMAN)
	var angle := deg_to_rad(TERRACE_SPIN / 2.0)
	var out := Vector3(cos(angle), 0, -sin(angle)) # (Halfway round.)
	expect(map.is_solid(TERRACE_AT + out * (TERRACE_BACK + TERRACE_TOP) / 2.0 + Vector3.UP * 3.0), "solid under its top")
	expect(map.is_solid(TERRACE_AT + out * (TERRACE_FOOT - 1.0) + Vector3.UP * 0.3), "solid under its slope")
	expect(not map.is_solid(TERRACE_AT + out * (TERRACE_FOOT - 1.0) + Vector3.UP * 2.0), "not over it")
	expect(not map.is_solid(TERRACE_AT + out * (TERRACE_BACK - 1.0) + Vector3.UP * 3.0), "nor inside its back (a ring)")
	var behind := Vector3(cos(-angle), 0, -sin(-angle)) # (Not spun round there.)
	expect(not map.is_solid(TERRACE_AT + behind * (TERRACE_BACK + TERRACE_TOP) / 2.0 + Vector3.UP * 3.0), "nor where it's not spun round to")
	var tops := _places(map, "Terraces")
	var area := 0.0
	for spot: ReachMap.Spot in tops:
		expect_near(spot.y, FLOOR_Y + RISE, 0.01, "%s at the top" % spot.name)
		area += spot.area.get_area()
		for corner: Vector2 in [spot.area.position, spot.area.end, Vector2(spot.area.position.x, spot.area.end.y), Vector2(spot.area.end.x, spot.area.position.y)]:
			var from_middle := corner - Vector2(TERRACE_AT.x, TERRACE_AT.z)
			expect(from_middle.length() >= TERRACE_BACK - 0.05 and from_middle.length() <= TERRACE_TOP + 0.05 and from_middle.x >= -0.05 and from_middle.y <= 0.05,
					"%s's corner %s is on its top" % [spot.name, corner])
	var whole := PI * (TERRACE_TOP * TERRACE_TOP - TERRACE_BACK * TERRACE_BACK) * TERRACE_SPIN / 360.0
	expect(area > 0.6 * whole, "between them, most of it (%.0f of %.0f m²)" % [area, whole])
	expect(_run_up(map, "SlopeGround", "Terraces"), "run up its slope")


func test_no_place_under_a_tower_on_the_terraces() -> void:
	var map := ReachMap.build(main.level, SUPERHUMAN)
	var at := _tower_at()
	var footprint := Rect2(at.x - 2.0, at.z - 2.0, 4.0, 4.0).grow(-0.3)
	for spot: ReachMap.Spot in _places(map, "Terraces"):
		expect(not spot.area.intersects(footprint), "%s isn't under the tower (%s, the tower %s)" % [spot.name, spot.area, footprint])
	expect(map.place_named("Terraces/Tower") != null, "the tower's top is a place")


# --- In the game ------------------------------------------------------------------------

func test_running_up_slopes_in_the_game() -> void:
	for degrees: float in [30.0, 40.0]:
		expect(await _run_up_in_game(degrees), "%d°: up it (at %s, via %s)" % [degrees, player.global_position, states_entered])
	expect(not await _run_up_in_game(46.0), "46°: not (at %s, via %s)" % [player.global_position, states_entered])


func test_running_up_the_terraces_in_the_game() -> void:
	var angle := deg_to_rad(TERRACE_SPIN / 2.0)
	var out := Vector3(cos(angle), 0, -sin(angle))
	await place(TERRACE_AT + out * (TERRACE_FOOT + 10.0) + Vector3.UP * 0.05, yaw_for(-out))
	expect(await _run_until_on(FLOOR_Y + RISE, &"move_forward"), "up the slope, curving round (at %s, via %s)" % [player.global_position, states_entered])


# --- Helpers ----------------------------------------------------------------------------

## Where the little tower on the terraces stands (its middle).
func _tower_at() -> Vector3:
	var angle := deg_to_rad(TERRACE_SPIN / 2.0)
	return TERRACE_AT + Vector3(cos(angle), 0, -sin(angle)) * (TERRACE_BACK + TERRACE_TOP) / 2.0 + Vector3.UP * (RISE + 2.0)


func _wedge_x(degrees: float) -> float:
	return -100.0 + (degrees - 30.0) * 4.0


## A slope `angle` steep, 8 m wide (x from x - 8 to x), rising RISE toward -z
## from z = 0, with a flat top 8 m deep behind it.
func _wedge(wedge_name: String, x: float, angle: float) -> CSGPolygon3D:
	var run := RISE / tan(angle)
	var prism := _shape(CSGPolygon3D.new(), wedge_name, main.level, Vector3(x, FLOOR_Y, 0)) as CSGPolygon3D
	# (Its outline is side-on: its x runs toward -z, y up; pushed out toward -x.)
	prism.basis = Basis(Vector3(0, 0, -1), Vector3.UP, Vector3(1, 0, 0))
	prism.polygon = PackedVector2Array([Vector2(0, 0), Vector2(run, RISE), Vector2(run + 8.0, RISE), Vector2(run + 8.0, 0)])
	prism.depth = 8.0
	return prism


## Runs (plain running and free-running, each tried) at the `degrees` wedge's
## slope from 12 m out; true if either gets onto its top.
func _run_up_in_game(degrees: float) -> bool:
	for action: StringName in [&"move_forward", &"free_run"]:
		await place(Vector3(_wedge_x(degrees) - 4.0, FLOOR_Y + 0.05, 12.0), yaw_for(Vector3.FORWARD))
		if await _run_until_on(FLOOR_Y + RISE, action):
			return true
	return false


func _run_until_on(height: float, action: StringName) -> bool:
	states_entered.clear()
	Input.action_press(action)
	var made_it := false
	for i in 60 * 4:
		await ticks(1)
		if player.state.name == &"Hang":
			Input.action_press(&"jump")
		if player.is_on_floor() and player.global_position.y > height - 0.3:
			made_it = true
			break
	release_all()
	return made_it


## Whether there's a "run up" link from `from` to `to` (or a piece of it).
func _run_up(map: ReachMap, from: String, to: String) -> bool:
	return map.links.any(func(link: ReachMap.Link) -> bool: return link.how == "run up" and link.from.name == from \
			and (link.to.name == to or link.to.name.begins_with(to + "#")))


func _places(map: ReachMap, prefix: String) -> Array:
	return map.places.filter(func(spot: ReachMap.Spot) -> bool: return spot.name == prefix or spot.name.begins_with(prefix + "#"))


func _box(box_name: String, parent: Node, at: Vector3, size: Vector3) -> CSGBox3D:
	var box := _shape(CSGBox3D.new(), box_name, parent, at) as CSGBox3D
	box.size = size
	return box


## Adds `shape` (named `shape_name`) to `parent` at `at`: on its own, solid
## (with collision, in the reach_solid group).
func _shape(shape: CSGShape3D, shape_name: String, parent: Node, at: Vector3) -> CSGShape3D:
	shape.name = shape_name
	shape.use_collision = true
	shape.add_to_group(&"reach_solid")
	parent.add_child(shape)
	shape.global_position = at
	return shape
