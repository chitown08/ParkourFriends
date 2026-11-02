extends GameTest
## The hanging chain (player/states/chain_hang.gd, chain_climb.gd): lower
## yourself over an edge, friends hang from each other's feet, the bottom one
## climbs the chain, everyone moves up after. The practice buddy plays the
## friend. On a 10 m wall built over a floor high above the test course: too
## tall for a plain jump and scramble alone (a well-timed readied leap just
## makes it: see test_reach.gd), in reach with one friend hanging from the top.

const FLOOR_Y := 200.0
const WALL_HEIGHT := 10.0
const WALL_FACE_Z := -20.0 ## Its face looks south (+Z); you climb it heading north.

var buddy: Player
var states_entered: Array[StringName] = []


func before_each() -> void:
	await super()
	player.set_profile(SUPERHUMAN)
	player.state_changed.connect(func(new_state: StringName) -> void: states_entered.append(new_state))
	_box(Vector3(0, FLOOR_Y - 0.5, 0), Vector3(400, 1, 400))
	_box(Vector3(0, FLOOR_Y + WALL_HEIGHT / 2.0, WALL_FACE_Z - 10.0), Vector3(30, WALL_HEIGHT, 20))
	main.call_buddy()
	buddy = main.buddy
	buddy.set_profile(SUPERHUMAN)
	await ticks(2) # Let the physics world take in the new boxes.


func test_lower_yourself_over_an_edge() -> void:
	await place(Vector3(0, FLOOR_Y + WALL_HEIGHT + 0.05, WALL_FACE_Z - 2.0), PI) # On top, facing the edge.
	Input.action_press(&"crouch")
	Input.action_press(&"move_forward")
	for i in 120:
		await ticks(1)
		if player.state.name == &"Hang":
			break
	release_all()
	await ticks(20)
	expect_state(&"Hang")
	expect_near(player.global_position.y, FLOOR_Y + WALL_HEIGHT - player.hang_height, 0.1, "hanging from the edge you crouched off")
	expect(player.facing_direction().dot(Vector3.FORWARD) > 0.9, "facing back toward the wall, facing %s" % player.facing_direction())


func test_lower_yourself_down_a_friend_to_lengthen_the_chain() -> void:
	await _hang_at_top(buddy, 0.0)
	await place(Vector3(0, FLOOR_Y + WALL_HEIGHT + 0.05, WALL_FACE_Z - 2.0), PI) # On top, above them.
	Input.action_press(&"crouch")
	Input.action_press(&"move_forward")
	for i in 120:
		await ticks(1)
		if player.state.name == &"ChainHang":
			break
	release_all()
	await ticks(30)
	expect(player.state.name == &"ChainHang" and player.sync_hanging_on == "Buddy", "you should climb down your friend and hang from their feet, %s on %s" % [player.state.name, player.sync_hanging_on])
	expect_near(player.global_position.y, buddy.global_position.y - player.hang_height, 0.1, "below them")


func test_too_tall_for_a_plain_scramble_alone() -> void:
	buddy.global_position = Vector3(20, FLOOR_Y + 0.05, 0) # Out of the way.
	await _run_and_scramble()
	expect(player.global_position.y < FLOOR_Y + 1.0, "with a plain jump and scramble, the 10 m wall should be out of reach alone, at %s" % player.global_position)


func test_scramble_up_to_a_hanging_friend_and_climb_the_chain() -> void:
	await _hang_at_top(buddy, 0.0)
	await _run_and_scramble()
	expect(&"ChainHang" in states_entered, "you should grab your friend's feet, went through %s" % [states_entered])
	await tap(&"jump") # Climb up them.
	for i in 90:
		await ticks(1)
		if player.is_on_floor():
			break
	expect(&"ChainClimb" in states_entered, "and climb up them, went through %s" % [states_entered])
	expect(player.is_on_floor() and player.global_position.y > FLOOR_Y + WALL_HEIGHT - 0.1, "onto the top, at %s in %s" % [player.global_position, player.state.name])
	expect_state_of(buddy, &"Hang")


func test_free_run_climbs_the_chain_for_you() -> void:
	await _hang_at_top(buddy, 0.0)
	await place(Vector3(0, FLOOR_Y + 0.05, WALL_FACE_Z + 12.0), FACE_NORTH)
	Input.action_press(&"free_run")
	for i in 60 * 4:
		await ticks(1)
		if player.is_on_floor() and player.global_position.y > FLOOR_Y + WALL_HEIGHT - 0.1:
			break
	release_all()
	expect(player.global_position.y > FLOOR_Y + WALL_HEIGHT - 0.1, "free-run should scramble, grab your friend and climb, at %s via %s" % [player.global_position, states_entered])


func test_everyone_moves_up_when_the_top_one_pulls_up() -> void:
	await _hang_at_top(player, 0.0)
	buddy.global_position = player.global_position + Vector3.DOWN * 2.0
	buddy.change_state(&"ChainHang", {"anchor": player, "toward_wall": Vector3.FORWARD})
	await ticks(30)
	expect_near(buddy.global_position.y, player.global_position.y - buddy.hang_height, 0.05, "your friend hangs with their hands at your feet")
	await tap(&"jump") # Pull yourself up.
	await ticks(60)
	expect(player.is_on_floor() and player.global_position.y > FLOOR_Y + WALL_HEIGHT - 0.1, "you're up, at %s" % player.global_position)
	expect_state_of(buddy, &"Hang")
	expect_near(buddy.global_position.y, FLOOR_Y + WALL_HEIGHT - buddy.hang_height, 0.1, "your friend has moved up into your place on the edge")


func test_let_go_and_the_chain_drops() -> void:
	await _hang_at_top(player, 0.0)
	buddy.global_position = player.global_position + Vector3.DOWN * 2.0
	buddy.change_state(&"ChainHang", {"anchor": player, "toward_wall": Vector3.FORWARD})
	await ticks(20)
	await tap(&"crouch")
	await ticks(5)
	expect_state_of(buddy, &"Air")


func test_the_chain_follows_the_top_one_along_the_edge() -> void:
	await _hang_at_top(player, 0.0)
	buddy.global_position = player.global_position + Vector3.DOWN * 2.0
	buddy.change_state(&"ChainHang", {"anchor": player, "toward_wall": Vector3.FORWARD})
	await hold(&"move_right", 60) # Shimmy east.
	await ticks(20)
	expect(player.global_position.x > 1.5, "you should shimmy along, at %s" % player.global_position)
	expect_near(buddy.global_position.x, player.global_position.x, 0.1, "your friend comes with you")


func test_a_taller_wall_needs_a_longer_chain() -> void:
	# 11.5 m, east of the 10 m wall: one friend hanging isn't enough...
	_box(Vector3(40, FLOOR_Y + 5.75, WALL_FACE_Z - 10.0), Vector3(20, 11.5, 20))
	await ticks(2)
	await _hang_at_top(buddy, 40.0, 11.5)
	await _run_and_scramble(40.0)
	expect(not &"ChainHang" in states_entered, "one friend shouldn't be enough for 11.5 m, went through %s" % [states_entered])
	# ...but a second friend hanging from the first is.
	var second := main.PLAYER_SCENE.instantiate() as Player
	second.name = "Buddy2"
	second.is_bot = true
	main.players.add_child(second)
	second.set_profile(SUPERHUMAN)
	second.global_position = buddy.global_position + Vector3.DOWN * 2.0
	second.change_state(&"ChainHang", {"anchor": buddy, "toward_wall": Vector3.FORWARD})
	await ticks(20)
	await _run_and_scramble(40.0)
	expect(&"ChainHang" in states_entered and player.sync_hanging_on == "Buddy2", "you should grab the second friend's feet, went through %s" % [states_entered])
	await tap(&"jump")
	for i in 120:
		await ticks(1)
		if player.is_on_floor():
			break
	expect(player.is_on_floor() and player.global_position.y > FLOOR_Y + 11.5 - 0.1, "and climb both of them onto the top, at %s in %s" % [player.global_position, player.state.name])
	expect_state_of(second, &"ChainHang")


func test_one_friend_per_pair_of_feet() -> void:
	await _hang_at_top(player, 0.0)
	buddy.global_position = player.global_position + Vector3.DOWN * 2.0
	buddy.change_state(&"ChainHang", {"anchor": player, "toward_wall": Vector3.FORWARD})
	await ticks(20)
	# A third friend drops with their hands right at your feet: already taken.
	var third := main.PLAYER_SCENE.instantiate() as Player
	third.name = "Buddy2"
	third.is_bot = true
	main.players.add_child(third)
	third.global_position = player.global_position + Vector3.DOWN * third.hang_height + Vector3.BACK * 0.3
	third.velocity = Vector3.ZERO
	third.change_state(&"Air")
	await ticks(10)
	expect(third.sync_hanging_on != str(player.name), "someone already hangs from your feet: nobody else can")


## Puts `who` hanging from the top edge of the wall (`height` tall), `x` along it.
func _hang_at_top(who: Player, x: float, height := WALL_HEIGHT) -> void:
	var feet := Vector3(x, FLOOR_Y + height - who.hang_height, WALL_FACE_Z + who.body_radius + 0.05)
	who.global_position = feet
	who.velocity = Vector3.ZERO
	who.reset_physics_interpolation()
	var ledge := who.find_ledge(feet, Vector3.FORWARD)
	expect(ledge != null, "%s should find the wall's top edge" % who.name)
	who.change_state(&"Hang", {"ledge": ledge})
	await ticks(10)


## Runs north at the wall and jumps into it (a scramble), pushing on for a while.
func _run_and_scramble(x := 0.0) -> void:
	await place(Vector3(x, FLOOR_Y + 0.05, WALL_FACE_Z + 10.0), FACE_NORTH)
	states_entered.clear()
	Input.action_press(&"move_forward")
	for i in 90:
		await ticks(1)
		if player.global_position.z < WALL_FACE_Z + 2.5:
			Input.action_press(&"jump")
		if player.state.name == &"ChainHang":
			break
	await ticks(60)
	release_all()
	await ticks(30)


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
