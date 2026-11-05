extends SceneTree
## Measures the character's body at rest (where its head, waist, hands and
## feet are, and how big) and every cosmetic model (its size and middle, in its
## own axes): numbers to start a fit from (cosmetics/fits.cfg).
## Usage: --headless --path . --script res://tools/measure_cosmetics.gd


func _init() -> void:
	var model := (load("res://characters/blob/blob_model.tscn") as PackedScene).instantiate()
	root.add_child(model)
	await process_frame
	var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var body: MeshInstance3D = model.find_children("*", "MeshInstance3D", true, false)[0]
	var points := body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var to_skeleton := skeleton.global_transform.affine_inverse() * body.global_transform
	var bands := {"head (above neck)": [1.3, 9.0], "waist (0.65-0.95)": [0.65, 0.95], "ankles (0.05-0.25)": [0.05, 0.25], "soles (below 0.05)": [-9.0, 0.05]}
	for band: String in bands:
		var box := AABB()
		var first := true
		for p in points:
			var q := to_skeleton * p
			if q.y >= bands[band][0] and q.y < bands[band][1] and (band != "ankles (0.05-0.25)" or q.x > 0.0) and (band != "soles (below 0.05)" or q.x > 0.0):
				box = AABB(q, Vector3.ZERO) if first else box.expand(q)
				first = false
		print("body %s: %s to %s" % [band, box.position, box.end])
	var hand := skeleton.get_bone_global_rest(skeleton.find_bone("LeftHand")).origin
	var near := AABB(hand, Vector3.ZERO)
	for p in points:
		var q := to_skeleton * p
		if q.distance_to(hand) < 0.25:
			near = near.expand(q)
	print("body left hand (bone %s): %s to %s" % [hand, near.position, near.end])
	for bone in ["Hips", "Head", "head_end", "Neck", "UpperChest", "LeftHand", "LeftFoot", "LeftToes"]:
		print("bone %s at %s" % [bone, skeleton.get_bone_global_rest(skeleton.find_bone(bone)).origin])
	for slot in ["head", "hands", "waist", "feet"]:
		for file in DirAccess.get_files_at("res://cosmetics/" + slot):
			if not file.ends_with(".glb"):
				continue
			var item := (load("res://cosmetics/%s/%s" % [slot, file]) as PackedScene).instantiate() as Node3D
			root.add_child(item)
			var box := AABB()
			var first := true
			for mesh: MeshInstance3D in item.find_children("*", "MeshInstance3D", true, false):
				var b := mesh.global_transform * mesh.get_aabb()
				box = b if first else box.merge(b)
				first = false
			print("%s/%s: size %s middle %s" % [slot, file.get_basename(), box.size, box.get_center()])
			item.free()
	quit()
