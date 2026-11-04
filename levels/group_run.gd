class_name GroupRun
extends Node3D
## A group run: a route across the rooftops you run together. Never a race:
## no clock, and the route waits for everyone.
##
## - Its start is a glowing ring (at this node) with a sign: the run's name,
##   its relics earned so far ("Relics: 2 of 4") and who it's waiting for.
##   When the whole crew (everyone in the game) stands in the ring, a short
##   countdown, and the run's on.
## - The route is the white gates (children of Gates, in order; see RunGate).
##   Only during a run can you see them. Each of you goes through the lit one;
##   the next only lights up once the whole crew is through ("Waiting for
##   Sam" over it). Going through one makes it your checkpoint, so a fall
##   just sends you back there, and the crew waits.
## - Gold gates (also in Gates) are extras somewhere hard: one of you is enough.
## - When the whole crew is through the last white gate, the run's relics
##   appear there (children of Rewards, locked until then): "Finish" the first
##   time, and one for each gold gate got this run that hadn't been before.
##   Only finishing pays, and a run can be done again any time.
##
## The host decides what happens (who's in the ring, who's through which
## gate) and shares it; each computer watches its own player go through gates
## and tells the host (report_through(), report_gold()).

enum Phase { IDLE, COUNTDOWN, RUNNING }

## The crew finished and earned new relics (on the host).
signal rewards_earned
## The crew finished a run (on every computer), and what it said: "Run
## complete!" and the relics earned.
signal finished(news: String)

## The start ring: stand within this far (metres, across) of its middle.
const RING_RADIUS := 4.0
const COUNTDOWN_TIME := 3.0
## The sign stands this high over the ring.
const SIGN_HEIGHT := 5.5

@export var title := "Group run"

# Decided by the host and shared (see _make_sync()).
var phase := Phase.IDLE
var countdown := 0.0
## Which white gate (along the route) the crew is heading for.
var gate := 0
## The crew on this run (node names), and who of them is through `gate`.
var crew := PackedStringArray()
var through := PackedStringArray()
## Gold gates (node names) one of you has got this run.
var gold_got := PackedStringArray()
## What the last run ended with, for the sign ("" for nothing to say).
var last_news := ""

var _route: Array[RunGate] = []
var _golds: Array[RunGate] = []
var _sign: Label3D
## Where your player was last tick (to see them go through a gate).
var _last_position := Vector3.INF


func _ready() -> void:
	add_to_group(&"group_runs")
	for child in get_node(^"Gates").get_children():
		if child is RunGate:
			(_golds if child.gold else _route).append(child)
	_make_ring()
	_make_sync()


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_host_update(delta)
	_watch_own_player()
	_show()


# --- The host ---------------------------------------------------------------------

func _host_update(delta: float) -> void:
	var everyone := crew_now()
	if phase != Phase.IDLE and phase != Phase.COUNTDOWN and everyone != crew:
		_stop("The crew changed: start again together")
		return
	var all_in := not everyone.is_empty() and Array(everyone).all(func(player_name: String) -> bool: return in_ring(player_name))
	match phase:
		Phase.IDLE:
			if all_in:
				phase = Phase.COUNTDOWN
				countdown = COUNTDOWN_TIME
		Phase.COUNTDOWN:
			if not all_in:
				phase = Phase.IDLE
				return
			countdown -= delta
			if countdown <= 0.0:
				crew = everyone
				gate = 0
				through = PackedStringArray()
				gold_got = PackedStringArray()
				last_news = ""
				phase = Phase.RUNNING


## A player went through white gate `index` (sent by their computer).
@rpc("any_peer", "call_local", "reliable")
func report_through(index: int) -> void:
	if not multiplayer.is_server() or phase != Phase.RUNNING or index != gate:
		return
	var who := _sender_name()
	if not who in crew or who in through:
		return
	through.append(who)
	if through.size() < crew.size():
		return
	# The whole crew is through: on to the next gate, or done.
	gate += 1
	through = PackedStringArray()
	if gate >= _route.size():
		_finish()


## A player went through the gold gate `gate_name`.
@rpc("any_peer", "call_local", "reliable")
func report_gold(gate_name: String) -> void:
	if multiplayer.is_server() and phase == Phase.RUNNING and _sender_name() in crew and not gate_name in gold_got:
		gold_got.append(gate_name)


func _finish() -> void:
	var earned := 0
	for reward_name: String in ["Finish"] + Array(gold_got):
		var reward := get_node_or_null(NodePath("Rewards/" + reward_name)) as WorldItem
		if reward and reward.state == WorldItem.State.LOCKED:
			reward.host_unlock()
			earned += 1
	if earned:
		rewards_earned.emit()
	var news := "Run complete! %s" % ("%d new relic%s" % [earned, "" if earned == 1 else "s"] if earned else "No new relics this time")
	_stop(news)
	celebrate.rpc(gold_got.size(), news)


## Everyone's party over the last gate: fireworks, and lots of them if you
## got a gold gate this run.
@rpc("authority", "call_local", "reliable")
func celebrate(golds: int, news: String) -> void:
	if not _route.is_empty():
		Celebration.play(self, _route.back().global_position, 4 if golds > 0 else 3)
	finished.emit(news)


func _stop(news: String) -> void:
	phase = Phase.IDLE
	crew = PackedStringArray()
	through = PackedStringArray()
	last_news = news


# --- Every computer ----------------------------------------------------------------

## Watches this computer's own player go through gates, and tells the host.
func _watch_own_player() -> void:
	var me := _own_player()
	if me == null or phase != Phase.RUNNING or not str(me.name) in crew:
		_last_position = Vector3.INF
		return
	var chest := me.global_position + Vector3.UP
	if _last_position != Vector3.INF:
		var heading_for := gate # (Telling the host may move it on at once.)
		if heading_for < _route.size() and not str(me.name) in through and _route[heading_for].passed_through(_last_position, chest):
			_make_checkpoint(me, _route[heading_for])
			report_through.rpc_id(1, heading_for)
		for gold in _golds:
			if not gold.name in gold_got and gold.passed_through(_last_position, chest):
				report_gold.rpc_id(1, str(gold.name))
	_last_position = chest


## Going through a gate makes the ground under it your checkpoint.
func _make_checkpoint(me: Player, at: RunGate) -> void:
	var hit := me.raycast(at.global_position, at.global_position + Vector3.DOWN * 20.0)
	if not hit.is_empty():
		me.set_checkpoint(hit.position + Vector3.UP * 0.05)


## Shows the gates and the sign as things stand.
func _show() -> void:
	for i in _route.size():
		var look := RunGate.Look.HIDDEN
		var waiting := ""
		if phase == Phase.RUNNING:
			look = RunGate.Look.DONE if i < gate else (RunGate.Look.NEXT if i == gate else RunGate.Look.AHEAD)
			if i == gate and not through.is_empty():
				waiting = _names(Array(crew).filter(func(who: String) -> bool: return not who in through))
		_route[i].show_look(look, waiting)
	for gold in _golds:
		var look := RunGate.Look.HIDDEN
		if phase == Phase.RUNNING:
			look = RunGate.Look.DONE if gold.name in gold_got else RunGate.Look.AHEAD
		gold.show_look(look)
	_sign.text = sign_text()


## What the sign says.
func sign_text() -> String:
	var lines := [title.to_upper(), "Relics: %d of %d" % [relics_earned(), rewards().size()]]
	match phase:
		Phase.IDLE:
			var missing := Array(crew_now()).filter(func(who: String) -> bool: return not in_ring(who))
			if last_news:
				lines.append(last_news)
			lines.append("Stand in the ring together to start" if missing.size() == crew_now().size() \
					else "Waiting for %s" % _names(missing))
		Phase.COUNTDOWN:
			lines.append(str(ceili(countdown)))
		Phase.RUNNING:
			lines.append("Run on: gate %d of %d" % [mini(gate + 1, _route.size()), _route.size()])
	return "\n".join(lines)


## The run's relics (earned or not).
func rewards() -> Array[WorldItem]:
	var found: Array[WorldItem] = []
	for child in get_node(^"Rewards").get_children():
		if child is WorldItem:
			found.append(child)
	return found


func relics_earned() -> int:
	return rewards().filter(func(reward: WorldItem) -> bool: return reward.state != WorldItem.State.LOCKED).size()


## Everyone in the game (node names; not the practice buddy).
func crew_now() -> PackedStringArray:
	var names := PackedStringArray()
	for player in _players():
		names.append(str(player.name))
	names.sort()
	return names


## True if the player called `player_name` stands in the start ring.
func in_ring(player_name: String) -> bool:
	for player in _players():
		if str(player.name) == player_name:
			var offset := player.global_position - global_position
			return Vector2(offset.x, offset.z).length() <= RING_RADIUS and absf(offset.y) < 2.0
	return false


func _players() -> Array[Player]:
	var found: Array[Player] = []
	var node := get_parent()
	while node and not node.has_node(^"Players"):
		node = node.get_parent()
	if node:
		for child in node.get_node(^"Players").get_children():
			if child is Player and not child.is_bot and not child.is_queued_for_deletion():
				found.append(child)
	return found


func _own_player() -> Player:
	for player in _players():
		if player.is_local:
			return player
	return null


## "Sam and Bo", "Sam, Bo and Ana": the players' names, by node name.
func _names(node_names: Array) -> String:
	var shown := []
	for player in _players():
		if str(player.name) in node_names:
			shown.append(player.sync_player_name if player.sync_player_name else "a friend")
	if shown.size() <= 1:
		return "".join(shown)
	return ", ".join(shown.slice(0, -1)) + " and " + shown.back()


func _sender_name() -> String:
	var sender := multiplayer.get_remote_sender_id()
	return str(sender if sender != 0 else multiplayer.get_unique_id())


func _make_ring() -> void:
	var material := RunGate._glow(Color(1, 1, 1, 0.8))
	var torus := TorusMesh.new()
	torus.inner_radius = RING_RADIUS - 0.15
	torus.outer_radius = RING_RADIUS
	torus.material = material
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	ring.mesh = torus
	ring.position.y = 0.05
	add_child(ring)
	_sign = Label3D.new()
	_sign.name = "Sign"
	_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sign.position.y = SIGN_HEIGHT
	_sign.font_size = 64
	_sign.outline_size = 16
	_sign.pixel_size = 0.007
	add_child(_sign)


## Shares what the host decides with everyone.
func _make_sync() -> void:
	var config := SceneReplicationConfig.new()
	for property in ["phase", "countdown", "gate", "crew", "through", "gold_got", "last_news"]:
		var path := NodePath(".:" + property)
		config.add_property(path)
		config.property_set_spawn(path, true)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "RunSync"
	sync.replication_config = config
	sync.set_multiplayer_authority(1)
	add_child(sync)
