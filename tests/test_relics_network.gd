extends MultiplayerTest
## Relics are shared by the team: whoever finds one, it counts for everyone,
## and players who join later are told what's already been found.

const PLAZA_RELIC := Vector3(11, 0.35, 20) ## Standing spot for RelicPlaza.
const STREET_RELIC := Vector3(-36, 0.05, 70) ## Standing spot for RelicWestStreet.


func _init() -> void:
	world_id = "old_town"


func before_each() -> void:
	await super()
	host_main.local_player.set_controls_enabled(false)


func test_client_finds_a_relic_for_everyone() -> void:
	await _move(client_main.local_player, PLAZA_RELIC)
	await ticks(10)
	for side_main: Node in [host_main, client_main]:
		var who := "host" if side_main == host_main else "client"
		expect(side_main.collected_relics.has("RelicPlaza"), "%s should know the relic was found" % who)
		expect(not side_main.level.get_node("Relics/RelicPlaza").visible, "%s should no longer see the relic" % who)


func test_host_finds_a_relic_for_everyone() -> void:
	await _move(host_main.local_player, PLAZA_RELIC)
	await ticks(10)
	expect(client_main.collected_relics.has("RelicPlaza"), "the client should be told about the host's find")


func test_both_touching_the_same_relic_counts_once() -> void:
	host_main.local_player.global_position = PLAZA_RELIC
	client_main.local_player.global_position = PLAZA_RELIC
	await ticks(15)
	expect(host_main.collected_relics.size() == 1, "host should count 1 relic, counts %d" % host_main.collected_relics.size())
	expect(client_main.collected_relics.size() == 1, "client should count 1 relic, counts %d" % client_main.collected_relics.size())


func test_late_joiner_is_told_what_was_found() -> void:
	await _move(host_main.local_player, STREET_RELIC)
	await ticks(5)
	# The client leaves and joins again: it should catch up on the find.
	client_main.leave_game()
	await ticks(30)
	client_main.start_join("127.0.0.1", TEST_PORT)
	for i in 300:
		await ticks(1)
		if client_main.level != null and client_main.local_player != null:
			break
	await ticks(10)
	expect(client_main.collected_relics.has("RelicWestStreet"), "a player joining later should know what's already found")
	if client_main.level:
		expect(not client_main.level.get_node("Relics/RelicWestStreet").visible, "and not see the found relic")


func _move(who: Player, spot: Vector3) -> void:
	who.global_position = spot
	who.velocity = Vector3.ZERO
	who.reset_physics_interpolation()
	await ticks(5)
