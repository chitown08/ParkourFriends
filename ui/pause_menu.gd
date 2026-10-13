extends CanvasLayer
## In-game menu (Esc / Start). The game keeps running underneath, since
## friends may still be playing; main.gd just switches your controls off.

signal resume_pressed
signal leave_pressed
signal quit_pressed

@onready var _sensitivity: HSlider = %Sensitivity
@onready var _sensitivity_value: Label = %SensitivityValue
@onready var _invert_y: CheckBox = %InvertY


func _ready() -> void:
	hide()
	%Resume.pressed.connect(resume_pressed.emit)
	%Leave.pressed.connect(leave_pressed.emit)
	%Quit.pressed.connect(quit_pressed.emit)
	_sensitivity.value_changed.connect(_on_sensitivity_changed)
	_invert_y.toggled.connect(_on_invert_y_toggled)


func open() -> void:
	_sensitivity.set_value_no_signal(Settings.mouse_sensitivity)
	_sensitivity_value.text = "%.2f" % Settings.mouse_sensitivity
	_invert_y.set_pressed_no_signal(Settings.invert_y)
	show()
	%Resume.grab_focus()


func _on_sensitivity_changed(value: float) -> void:
	Settings.mouse_sensitivity = value
	_sensitivity_value.text = "%.2f" % value
	Settings.save_to_disk()


func _on_invert_y_toggled(pressed: bool) -> void:
	Settings.invert_y = pressed
	Settings.save_to_disk()
