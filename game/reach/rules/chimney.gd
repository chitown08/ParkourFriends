extends ReachRule
## Climbing a chimney (player.gd try_chimney_kick()): in a gap no wider than
## Player.CHIMNEY_WIDTH between two walls facing each other (an alley between
## two buildings), free-running with jump held, you kick from wall to wall up
## to the top of the lower one, and onto its roof. From whatever's at the
## bottom of the gap (the street, say). Both walls must go straight up (not
## lean out over you), and the gap be open all the way up.

## The walls must face each other along at least this much of their length.
const FACING := 2.0


func add_links(map: ReachMap) -> void:
	for i in map.places.size():
		var a: ReachMap.Spot = map.places[i]
		for j in range(i + 1, map.places.size()):
			var b: ReachMap.Spot = map.places[j]
			var width := ReachMap.gap(a, b)
			if width < 1.0 or width > Player.CHIMNEY_WIDTH:
				continue
			var between := _between(a, b)
			if between.size.x < 0.0:
				continue # (Not facing each other along FACING.)
			var lower := a if a.y < b.y else b
			var higher := b if lower == a else a
			var middle := between.get_center()
			var floor := map.place_under(Vector3(middle.x, lower.y - 1.0, middle.y))
			if floor == null or lower.y - floor.y < 3.0:
				continue # (Low enough to jump or scramble: other rules.)
			var bottom := ReachMap.Spot.new()
			bottom.area = between
			bottom.y = floor.y
			if not map.segment_clear(Vector3(middle.x, floor.y + 1.0, middle.y), Vector3(middle.x, lower.y + 1.0, middle.y)):
				continue # (Something in the gap: a bridge, a net...)
			if map.wall_up(bottom, lower, lower.y - floor.y) and map.wall_up(bottom, higher, higher.y - floor.y):
				map.add_link(floor, lower, "chimney", [], 0, 0, 0, false)


## The strip of ground between `a` and `b` (from above) where they face each
## other along at least FACING, or a rectangle with a negative size if they don't.
static func _between(a: ReachMap.Spot, b: ReachMap.Spot) -> Rect2:
	var ra := a.area
	var rb := b.area
	# Side by side along x (a gap in x, overlapping in z), or along z.
	var overlap_z := minf(ra.end.y, rb.end.y) - maxf(ra.position.y, rb.position.y)
	var overlap_x := minf(ra.end.x, rb.end.x) - maxf(ra.position.x, rb.position.x)
	if overlap_z >= FACING and (ra.end.x <= rb.position.x or rb.end.x <= ra.position.x):
		var x0 := ra.end.x if ra.end.x <= rb.position.x else rb.end.x
		var x1 := rb.position.x if ra.end.x <= rb.position.x else ra.position.x
		return Rect2(x0, maxf(ra.position.y, rb.position.y), x1 - x0, overlap_z)
	if overlap_x >= FACING and (ra.end.y <= rb.position.y or rb.end.y <= ra.position.y):
		var z0 := ra.end.y if ra.end.y <= rb.position.y else rb.end.y
		var z1 := rb.position.y if ra.end.y <= rb.position.y else ra.position.y
		return Rect2(maxf(ra.position.x, rb.position.x), z0, overlap_x, z1 - z0)
	return Rect2(0, 0, -1, -1)
