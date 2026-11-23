extends TestCase
## The saved leaderboard, on a real disk. The test script runs with its own
## empty user folder, so nothing here touches a real board.


func _run(score_each: float) -> Session:
	var s := Session.create(1)
	for id in Tuning.DRILL_ORDER:
		s.record(DrillResult.make(id, String(id), score_each, "x"))
	return s


func _fresh() -> void:
	Board.reset_all()
	Board.last_entry = {}


func test_a_score_survives_a_restart() -> void:
	_fresh()
	var entry := Board.submit("ACE", _run(80.0))
	eq(int(entry["score"]), 8000)
	check(FileAccess.file_exists(Board.PATH), "the board file was written")
	Board.data = Leaderboard.new()      # as if the game had just started
	Board.load_board()
	eq(Board.data.entries.size(), 1)
	eq(str(Board.data.entries[0]["tag"]), "ACE")
	eq(Board.rank_today(int(Board.data.entries[0]["id"])), 1)


func test_each_save_keeps_the_one_before() -> void:
	_fresh()
	Board.submit("ONE", _run(50.0))
	Board.submit("TWO", _run(60.0))
	check(FileAccess.file_exists(Board.BACKUP), "a backup exists")
	check(not FileAccess.file_exists(Board.TEMP), "no half-written file is left behind")
	var older := Leaderboard.new()
	check(older.from_text(FileAccess.get_file_as_string(Board.BACKUP)), "the backup is a readable board")
	eq(older.entries.size(), 1, "the backup is the save before the last one")


func test_a_damaged_file_falls_back_to_the_backup() -> void:
	_fresh()
	Board.submit("KEEP", _run(70.0))
	Board.submit("ALSO", _run(40.0))
	var file := FileAccess.open(Board.PATH, FileAccess.WRITE)
	file.store_string("{ this is not a board")
	file.close()
	Board.data = Leaderboard.new()
	Board.load_board()
	eq(Board.data.entries.size(), 1, "loaded from the backup")
	eq(str(Board.data.entries[0]["tag"]), "KEEP")
	var set_aside := false
	for name in DirAccess.get_files_at("user://"):
		if name.begins_with("leaderboard.unreadable-"):
			set_aside = true
	check(set_aside, "the damaged file was kept for a person to look at")


func test_no_file_at_all_is_an_empty_board() -> void:
	_fresh()
	var dir := DirAccess.open("user://")
	for name in dir.get_files():
		if name.begins_with("leaderboard"):
			dir.remove(name)
	Board.data = Leaderboard.new()
	Board.load_board()
	eq(Board.data.entries.size(), 0)
	eq(Board.count_today(), 0)
	eq(Board.top_today(5).size(), 0)


func test_export_writes_a_spreadsheet_file() -> void:
	_fresh()
	Board.submit("ACE", _run(80.0))
	Board.submit("=SUM(A1)", _run(10.0))
	var path := Board.export_csv()
	check(path != "" and FileAccess.file_exists(path), "file written: %s" % path)
	var lines := FileAccess.get_file_as_string(path).strip_edges().split("\n")
	eq(lines.size(), 3)
	check(lines[0].begins_with("rank,tag,score"), lines[0])
	check(lines[1].begins_with("1,ACE,8000"), lines[1])
	check(lines[2].contains("'=SUM(A1)"), "a formula-like tag is defused: %s" % lines[2])


func test_clearing_today_and_everything() -> void:
	_fresh()
	Board.submit("A", _run(10.0))
	Board.submit("B", _run(20.0))
	# One entry from another day.
	Board.data.add("OLD", 9000, "S+", "FLEX", [90, 90, 90, 90, 90, 90], 1000, "2020-01-01")
	Board.touch()
	eq(Board.reset_today(), 2)
	eq(Board.data.entries.size(), 1, "other days are untouched")
	eq(Board.count_today(), 0)
	eq(Board.top_all(5).size(), 1)
	Board.reset_all()
	eq(Board.data.entries.size(), 0)
	Board.data = Leaderboard.new()
	Board.load_board()
	eq(Board.data.entries.size(), 0, "the empty board was saved")


func test_changes_are_announced() -> void:
	_fresh()
	var heard: Array[int] = [0]
	var listener := func() -> void: heard[0] += 1
	Board.changed.connect(listener)
	Board.submit("A", _run(10.0))
	Board.reset_today()
	Board.changed.disconnect(listener)
	eq(heard[0], 2)


func test_live_status_is_announced() -> void:
	var heard: Array[int] = [0]
	var listener := func() -> void: heard[0] += 1
	Board.live_changed.connect(listener)
	Board.set_live({"state": "playing", "drill": 2, "title": "REACT", "score": 1500})
	Board.live_changed.disconnect(listener)
	eq(heard[0], 1)
	eq(int(Board.live["drill"]), 2)
	Board.set_live({"state": "idle"})


func test_settings_flags() -> void:
	check(Config.flag("no-such-flag", "fallback") == "fallback", "missing flag gives the fallback")
	eq(Config.flag_int("no-such-flag", 7), 7)
	near(Config.flag_float("no-such-flag", 0.5), 0.5)
	check(not Config.has_flag("no-such-flag"), "has_flag")
	check(Config.card_url.begins_with("https://"), "card link is https")


func test_reading_a_full_board_every_frame_stays_cheap() -> void:
	# The screens read the top of the board on every frame. Late in a long day
	# that must not get slower as the scores pile up.
	_fresh()
	for i in 4000:
		Board.data.add("P%d" % i, (i * 37) % 10000, "B", "FLEX", [1, 2, 3, 4, 5, 6], Board.now(), Board.today())
	Board.touch()
	eq(Board.count_today(), 4000)
	var started := Time.get_ticks_usec()
	for frame in 600:   # ten seconds of frames
		Board.top_today(10)
		Board.top_all(10)
		Board.count_today()
		Board.best_today()
	var ms := float(Time.get_ticks_usec() - started) / 1000.0
	at_most(ms, 300.0, "600 frames of board reads took %.0f ms" % ms)
	eq(int(Board.top_today(1)[0]["score"]), Board.best_today())
	_fresh()


func test_sorted_lists_follow_every_change() -> void:
	_fresh()
	eq(Board.best_today(), 0)
	Board.submit("LOW", _run(20.0))
	eq(Board.best_today(), 2000)
	var top := Board.submit("TOP", _run(90.0))
	eq(Board.best_today(), 9000)
	eq(str(Board.top_today(1)[0]["tag"]), "TOP")
	eq(Board.rank_today(int(top["id"])), 1)
	eq(Board.rank_today(424242), 0)
	Board.reset_today()
	eq(Board.top_today(5).size(), 0)
	eq(Board.best_today(), 0)
