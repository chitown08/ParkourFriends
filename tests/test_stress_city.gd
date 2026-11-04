extends GameTest
## The stress city (levels/stress_city.gd: a throwaway for measuring how big a
## world can go) loads, baked, and you can stand on the hub and run about.


func test_you_land_on_the_hub_and_can_run() -> void:
	StressCity.size = 1000.0 # (Small, to be quick.)
	main.leave_game()
	await ticks(5)
	main.start_solo("stress_city")
	await ticks(30)
	player = main.get_node("Players/1")
	expect(main.level.find_children("Chunk*", "MeshInstance3D", true, false).size() > 0, "it's baked into chunks")
	expect(player.is_on_floor() and absf(player.global_position.y - StressCity.HUB_HEIGHT) < 0.5, "standing on the hub's roof (at %s)" % player.global_position)
	var start := player.global_position
	await hold(&"move_forward", 60)
	expect(player.global_position.distance_to(start) > 3.0 and player.global_position.y > StressCity.HUB_HEIGHT - 0.5, "running across it (at %s)" % player.global_position)
	StressCity.size = 3000.0
