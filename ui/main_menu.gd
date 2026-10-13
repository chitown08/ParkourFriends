extends CanvasLayer
## The start menu: play solo, host a game, or join one.
## It only reports what was clicked; game/main.gd does the actual work.

signal solo_pressed
signal host_pressed
signal join_pressed(address: String)

@onready var _address: LineEdit = %Address
@onready var _status: Label = %Status
@onready var _world: OptionButton = %World
@onready var _buttons: Array[Control] = [%Solo, %Host, %Join, %World]


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
		button.set(&"disabled", busy)
	_address.editable = not busy
	if message:
		_status.text = message


## Fills in the world picker. `ids` are world ids like "old_town".
func set_worlds(ids: Array, default_id: String) -> void:
	_world.clear()
	for id: String in ids:
		_world.add_item(id.capitalize())
		_world.set_item_metadata(_world.item_count - 1, id)
		if id == default_id:
			_world.select(_world.item_count - 1)


## The world id picked in the menu (used when playing solo or hosting).
func selected_world() -> String:
	return _world.get_item_metadata(_world.selected) if _world.item_count > 0 else ""
