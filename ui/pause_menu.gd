extends CanvasLayer
## In-game menu (Esc / Start). The game keeps running underneath, since
## friends may still be playing; main.gd just switches your controls off.

signal resume_pressed
signal leave_pressed
signal quit_pressed
## The player picked a different movement feel ("superhuman" or "human").
signal movement_changed(profile_id: String)
## The music volume slider moved (the new value is in Settings).
signal music_changed

@onready var _sensitivity: HSlider = %Sensitivity
@onready var _sensitivity_value: Label = %SensitivityValue
@onready var _invert_y: CheckBox = %InvertY
@onready var _movement: OptionButton = %Movement
@onready var _free_run: CheckBox = %FreeRun
@onready var _music: HSlider = %Music
@onready var _music_value: Label = %MusicValue


func _ready() -> void:
	hide()
	%Resume.pressed.connect(resume_pressed.emit)
	%Leave.pressed.connect(leave_pressed.emit)
	%Quit.pressed.connect(quit_pressed.emit)
	_sensitivity.value_changed.connect(_on_sensitivity_changed)
	_invert_y.toggled.connect(_on_invert_y_toggled)
	for profile_id: String in ["superhuman", "human"]:
		_movement.add_item(profile_id.capitalize())
		_movement.set_item_metadata(_movement.item_count - 1, profile_id)
	_movement.item_selected.connect(_on_movement_selected)
	_free_run.toggled.connect(_on_free_run_toggled)
	_music.value_changed.connect(_on_music_changed)


func open() -> void:
	_sensitivity.set_value_no_signal(Settings.mouse_sensitivity)
	_sensitivity_value.text = "%.2f" % Settings.mouse_sensitivity
	_invert_y.set_pressed_no_signal(Settings.invert_y)
	_free_run.set_pressed_no_signal(Settings.free_run_enabled)
	_music.set_value_no_signal(Settings.music_volume)
	_music_value.text = "%d%%" % roundi(Settings.music_volume * 100.0)
	for i in _movement.item_count:
		if _movement.get_item_metadata(i) == Settings.movement_profile:
			_movement.select(i)
	show()
	%Resume.grab_focus()


func _on_sensitivity_changed(value: float) -> void:
	Settings.mouse_sensitivity = value
	_sensitivity_value.text = "%.2f" % value
	Settings.save_to_disk()


func _on_invert_y_toggled(pressed: bool) -> void:
	Settings.invert_y = pressed
	Settings.save_to_disk()


func _on_movement_selected(index: int) -> void:
	movement_changed.emit(_movement.get_item_metadata(index))


func _on_free_run_toggled(pressed: bool) -> void:
	Settings.free_run_enabled = pressed
	Settings.save_to_disk()


func _on_music_changed(value: float) -> void:
	Settings.music_volume = value
	_music_value.text = "%d%%" % roundi(value * 100.0)
	Settings.save_to_disk()
	music_changed.emit()
