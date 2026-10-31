extends GameTest
## The stand-in animations and sounds (see Player._pose_visual, game/sfx.gd),
## on the Free-Run Line with the superhuman profile.

var visual: Node3D


func before_each() -> void:
	main = MAIN_SCENE.instantiate()
	add_child(main)
	main.start_solo("free_run_line")
	await ticks(5)
	player = main.get_node_or_null("Players/1")
	expect(player != null, "the game should have created a player")
	if player:
		player.set_profile(SUPERHUMAN)
		visual = player.get_node("Visual")


func test_readying_a_leap_squashes_you_down() -> void:
	await place(Vector3(0, 0.05, 0), FACE_NORTH)
	Input.action_press(&"free_run")
	Input.action_press(&"jump")
	await ticks(3)
	expect(visual.scale.y > 0.95, "a tap's worth of holding shouldn't squash yet, scale %.2f" % visual.scale.y)
	await ticks(20)
	expect(visual.scale.y < 0.8, "a readied leap should squash you down, scale %.2f" % visual.scale.y)
	expect_near(player.sync_leap_charge, 1.0, 0.01, "others are told the leap is fully readied")
	Input.action_release(&"jump")
	await ticks(4)
	expect(visual.scale.y > 1.05, "the leap should stretch you up, scale %.2f" % visual.scale.y)
	release_all()


func test_gliding_tips_you_forward_and_banks_into_turns() -> void:
	var glider: WorldItem = main.level.get_node("Items/Glider")
	glider.host_give_to(player)
	await place(Vector3(0, 1.05, -545), yaw_for(Vector3.RIGHT))
	Input.action_press(&"move_forward")
	Input.action_press(&"use_item")
	for i in 60:
		await ticks(1)
		if player.global_position.x > 3.0:
			break
	await tap(&"jump")
	await ticks(60)
	expect_state(&"Glide")
	expect(visual.rotation.x < -0.4, "should tip forward (head ahead of feet), pitch %.2f" % visual.rotation.x)
	Input.action_press(&"move_left")
	await ticks(20)
	expect(visual.rotation.z > 0.2, "turning left should bank left, roll %.2f" % visual.rotation.z)
	var wing := glider.global_basis.get_euler()
	expect(absf(wing.x) < 0.3, "the glider should stay fairly level, pitch %.2f" % wing.x)
	release_all()


func test_a_bat_swing_sweeps_the_bat_and_flashes_who_it_hits() -> void:
	var bat: WorldItem = main.level.get_node("Items/Bat")
	bat.host_give_to(player)
	await place(Vector3(0, 0.05, 0), FACE_NORTH)
	await press_event(&"call_buddy")
	var resting := bat.global_position - player.global_position
	await tap(&"use_item")
	await ticks(1)
	var swinging := bat.global_position - player.global_position
	expect(swinging.distance_to(resting) > 0.3, "the bat should swing round, moved %.2f m" % swinging.distance_to(resting))
	var buddy_body: MeshInstance3D = main.buddy.model.body
	var material := buddy_body.material_override as StandardMaterial3D
	expect(material.emission_enabled, "the buddy should flash when hit")
	await ticks(30)
	expect((bat.global_position - player.global_position).distance_to(resting) < 0.05, "and come back to rest")
	expect(not material.emission_enabled, "and the flash fades")


func test_every_sound_can_be_made() -> void:
	for sound: StringName in [&"jump", &"leap", &"land", &"swing", &"whack", &"glide", &"pickup", &"relic", &"delivered"]:
		var stream: AudioStreamWAV = Sfx._stream(sound)
		expect(stream.get_length() > 0.05, "%s should be a real sound, %.2f s" % [sound, stream.get_length()])
