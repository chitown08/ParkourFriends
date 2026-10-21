extends PlayerState
## Pulling up onto a ledge: first rise straight up, then step forward onto it.
## Used both from hanging and for quick vaults over low ledges ("mantling").

## Fraction of the climb spent rising; the rest is spent stepping forward.
const RISE_PORTION := 0.6

var _ledge: Ledge
var _duration := 0.4
var _progress := 0.0
var _start: Vector3


func enter(data: Dictionary) -> void:
	_ledge = data["ledge"]
	_duration = data["duration"]
	_progress = 0.0
	_start = player.global_position
	player.velocity = Vector3.ZERO


func physics_update(delta: float) -> void:
	_progress = minf(_progress + delta / _duration, 1.0)

	var top := player.stand_position(_ledge)
	var risen := Vector3(_start.x, top.y, _start.z)
	if _progress < RISE_PORTION:
		player.global_position = _start.lerp(risen, smoothstep(0.0, 1.0, _progress / RISE_PORTION))
	else:
		var t := (_progress - RISE_PORTION) / (1.0 - RISE_PORTION)
		player.global_position = risen.lerp(top, smoothstep(0.0, 1.0, t))
	player.face_direction(-_ledge.normal, delta)

	if _progress >= 1.0:
		player.apply_floor_snap() # Settle onto the surface so we count as on the floor.
		if input.move_direction.length() > 0.3:
			# Still pushing on: come out of the vault at full flow, so climbing
			# over things doesn't kill your momentum.
			player.velocity = -_ledge.normal * player.top_speed()
		player.change_state(&"Ground")
