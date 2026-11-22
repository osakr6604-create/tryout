class_name ClutchModel
extends DrillModel
## CLUTCH: the finale. Four opponents peek one after another, each for less
## time than the last, and you have five bullets. Drop all four for the clutch.

enum { PENDING, VISIBLE, DOWN, ESCAPED }

const MARGIN := 210.0

var foes: Array[Dictionary] = []     ## {start, window, pos, state}
var bullets: int = 0
var kills: int = 0
var misses: int = 0
var kill_times: Array[float] = []
var clutched: bool = false

var _end_at: float = -1.0


func _setup() -> void:
	id = &"clutch"
	title = "CLUTCH"
	hint = "1 v 4. Five bullets. Make them count."
	bullets = Tuning.CLUTCH_BULLETS
	kills = 0
	misses = 0
	clutched = false
	kill_times.clear()
	foes.clear()
	_end_at = -1.0

	var gaps := shuffled(Tuning.CLUTCH_GAPS)
	var at := Tuning.CLUTCH_LEAD_IN
	var last := field.get_center()
	for i in Tuning.CLUTCH_ENEMIES:
		var p := rand_point_away(last, 520.0, MARGIN)
		var window := float(Tuning.CLUTCH_WINDOWS[i])
		foes.append({"start": at, "window": window, "pos": p, "state": PENDING})
		at += window
		if i < gaps.size():
			at += float(gaps[i])
		last = p
	duration = at + 0.7


func visible_foe() -> Dictionary:
	for f in foes:
		if f["state"] == VISIBLE:
			return f
	return {}


func _advance(_dt: float) -> void:
	var open := 0
	for f in foes:
		if f["state"] == PENDING and t >= float(f["start"]):
			f["state"] = VISIBLE
			emit(&"peek", {"pos": f["pos"], "window": f["window"]})
		if f["state"] == VISIBLE and t >= float(f["start"]) + float(f["window"]):
			f["state"] = ESCAPED
			emit(&"shot_back", {"pos": f["pos"]})
		if f["state"] == PENDING or f["state"] == VISIBLE:
			open += 1
	if open == 0 and _end_at < 0.0:
		_end_at = t + 0.6
	if _end_at >= 0.0 and t >= _end_at:
		done = true


func _press(pos: Vector2) -> void:
	if bullets <= 0:
		emit(&"empty")
		return
	bullets -= 1
	var f := visible_foe()
	if not f.is_empty() and pos.distance_to(f["pos"]) <= Tuning.CLUTCH_RADIUS:
		f["state"] = DOWN
		kills += 1
		kill_times.append(t - float(f["start"]))
		emit(&"kill", {"pos": f["pos"], "count": kills})
		if kills >= Tuning.CLUTCH_ENEMIES:
			clutched = true
			emit(&"clutch")
	else:
		misses += 1
		emit(&"miss", {"pos": pos})


func average_ttk() -> float:
	if kill_times.is_empty():
		return 0.0
	var sum := 0.0
	for v in kill_times:
		sum += v
	return sum / kill_times.size()


func live_stat() -> String:
	return "%d / %d DOWN" % [kills, Tuning.CLUTCH_ENEMIES]


func result() -> DrillResult:
	var headline := "%d of %d down" % [kills, Tuning.CLUTCH_ENEMIES]
	if clutched:
		headline = "4 of 4, clutch"
	return DrillResult.make(id, title, Tuning.clutch_score(kills, average_ttk()), headline, {
		"kills": kills,
		"misses": misses,
		"clutched": clutched,
		"avg_ttk": average_ttk(),
	})
