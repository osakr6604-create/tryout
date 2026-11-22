extends TestCase
## The scouting report: totals, attributes, grades, roles and notes.


func _results(scores: Dictionary, false_starts: int = 0) -> Array[DrillResult]:
	var out: Array[DrillResult] = []
	for id in Tuning.DRILL_ORDER:
		var metrics: Dictionary = {}
		if id == &"react":
			metrics["false_starts"] = false_starts
		out.append(DrillResult.make(id, String(id).to_upper(), float(scores.get(id, 0.0)), "x", metrics))
	return out


func _flat(value: float) -> Dictionary:
	var out: Dictionary = {}
	for id in Tuning.DRILL_ORDER:
		out[id] = value
	return out


func test_total_runs_from_zero_to_ten_thousand() -> void:
	eq(Rating.total(_results(_flat(0.0))), 0)
	eq(Rating.total(_results(_flat(100.0))), 10000)
	eq(Rating.total(_results(_flat(50.0))), 5000)


func test_overall_is_two_digits() -> void:
	eq(Rating.overall(0), 0)
	eq(Rating.overall(7412), 74)
	eq(Rating.overall(10000), 99)


func test_every_weight_names_a_real_drill() -> void:
	for attr in Rating.ATTRS:
		check(Rating.WEIGHTS.has(attr), "no weights for %s" % attr)
		check(Rating.ROLES.has(attr), "no role for %s" % attr)
		check(Rating.STRENGTHS.has(attr) and Rating.WEAKNESSES.has(attr), "no note text for %s" % attr)
		var sum := 0.0
		for source: StringName in Rating.WEIGHTS[attr]:
			check(source == &"react_clean" or Tuning.DRILL_ORDER.has(source), "%s is not a drill" % source)
			sum += float(Rating.WEIGHTS[attr][source])
		near(sum, 1.0, 0.0001, "weights of %s" % attr)


func test_every_drill_feeds_an_attribute() -> void:
	for id in Tuning.DRILL_ORDER:
		var used := false
		for attr in Rating.ATTRS:
			if (Rating.WEIGHTS[attr] as Dictionary).has(id):
				used = true
		check(used, "%s feeds nothing" % id)


func test_attributes_stay_in_range() -> void:
	for value: float in [0.0, 37.0, 100.0]:
		var attrs := Rating.attributes(_results(_flat(value)))
		eq(attrs.size(), 6)
		for attr in Rating.ATTRS:
			at_least(float(attrs[attr]), 0.0)
			at_most(float(attrs[attr]), 99.0)


func test_one_strong_drill_lifts_its_attribute() -> void:
	var scores := _flat(40.0)
	scores[&"track"] = 100.0
	var attrs := Rating.attributes(_results(scores))
	eq(Rating.strongest(attrs), &"TRACKING")
	eq(Rating.role(attrs), "RIFLER")


func test_false_starts_cost_discipline() -> void:
	var clean := Rating.attributes(_results(_flat(70.0), 0))
	var jumpy := Rating.attributes(_results(_flat(70.0), 2))
	more(float(clean[&"DISCIPLINE"]), float(jumpy[&"DISCIPLINE"]))


func test_even_scores_read_as_flex() -> void:
	var attrs := Rating.attributes(_results(_flat(72.0)))
	eq(Rating.role(attrs), Rating.FLEX_ROLE)


func test_each_attribute_has_its_own_role() -> void:
	var seen: Dictionary = {}
	for attr in Rating.ATTRS:
		var attrs: Dictionary = {}
		for other in Rating.ATTRS:
			attrs[other] = 40
		attrs[attr] = 90
		var role := Rating.role(attrs)
		check(not seen.has(role), "role used twice: %s" % role)
		seen[role] = true
	eq(seen.size(), 6)


func test_note_names_strength_weakness_and_verdict() -> void:
	var attrs := {&"REFLEX": 92, &"PRECISION": 70, &"TRACKING": 66, &"TIMING": 61, &"DISCIPLINE": 30, &"AWARENESS": 64}
	var note := Rating.scout_note(attrs, "A")
	check(note.contains(str(Rating.STRENGTHS[&"REFLEX"])), note)
	check(note.contains(str(Rating.WEAKNESSES[&"DISCIPLINE"])), note)
	check(note.contains(str(Rating.VERDICTS["A"])), note)


func test_note_skips_the_weakness_when_nothing_is_weak() -> void:
	var attrs := {&"REFLEX": 95, &"PRECISION": 70, &"TRACKING": 66, &"TIMING": 61, &"DISCIPLINE": 60, &"AWARENESS": 64}
	var note := Rating.scout_note(attrs, "S")
	for attr in Rating.ATTRS:
		check(not note.contains(str(Rating.WEAKNESSES[attr])), note)


func test_notes_have_no_long_dashes() -> void:
	# House style for anything shown to the public.
	for table: Dictionary in [Rating.STRENGTHS, Rating.WEAKNESSES, Rating.VERDICTS]:
		for key: Variant in table:
			check(not str(table[key]).contains("—"), str(table[key]))


func test_every_grade_has_a_verdict() -> void:
	for row: Dictionary in Tuning.GRADES:
		check(Rating.VERDICTS.has(row["grade"]), "no verdict for %s" % row["grade"])


func test_commas() -> void:
	eq(Rating.with_commas(0), "0")
	eq(Rating.with_commas(999), "999")
	eq(Rating.with_commas(1000), "1,000")
	eq(Rating.with_commas(7412), "7,412")
	eq(Rating.with_commas(10000), "10,000")
	eq(Rating.with_commas(1234567), "1,234,567")


func test_stamp_words() -> void:
	eq(DrillResult.make(&"x", "X", 100.0, "").stamp(), "PERFECT")
	eq(DrillResult.make(&"x", "X", 80.0, "").stamp(), "GREAT")
	eq(DrillResult.make(&"x", "X", 60.0, "").stamp(), "GOOD")
	eq(DrillResult.make(&"x", "X", 40.0, "").stamp(), "OK")
	eq(DrillResult.make(&"x", "X", 5.0, "").stamp(), "ROUGH")
	near(DrillResult.make(&"x", "X", 250.0, "").score, 100.0, 0.001, "scores are clamped")


func test_session_walks_all_eight_drills() -> void:
	var s := Session.create(99)
	var ids: Array[StringName] = []
	while not s.is_complete():
		ids.append(s.current_id())
		var model := s.next_model(Tuning.FIELD)
		eq(model.id, s.current_id())
		s.record(DrillResult.make(model.id, model.title, 50.0, "x"))
	eq(ids, Tuning.DRILL_ORDER)
	eq(s.total(), 5000)
	eq(s.attribute_list().size(), 6)
	check(s.note() != "", "note")


func test_session_gives_each_drill_its_own_random_stream() -> void:
	var s := Session.create(7)
	var a := s.rng_for(0).randi()
	var b := s.rng_for(1).randi()
	check(a != b, "streams differ per drill")
	eq(Session.create(7).rng_for(0).randi(), a, "and repeat per seed")
