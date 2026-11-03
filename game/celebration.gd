class_name Celebration
extends RefCounted
## The party when a relic is delivered, bigger the more style it came in with
## (see tier_for()): confetti always; streamers; fireworks; lots of fireworks.
## All made from code (particles), played on everyone's computer.
##
##   Celebration.play(self, drop_off_position, Celebration.tier_for(...))

## What each size of party is called (on screen), from 1 up.
const NAMES := ["", "Relic delivered!", "Stylish delivery!", "Spectacular!", "LEGENDARY!"]
const COLOURS: Array[Color] = [Color(0.95, 0.15, 0.2), Color(1.0, 0.75, 0.0), Color(0.1, 0.45, 1.0),
		Color(1.0, 0.45, 0.0), Color(0.95, 0.2, 0.7), Color(0.15, 0.8, 0.3), Color(0.55, 0.25, 0.95)]


## How big a party a delivery gets (1-4), from its style: `speed` it came in at
## (m/s, carried or thrown), `drop` how far it came down to get here (metres,
## from the highest point in the last few seconds), `pack` how many of you came
## in free-running together, and whether it was `thrown` in.
static func tier_for(speed: float, drop: float, pack: int, thrown: bool) -> int:
	var points := clampf(speed / 6.0, 0.0, 3.0) + clampf(drop / 5.0, 0.0, 4.0) \
			+ maxi(pack - 1, 0) * 1.5 + (0.5 if thrown else 0.0)
	return 1 + int(points >= 2.0) + int(points >= 4.0) + int(points >= 6.5)


## Plays a party of size `tier` (1-4) at `position` (the drop-off's middle).
static func play(from: Node, position: Vector3, tier: int) -> void:
	if not from.is_inside_tree():
		return
	var root := from.get_viewport()
	_confetti(root, position, 60 * tier)
	if tier >= 2:
		_streamers(root, position, 24 * tier)
	if tier >= 3:
		var rockets := 3 if tier == 3 else 9
		for i in rockets:
			_firework(from, position, COLOURS[i % (COLOURS.size() - 1)], 0.25 + i * (0.35 if tier == 3 else 0.22))


## Tumbling paper bits shot up and fluttering down.
static func _confetti(root: Node, at: Vector3, amount: int) -> void:
	var bits := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.4, 0.22)
	quad.material = _particle_material(false)
	bits.mesh = quad
	bits.amount = amount
	bits.lifetime = 3.0
	bits.one_shot = true
	bits.explosiveness = 0.9
	bits.direction = Vector3.UP
	bits.spread = 35.0
	bits.initial_velocity_min = 10.0
	bits.initial_velocity_max = 20.0
	bits.gravity = Vector3.DOWN * 4.0
	bits.damping_min = 2.0
	bits.damping_max = 3.5
	bits.angle_min = 0.0
	bits.angle_max = 360.0
	bits.angular_velocity_min = -400.0
	bits.angular_velocity_max = 400.0
	bits.color_initial_ramp = _rainbow()
	_launch(root, bits, at, 3.5)


## Ribbons flying up and out, trailing behind them.
static func _streamers(root: Node, at: Vector3, amount: int) -> void:
	var ribbons := _trails(amount, 2.5, 0.7, 0.3)
	var process := ribbons.process_material as ParticleProcessMaterial
	process.direction = Vector3.UP
	process.spread = 40.0
	process.initial_velocity_min = 9.0
	process.initial_velocity_max = 16.0
	process.gravity = Vector3.DOWN * 6.0
	process.damping_min = 1.0
	process.damping_max = 2.0
	var colours := GradientTexture1D.new()
	colours.gradient = _rainbow()
	process.color_initial_ramp = colours
	_launch(root, ribbons, at, 3.0)


## A rocket streaking up from `at` after `delay` seconds, bursting into
## `colour` with a flash and a bang.
static func _firework(from: Node, at: Vector3, colour: Color, delay: float) -> void:
	var tree := from.get_tree()
	var root := from.get_viewport()
	await tree.create_timer(delay).timeout
	if not is_instance_valid(root):
		return
	var top := at + Vector3(randf_range(-8.0, 8.0), randf_range(22.0, 32.0), randf_range(-8.0, 8.0))
	# The rocket: a spark trail climbing.
	var rocket := _trails(12, 0.5, 0.4, 0.15)
	var trail := rocket.process_material as ParticleProcessMaterial
	trail.spread = 10.0
	trail.initial_velocity_min = 0.5
	trail.initial_velocity_max = 1.0
	trail.color = Color(1.0, 0.85, 0.5)
	rocket.one_shot = false
	root.add_child(rocket)
	rocket.global_position = at
	rocket.emitting = true
	Sfx.play(root, at, &"firework_launch", -6.0)
	var climb := rocket.create_tween()
	climb.tween_property(rocket, ^"global_position", top, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	await climb.finished
	if not is_instance_valid(rocket):
		return
	rocket.emitting = false
	tree.create_timer(1.0).timeout.connect(rocket.queue_free)
	# The burst.
	var burst := _trails(140, 1.8, 0.45, 0.22)
	var process := burst.process_material as ParticleProcessMaterial
	process.spread = 180.0
	process.initial_velocity_min = 9.0
	process.initial_velocity_max = 13.0
	process.gravity = Vector3.DOWN * 3.0
	process.damping_min = 2.0
	process.damping_max = 3.0
	var fade := Gradient.new() # White-hot, then the colour, fading only at the end.
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(colour.darkened(0.3), 0.0))
	fade.add_point(0.1, colour)
	fade.add_point(0.75, colour)
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	_launch(root, burst, top, 2.5)
	var flash := OmniLight3D.new()
	flash.light_color = colour
	flash.light_energy = 8.0
	flash.omni_range = 40.0
	root.add_child(flash)
	flash.global_position = top
	var dim := flash.create_tween()
	dim.tween_property(flash, ^"light_energy", 0.0, 0.6)
	dim.tween_callback(flash.queue_free)
	Sfx.play(root, top, &"firework_pop", 2.0)


## GPU particles that leave ribbon trails behind them (`width` metres wide,
## trailing for `trail` seconds).
static func _trails(amount: int, lifetime: float, trail: float, width: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.trail_enabled = true
	particles.trail_lifetime = trail
	particles.process_material = ParticleProcessMaterial.new()
	var ribbon := RibbonTrailMesh.new()
	ribbon.size = width
	ribbon.section_length = 0.1
	ribbon.material = _particle_material(true)
	particles.draw_pass_1 = ribbon
	return particles


static func _launch(root: Node, particles: Node3D, at: Vector3, life: float) -> void:
	root.add_child(particles)
	particles.global_position = at
	particles.set(&"emitting", true)
	root.get_tree().create_timer(life + 0.5).timeout.connect(particles.queue_free)


static func _particle_material(trails: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if trails:
		material.use_particle_trails = true
	else:
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	return material


## Party colours, picked at random for each bit.
static func _rainbow() -> Gradient:
	var gradient := Gradient.new()
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offsets := PackedFloat32Array()
	for i in COLOURS.size():
		offsets.append(float(i) / COLOURS.size())
	gradient.offsets = offsets
	gradient.colors = PackedColorArray(COLOURS)
	return gradient
