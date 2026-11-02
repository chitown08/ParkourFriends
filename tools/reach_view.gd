extends SceneTree
## Draws a world from above, every place coloured by how many players it takes
## to get there from the start (game/reach/): green alone, yellow two, orange
## three, red four or more, dark grey nobody (yet). Relics are the small
## squares, coloured the same way. Higher places are drawn over lower ones.
##
## Usage (from the project folder):
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/reach_view.gd -- <out.png> [world, default rooftop_district] [abilities, default flow]

const PIXELS_PER_METRE := 2.0
const MARGIN := 20.0
const MAX_PLAYERS := 4
const COLORS: Array[Color] = [
	Color(0.25, 0.25, 0.28), # nobody
	Color(0.3, 0.75, 0.35), # alone
	Color(0.95, 0.85, 0.25), # two
	Color(0.95, 0.55, 0.15), # three
	Color(0.9, 0.25, 0.2), # four or more
]


func _init() -> void:
	_draw.call_deferred()


func _draw() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://reach_view.png"
	var world: String = args[1] if args.size() > 1 else "rooftop_district"
	var abilities: Array[StringName] = []
	for ability in (args[2] if args.size() > 2 else "flow").split(",", false):
		abilities.append(StringName(ability))
	var level: Node = (load("res://levels/%s.tscn" % world) as PackedScene).instantiate()
	root.add_child(level)
	await process_frame
	await physics_frame

	var map := ReachMap.build(level, load("res://player/profiles/superhuman.tres"))
	var start := map.place_under(level.get_node("SpawnPoint").global_position + Vector3.UP)
	# The fewest players each spot needs (solving once per group size).
	var needed := {}
	for players in range(MAX_PLAYERS, 0, -1):
		for spot: ReachMap.Spot in map.solve(start, players, abilities):
			needed[spot] = players

	var bounds := Rect2()
	for spot in map.places:
		bounds = spot.area if bounds.size == Vector2.ZERO else bounds.merge(spot.area)
	var image := Image.create(int(bounds.size.x * PIXELS_PER_METRE + 2 * MARGIN), int(bounds.size.y * PIXELS_PER_METRE + 2 * MARGIN), false, Image.FORMAT_RGB8)
	image.fill(Color(0.12, 0.12, 0.14))
	var by_height := map.places.duplicate()
	by_height.sort_custom(func(a: ReachMap.Spot, b: ReachMap.Spot) -> bool: return a.y < b.y)
	for spot: ReachMap.Spot in by_height:
		var color := COLORS[mini(needed.get(spot, 0), COLORS.size() - 1)]
		# Higher places a little lighter, so roofs stand out from the street.
		color = color.lerp(Color.WHITE, clampf(spot.y / 80.0, 0.0, 0.35))
		var rect := _to_pixels(spot.area, bounds)
		image.fill_rect(rect, color.darkened(0.45))
		image.fill_rect(rect.grow(-1), color)
	for target in map.targets:
		var rect := _to_pixels(Rect2(target.area.position - Vector2.ONE * 2.0, Vector2.ONE * 4.0), bounds)
		image.fill_rect(rect.grow(2), Color.WHITE)
		image.fill_rect(rect, COLORS[mini(needed.get(target, 0), COLORS.size() - 1)])
	var at := _to_pixels(Rect2(Vector2(start.middle().x, start.middle().z) - Vector2.ONE * 2.0, Vector2.ONE * 4.0), bounds)
	image.fill_rect(at.grow(2), Color.BLACK)
	image.fill_rect(at, Color(0.3, 0.6, 1.0))
	image.save_png(out)
	print("Wrote %s: %d places, %d relics, %d links" % [out, map.places.size(), map.targets.size(), map.links.size()])
	quit()


func _to_pixels(area: Rect2, bounds: Rect2) -> Rect2i:
	var top_left := (area.position - bounds.position) * PIXELS_PER_METRE + Vector2.ONE * MARGIN
	return Rect2i(Vector2i(top_left), Vector2i(maxi(int(area.size.x * PIXELS_PER_METRE), 2), maxi(int(area.size.y * PIXELS_PER_METRE), 2)))
