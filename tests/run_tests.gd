extends SceneTree
## Runs every tests/test_*.gd file and prints the results.
## Start it with run_tests.cmd (or see README.md). To run only some files, add
## words after "--", e.g. `run_tests.cmd items` runs only test files with
## "items" in their name.
##
## A test fails if any expect() check fails, or if any script error or engine
## error happens while it runs (Godot normally just logs those and carries on).

const TEST_DIR := "res://tests/"


## Collects every error Godot logs, so the runner can fail the test.
class ErrorCatcher:
	extends Logger

	var errors: Array[String] = []
	var _mutex := Mutex.new() # Errors can be logged from other threads.

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		_mutex.lock()
		errors.append("%s (%s:%d in %s)" % [rationale if rationale else code, file, line, function])
		_mutex.unlock()

	func take_errors() -> Array[String]:
		_mutex.lock()
		var taken := errors.duplicate()
		errors.clear()
		_mutex.unlock()
		return taken


## In game seconds: run_tests.cmd runs the game flat out (--fixed-fps 60), as
## fast as the computer can (each test says how long it took for real).
const TIME_LIMIT_SECONDS := 1200.0


func _initialize() -> void:
	# Safety net: if a test gets stuck, give up instead of hanging forever.
	create_timer(TIME_LIMIT_SECONDS).timeout.connect(func() -> void:
		print("\nFAIL: the tests took longer than %d seconds - something is stuck." % TIME_LIMIT_SECONDS)
		quit(1))
	_run_all.call_deferred()


func _run_all() -> void:
	# The tests' own settings file (starting fresh), not the player's.
	Settings.path = "user://test_settings.cfg"
	Network.steam_allowed = false # (Tests play over the local network.)
	# Nor do they save progress unless a test turns it on, and then in a file of their own.
	Settings.save_progress = false
	Progress.path = "user://test_progress.cfg"
	DirAccess.remove_absolute(Progress.path)
	DirAccess.remove_absolute(Settings.path)
	var catcher := ErrorCatcher.new()
	OS.add_logger(catcher)
	var passed := 0
	var failed := 0
	var only := OS.get_cmdline_user_args()
	# How long each test and each file took (real seconds), for the slowest lists at the end.
	var timings := []
	var file_times := []

	for file in DirAccess.get_files_at(TEST_DIR):
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		if not only.is_empty() and not Array(only).any(func(word: String) -> bool: return word in file):
			continue
		print("\n%s" % file)
		var script := load(TEST_DIR + file) as GDScript
		if script == null or not script.can_instantiate():
			# Usually a typo in the test file; the error is printed above.
			failed += 1
			catcher.take_errors()
			print("  FAIL  (the file couldn't be loaded - see the error above)")
			continue
		var suite: GameTest = script.new()
		root.add_child(suite)
		var file_time := 0.0
		for method in suite.get_method_list():
			var test_name: String = method.name
			if not test_name.begins_with("test_"):
				continue
			suite.failures.clear()
			catcher.take_errors()
			var started := Time.get_ticks_msec()
			await suite.before_each()
			if suite.failures.is_empty():
				await suite.call(test_name)
			await suite.after_each()
			for error in catcher.take_errors():
				suite.failures.append("error: " + error)
			var took := (Time.get_ticks_msec() - started) / 1000.0
			timings.append([took, "%s %s" % [file.get_basename(), test_name]])
			file_time += took
			if suite.failures.is_empty():
				passed += 1
				print("  PASS  %s (%.1f s)" % [test_name, took])
			else:
				failed += 1
				print("  FAIL  %s (%.1f s)" % [test_name, took])
				for failure in suite.failures:
					print("          - %s" % failure)
		suite.queue_free()
		file_times.append([file_time, file.get_basename()])
		print("  (%.0f s)" % file_time)

	if catcher.take_errors().size() > 0 or (passed == 0 and failed == 0):
		failed += 1
		print("\nErrors outside of tests, or no tests found.")
	if timings.size() > 10:
		timings.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
		file_times.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
		print("\nSlowest files: %s" % ", ".join(file_times.slice(0, 8).map(func(t: Array) -> String: return "%s %.0f s" % [t[1], t[0]])))
		print("Slowest tests: %s" % ", ".join(timings.slice(0, 10).map(func(t: Array) -> String: return "%s %.0f s" % [t[1], t[0]])))
	print("\n%d passed, %d failed" % [passed, failed])
	# Give the audio server a moment to let go of the last sounds, so quitting
	# doesn't report them as leaks. (A real pause: with --fixed-fps, frames alone
	# go by too quickly for the audio thread.)
	for i in 10:
		OS.delay_msec(20)
		await process_frame
	quit(1 if failed > 0 else 0)
