extends CanvasLayer
## Debug overlay: shows state/speed/height, network status, and a controls cheat-sheet.

var network: Network
## When the current timed run started (Time.get_ticks_msec()), or -1 if not running.
var run_start_msec := -1

## The character this computer controls (null while in the menu).
var player: Player:
	set(value):
		if player and player.respawned.is_connected(_on_respawned):
			player.respawned.disconnect(_on_respawned)
			player.tree_exiting.disconnect(_on_player_removed)
			player.tossed_someone.disconnect(_on_tossed_someone)
			player.got_tossed.disconnect(_on_got_tossed)
		player = value
		if player:
			player.respawned.connect(_on_respawned)
			player.tree_exiting.connect(_on_player_removed)
			player.tossed_someone.connect(_on_tossed_someone)
			player.got_tossed.connect(_on_got_tossed)

var _show_help := true

@onready var _stats: Label = $Stats
@onready var _help: Label = $Help
@onready var _message: Label = $Message
@onready var _relics: Label = $Relics
@onready var _timer: Label = $Timer


func _process(_delta: float) -> void:
	_stats.visible = player != null
	_help.visible = _show_help and player != null
	_timer.visible = player != null and (run_start_msec >= 0 or _timer.text != "")
	if run_start_msec >= 0:
		_timer.text = format_time((Time.get_ticks_msec() - run_start_msec) / 1000.0)
	if player == null:
		return
	_stats.text = "State: %s\nSpeed: %.1f m/s  (flow %d%%)\nHeight: %.1f m\nAgility level %d\n%s - %d player(s)\nFPS: %d" % [
		player.state.name,
		player.get_horizontal_speed(),
		roundi(player.flow * 100.0),
		player.global_position.y,
		player.agility_level,
		network.describe(),
		_count_people(),
		Engine.get_frames_per_second(),
	]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_help"):
		_show_help = not _show_help


## Shows a short message in the middle of the screen.
func show_message(text: String) -> void:
	_message.text = text
	_message.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(_message, "modulate:a", 0.0, 0.5)


func _on_respawned() -> void:
	show_message("Respawned")


func _on_player_removed() -> void:
	player = null


func _on_tossed_someone(_target: Player) -> void:
	show_message("Toss!")


func _on_got_tossed() -> void:
	show_message("Launched!")


## Players in the game, not counting the practice buddy.
func _count_people() -> int:
	var count := 0
	for other in player.get_parent().get_children():
		if other is Player and not other.is_bot:
			count += 1
	return count


## Shows "Relics found / total" (hidden in worlds without relics).
func set_relic_count(found: int, total: int) -> void:
	_relics.visible = total > 0
	_relics.text = "Relics %d / %d" % [found, total]


## Shows a finished run's time (and your best this session).
func show_run_result(time: float, best: float, is_best: bool) -> void:
	_timer.text = "%s   (best %s)" % [format_time(time), format_time(best)]
	show_message("FINISH! %s%s" % [format_time(time), "  NEW BEST!" if is_best else ""])


## 75.25 seconds -> "1:15.25".
static func format_time(seconds: float) -> String:
	return "%d:%05.2f" % [int(seconds) / 60, fmod(seconds, 60.0)]


## Hides the run timer (e.g. when a new world loads).
func clear_run_timer() -> void:
	run_start_msec = -1
	_timer.text = ""
