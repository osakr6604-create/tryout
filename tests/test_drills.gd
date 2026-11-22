extends TestCase
## The drill rules themselves, driven directly (no bot): what counts as a hit,
## what ends a drill, and that the same seed replays the same drill.


func _fresh(id: StringName, seed_value: int = 5) -> DrillModel:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var model := Session.make_model(id)
	model.setup(rng, Tuning.FIELD)
	return model


func _run_out(model: DrillModel) -> void:
	var guard := 0
	while not model.done and guard < 10000:
		model.advance(Sim.DT)
		guard += 1


func test_every_drill_ends_by_itself_and_scores_zero_when_idle() -> void:
	for id in Tuning.DRILL_ORDER:
		for seed_value in [1, 2, 3]:
			var r := Sim.idle(id, seed_value)
			near(r.score, 0.0, 0.001, "%s idle score" % id)
			check(r.headline != "", "%s has a headline" % id)


func test_every_drill_fits_the_minute() -> void:
	# The whole run has to stay close to a minute of play.
	var total := 0.0
	for id in Tuning.DRILL_ORDER:
		var longest := 0.0
		for seed_value in range(1, 9):
			var model := _fresh(id, seed_value)
			_run_out(model)
			longest = maxf(longest, model.t)
			check(model.done, "%s finished" % id)
		at_most(longest, 9.5, "%s length" % id)
		at_least(longest, 4.0, "%s length" % id)
		total += longest
	at_most(total, 62.0, "idle run length")


func test_same_seed_same_drill() -> void:
	for id in Tuning.DRILL_ORDER:
		var a := Sim.play(id, 0.7, 42)
		var b := Sim.play(id, 0.7, 42)
		near(a.score, b.score, 0.0001, "%s repeat" % id)
		eq(a.headline, b.headline, "%s headline repeat" % id)


func test_different_seeds_differ() -> void:
	var a := _fresh(&"holdfire", 1) as HoldFireModel
	var b := _fresh(&"holdfire", 2) as HoldFireModel
	var same := true
	for i in a.slots.size():
		if (a.slots[i]["pos"] as Vector2) != (b.slots[i]["pos"] as Vector2):
			same = false
	check(not same, "two seeds gave the same layout")


func test_events_are_handed_over_once() -> void:
	var model := _fresh(&"flick")
	check(model.take_events().size() >= 1, "the first target is announced")
	eq(model.take_events().size(), 0, "second take is empty")


# ---- flick ----

func test_flick_hit_and_miss() -> void:
	var m := _fresh(&"flick") as FlickModel
	var first := m.target
	m.advance(0.2)
	m.press(first + Vector2(Tuning.FLICK_RADIUS - 1.0, 0.0))
	eq(m.hits, 1)
	check(m.target != first, "a new target appears")
	m.press(m.target + Vector2(Tuning.FLICK_RADIUS + 5.0, 0.0))
	eq(m.misses, 1)
	eq(m.streak, 0, "a miss breaks the streak")


func test_flick_targets_stay_inside_the_field() -> void:
	var m := _fresh(&"flick", 11) as FlickModel
	for i in 200:
		m.t = 0.0   # keep the drill open while we chain hits
		m.press(m.target)
		check(Tuning.FIELD.grow(-FlickModel.MARGIN + 1.0).has_point(m.target), "target %d at %s" % [i, m.target])


func test_flick_perfect_play_reaches_full_marks() -> void:
	var m := _fresh(&"flick") as FlickModel
	while not m.done:
		m.advance(0.3)
		m.press(m.target)
	near(m.result().score, 100.0, 0.01)


# ---- track ----

func test_track_perfect_and_absent() -> void:
	var m := _fresh(&"track") as TrackModel
	while not m.done:
		m.move(m.pos)
		m.advance(Sim.DT)
	at_least(m.fraction(), 0.95, "glued to the target")
	near(m.result().score, 100.0, 0.01)


func test_track_target_stays_inside_the_field() -> void:
	var m := _fresh(&"track", 9) as TrackModel
	while not m.done:
		m.advance(Sim.DT)
		check(Tuning.FIELD.has_point(m.pos), "target left the field at %s" % m.pos)


# ---- react ----

func test_react_measures_the_wait_and_rejects_early_clicks() -> void:
	var m := _fresh(&"react") as ReactModel
	m.press(Vector2.ZERO)   # far too early
	eq(m.times_ms[0], ReactModel.FALSE_START)
	# Let the "too early" message pass, then wait for the next go.
	while m.phase != ReactModel.Phase.GO and not m.done:
		m.advance(Sim.DT)
	for i in 24:            # 24 steps of 1/120 s = 200 ms
		m.advance(Sim.DT)
	m.press(Vector2.ZERO)
	near(float(m.times_ms[1]), 200.0, 10.0, "measured reaction")
	eq(m.false_starts(), 1)


func test_react_measured_press_is_used_as_given() -> void:
	var m := _fresh(&"react") as ReactModel
	while m.phase != ReactModel.Phase.GO:
		m.advance(Sim.DT)
	m.press_measured(187)
	eq(m.times_ms[0], 187)
	eq(m.best_ms(), 187)


func test_react_has_three_trials_then_ends() -> void:
	var m := _fresh(&"react") as ReactModel
	var guard := 0
	while not m.done and guard < 5000:
		if m.phase == ReactModel.Phase.GO and m.phase_t >= 0.2:
			m.press(Vector2.ZERO)
		m.advance(Sim.DT)
		guard += 1
	check(m.done, "ended")
	eq(m.times_ms.size(), Tuning.REACT_TRIALS)
	at_least(m.result().score, 80.0, "three clean 200 ms reactions")


# ---- hold fire ----

func test_holdfire_schedule_is_fair() -> void:
	for seed_value in range(1, 30):
		var m := _fresh(&"holdfire", seed_value) as HoldFireModel
		eq(m.slots.size(), Tuning.HOLD_COUNT)
		var enemies := 0
		var run := 0
		for s in m.slots:
			if s["enemy"]:
				enemies += 1
				run = 0
			else:
				run += 1
			check(run < 3, "three teammates in a row, seed %d" % seed_value)
		eq(enemies, Tuning.HOLD_ENEMIES)
		check(m.slots[0]["enemy"], "starts on an enemy")


func test_holdfire_hits_friendly_fire_and_holding() -> void:
	var m := _fresh(&"holdfire") as HoldFireModel
	while not m.done:
		var s := m.live()
		if not s.is_empty() and m.t >= float(s["start"]) + 0.3:
			if m.friendly == 0 and not s["enemy"]:
				m.press(s["pos"])           # one deliberate mistake
			elif s["enemy"]:
				m.press(s["pos"])
		m.advance(Sim.DT)
	eq(m.hits, Tuning.HOLD_ENEMIES)
	eq(m.friendly, 1)
	eq(m.held, Tuning.HOLD_COUNT - Tuning.HOLD_ENEMIES - 1)
	eq(m.whiffs, 0)


# ---- last hit ----

func test_lasthit_early_click_locks_and_gold_click_scores() -> void:
	var m := _fresh(&"lasthit") as LastHitModel
	while m.in_lane(int(m.minions[0]["lane"])).is_empty():
		m.advance(Sim.DT)
	var lane := int(m.minions[0]["lane"])
	m.press(m.lane_rect(lane).get_center())
	eq(m.early, 1, "full health click is early")
	check(m.is_locked(), "attack is locked after an early click")
	while float(m.minions[0]["hp"]) > Tuning.LASTHIT_KILL_ZONE - 0.02:
		m.advance(Sim.DT)
	check(not m.is_locked(), "lock has worn off")
	m.press(m.lane_rect(lane).get_center())
	eq(m.hits, 1)


func test_lasthit_lanes_never_overlap() -> void:
	for seed_value in range(1, 40):
		var m := _fresh(&"lasthit", seed_value) as LastHitModel
		eq(m.minions.size(), Tuning.LASTHIT_TOTAL)
		for a in m.minions.size():
			for b in range(a + 1, m.minions.size()):
				var x := m.minions[a]
				var y := m.minions[b]
				if x["lane"] != y["lane"]:
					continue
				var x_end := float(x["spawn"]) + float(x["drain"])
				var y_end := float(y["spawn"]) + float(y["drain"])
				check(x_end <= float(y["spawn"]) or y_end <= float(x["spawn"]), "two bars share a lane, seed %d" % seed_value)
			check(float(m.minions[a]["spawn"]) >= 0.0, "bar starts before the drill, seed %d" % seed_value)
			check(float(m.minions[a]["spawn"]) + float(m.minions[a]["drain"]) <= m.duration + 0.01, "bar outlives the drill, seed %d" % seed_value)


func test_lasthit_lanes_tile_the_field() -> void:
	var m := _fresh(&"lasthit") as LastHitModel
	for lane in Tuning.LASTHIT_LANES:
		eq(m.lane_at(m.lane_rect(lane).get_center()), lane)
	eq(m.lane_at(Vector2(-50.0, -50.0)), -1)


# ---- skillshot ----

func test_skillshot_needs_a_lead() -> void:
	var m := _fresh(&"skillshot") as SkillshotModel
	while m.runner.is_empty():
		m.advance(Sim.DT)
	# Put the runner far away, where the flight time matters most.
	m.runner["pos"] = Tuning.FIELD.position + Vector2(300.0, 130.0)
	m.runner["vel"] = Vector2(450.0, 0.0)
	m.runner["juke_at"] = -1.0
	# Aim straight at where the runner is now: the shot arrives late and misses.
	m.press(m.runner["pos"])
	eq(m.fired, 1)
	var guard := 0
	while not m.shots.is_empty() and guard < 600:
		m.advance(Sim.DT)
		guard += 1
	eq(m.hits, 0, "no lead, no hit")


func test_skillshot_exact_lead_hits() -> void:
	var m := _fresh(&"skillshot", 3) as SkillshotModel
	var hits_wanted := 0
	while not m.done:
		if not m.runner.is_empty() and m.cooldown_left() <= 0.0 and m.shots.is_empty() and not _about_to_juke(m):
			var p: Vector2 = m.runner["pos"]
			var v: Vector2 = m.runner["vel"]
			var aim := p
			for i in 6:   # settle on the meeting point
				aim = p + v * (aim.distance_to(m.caster) / Tuning.SKILL_SHOT_SPEED)
			m.press(aim)
			hits_wanted += 1
		m.advance(Sim.DT)
	at_least(float(m.hits), 3.0, "led shots land")
	at_most(float(m.fired), float(hits_wanted))


func _about_to_juke(m: SkillshotModel) -> bool:
	var at := float(m.runner["juke_at"])
	return at > 0.0 and not m.runner["juked"] and at - m.t < 0.7


func test_skillshot_cannot_fire_backwards_or_during_cooldown() -> void:
	var m := _fresh(&"skillshot") as SkillshotModel
	m.press(m.caster + Vector2(0.0, 60.0))
	eq(m.fired, 0, "below the caster")
	m.press(m.caster + Vector2(0.0, -400.0))
	m.press(m.caster + Vector2(50.0, -400.0))
	eq(m.fired, 1, "second click was inside the cooldown")


# ---- map check ----

func test_mapcheck_perfect_recall() -> void:
	var m := _fresh(&"mapcheck") as MapCheckModel
	m.press(m.cell_rect(m.cells[0]).get_center())
	eq(m.picks, 0, "clicks during the reveal do nothing")
	while m.phase != MapCheckModel.Phase.RECALL:
		m.advance(Sim.DT)
	for cell in m.cells:
		m.press(m.cell_rect(cell).get_center())
	eq(m.found.size(), Tuning.MAP_PINGS)
	_run_out(m)
	at_least(m.result().score, 99.0)
	at_most(m.t, Tuning.MAP_SHOW_UNTIL + 1.0, "ends soon after the last pick")


func test_mapcheck_wrong_cells_and_repeat_clicks() -> void:
	var m := _fresh(&"mapcheck") as MapCheckModel
	while m.phase != MapCheckModel.Phase.RECALL:
		m.advance(Sim.DT)
	var miss := -1
	for i in Tuning.MAP_GRID * Tuning.MAP_GRID:
		if not m.cells.has(i):
			miss = i
			break
	m.press(m.cell_rect(miss).get_center())
	m.press(m.cell_rect(miss).get_center())
	eq(m.wrong.size(), 1, "the same cell only counts once")
	eq(m.picks, 1)


func test_mapcheck_cells_round_trip() -> void:
	var m := _fresh(&"mapcheck") as MapCheckModel
	for cell in Tuning.MAP_GRID * Tuning.MAP_GRID:
		eq(m.cell_at(m.cell_rect(cell).get_center()), cell)
	eq(m.cell_at(m.grid_rect().position - Vector2(5.0, 5.0)), -1)
	eq(m.cells.size(), Tuning.MAP_PINGS)


# ---- clutch ----

func test_clutch_all_four_is_a_clutch() -> void:
	var m := _fresh(&"clutch") as ClutchModel
	while not m.done:
		var f := m.visible_foe()
		if not f.is_empty() and m.t >= float(f["start"]) + 0.3:
			m.press(f["pos"])
		m.advance(Sim.DT)
	eq(m.kills, Tuning.CLUTCH_ENEMIES)
	check(m.clutched, "clutched")
	eq(m.bullets, Tuning.CLUTCH_BULLETS - Tuning.CLUTCH_ENEMIES)
	near(m.result().score, 100.0, 0.5)


func test_clutch_runs_dry() -> void:
	var m := _fresh(&"clutch") as ClutchModel
	for i in Tuning.CLUTCH_BULLETS + 3:
		m.press(Vector2(-100.0, -100.0))
	eq(m.bullets, 0)
	eq(m.misses, Tuning.CLUTCH_BULLETS, "empty clicks are not misses")
	_run_out(m)
	eq(m.kills, 0)
	near(m.result().score, 0.0)
