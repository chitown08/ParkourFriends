extends GameTest
## Trails (player/trail.gd): banners, streamers and scarves that stream out
## behind you, on the Free-Run Line with the superhuman profile.


func before_each() -> void:
	main = MAIN_SCENE.instantiate()
	add_child(main)
	main.start_solo("free_run_line")
	await ticks(5)
	player = main.get_node_or_null("Players/1")
	expect(player != null, "the game should have created a player")
	if player:
		player.set_profile(SUPERHUMAN)


func test_every_trail_streams_out_behind_a_running_player() -> void:
	for item in Cosmetics.available(&"trail"):
		await place(Vector3(0, 0.05, 0), FACE_NORTH)
		_wear(item)
		Input.action_press(&"move_forward")
		await ticks(90)
		release_all()
		for trail in _trails():
			var behind := (trail.tip() - trail.anchor.global_position).dot(-player.facing_direction())
			expect(behind > trail.length * 0.6, "%s should stream out behind you, its end %.2f m back of %.2f m" % [item, behind, trail.length])


func test_standing_still_the_breeze_carries_it_out_behind_you() -> void:
	await place(Vector3(0, 0.05, 0), FACE_NORTH)
	_wear("streamer/" + _first("streamer"))
	await ticks(60)
	# Turn round on the spot: it should swing round to fly out behind you again.
	player.face_direction(Vector3.BACK, 1.0)
	await ticks(240)
	var trail := _trails()[0]
	var out := trail.tip() - trail.anchor.global_position
	var behind := out.dot(-player.facing_direction())
	expect(behind > trail.length / 3.0, "standing still, the breeze should carry it out behind you (%.2f m)" % behind)
	expect(out.y < 0.0, "and it should hang a little (%.2f m)" % out.y)


func test_a_trail_keeps_its_length_and_stays_out_of_your_body() -> void:
	await place(Vector3(0, 0.05, 0), FACE_NORTH)
	_wear("scarf/" + _first("scarf"))
	var skeleton := _skeleton()
	Input.action_press(&"move_forward")
	var worst_stretch := 0.0
	var deepest := 0.0
	for i in 150:
		await ticks(1)
		if i == 60:
			Input.action_release(&"move_forward")
			Input.action_press(&"move_back") # Turn round: the scarf swings across you.
		for trail in _trails():
			var points := trail.points()
			for p in range(1, points.size()):
				var link := points[p].distance_to(points[p - 1])
				worst_stretch = maxf(worst_stretch, absf(link - trail.length / Trail.SEGMENTS))
				deepest = maxf(deepest, Trail.BODY_RADIUS - _from_body_axis(skeleton, points[p]))
	release_all()
	expect(worst_stretch < 0.01, "the links shouldn't stretch, worst %.3f m" % worst_stretch)
	expect(deepest < 0.05, "it shouldn't pass into your body, %.2f m in at worst" % deepest)


func test_after_a_respawn_the_trail_comes_with_you_calmly() -> void:
	await place(Vector3(0, 0.05, -16), FACE_NORTH)
	_wear("banner/" + _first("banner"))
	await ticks(30)
	# Back down the course: it mustn't whip round from where you were.
	player.global_position = Vector3(0, 0.05, 0)
	player.reset_physics_interpolation()
	var trail := _trails()[0]
	await ticks(1)
	var last := trail.tip() - trail.anchor.global_position
	var wildest := 0.0
	for i in 30:
		await ticks(1)
		var out := trail.tip() - trail.anchor.global_position
		wildest = maxf(wildest, out.distance_to(last))
		last = out
	expect(wildest < 0.3, "the banner should be laid out afresh, not thrash about (%.2f m in one step)" % wildest)


func test_banners_and_streamers_fly_from_a_pole_and_scarves_from_your_neck() -> void:
	_wear("banner/" + _first("banner"))
	await ticks(2)
	expect(_skeleton().has_node(Cosmetics.PREFIX + "trail_pole"), "a banner needs its pole")
	expect(_trails().size() == 1, "one banner")
	expect(_trails()[0].anchor.global_position.y > _bone_y(&"mixamorig_HeadTop_End") + 0.5, "flying from well over your head")
	_wear("scarf/" + _first("scarf"))
	await ticks(2)
	expect(not _skeleton().has_node(Cosmetics.PREFIX + "trail_pole"), "swapping to a scarf takes the pole off")
	expect(_skeleton().has_node(Cosmetics.PREFIX + "trail_neck"), "a scarf wraps your neck")
	expect(_trails().size() == 2, "and has two tails, %d" % _trails().size())


func _wear(item: String) -> void:
	var outfit := PackedStringArray(["", "", "", "", item])
	player.sync_outfit = outfit


func _first(kind: String) -> String:
	for item in Cosmetics.available(&"trail"):
		if item.begins_with(kind + "/"):
			return item.get_slice("/", 1)
	return ""


func _skeleton() -> Skeleton3D:
	return player.model.find_children("*", "Skeleton3D", true, false)[0]


func _trails() -> Array[Trail]:
	var found: Array[Trail] = []
	for node in _skeleton().get_children():
		if node is Trail:
			found.append(node)
	return found


func _bone_y(bone: StringName) -> float:
	var skeleton := _skeleton()
	return (skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin).y


## How far `point` is from the middle line of the body (inside the capsule's height).
func _from_body_axis(skeleton: Skeleton3D, point: Vector3) -> float:
	var middle := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(Trail.BODY_BONE)).origin
	var axis := skeleton.global_basis.y.normalized()
	var along := (point - middle).dot(axis)
	if absf(along) > Trail.BODY_HALF_HEIGHT:
		return INF
	return (point - middle - axis * along).length()
