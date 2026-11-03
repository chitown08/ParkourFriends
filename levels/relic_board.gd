class_name RelicBoard
extends Node3D
## The lights on the hub tower: one for every relic in this world, lighting up
## gold when it's delivered, so anyone can look up at the tower and see how the
## crew's doing. Rows, top to bottom: the relics one of you can get, then two,
## three and four of you (by their rings), then a block for each group run.
## Stands on the tower's face, facing out along its -Z; builds itself from the
## world's relics when it's ready.

const LIGHT := 2.6 ## Each light's size (metres)... (big: it's read from across the city)
const GAP := 0.9 ## ...and the room between them.
const ROW_GAP := 2.5 ## Extra room between rows.
const UNLIT := Color(0.35, 0.36, 0.4)
const LIT := Color(1.0, 0.72, 0.15)

## The board's width to fit in (the tower face), so long rows wrap.
@export var width := 30.0

## Each relic's light (WorldItem -> MeshInstance3D).
var _lights := {}
var _relics: Array[WorldItem] = []
var _lit_material: StandardMaterial3D
var _unlit_material: StandardMaterial3D


func _ready() -> void:
	_lit_material = _material(LIT, 3.0)
	_unlit_material = _material(UNLIT, 0.0)
	# (The relics are ready by now: they come before the board in the world.)
	var level := get_parent()
	for item in level.find_children("*", "WorldItem", true, false):
		if item.item and item.item.deliverable:
			_relics.append(item)
	var y := 0.0
	for row: Array in rows():
		y = _lay_out_row(row, y)


## The relics in rows: by players they take (1-4), then one per group run.
func rows() -> Array:
	var by_players := {}
	var by_run := {}
	for relic in _relics:
		var run := relic.get_parent().get_parent() as GroupRun
		if run:
			if not by_run.has(run.name):
				by_run[run.name] = []
			by_run[run.name].append(relic)
		else:
			var players := maxi(relic.players_needed, 1)
			if not by_players.has(players):
				by_players[players] = []
			by_players[players].append(relic)
	var found := []
	for players in [1, 2, 3, 4]:
		if by_players.has(players):
			found.append(by_players[players])
	var run_names := by_run.keys()
	run_names.sort()
	for run_name in run_names:
		found.append(by_run[run_name])
	return found


## Lays a row out from `y` down (wrapping if it's too wide); returns where the next row starts.
func _lay_out_row(row: Array, y: float) -> float:
	var step := LIGHT + GAP
	var per_line := maxi(int((width + GAP) / step), 1)
	for i in row.size():
		var in_line := mini(row.size() - (i / per_line) * per_line, per_line)
		var x := ((i % per_line) - (in_line - 1) / 2.0) * step
		var light := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(LIGHT, LIGHT, 0.3)
		light.mesh = box
		light.material_override = _unlit_material
		light.position = Vector3(x, y - (i / per_line) * step, -0.15)
		add_child(light)
		_lights[row[i]] = light
	return y - ceili(row.size() / float(per_line)) * step - ROW_GAP


func _process(_delta: float) -> void:
	for relic in _relics:
		if is_instance_valid(relic):
			_lights[relic].material_override = _lit_material if relic.state == WorldItem.State.DELIVERED else _unlit_material


## How many lights are lit, of how many (for tests).
func lit() -> Vector2i:
	var on := 0
	for light: MeshInstance3D in _lights.values():
		on += 1 if light.material_override == _lit_material else 0
	return Vector2i(on, _lights.size())


static func _material(colour: Color, glow: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = colour
		material.emission_energy_multiplier = glow
	return material
