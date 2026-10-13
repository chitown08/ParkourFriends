extends SceneTree
## Runs every tests/test_*.gd file and prints the results.
## Start it with run_tests.cmd (or see README.md).
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


const TIME_LIMIT_SECONDS := 600.0


func _initialize() -> void:
	# Safety net: if a test gets stuck, give up instead of hanging forever.
	create_timer(TIME_LIMIT_SECONDS).timeout.connect(func() -> void:
		print("\nFAIL: the tests took longer than %d seconds - something is stuck." % TIME_LIMIT_SECONDS)
		quit(1))
	_run_all.call_deferred()


func _run_all() -> void:
	var catcher := ErrorCatcher.new()
	OS.add_logger(catcher)
	var passed := 0
	var failed := 0

	for file in DirAccess.get_files_at(TEST_DIR):
		if not (file.begins_with("test_") and file.ends_with(".gd")):
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
		for method in suite.get_method_list():
			var test_name: String = method.name
			if not test_name.begins_with("test_"):
				continue
			suite.failures.clear()
			catcher.take_errors()
			await suite.before_each()
			if suite.failures.is_empty():
				await suite.call(test_name)
			await suite.after_each()
			for error in catcher.take_errors():
				suite.failures.append("error: " + error)
			if suite.failures.is_empty():
				passed += 1
				print("  PASS  %s" % test_name)
			else:
				failed += 1
				print("  FAIL  %s" % test_name)
				for failure in suite.failures:
					print("          - %s" % failure)
		suite.queue_free()

	if catcher.take_errors().size() > 0 or (passed == 0 and failed == 0):
		failed += 1
		print("\nErrors outside of tests, or no tests found.")
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
