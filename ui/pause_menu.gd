extends CanvasLayer
## In-game menu (Esc / Start): settings on one side, your outfit on the other.
## The game keeps running underneath, since friends may still be playing;
## main.gd just switches your controls off.

signal resume_pressed
signal leave_pressed
signal quit_pressed
## "Invite Friends": open Steam's invite window.
signal invite_pressed
## The player picked a different movement feel ("superhuman" or "human").
signal movement_changed(profile_id: String)
## The music volume slider moved (the new value is in Settings).
signal music_changed
## The host picked a time of day (one of TimeOfDay.NAMES).
signal time_of_day_changed(time: String)
## Something picked in "Your outfit" (the new outfit is in Settings.outfit).
signal outfit_changed

## What "nothing" is called in each outfit slot's list.
const NOTHING := "None"

@onready var _sensitivity: HSlider = %Sensitivity
@onready var _sensitivity_value: Label = %SensitivityValue
@onready var _invert_y: CheckBox = %InvertY
@onready var _fullscreen: CheckBox = %Fullscreen
@onready var _movement: OptionButton = %Movement
@onready var _free_run: CheckBox = %FreeRun
@onready var _master: HSlider = %Master
@onready var _music: HSlider = %Music
@onready var _effects: HSlider = %Effects
## One list per outfit slot, in Cosmetics.SLOTS order.
var _slots: Array[OptionButton] = []


func _ready() -> void:
	hide()
	%Resume.pressed.connect(resume_pressed.emit)
	%Leave.pressed.connect(leave_pressed.emit)
	%Quit.pressed.connect(quit_pressed.emit)
	%Invite.pressed.connect(invite_pressed.emit)
	%Version.text = Settings.version()
	_sensitivity.value_changed.connect(_on_sensitivity_changed)
	_invert_y.toggled.connect(_on_invert_y_toggled)
	_fullscreen.toggled.connect(_on_fullscreen_toggled)
	%LightTrails.toggled.connect(func(pressed: bool) -> void:
		Settings.light_trails = pressed
		Settings.save_to_disk())
	for time in TimeOfDay.NAMES:
		%TimeOfDay.add_item(TimeOfDay.LABELS[time])
		%TimeOfDay.set_item_metadata(%TimeOfDay.item_count - 1, time)
	%TimeOfDay.item_selected.connect(func(index: int) -> void:
		time_of_day_changed.emit(String(%TimeOfDay.get_item_metadata(index))))
	for profile_id: String in ["superhuman", "human"]:
		_movement.add_item(profile_id.capitalize())
		_movement.set_item_metadata(_movement.item_count - 1, profile_id)
	_movement.item_selected.connect(_on_movement_selected)
	_free_run.toggled.connect(_on_free_run_toggled)
	%SaveProgress.toggled.connect(func(pressed: bool) -> void:
		Settings.save_progress = pressed
		Settings.save_to_disk())
	%ForgetProgress.pressed.connect(func() -> void:
		Progress.forget()
		%ForgetProgress.text = "Forgotten: the next game starts fresh")
	_master.value_changed.connect(_on_master_changed)
	_music.value_changed.connect(_on_music_changed)
	_effects.value_changed.connect(_on_effects_changed)
	_make_outfit_lists()


## Shows the menu; `can_invite`: in a Steam game, so there's an "Invite Friends"
## button; `is_host`: you pick the time of day (it's `time` now).
func open(can_invite := false, is_host := true, time := "day") -> void:
	%Invite.visible = can_invite
	%TimeOfDay.disabled = not is_host
	for i in %TimeOfDay.item_count:
		if %TimeOfDay.get_item_metadata(i) == time:
			%TimeOfDay.select(i)
	_sensitivity.set_value_no_signal(Settings.mouse_sensitivity)
	_sensitivity_value.text = "%.2f" % Settings.mouse_sensitivity
	_invert_y.set_pressed_no_signal(Settings.invert_y)
	_fullscreen.set_pressed_no_signal(Settings.fullscreen)
	%LightTrails.set_pressed_no_signal(Settings.light_trails)
	_free_run.set_pressed_no_signal(Settings.free_run_enabled)
	%SaveProgress.set_pressed_no_signal(Settings.save_progress)
	%ForgetProgress.text = "Forget saved progress"
	for pair: Array in [[_master, Settings.master_volume], [_music, Settings.music_volume], [_effects, Settings.effects_volume]]:
		pair[0].set_value_no_signal(pair[1])
		_show_percent(pair[0], pair[1])
	for i in _movement.item_count:
		if _movement.get_item_metadata(i) == Settings.movement_profile:
			_movement.select(i)
	%DevSettings.visible = Settings.dev_tools # (Not for the build friends play.)
	var outfit := Cosmetics.tidy(Settings.outfit)
	for i in _slots.size():
		var list := _slots[i]
		list.select(0)
		for item in list.item_count:
			if list.get_item_metadata(item) == outfit[i]:
				list.select(item)
	show()
	%Resume.grab_focus()


## A list for each outfit slot: "None", then everything made for it.
func _make_outfit_lists() -> void:
	for slot in Cosmetics.SLOTS:
		var label := Label.new()
		label.text = String(slot).capitalize()
		%Slots.add_child(label)
		var list := OptionButton.new()
		list.name = String(slot).capitalize()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_item(NOTHING)
		list.set_item_metadata(0, "")
		for item in Cosmetics.available(slot):
			# "banner/pirate_banner" -> "Pirate Banner"
			list.add_item(item.get_file().capitalize())
			list.set_item_metadata(list.item_count - 1, item)
		list.item_selected.connect(_on_outfit_picked.unbind(1))
		%Slots.add_child(list)
		_slots.append(list)


func _on_outfit_picked() -> void:
	var outfit := PackedStringArray()
	for list in _slots:
		outfit.append(list.get_selected_metadata())
	Settings.outfit = outfit
	Settings.save_to_disk()
	outfit_changed.emit()


func _on_sensitivity_changed(value: float) -> void:
	Settings.mouse_sensitivity = value
	_sensitivity_value.text = "%.2f" % value
	Settings.save_to_disk()


func _on_invert_y_toggled(pressed: bool) -> void:
	Settings.invert_y = pressed
	Settings.save_to_disk()


func _on_fullscreen_toggled(pressed: bool) -> void:
	Settings.fullscreen = pressed
	Settings.save_to_disk()
	Settings.apply_display()


func _on_movement_selected(index: int) -> void:
	movement_changed.emit(_movement.get_item_metadata(index))


func _on_free_run_toggled(pressed: bool) -> void:
	Settings.free_run_enabled = pressed
	Settings.save_to_disk()


func _on_master_changed(value: float) -> void:
	Settings.master_volume = value
	_volume_changed(_master, value)


func _on_music_changed(value: float) -> void:
	Settings.music_volume = value
	_volume_changed(_music, value)
	music_changed.emit()


func _on_effects_changed(value: float) -> void:
	Settings.effects_volume = value
	_volume_changed(_effects, value)


func _volume_changed(slider: HSlider, value: float) -> void:
	_show_percent(slider, value)
	Settings.save_to_disk()
	Settings.apply_audio()


func _show_percent(slider: HSlider, value: float) -> void:
	(slider.get_parent().get_child(2) as Label).text = "%d%%" % roundi(value * 100.0)

