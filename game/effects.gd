class_name Effects
extends RefCounted
## Placeholder visual effects made from code: little bursts of bits (dust when
## you land hard or leap, a "pop" when the bat connects, sparks off a rail).
##
##   Effects.burst(self, global_position, Effects.DUST)


const DUST := Color(0.8, 0.76, 0.68)
const POP := Color(1.0, 0.9, 0.35)
const SPARK := Color(1.0, 0.7, 0.25)


## A one-off burst of `amount` bits flying out from `position` at about
## `speed` m/s: upward (dust) or, with `all_ways`, in every direction (a pop).
static func burst(from: Node, position: Vector3, color: Color, amount := 16, speed := 3.0, all_ways := false) -> void:
	if not from.is_inside_tree():
		return
	var bits := CPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.1
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	mesh.material = material
	bits.mesh = mesh
	bits.one_shot = true
	bits.explosiveness = 1.0
	bits.amount = amount
	bits.lifetime = 0.45
	bits.direction = Vector3.UP
	bits.spread = 180.0 if all_ways else 80.0
	bits.initial_velocity_min = speed * 0.5
	bits.initial_velocity_max = speed
	bits.gravity = Vector3.DOWN * 6.0
	bits.damping_min = speed
	bits.damping_max = speed * 2.0
	bits.scale_amount_min = 0.6
	bits.scale_amount_max = 1.4
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	bits.scale_amount_curve = shrink
	from.get_viewport().add_child(bits)
	bits.global_position = position
	bits.emitting = true
	from.get_tree().create_timer(bits.lifetime + 0.2).timeout.connect(bits.queue_free)
