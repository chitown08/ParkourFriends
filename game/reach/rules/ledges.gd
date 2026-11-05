extends ReachRule
## Rows of window ledges (levels/ledges.gd) up a wall to its roof: from
## somewhere beside the wall (the street, a lower roof, a fire escape deck),
## jump and grab a ledge, then leap up ledge by ledge (each within a ledge
## leap of the last) and pull up onto the roof. Or catch a ledge from a jump
## across a gap (a running jump, or a readied leap), coming down onto it.

## Places this close (from above) to the ledges count as beside the wall.
const NEXT_TO := 1.0
## How far in front of your body you catch a ledge (body radius + Player
## ledge_detect_distance, about).
const REACH := 0.8


func add_links(map: ReachMap) -> void:
	var m := map.moves
	var jumps := [["jump", m.run_speed, m.jump_height], ["leap", m.free_run_speed + m.leap_boost, m.leap_height]]
	var farthest := map.air_distance(m.leap_height, m.free_run_speed + m.leap_boost, -40.0)
	for ledges: Ledges in map.level.find_children("*", "Ledges", true, false):
		var base := ledges.global_position.y
		var top := base + ledges.top
		var out := ledges.out_of_wall()
		var heights: Array[float] = []
		for h in ledges.heights:
			heights.append(base + h)
		heights.sort()
		if heights.is_empty() or top - heights[-1] > m.ledge_leap_height:
			continue
		# The lowest ledge you can climb all the way up from.
		var lowest := heights.size() - 1
		while lowest > 0 and heights[lowest] - heights[lowest - 1] <= m.ledge_leap_height:
			lowest -= 1
		for piece in ledges.pieces():
			var a := ledges.point_at(piece.x, top)
			var b := ledges.point_at(piece.y, top)
			var middle := (a + b) / 2.0
			var roof := map.place_under(middle - out * 1.0 + Vector3.UP * 0.5)
			if roof == null or absf(roof.y - top) > 0.3:
				continue
			var strip := Rect2(Vector2(a.x, a.z), Vector2.ZERO).expand(Vector2(b.x, b.z)).expand(Vector2(a.x, a.z) + Vector2(out.x, out.z) * Ledges.DEPTH)
			for from in map.places:
				if from == roof or from.y > top - 1.0:
					continue
				var edge := ReachMap._closest_in(from.area, strip.get_center())
				var nearest := ReachMap._closest_in(strip, edge)
				var away := nearest - edge
				if not from.area.grow(0.3).intersects(strip) and away.dot(Vector2(out.x, out.z)) > -0.01:
					continue # (Behind the wall: on its roof, or inside.)
				var distance := away.length()
				if distance > farthest:
					continue
				var how := _how(map, from, heights, lowest, distance, edge, nearest, out, jumps)
				if how != "":
					map.add_link(from, roof, how, [], 0, 0, 0, false)


## How you'd get from `from` onto the ledges (`distance` away from its edge
## at `edge`, the ledges at `nearest`): "" if you can't.
func _how(map: ReachMap, from: ReachMap.Spot, heights: Array[float], lowest: int, distance: float, edge: Vector2, nearest: Vector2, out: Vector3, jumps: Array) -> String:
	var m := map.moves
	for i in range(lowest, heights.size()):
		var above := heights[i] - from.y
		if distance <= NEXT_TO and above >= m.hang_min_height and above <= m.jump_height + m.ledge_max_height:
			return "ledges"
	# Caught from a jump across a gap: as you come down to it (the ledge at
	# the top of your reach), with room to fly across.
	for jump: Array in jumps:
		for i in range(lowest, heights.size()):
			var rise := heights[i] - m.ledge_max_height - from.y
			if rise > jump[2] * 0.9:
				break
			var reach := map.air_distance(jump[2], jump[1], rise)
			if distance + ReachMap.JUMP_MARGIN > reach + REACH:
				continue
			var at := from.y + ReachMap.PATH_MIDDLE + maxf(rise, 0.0)
			var to := Vector3(nearest.x, at, nearest.y) + out * 0.5
			if map.segment_clear(Vector3(edge.x, at, edge.y), to):
				return "ledges (caught from a %s)" % jump[0]
	return ""
