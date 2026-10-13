extends SceneTree
## Runs every tests/test_*.gd file and prints the results.
## Start it with run_tests.cmd (or see README.md).

const TEST_DIR := "res://tests/"


func _initialize() -> void:
	_run_all.call_deferred()


func _run_all() -> void:
	var passed := 0
	var failed := 0
	for file in DirAccess.get_files_at(TEST_DIR):
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		var suite: GameTest = load(TEST_DIR + file).new()
		root.add_child(suite)
		print("\n%s" % file)
		for method in suite.get_method_list():
			var test_name: String = method.name
			if not test_name.begins_with("test_"):
				continue
			suite.failures.clear()
			await suite.before_each()
			await suite.call(test_name)
			await suite.after_each()
			if suite.failures.is_empty():
				passed += 1
				print("  PASS  %s" % test_name)
			else:
				failed += 1
				print("  FAIL  %s" % test_name)
				for failure in suite.failures:
					print("          - %s" % failure)
		suite.queue_free()

	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
