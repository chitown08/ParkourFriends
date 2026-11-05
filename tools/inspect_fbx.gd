extends SceneTree
## Prints each FBX's skeleton bones and animations (a look before wiring them up).
## Usage: --headless --path . --script res://tools/inspect_fbx.gd -- <res:// file>...


func _init() -> void:
	for path in OS.get_cmdline_user_args():
		var scene := load(path) as PackedScene
		print("== ", path.get_file())
		if scene == null:
			print("  (didn't load)")
			continue
		var root := scene.instantiate()
		for skeleton: Skeleton3D in root.find_children("*", "Skeleton3D", true, false):
			var names := PackedStringArray()
			for i in skeleton.get_bone_count():
				var parent := skeleton.get_bone_parent(i)
				names.append("%s<%s" % [skeleton.get_bone_name(i), skeleton.get_bone_name(parent) if parent >= 0 else "-"])
			print("  skeleton %s (%d bones): %s" % [root.get_path_to(skeleton), skeleton.get_bone_count(), ", ".join(names)])
		for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			print("  mesh %s: %s" % [root.get_path_to(mesh), mesh.get_aabb()])
		for player: AnimationPlayer in root.find_children("*", "AnimationPlayer", true, false):
			for anim in player.get_animation_list():
				var a := player.get_animation(anim)
				print("  anim '%s' %.2f s, %d tracks, first: %s" % [anim, a.length, a.get_track_count(), a.track_get_path(0) if a.get_track_count() > 0 else ""])
		root.free()
	quit()
