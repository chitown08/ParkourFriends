extends SceneTree
## Renders the blob wearing every cosmetic, a few outfits side by side, from
## the front, the side, behind and close up: to check cosmetics/fits.cfg.
## Needs a window (not --headless).
##
## Usage: Godot_v4.7.2-stable_win64_console.exe --path . --script res://tools/cosmetics_lineup.gd -- <out.png> [animation] [seconds in] [look at height] [distance]

const CELL := Vector2i(360, 480)
## Camera directions (from the blob): front, front-left three-quarter, side, back.
const VIEWS := [Vector3(0, 0, 1), Vector3(0.7, 0, 0.7), Vector3(1, 0, 0), Vector3(0, 0, -1)]
const SLOTS: Array[StringName] = [&"head", &"hands", &"waist", &"feet"]


func _init() -> void:
	_build.call_deferred()


func _build() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://cosmetics_lineup.png"
	var animation: String = args[1] if args.size() > 1 else "idle"
	var at := float(args[2]) if args.size() > 2 else 0.5
	# Optionally a close-up: how high to look (metres above the feet) and how far away.
	var focus := float(args[3]) if args.size() > 3 else 0.95
	var distance := float(args[4]) if args.size() > 4 else 4.6
	# One outfit per row: the n-th item of each slot (or the last one).
	var rows := 0
	for slot in SLOTS:
		rows = maxi(rows, Cosmetics.available(slot).size())
	var viewports: Array[SubViewport] = []
	for row in rows:
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
			environment.environment.background_color = Color(0.15, 0.16, 0.18)
			environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			environment.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
			viewport.add_child(environment)
			var sun := DirectionalLight3D.new()
			viewport.add_child(sun)
			sun.look_at_from_position(Vector3(1, 2, -2), Vector3.ZERO) # From in front of the blob.
			var model := (load("res://characters/blob/blob_model.tscn") as PackedScene).instantiate() as CharacterModel
			viewport.add_child(model)
			await process_frame # Let it get ready.
			for slot in SLOTS:
				var items := Cosmetics.available(slot)
				if not items.is_empty():
					model.wear(slot, items[mini(row, items.size() - 1)])
			var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
			player.play(&"moves/" + animation)
			player.seek(at, true)
			player.pause()
			var camera := Camera3D.new()
			camera.fov = 30.0
			viewport.add_child(camera)
			# The game turns the blob round to face -Z; the camera follows suit.
			var from := Vector3(-view.x, 0, -view.z)
			camera.look_at_from_position(from * distance + Vector3(0, focus + 0.25 * distance / 4.6, 0), Vector3(0, focus, 0))
			viewports.append(viewport)
	for i in 10:
		await process_frame
	var sheet := Image.create(CELL.x * VIEWS.size(), CELL.y * rows, false, Image.FORMAT_RGBA8)
	for i in viewports.size():
		var image := viewports[i].get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, CELL), Vector2i((i % VIEWS.size()) * CELL.x, (i / VIEWS.size()) * CELL.y))
	sheet.save_png(out)
	print("Saved ", out)
	quit()
