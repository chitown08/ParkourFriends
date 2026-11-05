extends ReachRule
## Fire escape stairs (levels/stairs.gd): run up a flight from the deck (or
## street) at its foot to the deck at its top. (Down is a drop: the jump rule.)


func add_links(map: ReachMap) -> void:
	for stairs: Stairs in map.level.find_children("*", "Stairs", true, false):
		var inward := stairs.toward_wall() * absf(stairs.landing_in)
		var foot := map.place_under(stairs.bottom() + inward + Vector3.UP * 0.3)
		var head := map.place_under(stairs.top() + inward + Vector3.UP * 0.3)
		if head == null or absf(head.y - stairs.top().y) > 0.3:
			# (The last flight: onto a landing just past its top.)
			var along := (stairs.top() - stairs.bottom())
			along = Vector3(along.x, 0.0, along.z).normalized()
			head = map.place_under(stairs.top() + along * 1.0 + Vector3.UP * 0.3)
		if foot != null and head != null and absf(head.y - stairs.top().y) < 0.3 and head.y > foot.y:
			map.add_link(foot, head, "fire escape stairs", [], 0, 0, 0, false)
