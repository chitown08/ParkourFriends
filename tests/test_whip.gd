extends GameTest
## Crack the whip: free-running in a pack, the toss button takes a friend's
## hand (a line); the leader turns hard their own way and the line swings round
## them, flinging the one on the end. Runs on a big flat floor added high
## above the test course, with the practice buddy as a ghost runner.

const FLOOR_Y := 200.0
const FACE_EAST := -PI / 2

var buddy: Player


func before_each() -> void:
	await super()
	player.set_profile(SUPERHUMAN)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(400, 1, 400)
	floor_body.add_child(shape)
	main.level.add_child(floor_body)
	floor_body.global_position = Vector3(0, FLOOR_Y - 0.5, 0)
	await place(Vector3(0, FLOOR_Y + 0.05, 0), FACE_NORTH)
	buddy = _ghost(Vector3(-3, 0, 0))


func test_the_toss_button_in_a_pack_takes_a_friends_hand() -> void:
	Input.action_press(&"free_run")
	await ticks(60)
	await tap(&"toss")
	expect(buddy.state.name == &"Linked", "the buddy should take your hand, it's %s" % buddy.state.name)
	expect(buddy.sync_linked_to == str(player.name), "...yours")
	await ticks(60)
	release_all()
	var beside := buddy.global_position - player.global_position
	expect_near(Vector2(beside.x, beside.z).length(), Player.LINK_SPACING, 0.3, "running beside you, hand in hand")
	expect(beside.x < 0.0, "on the side it was on (your left)")
	expect(Array(player.line()) == [player, buddy], "a line of two, you leading")


func test_holding_hands_keeps_the_music_big() -> void:
	# Hand in hand is as together as it gets: the song stays swollen.
	main._play_layered("res://audio/music/rooftop_test/")
	await _line_up()
	await ticks(180)
	release_all()
	expect(buddy.state.name == &"Linked", "test setup: still hand in hand")
	expect(player.together_size() == 1, "moving together with one friend, %d" % player.together_size())
	expect(main.layered != null and main.layered.volume("pack1") > 0.9, "the synth stays in: %.2f" % (main.layered.volume("pack1") if main.layered else -1.0))


func test_no_hand_to_take_out_of_a_pack() -> void:
	await tap(&"toss") # Standing still: no pack.
	expect(buddy.state.name != &"Linked", "standing about, the toss button doesn't take a hand")


func test_a_friend_running_by_doesnt_take_your_hand_unless_you_run_too() -> void:
	# The buddy goes by free-running; you stand still: the toss button tosses it.
	await ticks(20) # (It lands.)
	buddy.ghost_of = null
	buddy.set_physics_process(false)
	buddy.sync_free_run_velocity = Vector3(0, 0, -10)
	buddy.global_position = player.global_position + Vector3(0, 0, -1.5)
	await tap(&"toss")
	buddy.set_physics_process(true)
	expect(buddy.state.name != &"Linked", "you're not running with it: no hand to take")
	expect(buddy.velocity.y > 5.0, "so you toss it instead, vy = %.1f" % buddy.velocity.y)


func test_turning_hard_your_way_cracks_the_whip() -> void:
	await _line_up()
	var speed := buddy.get_horizontal_speed()
	player.camera_rig.yaw = FACE_EAST # Hard right: away from the buddy, on your left.
	await ticks(1)
	expect_state(&"Whip")
	var flung := await _until_let_go(buddy)
	release_all()
	expect(flung, "the buddy should be let go after the swing")
	expect(buddy.global_position.z < player.global_position.z - 0.5, "it swings round in front of you (not behind), let go at %s" % (buddy.global_position - player.global_position))
	expect(buddy.state.name == &"Air" and buddy.velocity.y > 0.0, "flung off into the air, it's %s" % buddy.state.name)
	var going := Vector3(buddy.velocity.x, 0.0, buddy.velocity.z)
	expect(going.normalized().dot(Vector3.RIGHT) > 0.95, "the way you turned (east), going %s" % going)
	expect_near(going.length(), speed * Player.whip_boost(1), 0.5, "30%% faster than it ran (%.1f m/s)" % speed)
	expect(going.length() > speed * 1.25, "faster than it ran, %.1f m/s (from %.1f)" % [going.length(), speed])


func test_turning_toward_the_line_does_not_crack_it() -> void:
	await _line_up()
	player.camera_rig.yaw = -FACE_EAST # Hard left: into the buddy.
	await ticks(20)
	release_all()
	expect(player.state.name != &"Whip", "turning toward your line just turns it")
	expect(buddy.state.name == &"Linked", "and the buddy still holds your hand")


func test_a_gentle_turn_does_not_crack_it() -> void:
	await _line_up()
	player.camera_rig.yaw = FACE_EAST / 3.0 # 30 degrees right.
	await ticks(30)
	release_all()
	expect(player.state.name != &"Whip" and buddy.state.name == &"Linked", "a gentle turn: still in line")


func test_a_longer_line_flings_harder() -> void:
	var friend := _ghost(Vector3(-6, 0, 0), "Friend")
	await _line_up()
	await tap(&"toss") # A second friend joins the end of the line.
	expect(friend.state.name == &"Linked" and friend.sync_linked_to == str(buddy.name), "the friend should take the buddy's hand")
	await ticks(60)
	expect(Array(player.line()) == [player, buddy, friend], "a line of three")
	var speed := friend.get_horizontal_speed()
	player.camera_rig.yaw = FACE_EAST
	await _until_let_go(friend)
	release_all()
	expect(friend.state.name == &"Air", "the end of the line is flung off, it's %s" % friend.state.name)
	expect(buddy.state.name != &"Air", "the one in the middle is just let go, it's %s" % buddy.state.name)
	expect_near(friend.get_horizontal_speed(), speed * Player.whip_boost(2), 0.6, "two places out: 60%% faster (%.1f m/s)" % speed)


func test_the_line_lets_go_when_snagged() -> void:
	await _line_up()
	buddy.global_position += Vector3(0, 0, 5) # Held back by something.
	await ticks(2)
	release_all()
	expect(buddy.state.name != &"Linked", "pulled away from your side, the buddy lets go")


func test_a_fling_goes_as_far_as_the_checker_says() -> void:
	# A line of three at full flow: the end one is let go at the speed the
	# checker uses, and flies as far as it says (a touch short: it peaks a
	# little lower; well inside the room every jump gets, ReachMap.JUMP_MARGIN).
	var friend := _ghost(Vector3(-6, 0, 0), "Friend")
	for who: Player in [player, buddy, friend]:
		who.debug_full_flow = true
	await _line_up()
	await tap(&"toss")
	await ticks(60)
	player.camera_rig.yaw = FACE_EAST
	await _until_let_go(friend)
	var let_go_at := friend.global_position
	var speed := friend.get_horizontal_speed()
	for i in 120:
		await ticks(1)
		if friend.is_on_floor():
			break
	release_all()
	var map := ReachMap.build(main.level, SUPERHUMAN)
	expect_near(speed, SUPERHUMAN.flow_speed * Player.whip_boost(2), 0.3, "let go at")
	var flew := Vector2(friend.global_position.x - let_go_at.x, friend.global_position.z - let_go_at.z).length()
	var expected := map.air_distance(SUPERHUMAN.leap_height, SUPERHUMAN.flow_speed * Player.whip_boost(2), 0.0)
	expect(flew >= expected - 0.5 and flew <= expected + 1.0, "flung %.2f m, the checker says %.2f" % [flew, expected])


func test_a_friend_in_a_line_cant_be_tossed() -> void:
	await _line_up()
	expect(player.find_toss_target() == null, "holding hands: not one to toss")
	release_all()


## Free-runs north with the buddy and has it take your hand; returns with
## free-run still held.
func _line_up() -> void:
	Input.action_press(&"free_run")
	await ticks(60)
	await tap(&"toss")
	expect(buddy.state.name == &"Linked", "test setup: the buddy takes your hand")
	await ticks(60)


## Waits (up to a second) until `who` is let go by the whip; true if they were.
func _until_let_go(who: Player) -> bool:
	var swung := false
	for i in 60:
		await ticks(1)
		if who.state.name == &"Whipped":
			swung = true
		elif swung:
			return true
	return false


## A practice friend `offset` from you that ghost-runs with you, steadily.
func _ghost(offset: Vector3, friend_name := "") -> Player:
	var ghost: Player
	if friend_name == "":
		main.call_buddy()
		ghost = main.buddy
	else:
		ghost = main.PLAYER_SCENE.instantiate() as Player
		ghost.name = friend_name
		ghost.is_bot = true
		main.players.add_child(ghost)
	ghost.set_profile(SUPERHUMAN)
	ghost.ghost_of = player
	ghost.ghost_wander_degrees = 0.0
	ghost.global_position = player.global_position + offset
	ghost.velocity = Vector3.ZERO
	ghost.reset_physics_interpolation()
	return ghost
