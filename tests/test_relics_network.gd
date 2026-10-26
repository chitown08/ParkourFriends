extends MultiplayerTest
## Relics are shared by the team: whoever delivers one, it counts for everyone,
## and players who join later are told what's already been delivered.

const PILLAR_TOP := Vector3(10.5, 5.05, -72) ## Standing under RelicPillarTop.
const DROP_OFF := Vector3(-7, 0.05, 0)


func _init() -> void:
	world_id = "free_run_line"


func before_each() -> void:
	await super()
	host_main.local_player.set_controls_enabled(false)


func test_client_delivers_a_relic_for_everyone() -> void:
	await _move(client_main.local_player, PILLAR_TOP)
	await ticks(10)
	var client_id := str(client_main.local_player.name)
	expect(_relic(host_main).holder_name == client_id, "test setup: the client picked up the relic by touch")
	await _move(client_main.local_player, DROP_OFF)
	await ticks(10)
	for side_main: Node in [host_main, client_main]:
		var who := "host" if side_main == host_main else "client"
		expect(side_main.delivered_relics.has("RelicPillarTop"), "%s should know the relic was delivered" % who)
		expect(not _relic(side_main).visible, "%s should no longer see the relic" % who)


func test_host_delivers_a_relic_for_everyone() -> void:
	await _move(host_main.local_player, PILLAR_TOP)
	await _move(host_main.local_player, DROP_OFF)
	await ticks(10)
	expect(client_main.delivered_relics.has("RelicPillarTop"), "the client should be told about the host's delivery")


func test_late_joiner_is_told_what_was_delivered() -> void:
	await _move(host_main.local_player, PILLAR_TOP)
	await _move(host_main.local_player, DROP_OFF)
	# The client leaves and joins again: it should catch up on the delivery.
	client_main.leave_game()
	await ticks(30)
	client_main.start_join("127.0.0.1", TEST_PORT)
	for i in 300:
		await ticks(1)
		if client_main.level != null and client_main.local_player != null:
			break
	await ticks(10)
	expect(client_main.delivered_relics.has("RelicPillarTop"), "a player joining later should know what's already delivered")
	if client_main.level:
		expect(not _relic(client_main).visible, "and not see the delivered relic")


func _relic(side_main: Node) -> WorldItem:
	return side_main.level.get_node("Relics/RelicPillarTop")


func _move(who: Player, spot: Vector3) -> void:
	who.global_position = spot
	who.velocity = Vector3.ZERO
	who.reset_physics_interpolation()
	await ticks(10)
