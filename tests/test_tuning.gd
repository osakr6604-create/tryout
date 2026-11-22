extends TestCase
## The scoring curves: their ends, and that better numbers never score lower.


func test_lin_ends_and_middle() -> void:
	near(Tuning.lin(0.0, 0.0, 10.0), 0.0)
	near(Tuning.lin(10.0, 0.0, 10.0), 1.0)
	near(Tuning.lin(5.0, 0.0, 10.0), 0.5)
	near(Tuning.lin(-5.0, 0.0, 10.0), 0.0, 0.001, "clamps below")
	near(Tuning.lin(50.0, 0.0, 10.0), 1.0, 0.001, "clamps above")


func test_lin_works_downward() -> void:
	# Reaction time: lower is better, so "zero" is the larger number.
	near(Tuning.lin(430.0, 430.0, 165.0), 0.0)
	near(Tuning.lin(165.0, 430.0, 165.0), 1.0)
	more(Tuning.lin(200.0, 430.0, 165.0), Tuning.lin(300.0, 430.0, 165.0))


func test_flick_score_range() -> void:
	near(Tuning.flick_score(0, 0), 0.0)
	near(Tuning.flick_score(0, 12), 0.0)
	near(Tuning.flick_score(15, 0), 100.0)
	near(Tuning.flick_score(40, 0), 100.0, 0.001, "never above 100")


func test_flick_more_hits_never_score_less() -> void:
	var last := -1.0
	for hits in range(0, 22):
		var s := Tuning.flick_score(hits, 2)
		at_least(s, last, "hits %d" % hits)
		last = s


func test_flick_misses_cost_points() -> void:
	more(Tuning.flick_score(10, 0), Tuning.flick_score(10, 5))


func test_track_score_range() -> void:
	near(Tuning.track_score(0.0), 0.0)
	near(Tuning.track_score(Tuning.TRACK_FRAC_FULL), 100.0)
	near(Tuning.track_score(1.0), 100.0)
	more(Tuning.track_score(0.6), Tuning.track_score(0.4))


func test_react_trial_score() -> void:
	near(Tuning.react_trial_score(ReactModel.FALSE_START), 0.0, 0.001, "false start")
	near(Tuning.react_trial_score(ReactModel.TIMEOUT), 0.0, 0.001, "timeout")
	near(Tuning.react_trial_score(150), 100.0)
	near(Tuning.react_trial_score(600), 0.0)
	more(Tuning.react_trial_score(220), Tuning.react_trial_score(280))


func test_holdfire_friendly_fire_hurts() -> void:
	var all := Tuning.HOLD_ENEMIES
	var clean := Tuning.holdfire_score(all, 0, 0, 0.5)
	var dirty := Tuning.holdfire_score(all, 1, 0, 0.5)
	near(clean - dirty, Tuning.HOLD_FRIENDLY_PENALTY, 0.01)
	near(Tuning.holdfire_score(0, 3, 9, 0.0), 0.0, 0.001, "never below zero")
	near(Tuning.holdfire_score(all, 0, 0, 0.2), 100.0)
	near(Tuning.holdfire_score(all + 3, 0, 0, 0.2), 100.0, 0.001, "never above 100")


func test_lasthit_score() -> void:
	near(Tuning.lasthit_score(Tuning.LASTHIT_TOTAL, 0), 100.0)
	near(Tuning.lasthit_score(0, 5), 0.0)
	more(Tuning.lasthit_score(5, 0), Tuning.lasthit_score(5, 2))


func test_skillshot_score() -> void:
	near(Tuning.skillshot_score(0, 6), 0.0)
	near(Tuning.skillshot_score(4, 4), 100.0)
	more(Tuning.skillshot_score(3, 3), Tuning.skillshot_score(3, 8), "wasted shots cost")
	more(Tuning.skillshot_score(3, 8), Tuning.skillshot_score(2, 2), "a hit is worth more than tidy shooting")


func test_mapcheck_score() -> void:
	near(Tuning.mapcheck_score(0, 1.0), 0.0)
	near(Tuning.mapcheck_score(Tuning.MAP_PINGS, 1.0), 100.0)
	more(Tuning.mapcheck_score(5, 2.0), Tuning.mapcheck_score(5, 4.0), "faster recall")
	more(Tuning.mapcheck_score(4, 4.0), Tuning.mapcheck_score(3, 1.0), "a ping is worth more than speed")


func test_clutch_score() -> void:
	near(Tuning.clutch_score(0, 0.0), 0.0)
	near(Tuning.clutch_score(4, 0.3), 100.0)
	more(Tuning.clutch_score(4, 0.6), Tuning.clutch_score(3, 0.3), "the clutch bonus beats speed")


func test_grades_cover_every_total() -> void:
	eq(Tuning.grade_for(0), "D")
	eq(Tuning.grade_for(10000), "S+")
	eq(Tuning.grade_for(8000), "S")
	eq(Tuning.grade_for(7999), "A")
	var last := 99999
	for row: Dictionary in Tuning.GRADES:
		check(int(row["min"]) < last, "grade thresholds go down the list")
		last = int(row["min"])


func test_run_has_eight_distinct_drills() -> void:
	eq(Tuning.DRILL_ORDER.size(), 8)
	var seen: Dictionary = {}
	for id in Tuning.DRILL_ORDER:
		check(not seen.has(id), "drill listed twice: %s" % id)
		seen[id] = true
		var model := Session.make_model(id)
		check(model.get_script() != DrillModel, "no model for %s" % id)
