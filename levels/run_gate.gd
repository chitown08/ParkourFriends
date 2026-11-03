class_name RunGate
extends Node3D
## A hoop on a group run's route (see GroupRun), standing upright, facing
## along its -Z. White gates are the route: each of you goes through, and the
## next only lights up once the whole crew has. Gold gates are extras, put
## somewhere hard: one of you getting through is enough, and each earns a
## bonus relic when the crew finishes. Hidden unless a run is on.

const WHITE := Color(1.0, 1.0, 1.0)
const GOLD := Color(1.0, 0.72, 0.15)
## Through the hoop: this close (metres) to its middle counts.
const RADIUS := 2.2
const THICKNESS := 0.18
## The beam rising from the gate to head for (this tall).
const BEAM_HEIGHT := 50.0

## A gold gate (one of you is enough; earns a bonus relic) rather than a white one.
@export var gold := false

## How it looks right now (GroupRun sets it): hidden, the one to head for,
## waiting (some of you are through), or done.
enum Look { HIDDEN, AHEAD, NEXT, DONE }

var _hoop: MeshInstance3D
var _beam: MeshInstance3D
var _material: StandardMaterial3D
var _beam_material: StandardMaterial3D
var _label: Label3D


func _ready() -> void:
	add_to_group(&"run_gates")
	_material = _glow(GOLD if gold else WHITE)
	var torus := TorusMesh.new()
	torus.inner_radius = RADIUS - THICKNESS
	torus.outer_radius = RADIUS
	torus.material = _material
	_hoop = MeshInstance3D.new()
	_hoop.mesh = torus
	_hoop.rotation.x = PI / 2.0 # Stand it upright, facing -Z.
	add_child(_hoop)
	_beam_material = _glow(GOLD if gold else WHITE)
	_beam_material.no_depth_test = true
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.2
	cylinder.bottom_radius = 0.2
	cylinder.height = BEAM_HEIGHT
	cylinder.material = _beam_material
	_beam = MeshInstance3D.new()
	_beam.mesh = cylinder
	_beam.position.y = RADIUS + BEAM_HEIGHT / 2.0
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = RADIUS + 0.8
	_label.font_size = 56
	_label.outline_size = 14
	_label.pixel_size = 0.01
	_label.no_depth_test = true
	add_child(_label)
	show_look(Look.HIDDEN)


## Shows the gate hidden, ahead (a gold gate, or a white gate still to come:
## faint), next (the one to head for: bright, with its beam), or done (faint).
## `waiting_for`: names of the crew not through yet, shown over it.
func show_look(look: Look, waiting_for := "") -> void:
	visible = look != Look.HIDDEN
	var base := GOLD if gold else WHITE
	_material.albedo_color = Color(base, 0.9 if look == Look.NEXT or gold else 0.25)
	_material.emission_energy_multiplier = 2.5 if look == Look.NEXT or (gold and look != Look.DONE) else 0.3
	_beam.visible = look == Look.NEXT or (gold and look == Look.AHEAD)
	_beam_material.albedo_color = Color(base, 0.45)
	_label.text = "Waiting for %s" % waiting_for if waiting_for else ""


## True if something going from `from` to `to` passed through the hoop.
func passed_through(from: Vector3, to: Vector3) -> bool:
	var closest := Geometry3D.get_closest_point_to_segment(global_position, from, to)
	return closest.distance_to(global_position) <= RADIUS


static func _glow(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = colour
	material.emission_enabled = true
	material.emission = colour
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
