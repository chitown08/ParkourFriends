extends SceneTree
## Prints each cosmetic's size, centre, triangle count and texture sizes, to
## help fit it (see docs/COSMETICS_GUIDE.md).
##
## Usage (from the project folder):
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/inspect_cosmetics.gd


func _init() -> void:
	_scan("res://cosmetics/")
	quit()


func _scan(dir: String) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_scan(dir + sub + "/")
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".glb"):
			_report(dir + file)


func _report(path: String) -> void:
	var scene: Node3D = (load(path) as PackedScene).instantiate()
	var box := AABB()
	var first := true
	var triangles := 0
	var textures := []
	for mesh_node: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var to_root := Transform3D()
		var node: Node = mesh_node
		while node != scene:
			to_root = (node as Node3D).transform * to_root
			node = node.get_parent()
		var part := to_root * mesh_node.mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
		for s in mesh_node.mesh.get_surface_count():
			var arrays := mesh_node.mesh.surface_get_arrays(s)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			triangles += (indices.size() if indices.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
			var material := mesh_node.mesh.surface_get_material(s) as BaseMaterial3D
			if material and material.albedo_texture:
				textures.append(material.albedo_texture.get_size())
	print("%s\n  size %v  centre %v\n  %d triangles, textures %s" % [path, box.size, box.get_center(), triangles, textures])
	scene.free()
