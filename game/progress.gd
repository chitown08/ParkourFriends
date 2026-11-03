class_name Progress
extends RefCounted
## What the crew has done in each world, saved between sessions on the host's
## computer: the relics delivered, and the group runs' relics earned (but
## maybe not yet delivered). Each relic is named by where it is in its world
## (e.g. "Relics/RelicBlock12_1", "Runs/Run1/Rewards/Finish").
##
## Saved in the user data folder (progress.cfg), next to settings.cfg.
## Developers can switch saving off in the pause menu (Settings.save_progress);
## the build friends play always saves.

## Where it's saved. (The tests use a file of their own.)
static var path := "user://progress.cfg"


## True if progress is being saved and loaded.
static func is_on() -> bool:
	return Settings.save_progress or not Settings.dev_tools


## What's saved for `world_id`: {"delivered": [...], "earned": [...]} (empty lists if nothing).
static func load_world(world_id: String) -> Dictionary:
	var file := ConfigFile.new()
	var loaded := file.load(path) == OK
	return {
		"delivered": file.get_value(world_id, "delivered", []) if loaded else [],
		"earned": file.get_value(world_id, "earned", []) if loaded else [],
	}


## Saves `world_id`'s progress: relics `delivered`, and run relics `earned`.
static func save_world(world_id: String, delivered: Array, earned: Array) -> void:
	var file := ConfigFile.new()
	file.load(path) # (Keep the other worlds.)
	file.set_value(world_id, "delivered", delivered)
	file.set_value(world_id, "earned", earned)
	file.save(path)


## Forgets everything saved, in every world.
static func forget() -> void:
	DirAccess.remove_absolute(path)
