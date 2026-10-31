class_name CharacterModel
extends Node3D
## The character you see: a model rigged in Mixamo, and its animations (see
## docs/CHARACTER_GUIDE.md). Each frame the Player says what you're doing
## (animate()), and this picks the animation to match and blends into it.
## Works the same for your friends' characters on your screen, from what the
## network tells us about them.

## Where the animations are: one file per move, pulled out of the FBX files
## when Godot imports them (see each anims/*.fbx.import).
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
## Moves whose animation climbs upward by itself (the game already lifts you).
const RISING_MOVES: Array[String] = ["climb_up", "wall_scramble", "vault"]
## The bone that carries the whole body.
const HIPS := "mixamorig_Hips"
## States where a one-off move plays over what you're doing.
const ACTION_STATES: Array[StringName] = [&"Ground", &"Crouch", &"Air"]

## How long climbing moves take (copied from the Player's movement numbers),
## so the animation fits.
var climb_up_time := 0.35
var mantle_time := 0.2

## The skinned body mesh (the Player recolours it per player).
@onready var body: MeshInstance3D = find_children("*", "MeshInstance3D", true, false)[0]
@onready var _animations: AnimationPlayer = find_children("*", "AnimationPlayer", true, false)[0]

static var _library: AnimationLibrary

var _current := &""
var _action_timer := 0.0
var _last_state := &""
var _climb_animation := &"climb_up"


func _ready() -> void:
	if _library == null:
		_library = AnimationLibrary.new()
		for file in DirAccess.get_files_at(ANIM_DIR):
			if file.ends_with(".res"):
				var animation: Animation = load(ANIM_DIR + file).duplicate()
				_hold_in_place(animation, file.get_basename() in RISING_MOVES)
				_library.add_animation(file.get_basename(), animation)
	_animations.add_animation_library(&"moves", _library)
	_play(&"idle")


## Picks the animation for what you're doing: `state` is your movement state,
## `speed` how fast you're moving across the ground, `rising` whether you're
## going up, `lean` the wall-run lean (positive: the wall's on your right).
func animate(state: StringName, speed: float, rising: bool, lean: float,
		tossed: bool, carrying: bool, delta: float) -> void:
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
			if speed < STILL_SPEED:
				_play(&"carry" if carrying else &"idle")
			elif speed < SPRINT_FROM:
				_play(&"run", speed / RUN_ANIM_SPEED)
			else:
				_play(&"sprint", speed / SPRINT_ANIM_SPEED)
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
			_play(&"hang")
		&"Climb":
			var time := climb_up_time if _climb_animation == &"climb_up" else mantle_time
			_play(_climb_animation, _length(_climb_animation) / maxf(time, 0.05))
		&"WallRun":
			_play(&"wall_run_right" if lean > 0.0 else &"wall_run_left", speed / RUN_ANIM_SPEED)
		&"WallScramble":
			_play(&"wall_scramble")
		&"Grind":
			_play(&"grind")
		&"Glide":
			_play(&"glide")
		_:
			_play(&"idle")


## Plays a one-off move (`swing`, `throw`, `toss`) over whatever you're doing.
func play_action(animation: StringName, time := ACTION_TIME) -> void:
	_action_timer = time
	_play(animation, _length(animation) / time, true)


## A landing from a big drop (only when you're not running on, so it doesn't
## interrupt a run).
func play_landing() -> void:
	play_action(&"land", LAND_TIME)


func _play(animation: StringName, speed := 1.0, restart := false) -> void:
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
	return _library.get_animation(animation).length if _library.has_animation(animation) else 1.0


## The animation playing now (for tests).
func current_animation() -> StringName:
	return _current
