extends CanvasLayer
## The start menu: play solo, host a game, or join one.
## It only reports what was clicked; game/main.gd does the actual work.

signal solo_pressed
signal host_pressed
signal join_pressed(address: String)

@onready var _address: LineEdit = %Address
@onready var _status: Label = %Status
@onready var _buttons: Array[Button] = [%Solo, %Host, %Join]


func _ready() -> void:
	%Solo.pressed.connect(solo_pressed.emit)
	%Host.pressed.connect(host_pressed.emit)
	%Join.pressed.connect(func() -> void: join_pressed.emit(_address.text.strip_edges()))
	_address.text_submitted.connect(func(text: String) -> void: join_pressed.emit(text.strip_edges()))
	open()


func open(message: String = "") -> void:
	visible = true
	set_busy(false)
	_status.text = message
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	%Solo.grab_focus()


## Shows a message and greys out the buttons while something is happening.
func set_busy(busy: bool, message: String = "") -> void:
	for button in _buttons:
		button.disabled = busy
	_address.editable = not busy
	if message:
		_status.text = message
