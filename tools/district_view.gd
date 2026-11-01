extends SceneTree
## Takes a picture of the rooftop district from a camera at one point looking
## at another. Needs a window (not --headless).
##
## Usage: Godot_v4.7.2-stable_win64_console.exe --path . --script res://tools/district_view.gd -- <out.png> <x,y,z camera> <x,y,z looking at>

const SIZE := Vector2i(1280, 720)


func _init() -> void:
	_shoot.call_deferred()


func _shoot() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://district_view.png"
	var from := _vector(args[1]) if args.size() > 1 else Vector3(0, 60, 80)
	var to := _vector(args[2]) if args.size() > 2 else Vector3.ZERO
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child((load("res://levels/rooftop_district.tscn") as PackedScene).instantiate())
	var camera := Camera3D.new()
	camera.fov = 60.0
	camera.far = 1000.0
	viewport.add_child(camera)
	camera.look_at_from_position(from, to)
	for i in 10:
		await process_frame
	var image := viewport.get_texture().get_image()
	image.save_png(out)
	print("Saved %s" % out)
	quit()


func _vector(text: String) -> Vector3:
	var parts := text.split(",")
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
