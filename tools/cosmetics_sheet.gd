extends SceneTree
## Renders every cosmetic from the front (+Z), the side (+X) and above (+Y),
## with red/green/blue axis sticks (x/y/z), into one picture: to see which way
## each model faces before fitting it. Needs a window (not --headless).
##
## Usage: Godot_v4.7.2-stable_win64_console.exe --path . --script res://tools/cosmetics_sheet.gd -- <out.png>

const CELL := 384
const VIEWS := [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0.001)]


func _init() -> void:
	var paths: Array[String] = []
	_scan("res://cosmetics/", paths)
	var viewports: Array[SubViewport] = []
	for path in paths:
		for view: Vector3 in VIEWS:
			var viewport := SubViewport.new()
			viewport.size = Vector2i(CELL, CELL)
			viewport.own_world_3d = true
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(viewport)
			var environment := WorldEnvironment.new()
			environment.environment = Environment.new()
			environment.environment.background_mode = Environment.BG_COLOR
			environment.environment.background_color = Color(0.15, 0.16, 0.18)
			environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			environment.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
			viewport.add_child(environment)
			var sun := DirectionalLight3D.new()
			viewport.add_child(sun)
			sun.look_at_from_position(Vector3(1, 2, 3), Vector3.ZERO)
			viewport.add_child((load(path) as PackedScene).instantiate())
			for axis in 3:
				var stick := MeshInstance3D.new()
				var box := BoxMesh.new()
				box.size = Vector3.ONE * 0.02
				box.size[axis] = 0.6
				var material := StandardMaterial3D.new()
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				material.albedo_color = [Color.RED, Color.GREEN, Color.BLUE][axis]
				box.material = material
				stick.mesh = box
				stick.position[axis] = 0.3
				stick.position += Vector3(-0.7, -0.7, -0.7)
				viewport.add_child(stick)
			var camera := Camera3D.new()
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = 1.6
			viewport.add_child(camera)
			camera.look_at_from_position(view * 3.0, Vector3.ZERO, Vector3.UP if view.y < 0.5 else Vector3.FORWARD)
			viewports.append(viewport)
	for i in 10:
		await process_frame
	var sheet := Image.create(CELL * VIEWS.size(), CELL * paths.size(), false, Image.FORMAT_RGBA8)
	for i in viewports.size():
		var image := viewports[i].get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i((i % VIEWS.size()) * CELL, (i / VIEWS.size()) * CELL))
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://cosmetics_sheet.png"
	sheet.save_png(out)
	print("Saved %s: rows %s" % [out, paths])
	quit()


func _scan(dir: String, paths: Array[String]) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_scan(dir + sub + "/", paths)
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".glb"):
			paths.append(dir + file)
