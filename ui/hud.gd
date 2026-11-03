extends CanvasLayer
## What's on screen while playing: a small controls card in a corner, a
## prompt for what a button would do right now ("E  Toss your friend"),
## messages, relics found and what you carry. Developers also get a readout of
## state, speed and so on (F3).

## The controls card: [action, what it does], one line each.
const CARD := [
	[&"move", "Move"],
	[&"look", "Look"],
	[&"jump", "Jump (hold: leap)"],
	[&"free_run", "Free-run (hold)"],
	[&"crouch", "Crouch, slide, let go"],
	[&"toss", "Friend: toss, brace, hold hands"],
	[&"interact", "Item: pick up, drop (hold: throw)"],
	[&"use_item", "Use item"],
	[&"respawn", "Back to checkpoint"],
	[&"pause", "Menu"],
	[&"toggle_help", "Hide this"],
]

var network: Network

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

var _show_card := true
var _show_stats := false

@onready var _stats: Label = $Stats
@onready var _card: RichTextLabel = $Card
@onready var _prompt: Label = $Prompt
@onready var _message: Label = $Message
@onready var _relics: Label = $Relics
@onready var _items: Label = $Items


func _ready() -> void:
	$Version.text = Settings.version()


func _process(_delta: float) -> void:
	_stats.visible = _show_stats and Settings.dev_tools and player != null
	_card.visible = _show_card and player != null
	_prompt.visible = player != null
	_items.visible = player != null
	$Version.visible = player != null # (The start menu shows its own.)
	if player == null:
		return
	_show_card_text()
	_prompt.text = hint_text(player.control_hints())
	_stats.text = "State: %s\nSpeed: %.1f m/s  (flow %d%%)%s\nHeight: %.1f m\n%s - %d player(s)\nFPS: %d" % [
		player.state.name,
		player.get_horizontal_speed(),
		roundi(player.flow * 100.0),
		"  - pack of %d" % (player.pack_size() + 1) if player.pack_size() > 0 else "",
		player.global_position.y,
		network.describe(),
		_count_people(),
		Engine.get_frames_per_second(),
	]
	_show_items()


func _input(event: InputEvent) -> void:
	ControlNames.note(event)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_help"):
		_show_card = not _show_card
	elif event.is_action_pressed("toggle_stats") and Settings.dev_tools:
		_show_stats = not _show_stats


## The words for a list of [action, words] hints, e.g. "E  Toss your friend".
static func hint_text(hints: Array) -> String:
	var parts := []
	for hint: Array in hints:
		var key := ControlNames.key(hint[0])
		parts.append(("%s  %s" % [key, hint[1]]) if key else hint[1])
	return "      ".join(parts)


func _show_card_text() -> void:
	var text := "[table=2]"
	for line: Array in CARD:
		var key := ControlNames.key(line[0])
		if key == "":
			continue
		text += "[cell][b]%s[/b]   [/cell][cell]%s[/cell]" % [key, line[1]]
	text += "[/table]"
	if _card.text != text:
		_card.text = text


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


## Shows what you're holding (nothing when your hands are empty).
func _show_items() -> void:
	var carrier := player.items
	var in_hands := carrier.hands_item()
	if in_hands == null:
		_items.text = ""
		return
	var slots := "Hands: %s" % in_hands.display_name()
	if in_hands and in_hands.is_bulky():
		slots += " (both hands: no climbing)"
	_items.text = slots
