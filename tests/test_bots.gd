extends TestCase
## Balance checks. The bot plays at several skill levels over many seeds; a
## fair drill gives better players better scores, lets a strong player get
## close to full marks and leaves a beginner well short.

const RUNS := 60


func test_better_play_scores_higher_in_every_drill() -> void:
	for id in Tuning.DRILL_ORDER:
		var low := Sim.mean(id, 0.15, RUNS)
		var mid := Sim.mean(id, 0.55, RUNS)
		var high := Sim.mean(id, 0.95, RUNS)
		more(mid, low + 4.0, "%s: mid %.1f vs low %.1f" % [id, mid, low])
		more(high, mid + 4.0, "%s: high %.1f vs mid %.1f" % [id, high, mid])


func test_a_strong_player_can_nearly_max_each_drill() -> void:
	for id in Tuning.DRILL_ORDER:
		var best := 0.0
		for seed_value in range(1, RUNS + 1):
			best = maxf(best, Sim.play(id, 1.0, seed_value).score)
		at_least(best, 90.0, "%s best run at full skill" % id)


func test_a_beginner_is_left_room_to_improve() -> void:
	for id in Tuning.DRILL_ORDER:
		at_most(Sim.mean(id, 0.1, RUNS), 55.0, "%s at beginner skill" % id)


func test_no_drill_is_all_or_nothing_for_an_average_player() -> void:
	# An average player should land in the middle of the scale, not at an end.
	for id in Tuning.DRILL_ORDER:
		var mid := Sim.mean(id, 0.55, RUNS)
		at_least(mid, 25.0, "%s average player" % id)
		at_most(mid, 85.0, "%s average player" % id)


func test_whole_runs_spread_across_the_grades() -> void:
	var beginner := Sim.mean_total(0.15, 30)
	var average := Sim.mean_total(0.55, 30)
	var strong := Sim.mean_total(0.9, 30)
	more(average, beginner + 800.0, "average vs beginner total")
	more(strong, average + 800.0, "strong vs average total")
	at_most(beginner, float(_grade_min("B")), "a beginner should not average a B")
	at_least(strong, float(_grade_min("A")), "a strong player should average at least an A")


func _grade_min(grade: String) -> int:
	for row: Dictionary in Tuning.GRADES:
		if row["grade"] == grade:
			return int(row["min"])
	return 0


func test_bot_runs_always_finish() -> void:
	for seed_value in range(1, 25):
		var s := Sim.session(randf_range(0.0, 1.0), seed_value)
		check(s.is_complete(), "run %d did not finish" % seed_value)
		eq(s.results.size(), 8)
		at_least(float(s.total()), 0.0)
		at_most(float(s.total()), 10000.0)
