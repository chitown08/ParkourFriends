extends SceneTree
## Renders the blob wearing each trail: standing still, then running, from the
## side and from behind. One row per trail. Needs a window (not --headless).
##
## Usage: Godot_v4.7.2-stable_win64_console.exe --path . --script res://tools/trail_preview.gd -- <out.png> [run speed m/s]

const CELL := Vector2i(480, 400)
## Camera directions (from the blob, which runs toward -Z): side, behind and up a bit.
const VIEWS := [Vector3(1, 0.15, 0), Vector3(0.5, 0.45, 1)]
const STAND_TIME := 1.5
const RUN_TIME := 1.5


func _init() -> void:
	_build.call_deferred()


func _build() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://trail_preview.png"
	var speed := float(args[1]) if args.size() > 1 else 10.0
	var trails := Cosmetics.available(&"trail")
	var models: Array[CharacterModel] = []
	var cameras: Array[Camera3D] = []
	var viewports: Array[SubViewport] = []
	# Each trail twice (standing, running), each seen from every view.
	for trail in trails:
		for running in [false, true]:
			for view: Vector3 in VIEWS:
				var viewport := SubViewport.new()
				viewport.size = CELL
				viewport.own_world_3d = true
				viewport.msaa_3d = Viewport.MSAA_4X
				viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
				root.add_child(viewport)
				var environment := WorldEnvironment.new()
				environment.environment = Environment.new()
				environment.environment.background_mode = Environment.BG_COLOR
				environment.environment.background_color = Color(0.6, 0.7, 0.82)
				environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
				environment.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
				viewport.add_child(environment)
				var sun := DirectionalLight3D.new()
				viewport.add_child(sun)
				sun.look_at_from_position(Vector3(1, 2, -1), Vector3.ZERO)
				var floor_mesh := MeshInstance3D.new()
				floor_mesh.mesh = PlaneMesh.new()
				(floor_mesh.mesh as PlaneMesh).size = Vector2(400, 400)
				viewport.add_child(floor_mesh)
				var model := (load("res://characters/blob/blob_model.tscn") as PackedScene).instantiate() as CharacterModel
				viewport.add_child(model)
				await process_frame
				model.wear(&"trail", trail)
				model.set_meta(&"running", running)
				var animations := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
				animations.play(&"moves/idle")
				var camera := Camera3D.new()
				camera.fov = 40.0
				camera.set_meta(&"view", view)
				viewport.add_child(camera)
				models.append(model)
				cameras.append(camera)
				viewports.append(viewport)
	var time := 0.0
	var started_running := false
	while time < STAND_TIME + RUN_TIME:
		await process_frame
		var delta := 1.0 / 60.0
		time += delta
		for i in models.size():
			var model := models[i]
			if model.get_meta(&"running") and time > STAND_TIME:
				if not started_running or not (model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer).current_animation.ends_with("run"):
					(model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer).play(&"moves/run")
				model.position += Vector3.FORWARD * speed * delta
			var view: Vector3 = cameras[i].get_meta(&"view")
			# (Kites fly high: pull back to see the whole string.)
			var kite: bool = trails[i / (VIEWS.size() * 2)].begins_with("kite/")
			var middle := model.position + (Vector3(0, 5.5, 4.0) if kite else Vector3(0, 1.6, 1.0))
			cameras[i].look_at_from_position(middle + view.normalized() * (20.0 if kite else 7.0), middle)
		started_running = time > STAND_TIME
	var sheet := Image.create(CELL.x * VIEWS.size() * 2, CELL.y * trails.size(), false, Image.FORMAT_RGBA8)
	for i in viewports.size():
		var image := viewports[i].get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		var column := i % (VIEWS.size() * 2)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, CELL), Vector2i(column * CELL.x, (i / (VIEWS.size() * 2)) * CELL.y))
	sheet.save_png(out)
	print("Saved %s: rows %s; columns: standing (side, behind), running (side, behind)" % [out, trails])
	quit()
