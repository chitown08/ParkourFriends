extends GameTest
## Delivery celebrations (game/celebration.gd): a party at the drop-off when a
## relic comes in, bigger the more style it came with: confetti; streamers;
## fireworks; lots of fireworks. On the Free-Run Line (its drop-off is 7 m
## west of the spawn).

const DROP_OFF := Vector3(-7, 0.05, 0)


func before_each() -> void:
	main = MAIN_SCENE.instantiate()
	add_child(main)
	main.start_solo("free_run_line")
	await ticks(5)
	player = main.get_node("Players/1")
	player.set_profile(SUPERHUMAN)
	await ticks(10)


func test_more_style_a_bigger_party() -> void:
	expect(Celebration.tier_for(2.0, 0.0, 1, false) == 1, "walked in: a little party")
	expect(Celebration.tier_for(14.0, 0.0, 1, false) == 2, "running in fast: bigger")
	expect(Celebration.tier_for(2.0, 10.0, 1, false) == 2, "dropping in from a roof: bigger")
	expect(Celebration.tier_for(2.0, 20.0, 1, false) == 3, "from a tall one: fireworks")
	expect(Celebration.tier_for(12.0, 12.0, 1, false) == 3, "fast and high: fireworks")
	expect(Celebration.tier_for(15.0, 0.0, 4, false) == 4, "four of you free-running in together: the biggest")
	expect(Celebration.tier_for(15.0, 25.0, 2, true) == 4, "fast, high, with a friend, thrown in: the biggest")


func test_walking_a_relic_in_gets_a_small_party() -> void:
	var relic: WorldItem = main.level.get_node("Relics/RelicPillarTop")
	relic.host_give_to(player)
	await place(DROP_OFF, FACE_NORTH)
	expect(main.hud.get_node("Message").text.begins_with("Relic delivered!"), "a plain delivery: '%s'" % main.hud.get_node("Message").text)
	expect(_particles() > 0, "with confetti")


func test_dropping_in_from_high_gets_fireworks() -> void:
	var relic: WorldItem = main.level.get_node("Relics/RelicPillarTop")
	relic.host_give_to(player)
	# Falling in from 24 m up.
	player.global_position = DROP_OFF + Vector3.UP * 24.0
	player.velocity = Vector3.ZERO
	player.change_state(&"Air")
	player.reset_physics_interpolation()
	for i in 120:
		await ticks(1)
		if relic.state == WorldItem.State.DELIVERED:
			break
	var said: String = main.hud.get_node("Message").text
	expect(said.begins_with("Spectacular!") or said.begins_with("LEGENDARY!"), "a big drop: a big party, '%s'" % said)
	var lights_before := _lights()
	await ticks(90) # (The rockets go up, then burst.)
	expect(_lights() > lights_before, "fireworks burst over the drop-off")


func test_the_crew_coming_in_free_running_together_counts() -> void:
	main.call_buddy()
	var buddy: Player = main.buddy
	buddy.is_bot = false # (Counts as a friend here.)
	buddy.global_position = DROP_OFF + Vector3(3, 0, 0)
	buddy.sync_free_run_velocity = Vector3(0, 0, -12)
	player.sync_free_run_velocity = Vector3(0, 0, -12)
	player.global_position = DROP_OFF
	var together: int = main.delivery_pack(player)
	buddy.global_position = DROP_OFF + Vector3(30, 0, 0)
	var apart: int = main.delivery_pack(player)
	buddy.is_bot = true
	expect(together == 2 and apart == 1, "a friend free-running in with you counts (2), one far off doesn't (1): %d, %d" % [together, apart])


func test_everyone_sees_a_celebration() -> void:
	Celebration.play(main, DROP_OFF + Vector3.UP, 2)
	await ticks(2)
	expect(_particles() >= 2, "confetti and streamers")


## Particle effects about.
func _particles() -> int:
	return get_viewport().find_children("*", "CPUParticles3D", true, false).size() + get_viewport().find_children("*", "GPUParticles3D", true, false).size()


func _lights() -> int:
	return get_viewport().find_children("*", "OmniLight3D", true, false).size()
