extends MultiplayerTest
## Real tosses between two connected players. The client does the tossing
## (pressing E); the host is the one being tossed, so the launch has to travel
## over the network to the host's computer to happen.

const SPOT := Vector3(-15, 0.05, 20) ## An open area of the Toss Yard.

var host_player: Player
var client_player: Player


func before_each() -> void:
	await super()
	host_player = host_main.local_player
	client_player = client_main.local_player
	host_player.set_controls_enabled(false) # Buttons are shared; only the client acts.


func test_toss_launches_the_friend() -> void:
	await _line_up(1.2, 0.0)
	var tossed_events := []
	client_player.tossed_someone.connect(func(target: Player) -> void: tossed_events.append(target.name))
	await tap(&"toss")
	await ticks(5)
	expect(tossed_events == [&"1"], "client should toss the host, events: %s" % [tossed_events])
	expect_state_of(host_player, &"Air")
	expect(host_player.velocity.y > 5.0, "host should fly upward, vy = %.2f" % host_player.velocity.y)
	await ticks(20)
	var puppet := _find(client_main, 1)
	expect(puppet.global_position.y > 2.0, "client should see the host in the air, y = %.2f" % puppet.global_position.y)


func test_toss_flies_the_way_the_camera_faces() -> void:
	await _line_up(1.2, 0.0)
	client_player.camera_rig.yaw = PI / 2 # Look toward -X, friend is still within reach.
	await tap(&"toss")
	await ticks(10)
	expect(host_player.velocity.x < -3.0 and absf(host_player.velocity.z) < 1.0,
			"host should fly toward -X, velocity %s" % host_player.velocity)


func test_friend_out_of_reach_is_not_tossed() -> void:
	await _line_up(3.5, 0.0)
	await tap(&"toss")
	await ticks(10)
	expect_state_of(host_player, &"Ground")


func test_friend_behind_you_is_not_tossed() -> void:
	await _line_up(1.2, PI) # Camera faces away from the friend.
	await tap(&"toss")
	await ticks(10)
	expect_state_of(host_player, &"Ground")


func test_midair_toss_gives_the_thrower_a_hop() -> void:
	await _line_up(1.2, 0.0)
	await tap(&"jump")
	await ticks(20) # Past the top of the jump, starting to fall.
	expect(client_player.velocity.y < 0.0, "test setup: client should be falling")
	await tap(&"toss")
	expect(client_player.velocity.y > 3.0, "thrower should get a hop, vy = %.2f" % client_player.velocity.y)
	await ticks(5)
	expect(host_player.velocity.y > 5.0, "host should be launched too, vy = %.2f" % host_player.velocity.y)


func test_thrower_can_only_toss_once_per_air_time() -> void:
	client_player.toss_cooldown = 0.0 # So only the once-per-air rule can block the second toss.
	await _line_up(1.2, 0.0)
	Input.action_press(&"jump")
	await ticks(3)
	await tap(&"toss") # First mid-air toss: allowed.
	var launched := await _host_launched()
	expect(launched, "test setup: first toss should work")
	await ticks(5)
	# Bring the host back next to the (still airborne) client and make them
	# tossable again, so only the thrower's limit is being tested.
	host_player.refresh_air_moves()
	host_player.global_position = client_player.global_position + Vector3(0, 0, -1.2)
	host_player.velocity = Vector3.ZERO
	host_player.reset_physics_interpolation()
	await ticks(10)
	expect_state_of(client_player, &"Air")
	await tap(&"toss")
	var fastest_rise := 0.0
	for i in 10:
		await ticks(1)
		fastest_rise = maxf(fastest_rise, host_player.velocity.y)
	expect(fastest_rise < 5.0, "second toss in the same air time should do nothing, host rose at %.2f m/s" % fastest_rise)


func test_two_player_chain_toss_and_toss_back() -> void:
	# The client tosses the host; the airborne host tosses the client back (a
	# two-link chain); then the client can't toss the host a second time.
	await _line_up(1.2, 0.0)
	await tap(&"toss")
	var launched := await _host_launched()
	expect(launched, "test setup: the client's toss should launch the host")
	await ticks(5)
	# Bring the client up beside the flying host, then the host tosses them.
	client_player.global_position = host_player.global_position + Vector3(0, 0, -1.2)
	client_player.velocity = Vector3.ZERO
	client_player.reset_physics_interpolation()
	await ticks(10)
	host_player.camera_rig.yaw = 0.0
	expect(host_player.try_toss(), "the airborne host should be able to toss the client back")
	await ticks(5)
	expect(client_player.velocity.y > 5.0, "the client should be launched, vy = %.2f" % client_player.velocity.y)
	expect(host_player.sync_tossed_by.has(client_player.name), "the host remembers being tossed by the client")


func test_cannot_toss_someone_already_tossed_this_air_time() -> void:
	await _line_up(1.2, 0.0)
	await tap(&"toss")
	await ticks(15)
	# Pull the flying host back down next to the client, still in the air.
	host_player.global_position = SPOT + Vector3(0, 1.0, -1.2)
	host_player.velocity = Vector3.ZERO
	host_player.reset_physics_interpolation()
	await ticks(10) # Toss cooldown passes; client's view catches up.
	await tap(&"toss")
	await ticks(5)
	expect(host_player.velocity.y < 5.0, "host shouldn't be tossed twice in one air time, vy = %.2f" % host_player.velocity.y)


func _host_launched() -> bool:
	for i in 10:
		await ticks(1)
		if host_player.velocity.y > 5.0:
			return true
	return false


func expect_state_of(who: Player, expected: StringName) -> void:
	expect(who.state.name == expected, "%s: expected state %s, got %s" % [who.name, expected, who.state.name])


## Stands the client at SPOT with the camera at `client_yaw`, and the host
## `distance` m in front (toward -Z). Waits for both screens to agree.
func _line_up(distance: float, client_yaw: float) -> void:
	host_player.global_position = SPOT + Vector3(0, 0, -distance)
	client_player.global_position = SPOT
	for who: Player in [host_player, client_player]:
		who.velocity = Vector3.ZERO
		who.reset_physics_interpolation()
	client_player.camera_rig.yaw = client_yaw
	await ticks(30)
