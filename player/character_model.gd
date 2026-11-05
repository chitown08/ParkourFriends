class_name CharacterModel
extends Node3D
## The character you see: a rigged model (Meshy), and its animations (see
## docs/CHARACTER_GUIDE.md). Each frame the Player says what you're doing
## (animate()), and this picks the animation to match and blends into it.
## Works the same for your friends' characters on your screen, from what the
## network tells us about them.

## Where the animations are: one file per move, pulled out of the FBX files
## when Godot imports them (see each anims/*.fbx.import).
## A move can have several animations to pick from, so it doesn't look the same
## every time: "vault" plus "vault-kong", "vault-roll"... (a name, a dash, and
## anything). Each time you start a move, one of its set is picked (see
## animate()'s `variant`), the same one on every screen. Add a variant by
## adding a file named that way: nothing else to change.
const ANIM_DIR := "res://characters/blob/anims/"
const BLEND_TIME := 0.15
## How fast (m/s) the run, sprint and crouch-walk animations look like they're
## going: they play faster or slower to match your real speed.
const RUN_ANIM_SPEED := 7.0
const SPRINT_ANIM_SPEED := 11.0
const CROUCH_WALK_ANIM_SPEED := 2.5
## Sprint instead of run above this speed (m/s).
const SPRINT_FROM := 11.0
## Slower than this counts as standing still.
const STILL_SPEED := 0.5
## One-off moves (bat swing, throw, toss, landing) are sped up to take this long.
const ACTION_TIME := 0.6
const LAND_TIME := 0.4
const LEAP_TIME := 0.7
## A flow vault (skimming over something low at a run) is played this fast.
const FLOW_VAULT_TIME := 0.35
## Moves whose animation climbs upward by itself (the game already lifts you).
const RISING_MOVES: Array[String] = ["climb_up", "wall_scramble", "vault"]
## The bone that carries the whole body.
const HIPS := "Hips"
## Every animation is retargeted onto Godot's standard humanoid skeleton when
## it's imported (characters/*_bone_map.tres), so ones made on different rigs
## (Meshy's, Mixamo's) all play on the character. The old Mixamo files don't
## have a proper rest pose, which leaves their hips this many times too high:
## put right as they load (they're the ones without an "Armature" track).
const MIXAMO_HIPS_HIGH := 2.98
## The animation for each state that just plays one (see animate()).
const STATE_MOVES := {
	&"WallScramble": &"wall_scramble", &"Grind": &"grind", &"Glide": &"glide",
	&"Brace": &"brace", &"LegUp": &"leg_up", &"ChainHang": &"chain_hang", &"ChainClimb": &"chain_climb",
	&"PipeClimb": &"pipe_climb", &"Catch": &"catch", &"Caught": &"caught",
	&"Linked": &"linked", &"Whip": &"whip", &"Whipped": &"whipped",
}
## Until a move has its own animation (see docs/ANIMATION_LIST.md), this one plays instead.
const STAND_INS := {
	"shimmy": &"hang", "brace": &"crouch_idle", "catch": &"crouch_idle", "caught": &"hang",
	"chain_hang": &"hang", "chain_climb": &"wall_scramble", "leg_up": &"wall_scramble",
	"pipe_climb": &"wall_scramble",
}
## States where a one-off move plays over what you're doing.
const ACTION_STATES: Array[StringName] = [&"Ground", &"Crouch", &"Air"]

## How long climbing moves take (copied from the Player's movement numbers),
## so the animation fits.
var climb_up_time := 0.35
var mantle_time := 0.2

## The skinned body mesh (the Player recolours it per player).
@onready var body: MeshInstance3D = find_children("*", "MeshInstance3D", true, false)[0]
@onready var _animations: AnimationPlayer = find_children("*", "AnimationPlayer", true, false)[0]
@onready var _skeleton: Skeleton3D = find_children("*", "Skeleton3D", true, false)[0]

static var _library: AnimationLibrary
## Each move's set of animations, by move: "vault" -> [&"vault", &"vault-kong", ...].
static var _variants := {}

var _current := &""
var _action_timer := 0.0
var _last_state := &""
var _climb_animation := &"climb_up"
## Which of a move's animations to play (see animate()).
var _variant := 0


func _ready() -> void:
	if _library == null:
		_library = AnimationLibrary.new()
		for file in DirAccess.get_files_at(ANIM_DIR):
			if file.ends_with(".res"):
				var animation: Animation = load(ANIM_DIR + file).duplicate()
				var animation_name := file.get_basename()
				var move := move_of(animation_name)
				_fit_to_skeleton(animation)
				_hold_in_place(animation, move in RISING_MOVES)
				_library.add_animation(animation_name, animation)
				if not _variants.has(move):
					_variants[move] = []
				_variants[move].append(StringName(animation_name))
		for move: String in _variants:
			_variants[move].sort()
	_animations.add_animation_library(&"moves", _library)
	_play(&"idle")


## Picks the animation for what you're doing: `state` is your movement state,
## `speed` how fast you're moving across the ground, `rising` whether you're
## going up, `lean` the wall-run lean (positive: the wall's on your right).
## `variant` picks which of a move's animations play (any number: it changes
## each time you start a move, and is the same on every screen).
func animate(state: StringName, speed: float, rising: bool, lean: float,
		tossed: bool, carrying: bool, delta: float, variant := 0) -> void:
	_variant = variant
	if state != _last_state:
		if state == &"Climb":
			# From a hang it's a pull-up; straight from a jump it's a quick vault.
			_climb_animation = &"climb_up" if _last_state == &"Hang" else &"vault"
		_last_state = state
	_action_timer -= delta
	if _action_timer > 0.0 and state in ACTION_STATES:
		return # Let the one-off move finish.

	match state:
		&"Ground":
			_run(speed, &"carry" if carrying else &"idle")
		&"PipeRun":
			# (Round a tube you're mostly not moving across the ground: run flat out.)
			if _variants.has("pipe_run"):
				_play(&"pipe_run")
			else:
				_run(maxf(speed, RUN_ANIM_SPEED), &"idle")
		&"Linked", &"Whipped":
			if _variants.has(STATE_MOVES[state]):
				_play(STATE_MOVES[state], maxf(speed, 1.0) / RUN_ANIM_SPEED)
			else:
				_run(speed, &"idle")
		&"Whip":
			if _variants.has("whip"):
				_play(&"whip")
			else:
				_run(speed, &"idle")
		&"Crouch":
			if speed < STILL_SPEED:
				_play(&"crouch_idle")
			else:
				_play(&"crouch_walk", speed / CROUCH_WALK_ANIM_SPEED)
		&"Slide":
			_play(&"slide")
		&"Air":
			if tossed:
				_play(&"tossed")
			else:
				_play(&"jump" if rising else &"fall")
		&"Hang":
			_play(&"shimmy" if speed > STILL_SPEED else &"hang")
		&"Climb":
			var time := climb_up_time if _climb_animation == &"climb_up" else mantle_time
			_play(_climb_animation, _length(_climb_animation) / maxf(time, 0.05))
		&"Vault":
			_play(&"vault", _length(&"vault") / FLOW_VAULT_TIME)
		&"WallRun":
			_play(&"wall_run_right" if lean > 0.0 else &"wall_run_left", speed / RUN_ANIM_SPEED)
		_:
			_play(STATE_MOVES.get(state, &"idle"))


## Standing, running or sprinting, by `speed` (`still`: what to play standing).
func _run(speed: float, still: StringName) -> void:
	if speed < STILL_SPEED:
		_play(still)
	elif speed < SPRINT_FROM:
		_play(&"run", speed / RUN_ANIM_SPEED)
	else:
		_play(&"sprint", speed / SPRINT_ANIM_SPEED)


## Plays a one-off move (`swing`, `throw`, `toss`) over whatever you're doing.
func play_action(animation: StringName, time := ACTION_TIME) -> void:
	_action_timer = time
	_play(animation, _length(animation) / time, true)


## A big free-run leap: a flip or a twist on the way up, if there are any
## "leap" animations (otherwise the jump plays as usual).
func play_leap() -> void:
	if _variants.has("leap"):
		play_action(&"leap", LEAP_TIME)


## A landing from a big drop (only when you're not running on, so it doesn't
## interrupt a run).
func play_landing() -> void:
	play_action(&"land", LAND_TIME)


func _play(move: StringName, speed := 1.0, restart := false) -> void:
	var animation := pick(move)
	_animations.speed_scale = clampf(speed, 0.3, 8.0)
	if animation == _current and not restart:
		return
	_current = animation
	_animations.play(&"moves/" + animation, BLEND_TIME)
	if restart:
		_animations.seek(0.0, true)


## Some Mixamo moves (a slide, a vault...) can't be downloaded "In Place": the
## body travels off on its own, but the game moves you already. This takes out
## that steady travel across the ground (and, with `rising`, upward too) while
## keeping the bob and sway.
static func _hold_in_place(animation: Animation, rising: bool) -> void:
	for track in animation.get_track_count():
		var path := str(animation.track_get_path(track))
		var keys := animation.track_get_key_count(track)
		if animation.track_get_type(track) != Animation.TYPE_POSITION_3D or not path.ends_with(HIPS) or keys < 2:
			continue
		var travel: Vector3 = animation.track_get_key_value(track, keys - 1) - animation.track_get_key_value(track, 0)
		if not rising:
			travel.y = 0.0
		var end := animation.track_get_key_time(track, keys - 1)
		for key in keys:
			var done := animation.track_get_key_time(track, key) / maxf(end, 0.001)
			animation.track_set_key_value(track, key, animation.track_get_key_value(track, key) - travel * done)


func _length(animation: StringName) -> float:
	animation = pick(animation)
	return _library.get_animation(animation).length if _library.has_animation(animation) else 1.0


## The move an animation is for: "vault-kong" -> "vault".
static func move_of(animation: String) -> String:
	return animation.get_slice("-", 0)


## Which of `move`'s animations plays this time (the move itself if it has no set).
func pick(move: StringName) -> StringName:
	if not _variants.has(String(move)) and STAND_INS.has(String(move)):
		move = STAND_INS[String(move)]
	var choices: Array = _variants.get(String(move), [])
	return choices[_variant % choices.size()] if choices.size() > 1 else move


## True if there's an animation for `move` (its own, not a stand-in).
func has_move(move: StringName) -> bool:
	return _variants.has(String(move))


## Every animation for `move` (for tests).
static func variants_of(move: String) -> Array:
	return _variants.get(move, [])


## Puts on a cosmetic: `item` from Cosmetics.available(slot), or "" to take it off.
func wear(slot: StringName, item: String) -> void:
	Cosmetics.wear(_skeleton, slot, item)


## The animation playing now (for tests).
func current_animation() -> StringName:
	return _current


## Makes an animation fit the character's skeleton: takes out tracks moving
## anything but its bones (Meshy's turn the whole rig over, left from the file
## format), and puts the old Mixamo files' hips right (see MIXAMO_HIPS_HIGH).
static func _fit_to_skeleton(animation: Animation) -> void:
	var from_mixamo := true
	for track in range(animation.get_track_count() - 1, -1, -1):
		if not str(animation.track_get_path(track)).contains(":"):
			from_mixamo = false
			animation.remove_track(track)
	if not from_mixamo:
		return
	for track in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_POSITION_3D or not str(animation.track_get_path(track)).ends_with(":" + HIPS):
			continue
		for key in animation.track_get_key_count(track):
			animation.track_set_key_value(track, key, animation.track_get_key_value(track, key) / MIXAMO_HIPS_HIGH)
