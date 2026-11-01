class_name Cosmetics
## Cosmetics: hats, gloves, belts, shoes (and later trails) that players wear.
## Each is a GLB in res://cosmetics/<slot>/ (see docs/COSMETICS_GUIDE.md),
## fitted onto the blob by an entry in cosmetics/fits.cfg, and attached to a
## bone of its skeleton so it moves with the body.
##
## A fit says where the item sits on the blob standing in its rest pose, in the
## blob's own space: metres, the blob facing +Z, its left hand at +X, its feet
## at y = -0.9 (it's 1.8 m tall, centred on its middle). Each entry:
##   position  where the item's middle goes
##   rotation  degrees to turn the model (x, y, z, applied y then x then z)
##   scale     the models come about 1 m across, so this is about their size
##   mirror    true if the model was made for the right side (fits are for the left)
## Pairs (hands, feet) are fitted on the left; the right gets the mirror image.

const DIR := "res://cosmetics/"
const FITS := "res://cosmetics/fits.cfg"
## The slots, in the order Player.sync_outfit lists them.
const SLOTS: Array[StringName] = [&"head", &"hands", &"waist", &"feet"]
## The bones each slot hangs from (left first).
const BONES := {
	&"head": ["mixamorig_Head"],
	&"hands": ["mixamorig_LeftHand", "mixamorig_RightHand"],
	&"waist": ["mixamorig_Hips"],
	&"feet": ["mixamorig_LeftFoot", "mixamorig_RightFoot"],
}
## The node name every attached cosmetic gets a prefix of (so it can be taken off).
const PREFIX := "Cosmetic_"

static var _fits: ConfigFile


## The names of the items made for `slot` (from the files in its folder).
static func available(slot: StringName) -> Array[String]:
	var names: Array[String] = []
	for file in DirAccess.get_files_at(DIR + slot):
		if file.ends_with(".glb"):
			names.append(file.get_basename())
	names.sort()
	return names


## Puts `item` (a name from available(slot), or "" for nothing) on `skeleton`,
## replacing whatever was in that slot.
static func wear(skeleton: Skeleton3D, slot: StringName, item: String) -> void:
	for node in skeleton.get_children():
		if node.name.begins_with(PREFIX + slot + "_"):
			skeleton.remove_child(node)
			node.queue_free()
	if item.is_empty():
		return
	var path := DIR + slot + "/" + item + ".glb"
	if not ResourceLoader.exists(path):
		push_warning("No cosmetic %s" % path)
		return
	var fit := fit_of(slot, item)
	var bones: Array = BONES[slot]
	for i in bones.size():
		var bone := skeleton.find_bone(bones[i])
		if bone == -1:
			continue
		var placed := fit if i == 0 else Transform3D(Basis.FLIP_X, Vector3.ZERO) * fit
		var attachment := BoneAttachment3D.new()
		attachment.name = "%s%s_%d" % [PREFIX, slot, i]
		attachment.bone_name = bones[i]
		var model := (load(path) as PackedScene).instantiate() as Node3D
		# The attachment follows the bone; undo where the bone sits at rest.
		model.transform = skeleton.get_bone_global_rest(bone).affine_inverse() * placed
		attachment.add_child(model)
		skeleton.add_child(attachment)


## Where `item` sits on the blob at rest (see the top of this file).
static func fit_of(slot: StringName, item: String) -> Transform3D:
	if _fits == null:
		_fits = ConfigFile.new()
		_fits.load(FITS)
	var section := "%s/%s" % [slot, item]
	var rotation: Vector3 = _fits.get_value(section, "rotation", Vector3.ZERO)
	var size = _fits.get_value(section, "scale", 0.3)
	var scale: Vector3 = size if size is Vector3 else Vector3.ONE * float(size)
	if _fits.get_value(section, "mirror", false):
		scale.x = -scale.x
	var basis := Basis.from_euler(rotation * PI / 180.0).scaled_local(scale)
	return Transform3D(basis, _fits.get_value(section, "position", Vector3.ZERO))
