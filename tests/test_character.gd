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


# --- Cosmetics (player/cosmetics.gd, cosmetics/fits.cfg) ---------------------------

func test_every_cosmetic_has_a_fit() -> void:
	var fits := ConfigFile.new()
	expect(fits.load(Cosmetics.FITS) == OK, "the fits file should load")
	for slot in Cosmetics.SLOTS:
		for item in Cosmetics.available(slot):
			expect(fits.has_section("%s/%s" % [slot, item]), "%s/%s should be fitted in %s" % [slot, item, Cosmetics.FITS])
	for item in Cosmetics.available(&"trail"):
		for key in ["along", "up", "length"]:
			expect(fits.has_section_key("trail/" + item, key), "trail/%s should say its %s" % [item, key])
		if item.begins_with("scarf/") and ResourceLoader.exists("res://cosmetics/trail/%s_neck.glb" % item):
			expect(fits.has_section("trail/%s_neck" % item), "%s's neck should be fitted" % item)


func test_cosmetics_sit_on_their_bones_with_pairs_mirrored() -> void:
	var outfit := PackedStringArray()
	for slot in Cosmetics.SLOTS:
		outfit.append(Cosmetics.available(slot)[0])
	player.sync_outfit = outfit
	await ticks(2)
	# How far each item's middle may be from its bone (the waist bone is low in the belly).
	var reach := {&"head": 0.45, &"hands": 0.3, &"waist": 0.35, &"feet": 0.3}
	for slot: StringName in Cosmetics.BONES:
		var bones: Array = Cosmetics.BONES[slot]
		for i in bones.size():
			var attachment := skeleton.get_node_or_null("%s%s_%d" % [Cosmetics.PREFIX, slot, i]) as BoneAttachment3D
			expect(attachment != null, "%s should be worn on %s" % [slot, bones[i]])
			if attachment == null:
				continue
			var item := attachment.get_child(0) as Node3D
			var bone := _bone(StringName(bones[i]))
			expect(item.global_position.distance_to(bone) < reach[slot], "%s should sit on %s, %.2f m away" % [slot, bones[i], item.global_position.distance_to(bone)])
			var mirrored := item.global_basis.determinant() < 0.0
			expect(mirrored == (i == 1), "the %s %s should %sbe the mirror image" % [["left", "right"][i], slot, "" if i == 1 else "not "])
	var hat := skeleton.get_node("%shead_0" % Cosmetics.PREFIX).get_child(0) as Node3D
	expect(hat.global_position.y > _bone(&"mixamorig_Head").y + 0.15, "the hat should sit on top of the head")
	player.sync_outfit = PackedStringArray()
	await ticks(2)
	expect(skeleton.get_children().all(func(node: Node) -> bool: return not node.name.begins_with(Cosmetics.PREFIX)),
			"an empty outfit should take everything off")


func test_o_cycles_through_outfits_and_back_to_nothing() -> void:
	var outfits := 0
	for slot in Cosmetics.SLOTS:
		outfits = maxi(outfits, Cosmetics.available(slot).size())
	await press_event(&"cycle_outfit")
	expect(player.sync_outfit[0] == Cosmetics.available(&"head")[0], "the first outfit should have the first hat, got %s" % [player.sync_outfit])
	for i in outfits:
		await press_event(&"cycle_outfit")
	expect(Array(player.sync_outfit).all(func(item: String) -> bool: return item.is_empty()), "then back to nothing, got %s" % [player.sync_outfit])


func test_a_move_can_have_a_set_of_animations_to_pick_from() -> void:
	expect(CharacterModel.move_of("vault-kong") == "vault" and CharacterModel.move_of("vault") == "vault", "'vault-kong' is one of the vault set")
	expect(CharacterModel.move_of("crouch_idle") == "crouch_idle", "(underscores are part of a name)")
	var model := player.model
	CharacterModel._variants["test_move"] = [&"test_move", &"test_move-flip", &"test_move-roll"]
	var picked := {}
	for variant in 6:
		model._variant = variant
		picked[model.pick(&"test_move")] = true
	CharacterModel._variants.erase("test_move")
	expect(picked.size() == 3, "different moves pick different ones of the set, picked %s" % [picked.keys()])
	expect(model.pick(&"idle") == &"idle" or CharacterModel.variants_of("idle").size() > 1, "a move with one animation just plays it")


func test_each_new_move_rolls_a_new_variant() -> void:
	var seen := {}
	for i in 20:
		player.change_state(&"Air" if i % 2 == 0 else &"Ground")
		seen[player.sync_move] = true
	expect(seen.size() > 10, "starting moves picks new numbers, %d different in 20" % seen.size())


func test_a_move_without_its_own_animation_plays_its_stand_in() -> void:
	if CharacterModel.variants_of("brace").is_empty():
		expect(player.model.pick(&"brace") == &"crouch_idle", "no brace animation yet: crouching stands in, got %s" % player.model.pick(&"brace"))
	for move: String in CharacterModel.STAND_INS:
		expect(not CharacterModel.variants_of(String(CharacterModel.STAND_INS[move])).is_empty(), "the stand-in for %s exists" % move)
	for state: StringName in CharacterModel.STATE_MOVES:
		var move: StringName = CharacterModel.STATE_MOVES[state]
		expect(not CharacterModel.variants_of(String(player.model.pick(move))).is_empty() or CharacterModel.variants_of(String(move)).size() > 0 \
				or ["linked", "whip", "whipped"].has(String(move)), "%s plays something (%s)" % [state, move])
