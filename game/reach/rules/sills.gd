extends ReachRule
## Columns of window sills (the district's WaysUp, named <building>_Sill1, 2,
## ...): jump to grab the lowest, ledge-leap up each to the next, then up onto
## the roof. Only counted if every step is in reach.


func add_links(map: ReachMap) -> void:
	var m := map.moves
	for node in map.level.find_children("*_Sill1", "CSGBox3D", true, false):
		var prefix := String(node.name).trim_suffix("1")
		var tops: Array[float] = []
		var k := 1
		var sill: Node3D = node
		while sill:
			tops.append(sill.global_position.y + (sill as CSGBox3D).size.y / 2.0)
			k += 1
			sill = node.get_parent().get_node_or_null(prefix + str(k))
		var foot := map.place_under(Vector3(node.global_position.x, tops[0] - 1.0, node.global_position.z))
		var roof := map.place_under(Vector3(node.global_position.x, INF, node.global_position.z) + _into_wall(map, node) * 1.0)
		if foot == null or roof == null or tops[0] - foot.y > m.jump_height + m.ledge_max_height:
			continue
		tops.append(roof.y)
		var ok := true
		for i in tops.size() - 1:
			ok = ok and tops[i + 1] - tops[i] <= m.ledge_leap_height
		if ok:
			map.add_link(foot, roof, "window sills")


## Which way the wall a sill sticks out of is (its long side is along the wall).
func _into_wall(map: ReachMap, sill: CSGBox3D) -> Vector3:
	var along_x := sill.size.x > sill.size.z
	for spot in map.places:
		if spot.area.grow(0.6).has_point(Vector2(sill.global_position.x, sill.global_position.z)) and spot.y > sill.global_position.y:
			var middle := spot.middle()
			var way := Vector3(0, 0, signf(middle.z - sill.global_position.z)) if along_x else Vector3(signf(middle.x - sill.global_position.x), 0, 0)
			return way
	return Vector3.ZERO
