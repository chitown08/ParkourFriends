extends GameTest
## Leg-ups (player/states/brace.gd, leg_up.gd): a friend braces at the foot of a
## wall (toss button, nobody to toss), you run at them and jump, and they
## launch you up the wall into a scramble. Friends climbing onto the braced
## one's shoulders put the hands higher. On walls built over a floor high above
## the test course: 11 m (too tall alone, see test_reach.gd; one friend
## braced is enough) and 12.5 m (needs two braced, one on the other).

const FLOOR_Y := 200.0
const WALL_FACE_Z := -20.0 ## Their faces look south (+Z); you climb them heading north.
const ONE_FRIEND_WALL := 11.0
const TWO_FRIEND_WALL := 12.5
const TWO_FRIEND_X := 40.0

var buddy: Player
var states_entered: Array[StringName] = []


func before_each() -> void:
	await super()
	player.set_profile(SUPERHUMAN)
	states_entered.clear()
	player.state_changed.connect(func(new_state: StringName) -> void: states_entered.append(new_state))
	_box(Vector3(0, FLOOR_Y - 0.5, 0), Vector3(400, 1, 400))
	_box(Vector3(0, FLOOR_Y + ONE_FRIEND_WALL / 2.0, WALL_FACE_Z - 10.0), Vector3(20, ONE_FRIEND_WALL, 20))
	_box(Vector3(TWO_FRIEND_X, FLOOR_Y + TWO_FRIEND_WALL / 2.0, WALL_FACE_Z - 10.0), Vector3(20, TWO_FRIEND_WALL, 20))
	main.call_buddy()
	buddy = main.buddy
	buddy.set_profile(SUPERHUMAN)
	await ticks(2) # Let the physics world take in the new boxes.


func test_toss_button_braces_you_at_a_wall() -> void:
	# Facing the wall, right up to it: you turn round and put your back to it.
	buddy.global_position = Vector3(20, FLOOR_Y + 0.05, 20) # Out of reach.
	await place(Vector3(0, FLOOR_Y + 0.05, WALL_FACE_Z + 0.9), FACE_NORTH)
	await press_event(&"toss")
	expect_state(&"Brace")
	expect_near(player.global_position.z, WALL_FACE_Z + player.body_radius + 0.05, 0.05, "back against the wall")
	expect(player.facing_direction().dot(Vector3.BACK) > 0.9, "facing away from it, facing %s" % player.facing_direction())
	await press_event(&"toss")
	expect_state(&"Ground")
	# Out in the open, there's nothing to brace against.
	await place(Vector3(0, FLOOR_Y + 0.05, 0), FACE_NORTH)
	await press_event(&"toss")
	expect_state(&"Ground")


func test_buddy_braces_when_called_looking_at_a_wall() -> void:
	await place(Vector3(0, FLOOR_Y + 0.05, WALL_FACE_Z + 6.0), FACE_NORTH)
	main.call_buddy()
	await ticks(10)
	expect_state_of(buddy, &"Brace")
	expect_near(buddy.global_position.z, WALL_FACE_Z + buddy.body_radius + 0.05, 0.1, "the buddy at the foot of the wall")
	expect(buddy.facing_direction().dot(Vector3.BACK) > 0.9, "facing you")


func test_too_tall_alone() -> void:
	buddy.global_position = Vector3(20, FLOOR_Y + 0.05, 20) # Out of the way.
	expect(not await _run_and_jump_at(0.0), "11 m should be too tall alone, went through %s" % [states_entered])


func test_a_leg_up_gets_you_up_a_wall_too_tall_alone() -> void:
	await _brace(buddy, 0.0)
	expect(await _run_and_jump_at(0.0), "a leg-up should get you up 11 m, went through %s" % [states_entered])
	expect(&"LegUp" in states_entered and &"WallScramble" in states_entered, "stepping into their hands, then scrambling: %s" % [states_entered])


func test_jumping_into_a_braced_friend_from_further_out() -> void:
	# Taking off well before them, you land in their hands on the way.
	await _brace(buddy, 0.0)
	expect(await _run_and_jump_at(0.0, 3.5), "jumping into them should work too, went through %s" % [states_entered])


func test_free_running_into_a_braced_friend() -> void:
	await _brace(buddy, 0.0)
	await place(Vector3(0, FLOOR_Y + 0.05, WALL_FACE_Z + 15.0), FACE_NORTH)
	states_entered.clear()
	Input.action_press(&"free_run")
	expect(await _until_on_top(), "free-run should take the leg-up for you, went through %s" % [states_entered])


func test_walking_past_or_away_isnt_a_leg_up() -> void:
	await _brace(buddy, 0.0)
	# Walking along the wall right past them...
	await place(Vector3(-3, FLOOR_Y + 0.05, WALL_FACE_Z + 1.2), FACE_WEST + PI)
	Input.action_press(&"move_forward")
	await ticks(40)
	release_all()
	# ...and jumping away from the wall beside them.
	await place(Vector3(0.5, FLOOR_Y + 0.05, WALL_FACE_Z + 1.2), PI)
	Input.action_press(&"move_forward")
	await tap(&"jump")
	await ticks(30)
	release_all()
	expect(not &"LegUp" in states_entered, "no leg-up unless you head for the wall, went through %s" % [states_entered])


func test_a_taller_wall_needs_a_friend_on_their_shoulders() -> void:
	await _brace(buddy, TWO_FRIEND_X)
	expect(not await _run_and_jump_at(TWO_FRIEND_X), "one friend braced shouldn't be enough for 12.5 m, went through %s" % [states_entered])
	# A second friend climbs onto the buddy's shoulders (pressing toss beside them).
	var second := _another_friend("Buddy2")
	await _brace(second, TWO_FRIEND_X + 0.8)
	expect(second.state.name == &"Brace" and second.sync_braced_on == "Buddy", "the second friend should be on the buddy's shoulders, is in %s on %s" % [second.state.name, second.sync_braced_on])
	expect_near(second.global_position.y, buddy.global_position.y + Player.BRACE_SHOULDERS, 0.1, "standing on their shoulders")
	expect(await _run_and_jump_at(TWO_FRIEND_X), "two of them should get you up 12.5 m, went through %s" % [states_entered])


func test_climbing_onto_a_braced_friend_yourself() -> void:
	await _brace(buddy, 0.0)
	await place(Vector3(0.8, FLOOR_Y + 0.05, WALL_FACE_Z + 1.5), FACE_NORTH)
	await press_event(&"toss")
	await ticks(20)
	expect(player.state.name == &"Brace" and player.sync_braced_on == "Buddy", "on the buddy's shoulders, in %s on %s" % [player.state.name, player.sync_braced_on])
	expect_near(player.global_position.y, buddy.global_position.y + Player.BRACE_SHOULDERS, 0.1, "your feet on their shoulders")
	# When they stop bracing, you drop.
	buddy.state.let_go()
	await ticks(5)
	expect(player.state.name != &"Brace", "you should drop when the friend under you stops bracing, in %s" % player.state.name)


func test_the_stack_has_a_limit() -> void:
	await _brace(buddy, 0.0)
	for i in Player.MOST_BRACED - 1:
		await _brace(_another_friend("Buddy%d" % (i + 2)), 0.8)
	var extra := _another_friend("Extra")
	await _brace(extra, 0.8)
	expect(buddy.brace_stack().size() == Player.MOST_BRACED, "a stack of %d, is %d" % [Player.MOST_BRACED, buddy.brace_stack().size()])
	expect(extra.state.name != &"Brace", "nobody more on top, %s is in %s" % [extra.name, extra.state.name])


# --- Helpers ---------------------------------------------------------------------

## Has `who` (a bot) press toss standing `x` along the wall's foot: braces
## there, or climbs onto the shoulders of a friend braced nearby.
func _brace(who: Player, x: float) -> void:
	who.global_position = Vector3(x, FLOOR_Y + 0.05, WALL_FACE_Z + 0.9)
	who.velocity = Vector3.ZERO
	who.reset_physics_interpolation()
	who.change_state(&"Air")
	await ticks(10)
	who.try_brace()
	await ticks(20)


func _another_friend(friend_name: String) -> Player:
	var friend := main.PLAYER_SCENE.instantiate() as Player
	friend.name = friend_name
	friend.is_bot = true
	main.players.add_child(friend)
	friend.set_profile(SUPERHUMAN)
	return friend


## Runs north at the wall `x` along and presses jump `jump_from` metres out
## from it, pushing on. True if you end up on top.
func _run_and_jump_at(x: float, jump_from := 1.8) -> bool:
	await place(Vector3(x, FLOOR_Y + 0.05, WALL_FACE_Z + 12.0), FACE_NORTH)
	states_entered.clear()
	Input.action_press(&"move_forward")
	for i in 120:
		await ticks(1)
		if player.global_position.z < WALL_FACE_Z + jump_from:
			Input.action_press(&"jump")
			break
	return await _until_on_top()


## Keeps pushing (pulling up from any hang) for a while; true if you end up on top.
func _until_on_top() -> bool:
	var on_top := false
	for i in 60 * 4:
		await ticks(1)
		if player.state.name == &"Hang":
			# Pull up: a fresh press of jump.
			if Input.is_action_pressed(&"jump"):
				Input.action_release(&"jump")
			else:
				Input.action_press(&"jump")
		if player.is_on_floor() and player.global_position.y > FLOOR_Y + 5.0:
			on_top = true
			break
	release_all()
	return on_top


func expect_state_of(who: Player, expected: StringName) -> void:
	expect(who.state.name == expected, "%s should be in %s, is in %s at %s" % [who.name, expected, who.state.name, who.global_position])


func _box(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	body.add_child(shape)
	main.level.add_child(body)
	body.global_position = at
