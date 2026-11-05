extends ReachRule
## Zip lines (levels/zip_line.gd): from the roof at the high pole's foot, jump
## up and grab the cable (its top is POLE over the roof: a standing jump's
## reach), and you're carried down to the roof at the low pole's foot.


func add_links(map: ReachMap) -> void:
	for line: ZipLine in map.level.find_children("*", "ZipLine", true, false):
		var top := map.place_under(line.global_position + Vector3.UP * 0.5)
		var bottom := map.place_under(line.global_transform * line.end + Vector3.UP * 0.5)
		var reach := map.moves.jump_height + ZipLine.HANDS + ZipLine.GRAB_REACH
		if top != null and bottom != null and bottom.y < top.y and line.start_point().y - top.y <= reach:
			map.add_link(top, bottom, "zip line", [], 0, 0, 0, false)
