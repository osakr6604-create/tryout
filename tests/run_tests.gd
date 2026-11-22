extends SceneTree
## Runs every tests/test_*.gd file and exits with 1 if anything failed.
##
##   godot --headless --path . --script res://tests/run_tests.gd
##   godot --headless --path . --script res://tests/run_tests.gd -- --filter=rating --verbose
##
## The last line is always "<n> tests, <m> failed", which the scripts and the
## CI job look for to know the run finished.


func _initialize() -> void:
	# Autoloads are only ready once this function has returned.
	call_deferred("_run")


func _run() -> void:
	var filter := ""
	var verbose := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.substr(9)
		elif arg == "--verbose":
			verbose = true

	var files: PackedStringArray = []
	for file in DirAccess.get_files_at("res://tests"):
		if file.begins_with("test_") and file.ends_with(".gd") and file != "test_case.gd":
			if filter == "" or file.contains(filter):
				files.append(file)
	files.sort()

	var total := 0
	var failed := 0
	var checks := 0
	var started := Time.get_ticks_msec()
	for file in files:
		var script: GDScript = load("res://tests/" + file)
		if script == null:
			print("FAIL  %s could not be loaded" % file)
			failed += 1
			total += 1
			continue
		var case: TestCase = script.new()
		for method: Dictionary in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			case.begin()
			case.call(method_name)
			total += 1
			if case.failed:
				failed += 1
				print("FAIL  %s :: %s" % [file, method_name])
				for line in case.messages:
					print("        " + line)
			elif verbose:
				print("ok    %s :: %s" % [file, method_name])
		checks += case.checks

	print("%d checks in %.1f s" % [checks, float(Time.get_ticks_msec() - started) / 1000.0])
	print("%d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 else 0)
