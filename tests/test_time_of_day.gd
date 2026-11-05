extends GameTest
## Times of day (game/time_of_day.gd, materials/sky.gdshader): the host picks
## one in the pause menu; it sets the sky, the sun, the light and the fog, and
## after dark the city's windows light up and coloured things glow.


func after_each() -> void:
	main.set_time_of_day("day")
	await super()


func test_each_time_of_day_sets_the_sky_sun_and_light() -> void:
	expect(TimeOfDay.NAMES == ["day", "morning", "golden_hour", "sunset", "night"], "day, morning, golden hour, sunset and night: %s" % [TimeOfDay.NAMES])
	var environment: Environment = (main.level.find_children("*", "WorldEnvironment", true, false)[0] as WorldEnvironment).environment
	var sun := main.level.find_children("*", "DirectionalLight3D", true, false)[0] as DirectionalLight3D
	for time in TimeOfDay.NAMES:
		main.set_time_of_day(time)
		var preset: Dictionary = TimeOfDay.PRESETS[time]
		var sky := environment.sky.sky_material as ShaderMaterial
		expect(sky != null and sky.shader == TimeOfDay.SKY_SHADER, "%s: our own sky" % time)
		if sky:
			expect(sky.get_shader_parameter(&"top_color") == preset.top and sky.get_shader_parameter(&"stars") == preset.stars, "%s: its sky's colours and stars" % time)
		expect(sun.global_basis.z.is_equal_approx(TimeOfDay.sun_direction(time)), "%s: the sun (or moon) where it should be" % time)
		expect(sun.light_color == preset.light and is_equal_approx(sun.light_energy, preset.energy), "%s: its light" % time)
		expect(environment.ambient_light_color == preset.ambient and is_equal_approx(environment.fog_density, preset.fog_density), "%s: ambient light and fog" % time)
		expect(is_equal_approx(TimeOfDay.night_glow, preset.night_glow), "%s: the city glows %.2f" % [time, preset.night_glow])
	expect(TimeOfDay.sun_direction("sunset").y < 0.1 and TimeOfDay.sun_direction("day").y > 0.7, "low at sunset, high by day")


func test_night_glows_and_day_doesnt() -> void:
	main.set_time_of_day("night")
	expect(TimeOfDay.night_glow >= 1.0, "at night the windows light up and colours glow")
	main.set_time_of_day("day")
	expect(TimeOfDay.night_glow == 0.0, "by day, nothing glows")
	var building: ShaderMaterial = load("res://materials/grid_platform.tres")
	var vault: ShaderMaterial = load("res://materials/grid_vault.tres")
	expect(building.get_shader_parameter(&"windows") == true, "buildings have windows to light")
	expect(vault.get_shader_parameter(&"windows") != true, "a red vault box doesn't")


func test_the_hosts_pick_is_kept_and_the_next_world_has_it() -> void:
	main.set_time_of_day("golden_hour")
	expect(Settings.time_of_day == "golden_hour", "remembered in your settings")
	# Start the game afresh (as if you'd quit and come back).
	main.leave_game()
	main.queue_free()
	await ticks(5)
	main = MAIN_SCENE.instantiate()
	add_child(main)
	main.start_solo("rooftop_district")
	await ticks(10)
	expect(main.time_of_day == "golden_hour", "the next game starts at golden hour too")
	var environment: Environment = (main.level.find_children("*", "WorldEnvironment", true, false)[0] as WorldEnvironment).environment
	expect(environment.ambient_light_color == TimeOfDay.PRESETS["golden_hour"].ambient, "and looks it")


func test_only_the_host_picks_in_the_pause_menu() -> void:
	var menu: Node = main.pause_menu
	menu.open(false, true, "sunset")
	var picker := menu.get_node("%TimeOfDay") as OptionButton
	expect(not picker.disabled and picker.get_item_metadata(picker.selected) == "sunset", "the host picks (it's sunset now)")
	var picked := []
	menu.time_of_day_changed.connect(func(time: String) -> void: picked.append(time))
	picker.select(TimeOfDay.NAMES.find("night"))
	picker.item_selected.emit(TimeOfDay.NAMES.find("night"))
	expect(picked == ["night"], "choosing one asks for it: %s" % [picked])
	menu.open(false, false, "morning")
	expect(picker.disabled and picker.get_item_metadata(picker.selected) == "morning", "a friend sees the host's pick, but can't change it")
	menu.hide()
