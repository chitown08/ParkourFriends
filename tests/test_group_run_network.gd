extends MultiplayerTest
## Group runs with two players (levels/group_run.gd): it only starts with the
## whole crew in the ring, and each gate waits for everyone.


func _init() -> void:
	world_id = "rooftop_district"


func test_the_run_starts_only_with_the_whole_crew_and_each_gate_waits_for_everyone() -> void:
	var host_self: Player = host_main.local_player
	var client_self: Player = client_main.local_player
	host_self.sync_player_name = "Ana"
	client_self.sync_player_name = "Bo"
	var host_run: GroupRun = host_main.level.get_node("Runs/Run1")
	var client_run: GroupRun = client_main.level.get_node("Runs/Run1")

	# The host alone in the ring: waiting for Bo.
	_put(host_self, host_run.global_position + Vector3.UP * 0.05)
	await ticks(30)
	expect(host_run.phase == GroupRun.Phase.IDLE, "one of two in the ring: no run yet")
	expect(client_run.sign_text().contains("Waiting for Bo"), "the sign says who it's waiting for, on both screens:\n%s" % client_run.sign_text())

	# Both in: the run starts, on both screens.
	_put(client_self, client_run.global_position + Vector3(1.5, 0.05, 0))
	await ticks(roundi(GroupRun.COUNTDOWN_TIME * 60) + 30)
	expect(host_run.phase == GroupRun.Phase.RUNNING and client_run.phase == GroupRun.Phase.RUNNING, "together: the run's on for both")
	var host_gate: RunGate = host_run.get_node("Gates/Gate1")
	var client_gate: RunGate = client_run.get_node("Gates/Gate1")
	expect(client_gate.visible, "the client sees the first gate")

	# The host goes through the first gate: it waits for Bo.
	await _go_through(host_self, host_gate)
	await ticks(20)
	expect(host_run.gate == 0 and client_run.through == PackedStringArray([str(host_self.name)]), "Ana's through, but the route waits")
	var waiting: Label3D = client_gate.get_child(2)
	expect(waiting.text == "Waiting for Bo", "'Waiting for Bo' over the gate: '%s'" % waiting.text)
	expect(not (client_run.get_node("Gates/Gate2") as RunGate).get_child(1).visible, "the next gate isn't lit yet")

	# The client goes through: on to the next gate.
	await _go_through(client_self, client_gate)
	await ticks(20)
	expect(host_run.gate == 1 and client_run.gate == 1, "the whole crew's through: on to gate 2 (host %d, client %d)" % [host_run.gate, client_run.gate])
	expect((client_run.get_node("Gates/Gate2") as RunGate).get_child(1).visible, "and it lights up")

	# The client leaves: the crew's changed, so the run stops.
	client_main.leave_game()
	await ticks(30)
	expect(host_run.phase == GroupRun.Phase.IDLE, "a friend leaving ends the run (start again together)")


func _put(who: Player, at: Vector3) -> void:
	who.global_position = at
	who.velocity = Vector3.ZERO
	who.reset_physics_interpolation()


func _go_through(who: Player, gate: RunGate) -> void:
	var across := gate.global_basis.z * 3.0
	for at: Vector3 in [gate.global_position + across, gate.global_position - across]:
		_put(who, at + Vector3.DOWN)
		await ticks(1)
	await ticks(2)
