class_name HoldFireModel
extends DrillModel
## HOLD FIRE: shapes pop up one at a time. Click the enemies (red diamonds),
## leave your teammates (blue circles) alone. Enemies stay up for less and
## less time. The next shape comes as soon as the last one is dealt with, so
## quick, sure players move through it faster.

enum { PENDING, LIVE, GONE }

const MARGIN := 170.0

var slots: Array[Dictionary] = []    ## {life, pos, enemy, state, start}
var current: int = -1
var hits: int = 0
var friendly: int = 0
var whiffs: int = 0
var escaped: int = 0
var held: int = 0
var reaction_times: Array[float] = []

var _next_at: float = 0.0
var _end_at: float = -1.0


func _setup() -> void:
	id = &"holdfire"
	title = "HOLD FIRE"
	hint = "Click red. Never click blue."
	hits = 0
	friendly = 0
	whiffs = 0
	escaped = 0
	held = 0
	current = -1
	reaction_times.clear()
	slots.clear()
	_next_at = 0.4
	_end_at = -1.0

	var kinds := _kinds()
	var last := field.get_center()
	var longest := _next_at
	var enemy_index := 0
	for i in Tuning.HOLD_COUNT:
		var life := Tuning.HOLD_ALLY_LIFE
		if kinds[i]:
			var k := float(enemy_index) / float(maxi(1, Tuning.HOLD_ENEMIES - 1))
			life = lerpf(Tuning.HOLD_LIFE_START, Tuning.HOLD_LIFE_END, k)
			enemy_index += 1
		var p := rand_point_away(last, 340.0, MARGIN)
		slots.append({"life": life, "pos": p, "enemy": kinds[i], "state": PENDING, "start": 0.0})
		longest += life + Tuning.HOLD_GAP
		last = p
	# The ceiling: nobody clicks anything and every shape runs out its time.
	duration = longest + 0.5


## Five enemies and three teammates. Starts on an enemy and never shows three
## teammates in a row, so the rhythm cannot lull anyone into a free pass.
func _kinds() -> Array:
	var base: Array = []
	for i in Tuning.HOLD_COUNT:
		base.append(i < Tuning.HOLD_ENEMIES)
	for attempt in 40:
		var order := shuffled(base)
		if not order[0]:
			continue
		var run := 0
		var ok := true
		for e: bool in order:
			run = 0 if e else run + 1
			if run >= 3:
				ok = false
				break
		if ok:
			return order
	return [true, false, true, true, false, true, false, true]


func _advance(_dt: float) -> void:
	var s := live()
	if not s.is_empty() and t >= float(s["start"]) + float(s["life"]):
		s["state"] = GONE
		if s["enemy"]:
			escaped += 1
			emit(&"escaped", {"pos": s["pos"]})
		else:
			held += 1
			emit(&"held", {"pos": s["pos"]})
		_resolved()
	if live().is_empty() and _end_at < 0.0 and t >= _next_at and current + 1 < slots.size():
		current += 1
		slots[current]["state"] = LIVE
		slots[current]["start"] = t
		emit(&"spawn", {"pos": slots[current]["pos"], "enemy": slots[current]["enemy"], "life": slots[current]["life"]})
	if _end_at >= 0.0 and t >= _end_at:
		done = true


func _resolved() -> void:
	_next_at = t + Tuning.HOLD_GAP
	if current + 1 >= slots.size():
		_end_at = t + 0.35


func live() -> Dictionary:
	if current >= 0 and slots[current]["state"] == LIVE:
		return slots[current]
	return {}


func _press(pos: Vector2) -> void:
	var s := live()
	if s.is_empty() or pos.distance_to(s["pos"]) > Tuning.HOLD_RADIUS:
		whiffs += 1
		emit(&"whiff", {"pos": pos})
		return
	s["state"] = GONE
	if s["enemy"]:
		hits += 1
		reaction_times.append(t - float(s["start"]))
		emit(&"hit", {"pos": s["pos"], "ms": int(round((t - float(s["start"])) * 1000.0))})
	else:
		friendly += 1
		emit(&"friendly", {"pos": s["pos"]})
	_resolved()


func average_rt() -> float:
	if reaction_times.is_empty():
		return 0.0
	var sum := 0.0
	for v in reaction_times:
		sum += v
	return sum / reaction_times.size()


func live_stat() -> String:
	return "%d / %d DOWN" % [hits, Tuning.HOLD_ENEMIES]


func result() -> DrillResult:
	var headline := "%d of %d enemies" % [hits, Tuning.HOLD_ENEMIES]
	if friendly > 0:
		headline += ", %d friendly fire" % friendly
	else:
		headline += ", no friendly fire"
	return DrillResult.make(id, title, Tuning.holdfire_score(hits, friendly, whiffs, average_rt()), headline, {
		"hits": hits,
		"friendly": friendly,
		"whiffs": whiffs,
		"escaped": escaped,
		"avg_rt": average_rt(),
	})
