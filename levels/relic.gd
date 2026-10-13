class_name Relic
extends Area3D
## A collectible. Touch it to collect it for the whole team: game/main.gd
## asks the host, and the host tells everyone it's been found.
## Drop relic.tscn into a world to add one (each needs a unique name).

## Sent on every computer when any character touches this relic.
signal touched(player: Player)

const SPIN_SPEED := 1.5 ## Radians per second.
const BOB_HEIGHT := 0.15

var _time := 0.0

@onready var _gem: Node3D = $Gem


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_time = randf() * TAU # So relics don't all bob in sync.


func _process(delta: float) -> void:
	_time += delta
	_gem.rotation.y = _time * SPIN_SPEED
	_gem.position.y = sin(_time * 2.0) * BOB_HEIGHT


## Hides the relic once found (or shows it again, e.g. for a new game).
func set_collected(collected: bool) -> void:
	visible = not collected
	set_deferred(&"monitoring", not collected)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		touched.emit(body)
