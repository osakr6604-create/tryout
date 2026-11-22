extends TestCase
## The leaderboard data: ordering, ties, days, saving and loading.

const DAY := "2026-11-23"
const NEXT_DAY := "2026-11-24"


func _board() -> Leaderboard:
	var b := Leaderboard.new()
	b.add("ACE", 8200, "S", "ENTRY", [90, 80, 70, 60, 50, 40], 1000, DAY)
	b.add("BEE", 6100, "B", "ANCHOR", [50, 50, 50, 50, 80, 50], 1010, DAY)
	b.add("CAT", 9100, "S+", "MARKSMAN", [90, 99, 90, 90, 90, 90], 1020, NEXT_DAY)
	return b


func test_highest_score_first() -> void:
	var all := _board().ranked(Leaderboard.Scope.ALL)
	eq(str(all[0]["tag"]), "CAT")
	eq(str(all[1]["tag"]), "ACE")
	eq(str(all[2]["tag"]), "BEE")


func test_a_tie_keeps_the_earlier_run_ahead() -> void:
	var b := Leaderboard.new()
	var first := b.add("FIRST", 5000, "C", "FLEX", [], 100, DAY)
	var second := b.add("SECOND", 5000, "C", "FLEX", [], 200, DAY)
	eq(b.rank_of(int(first["id"]), Leaderboard.Scope.ALL), 1)
	eq(b.rank_of(int(second["id"]), Leaderboard.Scope.ALL), 2)


func test_today_only_shows_today() -> void:
	var b := _board()
	eq(b.count(Leaderboard.Scope.TODAY, DAY), 2)
	eq(b.count(Leaderboard.Scope.ALL), 3)
	eq(str(b.top(10, Leaderboard.Scope.TODAY, DAY)[0]["tag"]), "ACE")
	eq(b.best_score(Leaderboard.Scope.TODAY, DAY), 8200)
	eq(b.best_score(Leaderboard.Scope.TODAY, "2030-01-01"), 0)


func test_top_is_capped() -> void:
	var b := Leaderboard.new()
	for i in 30:
		b.add("P%d" % i, i * 10, "D", "FLEX", [], i, DAY)
	eq(b.top(10, Leaderboard.Scope.ALL).size(), 10)
	eq(int(b.top(10, Leaderboard.Scope.ALL)[0]["score"]), 290)


func test_rank_of_and_rank_for_score_agree() -> void:
	var b := _board()
	eq(b.rank_for_score(7000, Leaderboard.Scope.ALL), 3)
	var e := b.add("NEW", 7000, "A", "FLEX", [], 2000, DAY)
	eq(b.rank_of(int(e["id"]), Leaderboard.Scope.ALL), 3)
	eq(b.rank_of(9999, Leaderboard.Scope.ALL), 0, "unknown id")
	eq(b.rank_of(int(e["id"]), Leaderboard.Scope.TODAY, NEXT_DAY), 0, "not in that day")


func test_ids_are_unique_and_survive_a_reload() -> void:
	var b := _board()
	var copy := Leaderboard.new()
	check(copy.from_text(b.to_text()), "loads its own text")
	eq(copy.entries.size(), 3)
	var e := copy.add("DOG", 1, "D", "FLEX", [], 5, DAY)
	eq(int(e["id"]), 4)
	var seen: Dictionary = {}
	for entry in copy.entries:
		check(not seen.has(entry["id"]), "id used twice")
		seen[entry["id"]] = true


func test_round_trip_keeps_whole_numbers() -> void:
	var copy := Leaderboard.new()
	copy.from_text(_board().to_text())
	var top := copy.ranked(Leaderboard.Scope.ALL)[0]
	eq(typeof(top["score"]), TYPE_INT)
	eq(typeof(top["ts"]), TYPE_INT)
	eq(typeof((top["attrs"] as Array)[1]), TYPE_INT)
	eq(int((top["attrs"] as Array)[1]), 99)
	eq(str(top["day"]), NEXT_DAY)


func test_damaged_files_never_load_and_never_crash() -> void:
	for text: String in ["", "not json", "[1,2,3]", "{\"entries\": 5}", "{\"version\": 1}", "null"]:
		var b := _board()
		check(not b.from_text(text), "accepted: %s" % text)
		eq(b.entries.size(), 0, "left empty after: %s" % text)


func test_odd_entries_are_skipped_not_fatal() -> void:
	var b := Leaderboard.new()
	var text := "{\"version\":1,\"entries\":[7,{\"tag\":\"OK\",\"score\":123456},{\"score\":5},\"x\",{\"tag\":\"NEG\",\"score\":-4}]}"
	check(b.from_text(text), "loads")
	eq(b.entries.size(), 2)
	eq(int(b.ranked(Leaderboard.Scope.ALL)[0]["score"]), 10000, "score is clamped")
	eq(int(b.ranked(Leaderboard.Scope.ALL)[1]["score"]), 0, "score is clamped")
	check(int(b.entries[0]["id"]) != int(b.entries[1]["id"]), "missing ids are filled in")


func test_clearing() -> void:
	var b := _board()
	eq(b.clear_day(DAY), 2)
	eq(b.entries.size(), 1)
	check(b.remove(int(b.entries[0]["id"])), "remove by id")
	check(not b.remove(12345), "remove unknown")
	b.add("X", 1, "D", "FLEX", [], 1, DAY)
	b.clear_all()
	eq(b.entries.size(), 0)


func test_the_board_trims_from_the_bottom() -> void:
	var b := Leaderboard.new()
	for i in Leaderboard.MAX_ENTRIES + 25:
		b.add("P", i, "D", "FLEX", [], i, DAY)
	eq(b.entries.size(), Leaderboard.MAX_ENTRIES)
	eq(b.best_score(Leaderboard.Scope.ALL), Leaderboard.MAX_ENTRIES + 24, "the best score is kept")
	var lowest := 999999
	for e in b.entries:
		lowest = mini(lowest, int(e["score"]))
	eq(lowest, 25, "the lowest scores went")


func test_csv_has_a_row_per_entry_in_rank_order() -> void:
	var lines := _board().to_csv().strip_edges().split("\n")
	eq(lines.size(), 4)
	check(lines[0].begins_with("rank,tag,score"), lines[0])
	check(lines[1].begins_with("1,CAT,9100,S+,MARKSMAN,90,99"), lines[1])
	check(lines[3].begins_with("3,BEE,6100"), lines[3])


func test_csv_defuses_formulas_and_commas() -> void:
	eq(Leaderboard._csv("=SUM(A1)"), "'=SUM(A1)")
	eq(Leaderboard._csv("-1+1"), "'-1+1")
	eq(Leaderboard._csv("A,B"), "\"A,B\"")
	eq(Leaderboard._csv("PLAIN"), "PLAIN")


func test_day_key_uses_local_time() -> void:
	# 2026-11-23 23:30 UTC is already the 24th two hours east, still the 23rd in UTC.
	var late := 1795476600
	eq(Leaderboard.day_key(late, 0), "2026-11-23")
	eq(Leaderboard.day_key(late, 120), "2026-11-24")
	eq(Leaderboard.day_key(late, -480), "2026-11-23")
