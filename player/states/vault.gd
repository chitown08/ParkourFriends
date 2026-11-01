extends PlayerState
## A flow vault: skimming over something low (a bench, an air-con box) at a
## run, only just clearing it and keeping your speed. Free-run starts it (see
## FreeRun._try_vault()), having checked there's room along the way.
##
## You rise quickly to just over the top before you reach it, carry straight
## on over it, and once you're past it you come down with your speed intact.

var _start: Vector3
var _direction: Vector3
var _speed := 0.0
## Metres along the way from the start: up to `_risen_at` you're rising; by
## `_clear_at` you're past the far side.
var _risen_at := 0.0
var _clear_at := 0.0
## How high your feet go above the start.
var _rise := 0.0
var _travelled := 0.0


func enter(data: Dictionary) -> void:
	_start = player.global_position
	_direction = data["direction"]
	_speed = data["speed"]
	_risen_at = data["risen_at"]
	_clear_at = data["clear_at"]
	_rise = data["rise"]
	_travelled = 0.0
	player.velocity = _direction * _speed


func physics_update(delta: float) -> void:
	_travelled = minf(_travelled + _speed * delta, _clear_at)
	var up := 1.0
	if _travelled < _risen_at:
		var t := _travelled / _risen_at
		up = 1.0 - (1.0 - t) * (1.0 - t) # Fast off the ground, easing in at the top.
	player.global_position = _start + _direction * _travelled + Vector3.UP * _rise * up
	player.velocity = _direction * _speed
	player.face_direction(_direction, delta)
	if _travelled >= _clear_at:
		player.change_state(&"Air") # Over: drop down the far side, still running.
