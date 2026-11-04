extends SceneTree
## Measures how the stress city (levels/stress_city.gd) runs, built each way:
## how long it takes to load, then flying a camera through a few views (all
## round from the hub's roof, down a street, between the towers, from high
## above the whole city), the frame times, how much is drawn, and memory.
## Writes a report and a screenshot of each view to the folder given.
## Run it with a window (not --headless), vsync off:
##   Godot --path . --script res://tools/bench_city.gd -- <folder> [km...] [occluders] [csg]

const SECONDS := 5.0
const SIZE := Vector2i(1920, 1080)

var _lines := PackedStringArray()


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	Settings.path = "user://test_settings.cfg"
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_size(SIZE)
	root.size = SIZE
	Engine.max_fps = 0
	_line("Stress city, on %s / %s, %s" % [RenderingServer.get_video_adapter_name(), OS.get_processor_name(), "%dx%d" % [SIZE.x, SIZE.y]])
	# Each size given (km, e.g. "6"; 3 if none): baked, and baked with occluders
	# ("occluders") or each building its own CSG ("csg") if asked.
	var sizes: Array = Array(args.slice(1)).filter(func(arg: String) -> bool: return arg.is_valid_float())
	if sizes.is_empty():
		sizes = ["3"]
	for km: String in sizes:
		StressCity.size = float(km) * 1000.0
		var configs := [["baked", false]]
		if "occluders" in args:
			configs.append(["baked", true])
		if "csg" in args:
			configs.append(["csg", false])
		for config: Array in configs:
			StressCity.mode = config[0]
			StressCity.occluders = config[1]
			await _measure("%skm %s%s" % [km, config[0], " + occluders" if config[1] else ""], out)
	var file := FileAccess.open(out.path_join("report.txt"), FileAccess.WRITE)
	file.store_string("\n".join(_lines) + "\n")
	file.close()
	quit()


func _measure(label: String, out: String) -> void:
	var main: Node = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var started := Time.get_ticks_msec()
	main.start_solo("stress_city")
	await process_frame
	var first_frame := Time.get_ticks_msec() - started
	for i in 30:
		await process_frame
	var city: StressCity = main.level
	_line("\n== %s ==" % label)
	_line("Built: %s" % [city.stats])
	_line("Load: %d ms to the first frame (building it: %d ms)" % [first_frame, city.stats.build_ms])
	main.hud.visible = false
	var camera := Camera3D.new()
	camera.far = maxf(4000.0, StressCity.size * 1.6)
	camera.fov = 75.0
	city.add_child(camera)
	camera.make_current()
	var half := StressCity.size / 2.0
	var avenues := StressCity.avenues()
	var east: float = avenues.filter(func(a: float) -> bool: return a > StressCity.FUTURE_FROM + 100.0)[0]
	var west: float = avenues[0]
	var views := [
		# [name, from, to, look (a direction, or a point if "at")]
		["hub roof, all round", Vector3(0, StressCity.HUB_HEIGHT + 8.0, 0), Vector3(0, StressCity.HUB_HEIGHT + 8.0, 0), "spin"],
		["street, old town", Vector3(-half * 0.93, 2.0, west), Vector3(-200, 2.0, west), "ahead"],
		["between the towers", Vector3(300, 100.0, east), Vector3(half * 0.93, 100.0, east), "ahead"],
		["over the whole city", Vector3(-half * 1.1, half * 0.45, half * 1.1), Vector3(-half * 0.8, half * 0.42, half * 0.8), "middle"],
	]
	for view: Array in views:
		var times: Array[float] = []
		var draws := 0.0
		var primitives := 0.0
		var objects := 0.0
		var frames := 0
		var last := Time.get_ticks_usec()
		var shot_taken := false
		var elapsed := 0.0
		while elapsed < SECONDS:
			var t := elapsed / SECONDS
			var at: Vector3 = (view[1] as Vector3).lerp(view[2], t)
			camera.global_position = at
			match view[3]:
				"spin": camera.rotation = Vector3(-0.08, t * TAU, 0)
				"ahead": camera.look_at(at + ((view[2] as Vector3) - (view[1] as Vector3)).normalized() + Vector3(0, -0.05, 0))
				"middle": camera.look_at(Vector3(0, 60, 0))
			await process_frame
			var now := Time.get_ticks_usec()
			var dt := (now - last) / 1000.0
			last = now
			elapsed += dt / 1000.0
			if frames > 5: # (Skip the first few: things settling.)
				times.append(dt)
				draws += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
				primitives += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
				objects += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
			frames += 1
			if not shot_taken and t > 0.4:
				shot_taken = true
				root.get_texture().get_image().save_png(out.path_join("%s_%s.png" % [label.replace(" + ", "_").replace(" ", "_"), view[0].replace(" ", "_").replace(",", "")]))
		times.sort()
		var n := times.size()
		var average := 0.0
		for dt in times:
			average += dt
		average /= n
		var worst: float = times[int(n * 0.99)] # (The slowest 1%.)
		_line("  %-22s %6.0f fps  (%.2f ms a frame, slowest 1%%: %.2f ms)  draw calls %5.0f  objects %5.0f  triangles %5.1fM" % [
				view[0], 1000.0 / average, average, worst, draws / n, objects / n, primitives / n / 1e6])
	_line("  Memory: %d MB (video: %d MB)" % [Performance.get_monitor(Performance.MEMORY_STATIC) / 1e6,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1e6])
	main.queue_free()
	for i in 10:
		await process_frame


func _line(text: String) -> void:
	_lines.append(text)
	print(text)
