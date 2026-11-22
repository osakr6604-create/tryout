extends SceneTree
## Prints how the bot scores at each skill level, drill by drill, and how whole
## runs spread across the grades. Used while tuning core/tuning.gd.
##
##   godot --headless --path . --script res://dev/balance.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var skills: Array[float] = [0.1, 0.3, 0.5, 0.7, 0.9, 1.0]
	var header := "drill       "
	for s in skills:
		header += "%7.1f" % s
	print(header)
	for id in Tuning.DRILL_ORDER:
		var line := "%-12s" % id
		for s in skills:
			line += "%7.1f" % Sim.mean(id, s, 80)
		print(line)
	print("")
	print("skill   mean total   grades over 80 runs")
	for s in skills:
		var counts: Dictionary = {}
		var sum := 0
		for i in 80:
			var run := Sim.session(s, 1000 + i)
			sum += run.total()
			counts[run.grade()] = int(counts.get(run.grade(), 0)) + 1
		var spread := ""
		for row: Dictionary in Tuning.GRADES:
			spread += "  %s:%d" % [row["grade"], int(counts.get(row["grade"], 0))]
		print("%5.1f   %10d  %s" % [s, sum / 80, spread])
	quit(0)
