extends SceneTree
## Renders the character in a grid of animations (each frozen partway, seen
## from its front-left): to check animations play right on the model, e.g.
## after a new rig or new animation files. Needs a window (not --headless).
##
## Usage: Godot_v4.7.2-stable_win64_console.exe --path . --script res://tools/pose_sheet.gd -- <out.png> [animation[@fraction]]...

const CELL := Vector2i(300, 400)
const COLUMNS := 6


func _init() -> void:
	_build.call_deferred()


func _build() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://pose_sheet.png"
	var moves: Array = args.slice(1) if args.size() > 1 else ["idle", "run", "sprint", "jump", "fall", "land"]
	var viewports: Array[SubViewport] = []
	for move: String in moves:
		var viewport := SubViewport.new()
		viewport.size = CELL
		viewport.own_world_3d = true
		viewport.msaa_3d = Viewport.MSAA_4X
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color(0.15, 0.16, 0.18)
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
		viewport.add_child(environment)
		var sun := DirectionalLight3D.new()
		viewport.add_child(sun)
		sun.look_at_from_position(Vector3(1, 2, -2), Vector3.ZERO)
		var floor := CSGBox3D.new()
		floor.size = Vector3(4, 0.02, 4)
		floor.position.y = -0.01
		viewport.add_child(floor)
		var model := (load("res://characters/blob/blob_model.tscn") as PackedScene).instantiate() as CharacterModel
		viewport.add_child(model)
		await process_frame
		var name := move.get_slice("@", 0)
		var fraction := float(move.get_slice("@", 1)) if "@" in move else 0.4
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		if player.has_animation(&"moves/" + name):
			player.play(&"moves/" + name, 0.0)
			player.seek(player.get_animation(&"moves/" + name).length * fraction, true)
			player.pause()
		var label := Label3D.new()
		label.text = move
		label.pixel_size = 0.004
		label.position = Vector3(0, 2.15, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		viewport.add_child(label)
		var camera := Camera3D.new()
		viewport.add_child(camera)
		# The character faces -Z: look at it from in front, a little to its left.
		camera.look_at_from_position(Vector3(-1.6, 1.4, -3.4), Vector3(0, 0.95, 0))
		viewports.append(viewport)
	for i in 10:
		await process_frame
	var rows := ceili(float(viewports.size()) / COLUMNS)
	var sheet := Image.create(CELL.x * mini(COLUMNS, viewports.size()), CELL.y * rows, false, Image.FORMAT_RGBA8)
	for i in viewports.size():
		var image := viewports[i].get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, CELL), Vector2i(i % COLUMNS, i / COLUMNS) * CELL)
	sheet.save_png(out)
	print("Wrote ", out)
	quit()
