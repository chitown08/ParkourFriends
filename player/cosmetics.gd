class_name Cosmetics
## Cosmetics that players wear: hats, gloves, belts and shoes on the body, and a
## trail streaming out behind (player/trail.gd). Each is a GLB in
## res://cosmetics/<slot>/ (see docs/COSMETICS_GUIDE.md), fitted by an entry in
## cosmetics/fits.cfg, and hung from a bone of the skeleton so it moves with the body.
##
## A body item's fit says where it sits on the blob standing in its rest pose,
## in the blob's own space: metres, the blob facing +Z, its left hand at +X, its
## feet at y = -0.9 (it's 1.8 m tall, centred on its middle). Each entry:
##   position  where the item's middle goes
##   rotation  degrees to turn the model (x, y, z, applied y then x then z)
##   scale     the models come about 1 m across, so this is about their size
##   mirror    true if the model was made for the right side (fits are for the left)
## Pairs (hands, feet) are fitted on the left; the right gets the mirror image.
##
## A trail's entry (trail/<kind>/<name>) says, in the model's own axes, which
## way runs from the end that attaches to the free end (`along`) and which way
## is up (`up`), and how long it is when worn (`length`, metres). Banners and
## streamers fly from a pole on your back; a scarf is two files, <name>_neck
## (fitted like a body item) and <name>_tail (worn twice, from the back of the neck).

const DIR := "res://cosmetics/"
const FITS := "res://cosmetics/fits.cfg"
## The slots, in the order Player.sync_outfit lists them.
const SLOTS: Array[StringName] = [&"head", &"hands", &"waist", &"feet", &"trail"]
## The bones each body slot hangs from (left first).
const BONES := {
	&"head": ["mixamorig_Head"],
	&"hands": ["mixamorig_LeftHand", "mixamorig_RightHand"],
	&"waist": ["mixamorig_Hips"],
	&"feet": ["mixamorig_LeftFoot", "mixamorig_RightFoot"],
}
## The node name every attached cosmetic gets a prefix of (so it can be taken off).
const PREFIX := "Cosmetic_"

## The pole banners and streamers fly from: up your back, from the waist to
## well over your head (blob space), on the upper spine.
const POLE_BONE := "mixamorig_Spine2"
const POLE_BOTTOM := Vector3(0, -0.25, -0.4)
const POLE_TOP := Vector3(0, 1.8, -0.4)
const POLE_RADIUS := 0.03
const POLE_COLOR := Color(0.32, 0.22, 0.14)
## Scarf tails start from the back of the neck, this far apart.
const NECK_BONE := "mixamorig_Neck"
const SCARF_TAILS_FROM := Vector3(0, 0.44, -0.24)
const SCARF_TAILS_APART := 0.14

static var _fits: ConfigFile


## The names of the items made for `slot` (from the files in its folder). A
## trail's name includes its kind: "banner/pirate_banner", "scarf/tartan".
static func available(slot: StringName) -> Array[String]:
	var names: Array[String] = []
	if slot == &"trail":
		for kind in DirAccess.get_directories_at(DIR + "trail"):
			for file in DirAccess.get_files_at(DIR + "trail/" + kind):
				if not file.ends_with(".glb") or (kind == "scarf" and not file.ends_with("_tail.glb")):
					continue
				names.append(kind + "/" + file.get_basename().trim_suffix("_tail"))
	else:
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
	if slot == &"trail":
		_wear_trail(skeleton, item)
		return
	var path := DIR + slot + "/" + item + ".glb"
	if not ResourceLoader.exists(path):
		push_warning("No cosmetic %s" % path)
		return
	var fit := fit_of(slot, item)
	var bones: Array = BONES[slot]
	for i in bones.size():
		var placed := fit if i == 0 else Transform3D(Basis.FLIP_X, Vector3.ZERO) * fit
		_attach(skeleton, "%s%s_%d" % [PREFIX, slot, i], bones[i], _instance(path), placed)


static func _wear_trail(skeleton: Skeleton3D, item: String) -> void:
	var kind := StringName(item.get_slice("/", 0))
	var item_name := item.get_slice("/", 1)
	var path := DIR + "trail/%s/%s.glb" % [kind, item_name + ("_tail" if kind == &"scarf" else "")]
	if not ResourceLoader.exists(path):
		push_warning("No cosmetic %s" % path)
		return
	var anchors: Array[Node3D] = []
	if kind == &"scarf":
		var neck := DIR + "trail/scarf/%s_neck.glb" % item_name
		if ResourceLoader.exists(neck):
			_attach(skeleton, PREFIX + "trail_neck", NECK_BONE, _instance(neck), fit_of(&"trail", "scarf/%s_neck" % item_name))
		for side in [-0.5, 0.5]:
			var at: Vector3 = SCARF_TAILS_FROM + Vector3.RIGHT * side * SCARF_TAILS_APART
			anchors.append(_attach(skeleton, PREFIX + "trail_anchor%d" % anchors.size(), NECK_BONE, Node3D.new(), Transform3D(Basis(), at)))
	else:
		var pole := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = POLE_RADIUS
		cylinder.bottom_radius = POLE_RADIUS
		cylinder.height = POLE_TOP.y - POLE_BOTTOM.y
		var material := StandardMaterial3D.new()
		material.albedo_color = POLE_COLOR
		cylinder.material = material
		pole.mesh = cylinder
		_attach(skeleton, PREFIX + "trail_pole", POLE_BONE, pole, Transform3D(Basis(), (POLE_TOP + POLE_BOTTOM) / 2.0))
		anchors.append(_attach(skeleton, PREFIX + "trail_anchor", POLE_BONE, Node3D.new(), Transform3D(Basis(), POLE_TOP)))
	_load_fits()
	var section := "trail/" + item
	for i in anchors.size():
		var trail := Trail.new()
		trail.name = "%strail_%d" % [PREFIX, i]
		trail.kind = kind
		trail.length = _fits.get_value(section, "length", 2.0)
		trail.anchor = anchors[i]
		trail.body = skeleton
		skeleton.add_child(trail)
		trail.build(load(path), _fits.get_value(section, "along", Vector3.FORWARD), _fits.get_value(section, "up", Vector3.UP))


## Hangs `node` from `bone_name` (in a BoneAttachment3D named `attachment_name`),
## at `placed` on the blob at rest. Returns `node`.
static func _attach(skeleton: Skeleton3D, attachment_name: String, bone_name: String, node: Node3D, placed: Transform3D) -> Node3D:
	var attachment := BoneAttachment3D.new()
	attachment.name = attachment_name
	attachment.bone_name = bone_name
	# The attachment follows the bone; undo where the bone sits at rest.
	var bone := skeleton.find_bone(bone_name)
	node.transform = (skeleton.get_bone_global_rest(bone).affine_inverse() if bone != -1 else Transform3D()) * placed
	attachment.add_child(node)
	skeleton.add_child(attachment)
	return node


static func _instance(path: String) -> Node3D:
	return (load(path) as PackedScene).instantiate() as Node3D


## Where `item` sits on the blob at rest (see the top of this file).
static func fit_of(slot: StringName, item: String) -> Transform3D:
	_load_fits()
	var section := "%s/%s" % [slot, item]
	var rotation: Vector3 = _fits.get_value(section, "rotation", Vector3.ZERO)
	var size = _fits.get_value(section, "scale", 0.3)
	var scale: Vector3 = size if size is Vector3 else Vector3.ONE * float(size)
	if _fits.get_value(section, "mirror", false):
		scale.x = -scale.x
	var basis := Basis.from_euler(rotation * PI / 180.0).scaled_local(scale)
	return Transform3D(basis, _fits.get_value(section, "position", Vector3.ZERO))


static func _load_fits() -> void:
	if _fits == null:
		_fits = ConfigFile.new()
		_fits.load(FITS)
