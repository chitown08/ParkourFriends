extends GameTest
## Group runs (levels/group_run.gd, run_gate.gd): stand in the start ring
## together, go through the white gates (each waits for the whole crew), get
## gold gates if you can, and the run's relics appear when you all finish. No
## clock. Played solo here in the Rooftop District's "Warm-up" (the crew
## waiting for each other: test_multiplayer.gd).

var run: GroupRun


func before_each() -> void:
	main = MAIN_SCENE.instantiate()
	add_child(main)
	main.start_solo("rooftop_district")
	await ticks(5)
	player = main.get_node("Players/1")
	player.set_profile(SUPERHUMAN)
	run = main.level.get_node("Runs/Run1")


func test_the_warm_up_run_has_its_gates_and_relics() -> void:
	var whites := _gates(false)
	var golds := _gates(true)
	expect(whites.size() == 5 and golds.size() == 2, "five white gates and two gold, got %d and %d" % [whites.size(), golds.size()])
	var names := run.rewards().map(func(reward: WorldItem) -> String: return str(reward.name))
	expect(names == ["Finish", "Gold1", "Gold2"], "a relic for finishing and one per gold gate, %s" % [names])
	expect(run.rewards().all(func(reward: WorldItem) -> bool: return reward.state == WorldItem.State.LOCKED and not reward.visible), "all still to earn: hidden")
	expect(main.hud.get_node("Relics").text.ends_with("/ 33"), "they count among the relics to find: %s" % main.hud.get_node("Relics").text)
	var first := whites[0]
	var way := (first.global_position - run.global_position).normalized()
	expect((-first.global_basis.z).dot(way) > 0.5, "the first gate faces the way you come at it from the ring")


func test_the_checker_says_white_gates_take_one_of_you_and_gold_gates_more() -> void:
	var map := ReachMap.build(main.level, SUPERHUMAN)
	var start := map.place_under(main.level.get_node("SpawnPoint").global_position + Vector3.UP)
	for target in map.targets:
		if not target.node is RunGate:
			continue
		var needed := map.players_needed(target, start)
		if (target.node as RunGate).gold:
			expect(needed >= 2, "%s should need friends (it's gold), takes %d" % [target.name, needed])
		else:
			expect(needed == 1, "%s should be reachable alone (everyone goes through it), takes %d" % [target.name, needed])


func test_nothing_shows_until_you_come_together() -> void:
	await place(Vector3(0, 0.05, 0), FACE_NORTH) # The plaza: nowhere near.
	await ticks(5)
	expect(_gates(false).all(func(gate: RunGate) -> bool: return not gate.visible) and _gates(true).all(func(gate: RunGate) -> bool: return not gate.visible), "no gates about")
	expect(run.get_node("Ring").visible, "just the start ring...")
	var sign_text := run.sign_text()
	expect(sign_text.contains("WARM-UP") and sign_text.contains("Relics: 0 of 3") and sign_text.contains("Stand in the ring together"), "...and its sign:\n%s" % sign_text)


func test_stand_in_the_ring_to_start() -> void:
	await _start_run()
	expect(run.phase == GroupRun.Phase.RUNNING and run.crew == PackedStringArray(["1"]), "the run's on, with you")
	var whites := _gates(false)
	expect(whites[0].visible and whites[0].get_child(1).visible, "the first gate lights up, with its beam")
	expect(whites[1].visible and not whites[1].get_child(1).visible, "the rest of the route shows faintly")
	expect(_gates(true).all(func(gate: RunGate) -> bool: return gate.visible), "and the gold gates")


func test_stepping_out_during_the_countdown_stops_it() -> void:
	await place(run.global_position + Vector3.UP * 0.05, FACE_NORTH)
	await ticks(30)
	expect(run.phase == GroupRun.Phase.COUNTDOWN and run.sign_text().contains("3"), "a countdown starts:\n%s" % run.sign_text())
	await place(run.global_position + Vector3(GroupRun.RING_RADIUS + 3.0, 0.05, 0), FACE_NORTH)
	await ticks(5)
	expect(run.phase == GroupRun.Phase.IDLE, "out of the ring: no run")


func test_go_through_every_gate_to_finish_and_earn_the_relic() -> void:
	await _start_run()
	var whites := _gates(false)
	for i in whites.size():
		await _go_through(whites[i])
		if i < whites.size() - 1:
			expect(run.gate == i + 1, "through gate %d: on to the next, heading for %d" % [i + 1, run.gate + 1])
	expect(run.phase == GroupRun.Phase.IDLE, "through the last: done")
	var finish := run.get_node("Rewards/Finish") as WorldItem
	expect(finish.state == WorldItem.State.IN_WORLD and finish.visible, "the finish relic appears")
	expect((run.get_node("Rewards/Gold1") as WorldItem).state == WorldItem.State.LOCKED, "(no gold gates got: their relics stay hidden)")
	expect(run.sign_text().contains("Relics: 1 of 3") and run.sign_text().contains("1 new relic"), "the sign says so:\n%s" % run.sign_text())
	expect(whites.all(func(gate: RunGate) -> bool: return not gate.visible), "and the gates are gone again")


func test_a_gate_is_your_checkpoint() -> void:
	await _start_run()
	var gate := _gates(false)[0]
	await _go_through(gate)
	var under := player.respawn_position
	expect(Vector2(under.x - gate.global_position.x, under.z - gate.global_position.z).length() < 0.1 and under.y < gate.global_position.y,
			"fall, and you're back under the gate you went through, %s" % under)


func test_gold_gates_pay_only_when_you_finish_and_runs_can_be_done_again() -> void:
	await _start_run()
	await _go_through(_gates(true)[1])
	expect(run.gold_got == PackedStringArray(["Gold2"]), "one of you through a gold gate: got, %s" % [run.gold_got])
	expect((run.get_node("Rewards/Gold2") as WorldItem).state == WorldItem.State.LOCKED, "but nothing yet: only finishing pays")
	for gate in _gates(false):
		await _go_through(gate)
	expect((run.get_node("Rewards/Gold2") as WorldItem).state == WorldItem.State.IN_WORLD, "finished: its relic appears")
	expect(run.sign_text().contains("2 new relics"), "with the finish one:\n%s" % run.sign_text())
	# Again: nothing new to earn this time, but it still runs.
	await _start_run()
	for gate in _gates(false):
		await _go_through(gate)
	expect(run.sign_text().contains("No new relics") and run.sign_text().contains("Relics: 2 of 3"), "again: no new relics, still 2 of 3:\n%s" % run.sign_text())


func test_a_gate_out_of_turn_doesnt_count() -> void:
	await _start_run()
	await _go_through(_gates(false)[2])
	expect(run.gate == 0, "the third gate before the first: still heading for the first")
	run.report_through(2) # (Say a late message arrives about another gate.)
	expect(run.gate == 0 and run.through.is_empty(), "the host only counts the gate the crew's heading for")


## Stands you in the start ring and waits out the countdown.
func _start_run() -> void:
	await place(run.global_position + Vector3.UP * 0.05, FACE_NORTH)
	await ticks(roundi(GroupRun.COUNTDOWN_TIME * 60) + 10)
	expect(run.phase == GroupRun.Phase.RUNNING, "test setup: the run starts, phase %d" % run.phase)


## Carries you straight through `gate` (a step either side of it).
func _go_through(gate: RunGate) -> void:
	var across := gate.global_basis.z * 3.0
	for at: Vector3 in [gate.global_position + across, gate.global_position - across]:
		player.global_position = at + Vector3.DOWN # (Your chest goes through the middle.)
		player.velocity = Vector3.ZERO
		player.reset_physics_interpolation()
		await ticks(1)
	await ticks(2)


func _gates(gold: bool) -> Array[RunGate]:
	var found: Array[RunGate] = []
	for gate: RunGate in run.get_node("Gates").get_children():
		if gate.gold == gold:
			found.append(gate)
	return found


func test_finishing_gets_a_party() -> void:
	await _start_run()
	for gate in _gates(false):
		await _go_through(gate)
	await ticks(2)
	var said: String = main.hud.get_node("Message").text
	expect(said.begins_with("Run complete!"), "the crew's told: '%s'" % said)
	var lights_before := get_viewport().find_children("*", "OmniLight3D", true, false).size()
	expect(get_viewport().find_children("*", "CPUParticles3D", true, false).size() > 0, "confetti over the finish")
	await ticks(90)
	expect(get_viewport().find_children("*", "OmniLight3D", true, false).size() > lights_before, "and fireworks")
