extends GameTest
## Saving progress between sessions (game/progress.gd): the relics the crew
## delivers and the group-run relics it earns are saved for each world on the
## host's computer, and put back next time. Developers can switch it off.


func before_each() -> void:
	Settings.save_progress = true
	Settings.save_to_disk() # (A game starting reads the settings back.)
	Progress.forget()
	await _play_district()


func after_each() -> void:
	Settings.save_progress = false
	Settings.save_to_disk()
	Settings.dev_tools = true
	Progress.forget()
	await super()


func test_delivered_relics_are_still_delivered_next_time() -> void:
	var relic: WorldItem = main.level.get_node("Relics").get_child(0)
	await _deliver(relic)
	expect(main.delivered_relics.size() == 1, "test setup: one delivered")
	await _play_district() # Next session.
	var again: WorldItem = main.level.get_node("Relics").get_child(0)
	expect(main.delivered_relics.size() == 1 and again.state == WorldItem.State.DELIVERED, "it's still delivered: %s" % [main.delivered_relics.keys()])
	expect(main.hud.get_node("Relics").text == "Relics 1 / 41", "and counted: %s" % main.hud.get_node("Relics").text)
	await ticks(2)
	expect((main.level.get_node("RelicBoard") as RelicBoard).lit().x == 1, "and lit on the hub tower")


func test_run_relics_earned_are_still_there_next_time() -> void:
	var run: GroupRun = main.level.get_node("Runs/Run1")
	var finish := run.get_node("Rewards/Finish") as WorldItem
	finish.host_unlock()
	run.rewards_earned.emit() # (As when the crew finishes.)
	await _play_district()
	run = main.level.get_node("Runs/Run1")
	expect((run.get_node("Rewards/Finish") as WorldItem).state == WorldItem.State.IN_WORLD, "the finish relic is there, waiting to be delivered")
	expect((run.get_node("Rewards/Gold1") as WorldItem).state == WorldItem.State.LOCKED, "(the gold gates' still to earn)")
	expect(run.sign_text().contains("Relics: 1 of 3"), "and the sign knows:\n%s" % run.sign_text())


func test_a_run_relic_delivered_is_saved_as_delivered() -> void:
	var finish := main.level.get_node("Runs/Run1/Rewards/Finish") as WorldItem
	finish.host_unlock()
	await _deliver(finish)
	await _play_district()
	expect(main.is_delivered("Finish") and (main.level.get_node("Runs/Run1/Rewards/Finish") as WorldItem).state == WorldItem.State.DELIVERED, "delivered, next time too")


func test_each_world_keeps_its_own() -> void:
	await _deliver(main.level.get_node("Relics").get_child(0))
	main.leave_game()
	await ticks(5)
	main.start_solo("free_run_line")
	await ticks(10)
	expect(main.delivered_relics.is_empty(), "another world starts with its own (none yet)")


func test_developers_can_switch_saving_off_but_friends_cant() -> void:
	Settings.save_progress = false
	Settings.save_to_disk()
	await _deliver(main.level.get_node("Relics").get_child(0))
	await _play_district()
	expect(main.delivered_relics.is_empty(), "saving off: every game starts fresh")
	Settings.dev_tools = false # The build friends play.
	expect(Progress.is_on(), "friends always save, whatever the setting")


func test_forgetting_starts_fresh() -> void:
	await _deliver(main.level.get_node("Relics").get_child(0))
	main.set_paused(true)
	expect(main.pause_menu.get_node("%ForgetProgress").visible, "developers have a button to forget")
	main.pause_menu.get_node("%ForgetProgress").pressed.emit()
	main.set_paused(false)
	await _play_district()
	expect(main.delivered_relics.is_empty(), "forgotten: a fresh start")


## Starts (or restarts) a solo game in the district.
func _play_district() -> void:
	if main:
		main.queue_free()
		await ticks(2)
	main = MAIN_SCENE.instantiate()
	add_child(main)
	main.start_solo("rooftop_district")
	await ticks(5)
	player = main.get_node("Players/1")


## Delivers `relic` (as if carried into the drop-off).
func _deliver(relic: WorldItem) -> void:
	relic.global_position = main.level.get_node("DropOff").global_position + Vector3.UP
	relic.sync_transform = relic.global_transform
	for i in 20:
		await ticks(1)
		if relic.state == WorldItem.State.DELIVERED:
			break
	await ticks(2)
