class_name RaceGate
extends Area3D
## A start or finish line for a timed run. Running through the start gate
## starts your timer; the finish gate stops it (see game/main.gd and the HUD).

signal passed(player: Player)

enum Kind { START, FINISH }

@export var kind := Kind.START


func _ready() -> void:
	body_entered.connect(func(body: Node3D) -> void:
		if body is Player:
			passed.emit(body))
