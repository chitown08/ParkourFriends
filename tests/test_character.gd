extends GameTest
## The character model and its animations (see CharacterModel and
## docs/CHARACTER_GUIDE.md), on the Free-Run Line with the superhuman profile.

const MOVES: Array[String] = ["idle", "run", "sprint", "jump", "fall", "land", "slide", "hang",
		"climb_up", "vault", "crouch_idle", "crouch_walk", "wall_run_left", "wall_run_right",
		"wall_scramble", "grind", "glide", "throw", "swing", "toss", "carry", "tossed"]
const LOOPING: Array[String] = ["idle", "run", "sprint", "fall", "hang", "crouch_idle", "crouch_walk",
		"wall_run_left", "wall_run_right", "wall_scramble", "grind", "glide", "carry"]

var skeleton: Skeleton3D


func before_each() -> void:
	main = MAIN_SCENE.instantiate()
	add_child(main)
	main.start_solo("free_run_line")
	await ticks(5)
	player = main.get_node_or_null("Players/1")
	expect(player != null, "the game should have created a player")
	if player:
		player.set_profile(SUPERHUMAN)
		skeleton = player.model.find_children("*", "Skeleton3D", true, false)[0]


func test_every_move_has_an_animation() -> void:
	for move in MOVES:
		var file := "res://characters/blob/anims/%s.res" % move
		expect(ResourceLoader.exists(file), "%s should have an animation" % move)
		if ResourceLoader.exists(file):
			var animation: Animation = load(file)
			var loops := animation.loop_mode != Animation.LOOP_NONE
			expect(loops == (move in LOOPING), "%s should %sloop" % [move, "" if move in LOOPING else "not "])


func test_the_character_stands_on_its_feet_facing_forward() -> void:
	await place(Vector3(0, 0.05, 0), FACE_NORTH)
	await ticks(30)
	var feet := player.global_position.y
	var head := _bone(&"mixamorig_HeadTop_End")
	var toe := _bone(&"mixamorig_LeftToeBase")
	expect(head.y - feet > 1.4 and head.y - feet < 2.0, "the head should be about 1.8 m up, %.2f m" % (head.y - feet))
	expect(absf(toe.y - feet) < 0.25, "the feet should be on the ground, %.2f m off" % (toe.y - feet))
	var toes_point := (toe - _bone(&"mixamorig_LeftFoot")).slide(Vector3.UP).normalized()
	expect(toes_point.dot(player.facing_direction()) > 0.5, "the character should face the way you're going")


func test_animations_follow_what_youre_doing() -> void:
	await place(Vector3(0, 0.05, 0), FACE_NORTH)
	await ticks(30)
	_expect_playing(&"idle", "standing still")
	Input.action_press(&"move_forward")
	await ticks(30)
	_expect_playing(&"run", "running")
	player.debug_full_flow = true
	await ticks(60)
	_expect_playing(&"sprint", "at full flow")
	player.debug_full_flow = false
	release_all()
	await ticks(60)
	Input.action_press(&"jump")
	await ticks(6)
	_expect_playing(&"jump", "going up")
	await ticks(40)
	_expect_playing(&"fall", "coming down")
	release_all()
	await ticks(60)
	Input.action_press(&"crouch")
	await ticks(20)
	_expect_playing(&"crouch_idle", "crouching")
	release_all()


func test_moves_that_travel_are_held_in_place() -> void:
	# The slide, vault and jump came out of Mixamo travelling metres on their own.
	var animations: AnimationPlayer = player.model.find_children("*", "AnimationPlayer", true, false)[0]
	for move in ["slide", "vault", "jump", "sprint", "climb_up"]:
		var animation := animations.get_animation("moves/" + move)
		var hips := animation.find_track(NodePath("Skeleton3D:mixamorig_Hips"), Animation.TYPE_POSITION_3D)
		var last := animation.track_get_key_count(hips) - 1
		var travel: Vector3 = animation.track_get_key_value(hips, last) - animation.track_get_key_value(hips, 0)
		expect(Vector2(travel.x, travel.z).length() < 0.05, "%s shouldn't travel across the ground, %.2f m" % [move, Vector2(travel.x, travel.z).length()])
	var climb := animations.get_animation("moves/climb_up")
	var hips := climb.find_track(NodePath("Skeleton3D:mixamorig_Hips"), Animation.TYPE_POSITION_3D)
	var rise: float = (climb.track_get_key_value(hips, climb.track_get_key_count(hips) - 1) - climb.track_get_key_value(hips, 0)).y
	expect(absf(rise) < 0.05, "the climb-up shouldn't lift you by itself (the game does), %.2f m" % rise)


func test_running_plays_faster_the_faster_you_go() -> void:
	await place(Vector3(0, 0.05, 0), FACE_NORTH)
	Input.action_press(&"move_forward")
	await ticks(20)
	var slower := _animation_speed()
	await ticks(25)
	expect(_animation_speed() > slower, "the run should speed up as you do, %.2f then %.2f" % [slower, _animation_speed()])
	release_all()


func _bone(bone: StringName) -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin


func _animation_speed() -> float:
	var animations: AnimationPlayer = player.model.find_children("*", "AnimationPlayer", true, false)[0]
	return animations.speed_scale


func _expect_playing(animation: StringName, doing: String) -> void:
	expect(player.model.current_animation() == animation, "%s should play %s, playing %s" % [doing, animation, player.model.current_animation()])
