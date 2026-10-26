extends Node3D
## Slowly spins and bobs a model so it catches the eye (looks only).

const SPIN_SPEED := 1.5 ## Radians per second.
const BOB_HEIGHT := 0.15

var _time := randf() * TAU # So copies don't all bob in sync.


func _process(delta: float) -> void:
	_time += delta
	rotation.y = _time * SPIN_SPEED
	position.y = sin(_time * 2.0) * BOB_HEIGHT
