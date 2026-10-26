extends GameTest
## The glider, on the Free-Run Line: it sits on the leap tower's roof (top
## y = 1, x = -4..4, z = -540..-550). An island 28 m east and 7 m down
## (x = 32..48, top -6) can only be reached by gliding.

const ROOF := Vector3(0, 1.05, -545)
const ISLAND_TOP := -6.0
const ISLAND_WEST_EDGE := 32.0

var glider: WorldItem


func before_each() -> void:
	main = MAIN_SCENE.instantiate()
	add_child(main)
	main.start_solo("free_run_line")
	await ticks(5)
	player = main.get_node_or_null("Players/1")
	expect(player != null, "the game should have created a player")
	if player:
		player.set_profile(SUPERHUMAN)
	glider = main.level.get_node("Items/Glider")


func test_holding_use_in_the_air_glides() -> void:
	glider.host_give_to(player)
	await _jump_east_off_the_roof()
	await ticks(60)
	expect_state(&"Glide")
	expect_near(player.velocity.y, -3.0, 0.2, "sink speed while gliding")


func test_gliding_reaches_the_island() -> void:
	glider.host_give_to(player)
	await _jump_east_off_the_roof()
	# Glide until over the island, then let go and drop onto it.
	for i in 60 * 6:
		await ticks(1)
		if player.global_position.x > ISLAND_WEST_EDGE + 4.0:
			break
	Input.action_release(&"use_item")
	expect(await _wait_for_ground(120), "should land")
	expect(player.global_position.x > ISLAND_WEST_EDGE and absf(player.global_position.y - ISLAND_TOP) < 0.2,
			"should land on the island, at %s" % player.global_position)


func test_a_plain_jump_falls_short_of_the_island() -> void:
	player.flow = 1.0
	await _jump_east_off_the_roof()
	await ticks(50) # (Any longer and you've fallen off the world and respawned.)
	expect(player.global_position.y < ISLAND_TOP - 1.0, "without a glider you should fall short, at %s" % player.global_position)


func test_letting_go_drops_you() -> void:
	glider.host_give_to(player)
	await _jump_east_off_the_roof()
	await ticks(60)
	Input.action_release(&"use_item")
	await ticks(20)
	expect_state(&"Air")
	expect(player.velocity.y < -8.0, "you should fall fast again, vy = %.1f" % player.velocity.y)


func test_gliders_turn_slowly() -> void:
	glider.host_give_to(player)
	await _jump_east_off_the_roof()
	await ticks(30)
	player.camera_rig.yaw = FACE_NORTH # Steer hard left (north).
	await ticks(60)
	var heading := Vector3(player.velocity.x, 0, player.velocity.z).normalized()
	var turned := rad_to_deg(Vector3.RIGHT.angle_to(heading))
	expect(turned > 30.0 and turned < 60.0, "about 50 degrees of turn in a second, turned %.0f" % turned)


func test_no_gliding_with_the_glider_in_your_backpack() -> void:
	main.level.get_node("Items/Backpack").host_give_to(player)
	glider.host_give_to(player)
	await tap(&"switch_item")
	expect(player.items.back_item() == glider, "test setup: glider in the backpack")
	await _jump_east_off_the_roof()
	await ticks(40)
	expect_state(&"Air")


func test_no_gliding_on_the_ground() -> void:
	glider.host_give_to(player)
	await place(ROOF, FACE_NORTH)
	await hold(&"use_item", 30)
	expect_state(&"Ground")


## From the middle of the roof, run east holding "use item" and jump off the
## edge. Leaves forward and "use item" held.
func _jump_east_off_the_roof() -> void:
	await place(ROOF, yaw_for(Vector3.RIGHT))
	Input.action_press(&"move_forward")
	Input.action_press(&"use_item")
	for i in 60:
		await ticks(1)
		if player.global_position.x > 3.0:
			break
	await tap(&"jump")


func _wait_for_ground(max_ticks: int) -> bool:
	for i in max_ticks:
		await ticks(1)
		if player.state.name == &"Ground":
			return true
	return false
