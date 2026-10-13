extends CanvasLayer
## Debug overlay: shows speed/height and a controls cheat-sheet.

var player: Player:
	set(value):
		player = value
		player.respawned.connect(_flash.bind("Respawned"))

@onready var _stats: Label = $Stats
@onready var _help: Label = $Help
@onready var _message: Label = $Message


func _process(_delta: float) -> void:
	if player == null:
		return
	_stats.text = "State: %s\nSpeed: %.1f m/s\nHeight: %.1f m\nFPS: %d" % [
		player.state.name,
		player.get_horizontal_speed(),
		player.global_position.y,
		Engine.get_frames_per_second(),
	]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_help"):
		_help.visible = not _help.visible


## Shows a short message in the middle of the screen.
func show_message(text: String) -> void:
	_flash(text)


func _flash(text: String) -> void:
	_message.text = text
	_message.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(_message, "modulate:a", 0.0, 0.5)
